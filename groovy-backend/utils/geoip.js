const geoip = require('geoip-lite');

// In-memory cache for IP lookups to avoid rate-limiting
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

let publicServerGeoCache = null;

/**
 * Resolve real location, city, country, region, and ISP from IP address using real-time geolocation providers
 */
async function resolveIpLocation(ip) {
  if (!ip) {
    return {
      country: 'Desconocido',
      countryCode: 'XX',
      flag: '🌐',
      city: 'Desconocido',
      region: '',
      isp: 'Desconocido',
    };
  }

  const cleanIp = ip.replace('::ffff:', '').trim();
  const isPrivateIp = 
    cleanIp === '127.0.0.1' ||
    cleanIp === '::1' ||
    cleanIp === 'localhost' ||
    cleanIp.startsWith('192.168.') ||
    cleanIp.startsWith('10.') ||
    /^172\.(1[6-9]|2[0-9]|3[0-1])\./.test(cleanIp);

  // If local / private LAN IP, query the real public egress IP dynamically
  if (isPrivateIp) {
    if (publicServerGeoCache) {
      return { ...publicServerGeoCache, isLocalLan: true };
    }
    try {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), 3000);
      const res = await fetch('http://ip-api.com/json/?fields=status,country,countryCode,regionName,city,isp,org,as,query', { signal: controller.signal });
      clearTimeout(timeout);
      if (res.ok) {
        const data = await res.json();
        if (data.status === 'success') {
          const flag = getCountryFlag(data.countryCode);
          publicServerGeoCache = {
            country: `${flag} ${data.country}`,
            countryCode: data.countryCode,
            flag,
            city: data.city || 'Desconocido',
            region: data.regionName || '',
            isp: data.org || data.isp || 'Desconocido',
            realIp: data.query,
            isLocalLan: true,
          };
          return publicServerGeoCache;
        }
      }
    } catch (_) {}

    try {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), 3000);
      const res = await fetch('https://ipwho.is/', { signal: controller.signal });
      clearTimeout(timeout);
      if (res.ok) {
        const data = await res.json();
        if (data.success !== false) {
          const flag = data.flag?.emoji || getCountryFlag(data.country_code);
          publicServerGeoCache = {
            country: `${flag} ${data.country}`,
            countryCode: data.country_code,
            flag,
            city: data.city || 'Desconocido',
            region: data.region || '',
            isp: data.connection?.org || data.connection?.isp || 'Desconocido',
            realIp: data.ip,
            isLocalLan: true,
          };
          return publicServerGeoCache;
        }
      }
    } catch (_) {}

    return {
      country: 'Red Local',
      countryCode: 'LAN',
      flag: '🏠',
      city: 'Localhost',
      region: '',
      isp: 'Red Local',
      isLocalLan: true,
    };
  }

  // Check cache
  if (ipGeoCache.has(cleanIp)) {
    return ipGeoCache.get(cleanIp);
  }

  let locationData = null;

  // 1. Query real provider: ip-api.com
  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 3000);
    const res = await fetch(`http://ip-api.com/json/${cleanIp}?fields=status,country,countryCode,regionName,city,isp,org,as`, {
      signal: controller.signal,
    });
    clearTimeout(timeout);
    if (res.ok) {
      const data = await res.json();
      if (data.status === 'success') {
        const flag = getCountryFlag(data.countryCode);
        locationData = {
          country: `${flag} ${data.country}`,
          countryCode: data.countryCode,
          flag,
          city: data.city || 'Desconocido',
          region: data.regionName || '',
          isp: data.org || data.isp || 'Desconocido',
        };
      }
    }
  } catch (_) {}

  // 2. Query real provider: ipwho.is
  if (!locationData) {
    try {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), 3000);
      const res = await fetch(`https://ipwho.is/${cleanIp}`, {
        signal: controller.signal,
      });
      clearTimeout(timeout);
      if (res.ok) {
        const data = await res.json();
        if (data.success !== false) {
          const flag = data.flag?.emoji || getCountryFlag(data.country_code);
          locationData = {
            country: `${flag} ${data.country}`,
            countryCode: data.country_code,
            flag,
            city: data.city || 'Desconocido',
            region: data.region || '',
            isp: data.connection?.org || data.connection?.isp || 'Desconocido',
          };
        }
      }
    } catch (_) {}
  }

  // 3. Fallback: geoip-lite
  if (!locationData) {
    try {
      const geo = geoip.lookup(cleanIp);
      if (geo) {
        const flag = getCountryFlag(geo.country);
        locationData = {
          country: `${flag} ${geo.country}`,
          countryCode: geo.country,
          flag,
          city: geo.city || 'Desconocido',
          region: geo.region || '',
          isp: 'Desconocido',
        };
      }
    } catch (_) {}
  }

  if (!locationData) {
    locationData = {
      country: 'Desconocido',
      countryCode: 'XX',
      flag: '🌐',
      city: 'Desconocido',
      region: '',
      isp: 'Desconocido',
    };
  }

  ipGeoCache.set(cleanIp, locationData);
  return locationData;
}

/**
 * Extract genuine client info directly from request headers and User-Agent without inventing fake data
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
  const customAppVersion = req.headers['x-app-version'] || req.body?.appVersion;

  // 1. Detect Real OS
  let os = customPlatform || '';
  if (!os || os === 'Unknown' || os === 'Web') {
    if (/windows/i.test(ua)) os = 'Windows';
    else if (/android/i.test(ua)) os = 'Android';
    else if (/iphone|ipad|ipod/i.test(ua)) os = 'iOS';
    else if (/macintosh|mac os x/i.test(ua)) os = 'macOS';
    else if (/linux/i.test(ua)) os = 'Linux';
    else if (/cros/i.test(ua)) os = 'ChromeOS';
    else os = 'Web';
  }

  // 2. Detect Real OS Version
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

  // 3. Detect Real Device Model (from custom headers sent by app or extracted from UA)
  let deviceModel = (customDeviceModel || '').trim();
  if (!deviceModel) {
    const androidModelMatch = ua.match(/;\s*([^;]+?)\s*Build\//i);
    if (androidModelMatch && androidModelMatch[1]) {
      deviceModel = androidModelMatch[1].trim();
    } else if (os === 'Windows') {
      deviceModel = 'Windows PC / Laptop';
    } else if (os === 'macOS') {
      deviceModel = 'Mac';
    } else if (os === 'iOS') {
      deviceModel = /ipad/i.test(ua) ? 'iPad' : 'iPhone';
    } else if (os === 'Android') {
      deviceModel = 'Dispositivo Android';
    } else {
      deviceModel = 'Dispositivo';
    }
  }

  // Deduplicate repeated brand prefix e.g. "Infinix Infinix X678B" -> "Infinix X678B"
  if (deviceModel) {
    const words = deviceModel.split(/\s+/);
    if (words.length >= 2 && words[0].toLowerCase() === words[1].toLowerCase()) {
      deviceModel = words.slice(1).join(' ');
    }
  }

  // 4. Detect Real Browser / App
  let browser = 'Web Client';
  let browserVersion = '';
  const isNativeApp = /groovy|flutter|dart/i.test(ua) || customPlatform === 'Android' || customPlatform === 'Windows' || customPlatform === 'Linux';

  if (isNativeApp) {
    browser = `Groovy App (${customPlatform || os})`;
    browserVersion = customAppVersion || '1.0.65';
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
  const deviceSummary = osVersion && osVersion !== deviceModel ? `${deviceModel} · ${osVersion}` : deviceModel;

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
};
