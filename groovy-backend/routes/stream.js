const express = require('express');
const router = express.Router();
const path = require('path');
const fs = require('fs');
const { spawn } = require('child_process');

// In-memory stream cache: videoId/songId -> { ts, data }
const streamCache = new Map();
const STREAM_CACHE_TTL = 5.5 * 60 * 60 * 1000; // 5.5 hours

// Song ID to Video ID map (for Deezer dz_..., etc.): songId -> videoId
const songToVideoMap = new Map();

// In-flight deduplication: key -> Promise
const inFlight = new Map();

// Find yt-dlp path
function getYtDlpPath() {
  const candidates = [
    '/usr/local/bin/yt-dlp',
    '/usr/bin/yt-dlp',
    path.resolve(__dirname, '../yt-dlp'),
    path.resolve(__dirname, './yt-dlp'),
    'yt-dlp',
  ];
  for (const p of candidates) {
    if (fs.existsSync(p)) return p;
  }
  return 'yt-dlp';
}

const ytDlpPath = getYtDlpPath();

// Find cookies.txt
function getCookiesPath() {
  const candidates = [
    path.resolve(__dirname, 'cookies.txt'),
    path.resolve(__dirname, '../cookies.txt'),
    '/home/ubuntu/Groovy/cookies.txt',
    '/home/ubuntu/cookies.txt',
  ];
  for (const c of candidates) {
    if (fs.existsSync(c)) return c;
  }
  return null;
}

const cookiesPath = getCookiesPath();

/**
 * Clean ID helper
 */
function cleanVideoId(rawId) {
  if (!rawId) return '';
  return String(rawId)
    .replace('ytmusic://', '')
    .replace('yt_', '')
    .trim();
}

/**
 * Resolve video ID for non-YouTube ID using YouTube Music Innertube search
 */
async function resolveVideoId(songId, title, artist) {
  const clean = cleanVideoId(songId);
  if (/^[a-zA-Z0-9_-]{11}$/.test(clean)) {
    return clean;
  }

  if (songToVideoMap.has(songId)) {
    return songToVideoMap.get(songId);
  }

  // Construct search query
  let query = (title || '').trim();
  if (artist && artist !== 'Unknown Artist') {
    query = `${query} ${artist}`.trim();
  }
  if (!query) query = clean;

  try {
    const searchBody = JSON.stringify({
      context: {
        client: {
          clientName: 'WEB_REMIX',
          clientVersion: '1.20240101.01.00',
        },
      },
      query: query,
      params: 'Eg-KAQwIABAAGAAgACgAMABqChAGMAVCAggCUAEYAA%3D%3D',
    });

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 2500);
    const resp = await fetch('https://music.youtube.com/youtubei/v1/search', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Origin': 'https://music.youtube.com',
        'Referer': 'https://music.youtube.com/',
      },
      body: searchBody,
      signal: controller.signal,
    });
    clearTimeout(timeout);

    if (resp.ok) {
      const json = await resp.json();
      const sections = json?.contents?.tabbedSearchResultsRenderer?.tabs?.[0]?.tabRenderer?.content?.sectionListRenderer?.contents || [];
      for (const sec of sections) {
        const shelf = sec?.musicShelfRenderer || sec?.musicCardShelfRenderer;
        const contents = shelf?.contents || [];
        for (const item of contents) {
          const flex = item?.musicResponsiveListItemRenderer;
          const navEndpoint = flex?.overlay?.musicItemThumbnailOverlayRenderer?.content?.musicPlayButtonRenderer?.playNavigationEndpoint;
          const vid = navEndpoint?.watchEndpoint?.videoId;
          if (vid && /^[a-zA-Z0-9_-]{11}$/.test(vid)) {
            songToVideoMap.set(songId, vid);
            return vid;
          }
        }
      }
    }
  } catch (_) {}

  // Fallback: fast search via yt-dlp --get-id
  try {
    const vid = await new Promise((resolve) => {
      const searchArgs = ['--get-id', '--no-warnings', '--no-playlist'];
      if (cookiesPath) searchArgs.push('--cookies', cookiesPath);
      searchArgs.push(`ytsearch1:${query}`);
      const proc = spawn(ytDlpPath, searchArgs);
      let out = '';
      const t = setTimeout(() => {
        try { proc.kill('SIGKILL'); } catch (_) {}
        resolve('');
      }, 8000);
      proc.stdout.on('data', d => out += d);
      proc.on('close', () => {
        clearTimeout(t);
        const trimmed = out.trim();
        const match = trimmed.match(/[a-zA-Z0-9_-]{11}/);
        resolve(match ? match[0] : '');
      });
      proc.on('error', () => {
        clearTimeout(t);
        resolve('');
      });
    });
    if (vid) {
      songToVideoMap.set(songId, vid);
      return vid;
    }
  } catch (_) {}

  return '';
}

/**
 * Extract audio stream info via yt-dlp
 */
function extractStreamInfo(videoId) {
  return new Promise((resolve, reject) => {
    const args = [
      '-j',
      '-f', '140/251/ba/bestaudio',
      '--no-playlist',
      '--no-warnings',
      '--no-check-certificates',
      '--skip-download',
    ];

    if (cookiesPath) {
      args.push('--cookies', cookiesPath);
    }

    args.push(`https://www.youtube.com/watch?v=${videoId}`);

    const child = spawn(ytDlpPath, args);
    let stdout = '';
    let stderr = '';

    const timer = setTimeout(() => {
      try { child.kill('SIGKILL'); } catch (_) {}
      reject(new Error('yt-dlp extraction timed out (8s)'));
    }, 8000);

    child.stdout.on('data', chunk => stdout += chunk);
    child.stderr.on('data', chunk => stderr += chunk);

    child.on('close', code => {
      clearTimeout(timer);
      if (code === 0 && stdout.trim()) {
        try {
          const data = JSON.parse(stdout.trim());
          const streamUrl = data.url;
          if (!streamUrl) {
            return reject(new Error('No stream URL found in yt-dlp output'));
          }

          const rawHeaders = data.http_headers || {};
          const headers = {
            'User-Agent': rawHeaders['User-Agent'] || 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Origin': 'https://www.youtube.com',
            'Referer': 'https://www.youtube.com/',
          };

          resolve({
            videoId: videoId,
            url: streamUrl,
            headers: headers,
            ext: data.ext || 'webm',
            title: data.title || '',
            duration: data.duration || 0,
          });
        } catch (err) {
          reject(new Error(`Failed to parse yt-dlp JSON: ${err.message}`));
        }
      } else {
        reject(new Error(`yt-dlp failed (code ${code}): ${stderr.slice(0, 200)}`));
      }
    });

    child.on('error', err => {
      clearTimeout(timer);
      reject(err);
    });
  });
}

/**
 * GET /api/stream/resolve
 * Ultra-fast audio stream resolution with in-memory caching and request deduplication
 */
router.get('/resolve', async (req, res) => {
  const rawId = req.query.id;
  const title = req.query.title;
  const artist = req.query.artist;
  const forceRefresh = req.query.forceRefresh === '1' || req.query.forceRefresh === 'true';

  if (!rawId && !title) {
    return res.status(400).json({ success: false, error: 'id o title es requerido' });
  }

  const cacheKey = rawId ? cleanVideoId(rawId) : `${title}_${artist || ''}`.toLowerCase();

  // 1. Check in-memory cache (< 5ms)
  if (!forceRefresh && streamCache.has(cacheKey)) {
    const cached = streamCache.get(cacheKey);
    if (Date.now() - cached.ts < STREAM_CACHE_TTL) {
      res.set('X-Cache', 'HIT');
      return res.json({
        success: true,
        ...cached.data,
        cached: true,
      });
    } else {
      streamCache.delete(cacheKey);
    }
  }

  // 2. In-flight deduplication
  if (inFlight.has(cacheKey)) {
    try {
      const data = await inFlight.get(cacheKey);
      res.set('X-Cache', 'HIT-INFLIGHT');
      return res.json({
        success: true,
        ...data,
        cached: true,
      });
    } catch (err) {
      // In-flight failed, fall through to retry
    }
  }

  // 3. Resolve stream
  const promise = (async () => {
    let videoId = cleanVideoId(rawId);
    if (!/^[a-zA-Z0-9_-]{11}$/.test(videoId)) {
      videoId = await resolveVideoId(rawId || cacheKey, title, artist);
    }

    if (!videoId || !/^[a-zA-Z0-9_-]{11}$/.test(videoId)) {
      throw new Error(`No se pudo resolver videoId para "${title || rawId}"`);
    }

    // Check cache by videoId
    if (!forceRefresh && streamCache.has(videoId)) {
      const cached = streamCache.get(videoId);
      if (Date.now() - cached.ts < STREAM_CACHE_TTL) {
        return cached.data;
      }
    }

    const info = await extractStreamInfo(videoId);
    streamCache.set(videoId, { ts: Date.now(), data: info });
    if (cacheKey !== videoId) {
      streamCache.set(cacheKey, { ts: Date.now(), data: info });
    }
    return info;
  })();

  inFlight.set(cacheKey, promise);

  try {
    const data = await promise;
    res.set('X-Cache', 'MISS');
    return res.json({
      success: true,
      ...data,
      cached: false,
    });
  } catch (err) {
    return res.status(500).json({
      success: false,
      error: err.message,
    });
  } finally {
    inFlight.delete(cacheKey);
  }
});

/**
 * GET /api/stream/health
 */
router.get('/health', (req, res) => {
  res.json({
    success: true,
    status: 'healthy',
    cachedCount: streamCache.size,
    hasCookies: Boolean(cookiesPath),
    ytDlpPath: ytDlpPath,
  });
});

module.exports = router;
