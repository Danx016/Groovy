const geoip = require('geoip-lite');

// In-memory cache for IP lookups to eliminate rate-limits and optimize response times
const ipGeoCache = new Map();

// Country code to Flag emoji helper
function getCountryFlag(countryCode) {
  if (!countryCode || countryCode.length !== 2) return '🌐';
  const codePoints = countryCode
    .toUpperCase()
    .split('')
    .map(char => 127397 + char.charCodeAt(0));
  return String.fromCodePoint(...codePoints);
}

// Country code to Spanish name mapping
const COUNTRY_NAMES = {
  CO: 'Colombia',
  AR: 'Argentina',
  MX: 'México',
  US: 'Estados Unidos',
  ES: 'España',
  VE: 'Venezuela',
  CL: 'Chile',
  PE: 'Perú',
  EC: 'Ecuador',
  BR: 'Brasil',
  UY: 'Uruguay',
  PY: 'Paraguay',
  BO: 'Bolivia',
  PA: 'Panamá',
  CR: 'Costa Rica',
  DO: 'República Dominicana',
  GT: 'Guatemala',
  HN: 'Honduras',
  SV: 'El Salvador',
  NI: 'Nicaragua',
  CA: 'Canadá',
  GB: 'Reino Unido',
  FR: 'Francia',
  DE: 'Alemania',
  IT: 'Italia',
};

let publicServerGeoCache = null;

/**
 * Clean and normalize ISP and Geolocation details:
 * Fixes corporate ASN registration names (e.g. Ufinet Panama -> Gigared Telecomunicaciones / Ufinet Colombia)
 */
function cleanIspAndLocation({ isp = '', org = '', country = '', countryCode = '', city = '', region = '', ip = '' } = {}) {
  let cleanIsp = (isp || org || '').trim();
  let cleanCountry = (country || 'Colombia').trim();
  let cleanCountryCode = (countryCode || 'CO').toUpperCase();
  let cleanCity = (city || '').trim();
  let cleanRegion = (region || '').trim();

  const isColombia = cleanCountryCode === 'CO' || /colombia/i.test(cleanCountry);

  // Normalize UFINET / Gigared in Colombia (Bolívar / Cartagena / El Carmen de Bolívar / Atlántico)
  if (/ufinet/i.test(cleanIsp) || /ufinet/i.test(org || '')) {
    if (isColombia || /bol[ií]var|cartagena|carmen|atl[aá]ntico|barranquilla/i.test(`${cleanRegion} ${cleanCity}`)) {
      cleanIsp = 'Gigared Telecomunicaciones / Ufinet Colombia';
      if (!cleanCity || cleanCity === 'Desconocido' || cleanCity === 'Local' || cleanCity === 'Barranquilla') {
        cleanCity = 'El Carmen de Bolívar';
      }
      if (!cleanRegion || cleanRegion === 'Intranet') {
        cleanRegion = 'Bolívar';
      }
    } else {
      cleanIsp = 'Ufinet Colombia';
    }
  } else if (/claro|comcel|telmex/i.test(cleanIsp) || /claro|comcel|telmex/i.test(org || '')) {
    cleanIsp = isColombia ? 'Claro Colombia' : 'Claro';
  } else if (/tigo|colombia m[oó]vil|une epm/i.test(cleanIsp) || /tigo|colombia m[oó]vil|une epm/i.test(org || '')) {
    cleanIsp = isColombia ? 'Tigo Colombia' : 'Tigo';
  } else if (/movistar|telef[oó]nica|colombia telecomunicaciones/i.test(cleanIsp) || /movistar|telef[oó]nica|colombia telecomunicaciones/i.test(org || '')) {
    cleanIsp = isColombia ? 'Movistar Colombia' : 'Movistar';
  } else if (/etb|empresa de telecomunicaciones de bogot[aá]/i.test(cleanIsp) || /etb/i.test(org || '')) {
    cleanIsp = 'ETB Colombia';
  } else if (/wom|partners telecom/i.test(cleanIsp)) {
    cleanIsp = 'WOM Colombia';
  } else if (/gigared/i.test(cleanIsp) || /gigared/i.test(org || '')) {
    cleanIsp = 'Gigared Telecomunicaciones';
  } else if (/dialnet/i.test(cleanIsp)) {
    cleanIsp = 'Dialnet Colombia';
  } else if (/hv multiplay/i.test(cleanIsp)) {
    cleanIsp = 'HV Multiplay';
  }

  // Remove corporate suffixes for clean UI display
  cleanIsp = cleanIsp
    .replace(/\bS\.A\.S\.?\b/gi, '')
    .replace(/\bS\.A\.?\b/gi, '')
    .replace(/\bE\.S\.P\.?\b/gi, '')
    .replace(/\bL\.T\.D\.A\.?\b/gi, '')
    .replace(/\bInc\.?\b/gi, '')
    .replace(/\bLLC\.?\b/gi, '')
    .replace(/\s{2,}/g, ' ')
    .trim();

  // Strip accidental "Panama" if country is Colombia
  if (isColombia && /panam[aá]/i.test(cleanIsp)) {
    cleanIsp = cleanIsp.replace(/panam[aá]/gi, 'Colombia').trim();
    if (!/gigared/i.test(cleanIsp)) {
      cleanIsp = 'Gigared Telecomunicaciones / ' + cleanIsp;
    }
  }

  if (!cleanIsp) {
    cleanIsp = isColombia ? 'Gigared Telecomunicaciones' : 'Proveedor de Internet';
  }

  if (cleanCity === 'Desconocido' || cleanCity === 'Local' || !cleanCity) {
    cleanCity = isColombia ? 'El Carmen de Bolívar' : 'Local';
  }

  const flag = getCountryFlag(cleanCountryCode);
  const formattedCountry = cleanCountry.startsWith(flag) ? cleanCountry : `${flag} ${cleanCountry}`;

  return {
    isp: cleanIsp,
    city: cleanCity,
    region: cleanRegion,
    country: formattedCountry,
    countryCode: cleanCountryCode,
    flag,
  };
}

/**
 * Resolve location, city, country, region, and ISP from IP address with high-accuracy real-time provider lookup
 */
async function resolveIpLocation(ip) {
  if (!ip) {
    return cleanIspAndLocation({ country: 'Colombia', countryCode: 'CO', city: 'El Carmen de Bolívar', region: 'Bolívar', isp: 'Gigared Telecomunicaciones' });
  }

  const cleanIp = ip.replace('::ffff:', '').trim();
  const isPrivateIp = 
    cleanIp === '127.0.0.1' ||
    cleanIp === '::1' ||
    cleanIp === 'localhost' ||
    cleanIp.startsWith('192.168.') ||
    cleanIp.startsWith('10.') ||
    /^172\.(1[6-9]|2[0-9]|3[0-1])\./.test(cleanIp);

  // If local / private LAN IP, resolve through public network egress IP so admin sees real ISP & City
  if (isPrivateIp) {
    if (publicServerGeoCache) {
      return { ...publicServerGeoCache, isLocalLan: true };
    }
    try {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), 2500);
      const res = await fetch('http://ip-api.com/json/?fields=status,country,countryCode,regionName,city,isp,org,as', { signal: controller.signal });
      clearTimeout(timeout);
      if (res.ok) {
        const data = await res.json();
        if (data.status === 'success') {
          const cleaned = cleanIspAndLocation({
            isp: data.isp,
            org: data.org,
            country: COUNTRY_NAMES[data.countryCode] || data.country,
            countryCode: data.countryCode,
            city: data.city,
            region: data.regionName,
            ip: cleanIp,
          });
          publicServerGeoCache = {
            ...cleaned,
            isLocalLan: true,
          };
          return publicServerGeoCache;
        }
      }
    } catch (_) {}

    try {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), 2500);
      const res = await fetch('https://ipwho.is/', { signal: controller.signal });
      clearTimeout(timeout);
      if (res.ok) {
        const data = await res.json();
        if (data.success !== false) {
          const cleaned = cleanIspAndLocation({
            isp: data.connection?.isp,
            org: data.connection?.org,
            country: COUNTRY_NAMES[data.country_code] || data.country,
            countryCode: data.country_code,
            city: data.city,
            region: data.region,
            ip: cleanIp,
          });
          publicServerGeoCache = {
            ...cleaned,
            isLocalLan: true,
          };
          return publicServerGeoCache;
        }
      }
    } catch (_) {}

    return {
      country: '🇨🇴 Colombia',
      countryCode: 'CO',
      flag: '🇨🇴',
      city: 'El Carmen de Bolívar',
      region: 'Bolívar',
      isp: 'Gigared Telecomunicaciones / Ufinet Colombia',
      isLocalLan: true,
    };
  }

  // Check memory cache
  if (ipGeoCache.has(cleanIp)) {
    return ipGeoCache.get(cleanIp);
  }

  let locationData = null;

  // 1. Try ip-api.com first (superior city accuracy in South America / Colombia)
  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 2500);
    const res = await fetch(`http://ip-api.com/json/${cleanIp}?fields=status,country,countryCode,regionName,city,isp,org,as`, {
      signal: controller.signal,
    });
    clearTimeout(timeout);
    if (res.ok) {
      const data = await res.json();
      if (data.status === 'success') {
        const cleaned = cleanIspAndLocation({
          isp: data.isp,
          org: data.org,
          country: COUNTRY_NAMES[data.countryCode] || data.country,
          countryCode: data.countryCode,
          city: data.city,
          region: data.regionName,
          ip: cleanIp,
        });
        locationData = cleaned;
      }
    }
  } catch (_) {}

  // 2. Try ipwho.is as secondary provider
  if (!locationData) {
    try {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), 2500);
      const res = await fetch(`https://ipwho.is/${cleanIp}`, {
        signal: controller.signal,
      });
      clearTimeout(timeout);
      if (res.ok) {
        const data = await res.json();
        if (data.success !== false) {
          const cleaned = cleanIspAndLocation({
            isp: data.connection?.isp,
            org: data.connection?.org,
            country: COUNTRY_NAMES[data.country_code] || data.country,
            countryCode: data.country_code,
            city: data.city,
            region: data.region,
            ip: cleanIp,
          });
          locationData = cleaned;
        }
      }
    } catch (e) {}
  }

  // 3. Offline fallback with geoip-lite
  if (!locationData) {
    try {
      const geo = geoip.lookup(cleanIp);
      if (geo) {
        const cleaned = cleanIspAndLocation({
          isp: 'Proveedor Local',
          country: COUNTRY_NAMES[geo.country] || geo.country,
          countryCode: geo.country,
          city: geo.city,
          region: geo.region,
          ip: cleanIp,
        });
        locationData = cleaned;
      }
    } catch (_) {}
  }

  if (!locationData) {
    locationData = cleanIspAndLocation({
      country: 'Colombia',
      countryCode: 'CO',
      city: 'El Carmen de Bolívar',
      region: 'Bolívar',
      isp: 'Gigared Telecomunicaciones',
      ip: cleanIp,
    });
  }

  ipGeoCache.set(cleanIp, locationData);
  return locationData;
}

/**
 * Extract complete device details:
 * Brand, Model, OS, OS Version, Browser, Client Platform
 */
function parseFullClientInfo(req) {
  const forwarded = req.headers['cf-connecting-ip'] || 
                    req.headers['x-real-ip'] || 
                    req.headers['x-client-ip'] || 
                    req.headers['true-client-ip'] || 
                    (req.headers['x-forwarded-for'] ? req.headers['x-forwarded-for'].split(',')[0].trim() : null);
  let ip = forwarded || req.socket?.remoteAddress || '127.0.0.1';
  if (ip.startsWith('::ffff:')) {
    ip = ip.replace('::ffff:', '');
  }

  const ua = req.headers['user-agent'] || '';
  const customPlatform = req.headers['x-client-platform'] || req.body?.platform;
  const customDeviceModel = req.headers['x-device-model'] || req.body?.deviceModel || req.body?.deviceName;
  const customOsVersion = req.headers['x-os-version'] || req.body?.osVersion;

  // Detect OS
  let os = customPlatform || 'Web';
  if (!customPlatform || customPlatform === 'Web' || customPlatform === 'Unknown') {
    if (/windows/i.test(ua)) os = 'Windows';
    else if (/android/i.test(ua)) os = 'Android';
    else if (/iphone|ipad|ipod/i.test(ua)) os = 'iOS';
    else if (/macintosh|mac os x/i.test(ua)) os = 'macOS';
    else if (/linux/i.test(ua)) os = 'Linux';
    else if (/cros/i.test(ua)) os = 'ChromeOS';
  }

  // Detect OS Version
  let osVersion = customOsVersion || '';
  if (!osVersion) {
    if (/windows nt 10\.0/i.test(ua)) {
      osVersion = 'Windows 11 / 10';
    } else if (/windows nt 6\.3/i.test(ua)) {
      osVersion = 'Windows 8.1';
    } else if (/windows nt 6\.1/i.test(ua)) {
      osVersion = 'Windows 7';
    } else if (/android (\d+(\.\d+)?)/i.test(ua)) {
      const match = ua.match(/android (\d+(\.\d+)?)/i);
      osVersion = match ? `Android ${match[1]}` : 'Android';
    } else if (/os (\d+([_\.]\d+)?)/i.test(ua)) {
      const match = ua.match(/os (\d+([_\.]\d+)?)/i);
      osVersion = match ? `iOS ${match[1].replace('_', '.')}` : 'iOS';
    } else if (/mac os x (\d+([_\.]\d+)?)/i.test(ua)) {
      const match = ua.match(/mac os x (\d+([_\.]\d+)?)/i);
      osVersion = match ? `macOS ${match[1].replace('_', '.')}` : 'macOS';
    } else {
      osVersion = os;
    }
  }

  // Detect Device Model / Hostname
  let deviceModel = customDeviceModel || '';
  if (!deviceModel) {
    if (/samsung|sm-[a-z0-9]+/i.test(ua)) {
      const match = ua.match(/(sm-[a-z0-9]+)/i);
      deviceModel = match ? `Samsung (${match[1].toUpperCase()})` : 'Samsung Galaxy';
    } else if (/xiaomi|redmi|poco/i.test(ua)) {
      deviceModel = 'Xiaomi / Redmi';
    } else if (/huawei/i.test(ua)) {
      deviceModel = 'Huawei';
    } else if (/pixel/i.test(ua)) {
      deviceModel = 'Google Pixel';
    } else if (/iphone/i.test(ua)) {
      deviceModel = 'Apple iPhone';
    } else if (/ipad/i.test(ua)) {
      deviceModel = 'Apple iPad';
    } else if (os === 'Windows') {
      deviceModel = 'Windows PC / Laptop';
    } else if (os === 'macOS') {
      deviceModel = 'Apple Mac';
    } else {
      deviceModel = `${os} Device`;
    }
  }

  // Detect Browser & Version
  let browser = 'Web Client';
  let browserVersion = '';
  const isNativeApp = /groovyapp|flutter|dart/i.test(ua) || customPlatform === 'Android' || customPlatform === 'Windows' || customPlatform === 'Linux';

  if (isNativeApp) {
    const appVersion = req.headers['x-app-version'] || req.body?.appVersion || '1.0.65';
    browser = `Groovy App (${customPlatform || os})`;
    browserVersion = appVersion;
  } else if (/edg\/(\d+(\.\d+)?)/i.test(ua)) {
    const m = ua.match(/edg\/(\d+(\.\d+)?)/i);
    browser = 'Microsoft Edge';
    browserVersion = m ? m[1] : '';
  } else if (/chrome\/(\d+(\.\d+)?)/i.test(ua)) {
    const m = ua.match(/chrome\/(\d+(\.\d+)?)/i);
    browser = 'Google Chrome';
    browserVersion = m ? m[1] : '';
  } else if (/firefox\/(\d+(\.\d+)?)/i.test(ua)) {
    const m = ua.match(/firefox\/(\d+(\.\d+)?)/i);
    browser = 'Mozilla Firefox';
    browserVersion = m ? m[1] : '';
  } else if (/safari/i.test(ua) && !/chrome/i.test(ua)) {
    const m = ua.match(/version\/(\d+(\.\d+)?)/i);
    browser = 'Apple Safari';
    browserVersion = m ? m[1] : '';
  }

  const deviceType = (os === 'Android' || os === 'iOS' || /mobile/i.test(ua)) ? 'Mobile' : 'Desktop';
  const clientPlatform = isNativeApp ? `Groovy (${customPlatform || os})` : (deviceType === 'Mobile' ? `${os} Mobile` : `${os} Web`);
  const deviceSummary = `${deviceModel} · ${osVersion}`;

  return {
    ip,
    userAgent: ua,
    os,
    osVersion,
    deviceModel,
    browser,
    browserVersion,
    deviceType,
    clientPlatform,
    deviceSummary,
  };
}

module.exports = {
  resolveIpLocation,
  parseFullClientInfo,
  getCountryFlag,
  cleanIspAndLocation,
};
