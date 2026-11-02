const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const morgan = require('morgan');
require('dotenv').config();

const { initDatabase, getPool } = require('./database');
const authRoutes = require('./routes/auth');
const libraryRoutes = require('./routes/library');
const adminRoutes = require('./routes/admin');
const telemetryRoutes = require('./routes/telemetry');
const musicRoutes = require('./routes/music');
const downloadRoutes = require('./routes/download');

const app = express();
app.set('trust proxy', 1); // Trust nginx X-Forwarded-For header for correct rate limiting and IP logging
const PORT = process.env.PORT || 4000;
const allowedOrigins = (process.env.CORS_ALLOWED_ORIGINS || '')
  .split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);

// Security Headers (Disable CSP to allow CDN album art and audio streams)
app.use(helmet({
  contentSecurityPolicy: false,
  crossOriginEmbedderPolicy: false,
}));

// Middleware
app.use(cors({
  origin: allowedOrigins.length === 0
    ? '*'
    : (origin, callback) => {
      if (!origin || allowedOrigins.includes(origin)) {
        return callback(null, true);
      }
      return callback(new Error('CORS origin not allowed'));
    },
}));
app.use(express.json({ limit: '10mb' }));
app.use(morgan('combined'));

// Rate Limiting: Brute-force protection for auth routes (20 attempts per 15 min)
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20,
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, error: 'Demasiadas solicitudes. Por favor intenta de nuevo en 15 minutos.' },
});

// General API rate limiter (400 requests per minute)
const generalLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 400,
  standardHeaders: true,
  legacyHeaders: false,
});

// Dedicated high-throughput rate limiter for real-time telemetry, long-polling, and presence (3500 req/min)
const telemetryLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 3500,
  standardHeaders: true,
  legacyHeaders: false,
});

// Health check
app.get('/api/health', (req, res) => {
  res.json({
    status: 'ok',
    service: 'Groovy Music Cloud API',
    database: 'MySQL',
    timestamp: new Date().toISOString(),
  });
});

const path = require('path');
const fs = require('fs');

// Serve compiled React frontend if present
const distPath = path.join(__dirname, '../react-website/dist');
const localDistPath = path.join(__dirname, 'public');
const staticDir = fs.existsSync(distPath) ? distPath : (fs.existsSync(localDistPath) ? localDistPath : null);

if (staticDir) {
  console.log(`📁 Serving React frontend from: ${staticDir}`);
  app.use(express.static(staticDir));
}

// Routes
app.use('/api/auth/login', authLimiter);
app.use('/api/auth/register', authLimiter);
app.use('/api/telemetry', telemetryLimiter);
app.use('/api', generalLimiter);

app.use('/api/auth', authRoutes);
app.use('/api/library', libraryRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/telemetry', telemetryRoutes);
app.use('/api/music', musicRoutes);
app.use('/api/download', downloadRoutes);

// Digital Asset Links for Android App Links auto-verification
app.get('/.well-known/assetlinks.json', (req, res) => {
  res.setHeader('Content-Type', 'application/json');
  res.json([
    {
      relation: ["delegate_permission/common.handle_all_urls"],
      target: {
        namespace: "android_app",
        package_name: "com.groovy.music",
        sha256_cert_fingerprints: [
          "9F:31:83:E2:AC:80:5D:65:86:73:02:C6:E3:27:44:03:02:04:F4:AB:92:7A:E5:1F:A7:B2:C0:46:6E:81:FB:77"
        ]
      }
    }
  ]);
});

const escapeHtml = (str) => String(str || '')
  .replace(/&/g, '&amp;')
  .replace(/</g, '&lt;')
  .replace(/>/g, '&gt;')
  .replace(/"/g, '&quot;')
  .replace(/'/g, '&#39;');

function buildLandingPage({
  type,
  id,
  title,
  subtitle,
  description,
  coverUrl,
  isRoundCover = false,
  badgeText = 'Groovy Music',
  actionText = 'Abrir en Groovy',
  pageUrl,
  deepLink,
  androidIntent
}) {
  return `<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${escapeHtml(title)} | Groovy</title>

  <!-- OpenGraph Metadata for WhatsApp / Telegram / Discord / Social Previews (Spotify style) -->
  <meta property="og:site_name" content="Groovy">
  <meta property="og:type" content="${type === 'album' ? 'music.album' : type === 'artist' ? 'profile' : 'music.song'}">
  <meta property="og:title" content="${escapeHtml(title)}">
  <meta property="og:description" content="${escapeHtml(description)}">
  <meta property="og:image" content="${escapeHtml(coverUrl)}">
  <meta property="og:image:secure_url" content="${escapeHtml(coverUrl)}">
  <meta property="og:image:type" content="image/jpeg">
  <meta property="og:image:width" content="640">
  <meta property="og:image:height" content="640">
  <meta property="og:url" content="${escapeHtml(pageUrl)}">

  <!-- Twitter Card -->
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="${escapeHtml(title)}">
  <meta name="twitter:description" content="${escapeHtml(description)}">
  <meta name="twitter:image" content="${escapeHtml(coverUrl)}">
  <meta name="theme-color" content="#1DB954">

  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      background-color: #0b0b0b;
      color: #ffffff;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      padding: 24px 16px;
      position: relative;
      overflow-x: hidden;
    }
    .background-blur {
      position: fixed;
      top: -50%;
      left: -50%;
      width: 200%;
      height: 200%;
      background-image: url('${escapeHtml(coverUrl)}');
      background-size: cover;
      background-position: center;
      filter: blur(80px) brightness(0.22);
      z-index: 0;
      pointer-events: none;
    }
    .card {
      position: relative;
      z-index: 1;
      width: 100%;
      max-width: 380px;
      background: rgba(24, 24, 27, 0.88);
      border: 1px solid rgba(255, 255, 255, 0.12);
      backdrop-filter: blur(24px);
      -webkit-backdrop-filter: blur(24px);
      border-radius: 24px;
      padding: 30px 24px;
      text-align: center;
      box-shadow: 0 20px 50px rgba(0, 0, 0, 0.6);
    }
    .badge-groovy {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      background: rgba(29, 185, 84, 0.15);
      color: #1DB954;
      font-weight: 700;
      font-size: 11px;
      letter-spacing: 1.2px;
      text-transform: uppercase;
      padding: 6px 14px;
      border-radius: 999px;
      margin-bottom: 20px;
      border: 1px solid rgba(29, 185, 84, 0.35);
    }
    .cover-container {
      width: 230px;
      height: 230px;
      margin: 0 auto 20px auto;
      border-radius: ${isRoundCover ? '50%' : '18px'};
      overflow: hidden;
      box-shadow: 0 12px 36px rgba(0, 0, 0, 0.65), 0 0 24px rgba(29, 185, 84, 0.25);
      background: #18181b;
    }
    .cover-container img {
      width: 100%;
      height: 100%;
      object-fit: cover;
      display: block;
    }
    .item-title {
      font-size: 21px;
      font-weight: 700;
      color: #ffffff;
      margin-bottom: 6px;
      line-height: 1.3;
      display: -webkit-box;
      -webkit-line-clamp: 2;
      -webkit-box-orient: vertical;
      overflow: hidden;
    }
    .item-subtitle {
      font-size: 15px;
      font-weight: 500;
      color: #a1a1aa;
      margin-bottom: 24px;
    }
    .btn-play {
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 10px;
      width: 100%;
      background: #1DB954;
      color: #000000;
      font-size: 15px;
      font-weight: 800;
      letter-spacing: 0.5px;
      text-transform: uppercase;
      text-decoration: none;
      padding: 16px 20px;
      border-radius: 999px;
      transition: transform 0.15s ease, background-color 0.15s ease, box-shadow 0.15s ease;
      box-shadow: 0 8px 24px rgba(29, 185, 84, 0.4);
      cursor: pointer;
      border: none;
    }
    .btn-play:hover {
      background: #1ed760;
      transform: scale(1.02);
      box-shadow: 0 10px 28px rgba(29, 185, 84, 0.6);
    }
    .btn-play:active {
      transform: scale(0.98);
    }
    .btn-sub {
      display: inline-block;
      margin-top: 14px;
      font-size: 13px;
      color: #71717a;
      text-decoration: none;
      transition: color 0.15s;
    }
    .btn-sub:hover {
      color: #ffffff;
      text-decoration: underline;
    }
    .hint {
      margin-top: 18px;
      font-size: 12px;
      color: #71717a;
      line-height: 1.4;
    }
    .equalizer {
      display: flex;
      align-items: flex-end;
      justify-content: center;
      gap: 3px;
      height: 16px;
      margin-bottom: 14px;
    }
    .bar {
      width: 3px;
      background: #1DB954;
      border-radius: 2px;
      animation: bounce 1.2s infinite ease-in-out;
    }
    .bar:nth-child(1) { height: 6px; animation-delay: 0.1s; }
    .bar:nth-child(2) { height: 14px; animation-delay: 0.3s; }
    .bar:nth-child(3) { height: 10px; animation-delay: 0.2s; }
    .bar:nth-child(4) { height: 16px; animation-delay: 0.4s; }
    .bar:nth-child(5) { height: 8px; animation-delay: 0.15s; }
    @keyframes bounce {
      0%, 100% { transform: scaleY(0.4); }
      50% { transform: scaleY(1.0); }
    }
  </style>
</head>
<body>
  <div class="background-blur"></div>
  <div class="card">
    <div class="badge-groovy">
      <svg width="12" height="12" viewBox="0 0 24 24" fill="currentColor">
        <path d="M12 3v10.55c-.59-.34-1.27-.55-2-.55-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4V7h4V3h-6z"/>
      </svg>
      ${escapeHtml(badgeText)}
    </div>

    <div class="cover-container">
      <img src="${escapeHtml(coverUrl)}" alt="${escapeHtml(title)}" onerror="this.src='/logo.png'">
    </div>

    <div class="equalizer">
      <div class="bar"></div>
      <div class="bar"></div>
      <div class="bar"></div>
      <div class="bar"></div>
      <div class="bar"></div>
    </div>

    <h1 class="item-title">${escapeHtml(title)}</h1>
    <div class="item-subtitle">${escapeHtml(subtitle)}</div>

    <button id="actionBtn" class="btn-play" onclick="openGroovyApp()">
      <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
        <path d="M8 5v14l11-7z"/>
      </svg>
      ${escapeHtml(actionText)}
    </button>

    <div class="hint">¿No tienes la app instalada?</div>
    <a href="/#download" class="btn-sub">Descargar Groovy gratis</a>
  </div>

  <script>
    const isAndroid = /Android/i.test(navigator.userAgent);
    const androidIntent = "${androidIntent}";
    const deepLink = "${deepLink}";

    function openGroovyApp() {
      if (isAndroid) {
        window.location.href = androidIntent;
      } else {
        window.location.href = deepLink;
      }
    }

    // Auto-launch when page is loaded (Spotify behavior)
    window.addEventListener('DOMContentLoaded', () => {
      setTimeout(openGroovyApp, 200);
    });
  </script>
</body>
</html>`;
}

// 1. Spotify-style track landing page with OpenGraph cards & instant app deep link
app.get(['/track/:id', '/song/:id'], (req, res) => {
  const rawId = req.params.id || '';
  const cleanId = rawId.replace(/^ytmusic:\/\//, '').replace(/^yt_/, '').trim();
  
  if (!cleanId) {
    return res.redirect('/');
  }

  const title = (req.query.title || 'Canción').trim();
  const artist = (req.query.artist || 'Groovy').trim();
  const album = (req.query.album || '').trim();
  const year = (req.query.year || '').trim();
  const coverUrl = req.query.cover || `https://i.ytimg.com/vi/${cleanId}/hqdefault.jpg`;
  
  // Format Spotify preview card: "Los Betos · 30 Grandes Exitos Vol. 2 · Canción · 2003"
  const description = `${artist}${album ? ' · ' + album : ''} · Canción${year ? ' · ' + year : ''}`;

  const queryParams = new URLSearchParams();
  if (title) queryParams.set('title', title);
  if (artist) queryParams.set('artist', artist);
  if (album) queryParams.set('album', album);
  if (year) queryParams.set('year', year);
  if (req.query.cover) queryParams.set('cover', req.query.cover);
  const qStr = queryParams.toString() ? `?${queryParams.toString()}` : '';

  const pageUrl = `https://groovyapi.duckdns.org/track/${cleanId}${qStr}`;
  const deepLink = `groovy://track/${cleanId}${qStr}`;
  const androidIntent = `intent://track/${cleanId}${qStr}#Intent;scheme=groovy;package=com.groovy.music;S.browser_fallback_url=${encodeURIComponent(pageUrl)};end`;

  const html = buildLandingPage({
    type: 'track',
    id: cleanId,
    title,
    subtitle: artist,
    description,
    coverUrl,
    isRoundCover: false,
    badgeText: 'Groovy Music',
    actionText: 'Reproducir en Groovy',
    pageUrl,
    deepLink,
    androidIntent
  });

  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.send(html);
});

// 2. Spotify-style album landing page
app.get('/album/:id', (req, res) => {
  const rawId = req.params.id || '';
  const cleanId = rawId.trim();
  
  if (!cleanId) {
    return res.redirect('/');
  }

  const title = (req.query.title || req.query.name || 'Álbum').trim();
  const artist = (req.query.artist || 'Groovy').trim();
  const year = (req.query.year || '').trim();
  const coverUrl = req.query.cover || req.query.image || 'https://groovyapi.duckdns.org/assets/groovy-logo.png';

  // Format Spotify preview card: "Los Betos · Álbum · 2003 · Groovy"
  const description = `${artist} · Álbum${year ? ' · ' + year : ''} · Groovy`;

  const queryParams = new URLSearchParams();
  if (title) queryParams.set('title', title);
  if (artist) queryParams.set('artist', artist);
  if (year) queryParams.set('year', year);
  if (req.query.cover) queryParams.set('cover', req.query.cover);
  const qStr = queryParams.toString() ? `?${queryParams.toString()}` : '';

  const pageUrl = `https://groovyapi.duckdns.org/album/${cleanId}${qStr}`;
  const deepLink = `groovy://album/${cleanId}${qStr}`;
  const androidIntent = `intent://album/${cleanId}${qStr}#Intent;scheme=groovy;package=com.groovy.music;S.browser_fallback_url=${encodeURIComponent(pageUrl)};end`;

  const html = buildLandingPage({
    type: 'album',
    id: cleanId,
    title,
    subtitle: `${artist}${year ? ' • ' + year : ''}`,
    description,
    coverUrl,
    isRoundCover: false,
    badgeText: 'Álbum',
    actionText: 'Abrir Álbum en Groovy',
    pageUrl,
    deepLink,
    androidIntent
  });

  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.send(html);
});

// 3. Spotify-style artist landing page
app.get('/artist/:id', (req, res) => {
  const rawId = req.params.id || '';
  const cleanId = rawId.trim();
  
  if (!cleanId) {
    return res.redirect('/');
  }

  const name = (req.query.name || req.query.title || 'Artista').trim();
  const imageUrl = req.query.image || req.query.cover || 'https://groovyapi.duckdns.org/assets/groovy-logo.png';
  const description = `Artista · Groovy`;

  const queryParams = new URLSearchParams();
  if (name) queryParams.set('name', name);
  if (req.query.image) queryParams.set('image', req.query.image);
  const qStr = queryParams.toString() ? `?${queryParams.toString()}` : '';

  const pageUrl = `https://groovyapi.duckdns.org/artist/${cleanId}${qStr}`;
  const deepLink = `groovy://artist/${cleanId}${qStr}`;
  const androidIntent = `intent://artist/${cleanId}${qStr}#Intent;scheme=groovy;package=com.groovy.music;S.browser_fallback_url=${encodeURIComponent(pageUrl)};end`;

  const html = buildLandingPage({
    type: 'artist',
    id: cleanId,
    title: name,
    subtitle: 'Artista',
    description,
    coverUrl: imageUrl,
    isRoundCover: true,
    badgeText: 'Artista',
    actionText: 'Ver Artista en Groovy',
    pageUrl,
    deepLink,
    androidIntent
  });

  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.send(html);
});

// SPA fallback: Return index.html for all frontend routes (excluding /api)
app.get('*', (req, res) => {
  if (req.path.startsWith('/api')) {
    return res.status(404).json({ error: 'API endpoint not found' });
  }
  if (staticDir && fs.existsSync(path.join(staticDir, 'index.html'))) {
    return res.sendFile(path.join(staticDir, 'index.html'));
  }
  res.send('🎵 Groovy Cloud Music API is running! (Frontend build not found)');
});

// Start server after DB is ready
async function startServer() {
  try {
    await initDatabase();
    app.listen(PORT, '0.0.0.0', () => {
      console.log(`🚀 Groovy Cloud API listening on http://0.0.0.0:${PORT}`);
    });

    // Periodically prune stale presence records older than 10 minutes (every 5 minutes)
    setInterval(async () => {
      try {
        const pool = getPool();
        if (pool) {
          await pool.query('DELETE FROM user_live_playback WHERE last_ping_at < NOW() - INTERVAL 10 MINUTE');
        }
      } catch (_) {}
    }, 5 * 60 * 1000);
  } catch (err) {
    console.error('❌ Failed to start Groovy server:', err);
    process.exit(1);
  }
}

startServer();
