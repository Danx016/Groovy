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

/**
 * Resolve location, city, country, region, and ISP from IP address
 */
async function resolveIpLocation(ip) {
  if (!ip) {
    return { country: 'Desconocido', countryCode: 'XX', flag: '🌐', city: 'Desconocido', region: '', isp: '' };
  }

  // Handle local / private networks
  const cleanIp = ip.replace('::ffff:', '').trim();
  if (
    cleanIp === '127.0.0.1' ||
    cleanIp === '::1' ||
    cleanIp === 'localhost' ||
    cleanIp.startsWith('192.168.') ||
    cleanIp.startsWith('10.') ||
    cleanIp.startsWith('172.16.') ||
    cleanIp.startsWith('172.17.') ||
    cleanIp.startsWith('172.18.') ||
    cleanIp.startsWith('172.19.')
  ) {
    return {
      country: 'Red Local / Servidor',
      countryCode: 'LAN',
      flag: '🏠',
      city: 'Localhost',
      region: 'Intranet',
      isp: 'Red Local Privada',
    };
  }

  // Check memory cache
  if (ipGeoCache.has(cleanIp)) {
    return ipGeoCache.get(cleanIp);
  }

  let locationData = null;

  // 1. Try ip-api.com (has ISP, City, and Region name)
  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 2000);
    const res = await fetch(`http://ip-api.com/json/${cleanIp}?fields=status,country,countryCode,regionName,city,isp`, {
      signal: controller.signal,
    });
    clearTimeout(timeout);
    if (res.ok) {
      const data = await res.json();
      if (data.status === 'success') {
        const flag = getCountryFlag(data.countryCode);
        const countryName = COUNTRY_NAMES[data.countryCode] || data.country;
        locationData = {
          country: `${flag} ${countryName}`,
          countryCode: data.countryCode,
          flag,
          city: data.city || 'Desconocido',
          region: data.regionName || '',
          isp: data.isp || '',
        };
      }
    }
  } catch (e) {
    // Network timeout or offline, fallback to geoip-lite below
  }

  // 2. Offline fallback with geoip-lite
  if (!locationData) {
    try {
      const geo = geoip.lookup(cleanIp);
      if (geo) {
        const flag = getCountryFlag(geo.country);
        const countryName = COUNTRY_NAMES[geo.country] || geo.country;
        locationData = {
          country: `${flag} ${countryName}`,
          countryCode: geo.country,
          flag,
          city: geo.city || 'Desconocido',
          region: geo.region || '',
          isp: '',
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
      isp: '',
    };
  }

  ipGeoCache.set(cleanIp, locationData);
  return locationData;
}

/**
 * Extract complete device details:
 * Brand, Model, OS, OS Version, Browser, Client Platform
 */
function parseFullClientInfo(req) {
  const forwarded = req.headers['x-forwarded-for'];
  let ip = forwarded ? forwarded.split(',')[0].trim() : (req.headers['x-real-ip'] || req.socket?.remoteAddress || '127.0.0.1');
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
  if (/edg\/(\d+(\.\d+)?)/i.test(ua)) {
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
  } else if (/dart|flutter/i.test(ua)) {
    browser = 'Groovy Native App';
    browserVersion = '1.0.65';
  }

  const deviceType = (os === 'Android' || os === 'iOS' || /mobile/i.test(ua)) ? 'Mobile' : 'Desktop';
  const clientPlatform = customPlatform ? `Groovy (${customPlatform})` : (deviceType === 'Mobile' ? `${os} Mobile` : `${os} Web`);
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
};
