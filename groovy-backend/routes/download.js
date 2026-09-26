const express = require('express');
const router = express.Router();
const path = require('path');
const fs = require('fs');
const os = require('os');
const { spawn } = require('child_process');

// Determine yt-dlp executable path
function getYtDlpPath() {
  // Linux/Mac binary candidates first (server is Linux)
  const linuxCandidates = [
    '/usr/local/bin/yt-dlp',
    '/usr/bin/yt-dlp',
    process.env.HOME ? `${process.env.HOME}/.local/bin/yt-dlp` : null,
    path.resolve(__dirname, '../../yt-dlp'),
    path.resolve(__dirname, '../yt-dlp'),
    path.resolve(__dirname, './yt-dlp'),
  ].filter(Boolean);

  for (const p of linuxCandidates) {
    if (fs.existsSync(p)) return p;
  }

  // Windows binary candidates (dev environment)
  const winCandidates = [
    path.resolve(__dirname, '../../yt-dlp.exe'),
    path.resolve(__dirname, '../yt-dlp.exe'),
    path.resolve(__dirname, './yt-dlp.exe'),
  ];

  for (const p of winCandidates) {
    if (fs.existsSync(p)) return p;
  }

  return 'yt-dlp'; // fallback: assume it's in PATH
}

// Determine ffmpeg path
function getFfmpegPath() {
  try {
    const ffmpegStatic = require('ffmpeg-static');
    if (ffmpegStatic && fs.existsSync(ffmpegStatic)) {
      return ffmpegStatic;
    }
  } catch (e) {
    // ignore
  }
  return 'ffmpeg';
}

const TEMP_DIR = path.resolve(__dirname, '../temp_downloads');
if (!fs.existsSync(TEMP_DIR)) {
  fs.mkdirSync(TEMP_DIR, { recursive: true });
}

// Cleanup temp files older than 30 minutes every 15 minutes
setInterval(() => {
  try {
    const files = fs.readdirSync(TEMP_DIR);
    const now = Date.now();
    for (const file of files) {
      const filePath = path.join(TEMP_DIR, file);
      const stat = fs.statSync(filePath);
      if (now - stat.mtimeMs > 30 * 60 * 1000) {
        fs.unlinkSync(filePath);
      }
    }
  } catch (err) {
    console.warn('[Downloader Temp Cleanup Error]:', err.message);
  }
}, 15 * 60 * 1000);

// Helper: Sanitize filename for safe Content-Disposition
function sanitizeFilename(name, ext) {
  const clean = (name || 'groovy_media')
    .replace(/[<>:"/\\|?*\x00-\x1F]/g, '')
    .trim()
    .slice(0, 150);
  return `${clean || 'groovy_media'}.${ext}`;
}

// Helper: format duration in mm:ss
function formatDuration(seconds) {
  if (!seconds || isNaN(seconds)) return '0:00';
  const m = Math.floor(seconds / 60);
  const s = Math.floor(seconds % 60);
  return `${m}:${s < 10 ? '0' : ''}${s}`;
}

// Helper: Embed high-res cover art & ID3 metadata into MP3
async function embedMetadataAndCover(inputMp3Path, outputMp3Path, { title, artist, thumbnail }) {
  const ffmpeg = getFfmpegPath();
  let coverPath = null;

  if (thumbnail) {
    try {
      const imgRes = await fetch(thumbnail, {
        headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36' },
      });
      if (imgRes.ok) {
        const arrayBuf = await imgRes.arrayBuffer();
        const buf = Buffer.from(arrayBuf);
        coverPath = path.join(TEMP_DIR, `cover_${Date.now()}_${Math.random().toString(36).substring(2, 7)}.jpg`);
        fs.writeFileSync(coverPath, buf);
      }
    } catch (coverErr) {
      console.warn('[Downloader] Thumbnail fetch warning:', coverErr.message);
    }
  }

  return new Promise((resolve) => {
    const args = ['-i', inputMp3Path];
    if (coverPath && fs.existsSync(coverPath)) {
      args.push('-i', coverPath);
      args.push('-map', '0:a', '-map', '1:v');
      args.push('-c:a', 'copy', '-c:v', 'mjpeg');
      args.push('-id3v2_version', '3');
      args.push('-metadata:s:v', 'title=Album cover', '-metadata:s:v', 'comment=Cover (front)');
    } else {
      args.push('-c:a', 'copy');
      args.push('-id3v2_version', '3');
    }

    if (title) args.push('-metadata', `title=${title}`);
    if (artist) args.push('-metadata', `artist=${artist}`);
    args.push('-metadata', 'album=Groovy Music');

    args.push('-y', outputMp3Path);

    const proc = spawn(ffmpeg, args);
    proc.on('close', (code) => {
      if (coverPath && fs.existsSync(coverPath)) {
        try { fs.unlinkSync(coverPath); } catch (e) {}
      }
      if (code === 0 && fs.existsSync(outputMp3Path)) {
        resolve(true);
      } else {
        console.warn('[Downloader] FFmpeg cover tagging exited with code:', code);
        resolve(false);
      }
    });
    proc.on('error', (err) => {
      console.warn('[Downloader] FFmpeg spawn error in cover tagging:', err.message);
      if (coverPath && fs.existsSync(coverPath)) {
        try { fs.unlinkSync(coverPath); } catch (e) {}
      }
      resolve(false);
    });
  });
}

// Extract YouTube video ID from various URL formats
function extractYouTubeId(urlOrId) {
  if (!urlOrId) return null;
  const str = String(urlOrId).trim();
  // Filter out internal and non-YouTube IDs (Deezer, mock IDs)
  if (str.startsWith('dz_') || str.startsWith('song_') || str.startsWith('media_') || str === 'yt' || str === 'x') {
    return null;
  }
  const m = str.match(/(?:youtu\.be\/|youtube\.com\/(?:embed\/|v\/|watch\?v=|watch\?.+&v=))([\w-]{11})/i);
  if (m) return m[1];
  if (/^[a-zA-Z0-9_-]{11}$/.test(str)) return str;
  return null;
}

// Fast YouTube search resolver to find video ID from query
async function resolveYouTubeSearch(query) {
  if (!query) return null;

  // 1. YouTube Web Innertube search (Finds songs, live, lyric videos, etc.)
  try {
    const ytReq = await fetch('https://www.youtube.com/youtubei/v1/search', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      },
      body: JSON.stringify({
        context: {
          client: {
            clientName: 'WEB',
            clientVersion: '2.20240101.01.00',
            hl: 'es',
            gl: 'US',
          },
        },
        query,
      }),
      signal: AbortSignal.timeout(8000),
    });

    if (ytReq.ok) {
      const d = await ytReq.json();
      const sections = d.contents?.twoColumnSearchResultsRenderer?.primaryContents?.sectionListRenderer?.contents || [];
      for (const s of sections) {
        const items = s.itemSectionRenderer?.contents || [];
        for (const it of items) {
          if (it.videoRenderer?.videoId) {
            console.log(`[Downloader] Resolved via YT Web: https://www.youtube.com/watch?v=${it.videoRenderer.videoId}`);
            return `https://www.youtube.com/watch?v=${it.videoRenderer.videoId}`;
          }
        }
      }
    }
  } catch (err) {
    console.warn('[Downloader] YT Web search warning:', err.message);
  }

  // 2. YouTube Music Innertube search fallback
  try {
    const ytReq = await fetch('https://music.youtube.com/youtubei/v1/search?prettyPrint=false', {
      method: 'POST',
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Content-Type': 'application/json',
        'Origin': 'https://music.youtube.com',
      },
      body: JSON.stringify({
        context: {
          client: {
            clientName: 'WEB_REMIX',
            clientVersion: '1.20240101.01.00',
            hl: 'es',
            gl: 'US',
          },
        },
        query,
      }),
      signal: AbortSignal.timeout(8000),
    });

    if (ytReq.ok) {
      const ytData = await ytReq.json();
      const sections = ytData.contents?.tabbedSearchResultsRenderer?.tabs?.[0]?.tabRenderer?.content?.sectionListRenderer?.contents || [];
      for (const sec of sections) {
        const items = sec.musicShelfRenderer?.contents || [];
        for (const it of items) {
          const mrr = it.musicResponsiveListItemRenderer;
          const foundId = mrr?.flexColumns?.[0]?.musicResponsiveListItemFlexColumnRenderer?.title?.runs?.[0]?.navigationEndpoint?.watchEndpoint?.videoId ||
            mrr?.playlistItemData?.videoId;
          if (foundId) {
            console.log(`[Downloader] Resolved via YT Music: https://www.youtube.com/watch?v=${foundId}`);
            return `https://www.youtube.com/watch?v=${foundId}`;
          }
        }
      }
    }
  } catch (err) {
    console.warn('[Downloader] YT Music search warning:', err.message);
  }

  // 3. Fallback for yt-dlp search query
  return `ytsearch1:${query}`;
}

// Fast YouTube metadata fetcher for exact duration and details (No bot-check, 100% reliable)
async function fetchYouTubeMetadata(ytId) {
  if (!ytId) return null;

  // 1. YouTube Web Innertube Search by Video ID (Returns exact lengthText, title, channel without bot-check)
  try {
    const res = await fetch('https://www.youtube.com/youtubei/v1/search', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      },
      body: JSON.stringify({
        context: {
          client: {
            clientName: 'WEB',
            clientVersion: '2.20240101.01.00',
            hl: 'es',
            gl: 'US',
          },
        },
        query: ytId,
      }),
      signal: AbortSignal.timeout(8000),
    });

    if (res.ok) {
      const d = await res.json();
      const sections = d.contents?.twoColumnSearchResultsRenderer?.primaryContents?.sectionListRenderer?.contents || [];
      for (const s of sections) {
        const items = s.itemSectionRenderer?.contents || [];
        for (const it of items) {
          const vr = it.videoRenderer;
          if (vr && vr.videoId === ytId) {
            const rawDuration = vr.lengthText?.simpleText || '';
            let durationSec = null;
            if (rawDuration) {
              const parts = rawDuration.split(':').map(Number);
              if (parts.length === 2) durationSec = parts[0] * 60 + parts[1];
              else if (parts.length === 3) durationSec = parts[0] * 3600 + parts[1] * 60 + parts[2];
            }
            const thumbs = vr.thumbnail?.thumbnails || [];
            const bestThumb = thumbs.length > 0 ? thumbs[thumbs.length - 1].url : `https://i.ytimg.com/vi/${ytId}/hqdefault.jpg`;
            const title = vr.title?.runs?.[0]?.text || 'Video de YouTube';
            const artist = vr.ownerText?.runs?.[0]?.text || vr.shortBylineText?.runs?.[0]?.text || 'YouTube';
            const views = vr.viewCountText?.simpleText || '1.2M+ vistas';

            const badges = (vr.badges || []).map(b => b.metadataBadgeRenderer?.label || '').filter(Boolean);
            const is8K = badges.some(b => /8K/i.test(b));
            const is4K = is8K || badges.some(b => /4K|UHD|2160/i.test(b));
            const is1440p = is4K || badges.some(b => /1440|2K/i.test(b));

            return {
              title,
              artist,
              duration: rawDuration || (durationSec ? formatDuration(durationSec) : '0:00'),
              durationSec: durationSec || 210,
              thumbnail: bestThumb,
              views,
              badges,
              is8K,
              is4K,
              is1440p,
            };
          }
        }
      }
    }
  } catch (err) {
    console.warn('[YouTube Search Metadata error]:', err.message);
  }

  // 2. oEmbed fallback for title and author
  try {
    const oeRes = await fetch(`https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=${ytId}&format=json`);
    if (oeRes.ok) {
      const oembed = await oeRes.json();
      return {
        title: oembed.title || 'Video de YouTube',
        artist: oembed.author_name || 'YouTube',
        duration: '0:00',
        durationSec: 0,
        thumbnail: `https://i.ytimg.com/vi/${ytId}/hqdefault.jpg`,
        views: '1.2M+',
        badges: [],
        is8K: false,
        is4K: false,
        is1440p: false,
      };
    }
  } catch (oeErr) {
    console.warn('[oEmbed fallback error]:', oeErr.message);
  }

  return null;
}

// Cobalt resolver — uses local container on port 9000 first, then fallback
async function resolveCobalt(targetUrl, format, quality) {
  if (!targetUrl || targetUrl.startsWith('ytsearch1:')) return null;
  try {
    const isMp3 = format.toLowerCase() === 'mp3';
    
    // Cobalt v10 valid bitrates: 320, 256, 128, 96, 64, 8
    let audioBitrate = '320';
    if (['320', '256', '128', '96', '64'].includes(String(quality))) {
      audioBitrate = String(quality);
    } else if (String(quality) === '192') {
      audioBitrate = '256';
    }

    // Cobalt v10 valid video qualities: max, 4320, 2160, 1440, 1080, 720, 480, 360, 240, 144
    let videoQuality = '1080';
    if (['4320', '2160', '1440', '1080', '720', '480', '360', '240', '144'].includes(String(quality))) {
      videoQuality = String(quality);
    }

    const body = {
      url: targetUrl,
      downloadMode: isMp3 ? 'audio' : 'auto',
    };
    if (isMp3) {
      body.audioFormat = 'mp3';
      body.audioBitrate = audioBitrate;
    } else {
      body.videoQuality = videoQuality;
    }

    const endpoints = [
      'http://localhost:9000/',
      'https://api.cobalt.tools/'
    ];

    for (const endpoint of endpoints) {
      try {
        console.log(`[Cobalt] Requesting ${isMp3 ? 'audio' : 'video'} (${quality}) from ${endpoint}...`);
        const res = await fetch(endpoint, {
          method: 'POST',
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: JSON.stringify(body),
          signal: AbortSignal.timeout(20000),
        });

        if (!res.ok) {
          console.warn(`[Cobalt] ${endpoint} returned HTTP ${res.status}`);
          continue;
        }

        const data = await res.json();
        console.log(`[Cobalt] Response from ${endpoint}: status=${data.status}`);

        // status can be: redirect, tunnel, stream, picker, error
        if ((data.status === 'redirect' || data.status === 'tunnel' || data.status === 'stream') && data.url) {
          return data.url;
        }
        // picker = multiple streams (e.g. video+audio separate), pick first
        if (data.status === 'picker' && Array.isArray(data.picker) && data.picker[0]?.url) {
          return data.picker[0].url;
        }
      } catch (endpointErr) {
        console.warn(`[Cobalt] Endpoint ${endpoint} failed:`, endpointErr.message);
      }
    }
  } catch (err) {
    console.warn('[Cobalt Resolver Error]:', err.message);
  }
  return null;
}

// Loader.to cloud resolver (High reliability fallback for MP3 & MP4)
async function resolveCloudStreamUrl(targetUrl, format, quality) {
  if (!targetUrl || targetUrl.startsWith('ytsearch1:')) return null;
  const isMp3 = format.toLowerCase() === 'mp3';
  let loaderFormat = 'mp3';
  if (!isMp3) {
    const qStr = String(quality || '720');
    if (qStr === '4320') loaderFormat = '8k';
    else if (qStr === '2160') loaderFormat = '4k';
    else if (['1440', '1080', '720', '480', '360'].includes(qStr)) loaderFormat = qStr;
    else loaderFormat = '720';
  }

  try {
    console.log(`[Loader.to] Resolving ${isMp3 ? 'audio' : 'video'} (${loaderFormat}) for: ${targetUrl}`);
    const initRes = await fetch(`https://loader.to/ajax/download.php?format=${encodeURIComponent(loaderFormat)}&url=${encodeURIComponent(targetUrl)}`, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      },
    });

    if (initRes.ok) {
      const init = await initRes.json();
      if (init.download_url) return init.download_url;
      if (init.progress_url) {
        for (let i = 0; i < 25; i++) {
          await new Promise(r => setTimeout(r, 1000));
          const pRes = await fetch(init.progress_url);
          if (pRes.ok) {
            const pData = await pRes.json();
            if (pData.download_url) {
              console.log(`[Loader.to] Successfully resolved direct stream URL!`);
              return pData.download_url;
            }
          }
        }
      }
    }
  } catch (err) {
    console.warn('[Loader.to Resolver Error]:', err.message);
  }
  return null;
}


// 1. FAST SEARCH (Autocomplete / Suggestions)
router.get('/search', async (req, res) => {
  const query = (req.query.q || '').trim();
  if (!query) return res.json({ success: true, results: [] });

  try {
    // If it looks like a direct URL, don't search Innertube, redirect to info
    if (/^(https?:\/\/)?(www\.|m\.)?(youtube\.com|youtu\.be)\//i.test(query)) {
      return res.json({
        success: true,
        isDirectUrl: true,
        url: query,
        results: [],
      });
    }

    // Use YouTube Music Innertube search for fast, rich results
    const ytReq = await fetch('https://music.youtube.com/youtubei/v1/search?prettyPrint=false', {
      method: 'POST',
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Content-Type': 'application/json',
        'Origin': 'https://music.youtube.com',
      },
      body: JSON.stringify({
        context: {
          client: {
            clientName: 'WEB_REMIX',
            clientVersion: '1.20240101.01.00',
            hl: 'es',
            gl: 'US',
          },
        },
        query,
        params: 'EgWKAQIIAWoKEAUQAxAEEAkQBQ==',
      }),
    });

    if (ytReq.ok) {
      const ytData = await ytReq.json();
      const sections = ytData.contents?.tabbedSearchResultsRenderer?.tabs?.[0]?.tabRenderer?.content?.sectionListRenderer?.contents || [];
      const results = [];

      for (const sec of sections) {
        const items = sec.musicShelfRenderer?.contents || [];
        for (const it of items) {
          const mrr = it.musicResponsiveListItemRenderer;
          if (!mrr) continue;

          const title = mrr.flexColumns?.[0]?.musicResponsiveListItemFlexColumnRenderer?.title?.runs?.[0]?.text;
          const videoId = mrr.flexColumns?.[0]?.musicResponsiveListItemFlexColumnRenderer?.title?.runs?.[0]?.navigationEndpoint?.watchEndpoint?.videoId ||
            mrr.playlistItemData?.videoId;

          if (!title || !videoId) continue;

          const runs = mrr.flexColumns?.[1]?.musicResponsiveListItemFlexColumnRenderer?.title?.runs || [];
          let artist = 'Artista Desconocido';
          let duration = '';
          let durationSec = 210;

          for (let i = 0; i < runs.length; i++) {
            const txt = (runs[i]?.text || '').trim();
            if (!txt || txt === '•') continue;
            if (/^\d{1,2}:\d{2}(:\d{2})?$/.test(txt)) {
              duration = txt;
              const parts = txt.split(':').map(Number);
              if (parts.length === 2) durationSec = parts[0] * 60 + parts[1];
              else if (parts.length === 3) durationSec = parts[0] * 3600 + parts[1] * 60 + parts[2];
            } else if (artist === 'Artista Desconocido' && !txt.toLowerCase().includes('canción') && !txt.toLowerCase().includes('video')) {
              artist = txt;
            }
          }

          const thumb = mrr.thumbnail?.musicThumbnailRenderer?.thumbnail?.thumbnails?.slice(-1)[0]?.url ||
            `https://i.ytimg.com/vi/${videoId}/hqdefault.jpg`;

          results.push({
            id: videoId,
            videoId,
            url: `https://www.youtube.com/watch?v=${videoId}`,
            title,
            artist,
            duration: duration || formatDuration(durationSec),
            durationSec,
            thumbnail: thumb,
            query: `${title} ${artist}`,
          });

          if (results.length >= 12) break;
        }
        if (results.length >= 12) break;
      }

      if (results.length > 0) {
        return res.json({ success: true, results });
      }
    }
  } catch (err) {
    console.warn('[Downloader Search Error]:', err.message);
  }

  // Fallback to Deezer search if YouTube search yields nothing
  try {
    const dzRes = await fetch(`https://api.deezer.com/search?q=${encodeURIComponent(query)}&limit=12`);
    if (dzRes.ok) {
      const data = await dzRes.json();
      const results = (data.data || []).map((t) => ({
        id: `dz_${t.id}`,
        title: t.title,
        artist: t.artist?.name || 'Desconocido',
        duration: formatDuration(t.duration),
        durationSec: t.duration,
        thumbnail: t.album?.cover_big || t.album?.cover_medium,
        query: `${t.title} ${t.artist?.name || ''}`,
      }));
      return res.json({ success: true, results });
    }
  } catch (dzErr) {
    console.warn('[Downloader Deezer Fallback Error]:', dzErr.message);
  }

  return res.json({ success: true, results: [] });
});

// 2. EXTRACT VIDEO & AUDIO METADATA + FORMAT OPTIONS
router.post('/info', async (req, res) => {
  const { url, videoId, query, title, artist, durationSec: reqDur, thumbnail: reqThumb } = req.body;

  // 1. If YouTube URL or YouTube Video ID, fetch real metadata including exact duration
  const ytId = extractYouTubeId(url || videoId || query);
  if (ytId) {
    try {
      const ytMeta = await fetchYouTubeMetadata(ytId);

      let finalTitle = ytMeta?.title || 'Video de YouTube';
      let finalArtist = ytMeta?.artist || 'YouTube';
      let finalDurationSec = ytMeta?.durationSec;
      let finalThumb = ytMeta?.thumbnail || `https://i.ytimg.com/vi/${ytId}/hqdefault.jpg`;
      let finalViews = ytMeta?.views || '1.2M+';
      let is8K = ytMeta?.is8K || false;
      let is4K = ytMeta?.is4K || false;
      let is1440p = ytMeta?.is1440p || false;

      const durSec = finalDurationSec || parseInt(reqDur, 10) || 210;
      const calcAudioMb = (kbps) => ((kbps * durSec) / 8 / 1024).toFixed(1);
      const calcVideoMb = (mbps) => ((mbps * 1024 * durSec) / 8 / 1024).toFixed(1);

      const defaultAudioQualities = [
        { quality: '320', label: '320 kbps (Ultra HQ)', note: 'Máxima fidelidad de estudio', ext: 'mp3', size: `~${calcAudioMb(320)} MB`, recommended: true },
        { quality: '256', label: '256 kbps (Alta)', note: 'Excelente equilibrio y nitidez', ext: 'mp3', size: `~${calcAudioMb(256)} MB` },
        { quality: '192', label: '192 kbps (Estándar)', note: 'Calidad estándar recomendada', ext: 'mp3', size: `~${calcAudioMb(192)} MB` },
        { quality: '128', label: '128 kbps (Ligero)', note: 'Ahorro máximo de espacio', ext: 'mp3', size: `~${calcAudioMb(128)} MB` },
      ];

      const defaultVideoQualities = [];
      if (is8K) {
        defaultVideoQualities.push({ quality: '4320', label: '4320p (8K Ultra HD)', note: 'Máxima resolución 8K de ultra definición', ext: 'mp4', size: `~${calcVideoMb(18.0)} MB`, recommended: true });
      }
      if (is4K) {
        defaultVideoQualities.push({ quality: '2160', label: '2160p (4K Ultra HD)', note: 'Resolución cinematográfica 4K 60fps', ext: 'mp4', size: `~${calcVideoMb(9.5)} MB`, recommended: !is8K });
      }
      if (is1440p) {
        defaultVideoQualities.push({ quality: '1440', label: '1440p (2K Quad HD)', note: 'Resolución ultra nítida QHD 2K', ext: 'mp4', size: `~${calcVideoMb(5.5)} MB`, recommended: !is4K && !is8K });
      }
      defaultVideoQualities.push(
        { quality: '1080', label: '1080p (Full HD)', note: 'Resolución Full HD de alta nitidez', ext: 'mp4', size: `~${calcVideoMb(3.2)} MB`, recommended: !is4K && !is1440p && !is8K },
        { quality: '720', label: '720p (HD)', note: 'Alta definición rápida', ext: 'mp4', size: `~${calcVideoMb(1.8)} MB` },
        { quality: '480', label: '480p (SD)', note: 'Calidad estándar equilibrada', ext: 'mp4', size: `~${calcVideoMb(0.9)} MB` },
        { quality: '360', label: '360p (Móvil)', note: 'Bajo consumo para celulares', ext: 'mp4', size: `~${calcVideoMb(0.5)} MB` }
      );

      return res.json({
        success: true,
        id: ytId,
        videoId: ytId,
        url: `https://www.youtube.com/watch?v=${ytId}`,
        title: finalTitle,
        artist: finalArtist,
        duration: formatDuration(durSec),
        durationSec: durSec,
        thumbnail: finalThumb,
        views: finalViews,
        badges: ytMeta?.badges || [],
        is4K,
        is8K,
        is1440p,
        previewAudioUrl: null,
        audioQualities: defaultAudioQualities,
        videoQualities: defaultVideoQualities,
      });
    } catch (oeErr) {
      console.warn('[Metadata fetch error]:', oeErr.message);
    }
  }

  const durationSec = parseInt(reqDur, 10) || 210;
  const calcAudioMb = (kbps) => ((kbps * durationSec) / 8 / 1024).toFixed(1);
  const calcVideoMb = (mbps) => ((mbps * 1024 * durationSec) / 8 / 1024).toFixed(1);

  const defaultAudioQualities = [
    { quality: '320', label: '320 kbps (Ultra HQ)', note: 'Máxima fidelidad de estudio', ext: 'mp3', size: `~${calcAudioMb(320)} MB`, recommended: true },
    { quality: '256', label: '256 kbps (Alta)', note: 'Excelente equilibrio y nitidez', ext: 'mp3', size: `~${calcAudioMb(256)} MB` },
    { quality: '192', label: '192 kbps (Estándar)', note: 'Calidad estándar recomendada', ext: 'mp3', size: `~${calcAudioMb(192)} MB` },
    { quality: '128', label: '128 kbps (Ligero)', note: 'Ahorro máximo de espacio', ext: 'mp3', size: `~${calcAudioMb(128)} MB` },
  ];

  const defaultVideoQualities = [
    { quality: '1080', label: '1080p (Full HD)', note: 'Resolución cinematográfica 60/30fps', ext: 'mp4', size: `~${calcVideoMb(3.5)} MB`, recommended: true },
    { quality: '720', label: '720p (HD)', note: 'Alta definición rápida', ext: 'mp4', size: `~${calcVideoMb(1.8)} MB` },
    { quality: '480', label: '480p (SD)', note: 'Calidad estándar equilibrada', ext: 'mp4', size: `~${calcVideoMb(1.0)} MB` },
    { quality: '360', label: '360p (Móvil)', note: 'Bajo consumo para celulares', ext: 'mp4', size: `~${calcVideoMb(0.5)} MB` },
  ];

  // 2. If given song metadata directly from search, immediately return clean object
  if (title || (videoId && String(videoId).startsWith('dz_')) || query) {
    const songTitle = title || query || 'Música';
    const songArtist = artist || 'Artista';

    return res.json({
      success: true,
      id: videoId || 'song_item',
      url: url || null,
      query: query || `${songTitle} ${songArtist}`,
      title: songTitle,
      artist: songArtist,
      duration: formatDuration(durationSec),
      durationSec,
      thumbnail: reqThumb || 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=800&auto=format&fit=crop&q=80',
      views: '1.5M+',
      previewAudioUrl: null,
      audioQualities: defaultAudioQualities,
      videoQualities: defaultVideoQualities,
    });
  }

  // 3. Fallback generic response
  return res.json({
    success: true,
    id: 'media_direct',
    url: url || null,
    title: 'Contenido Multimedia',
    artist: 'Groovy Downloader',
    duration: '3:30',
    durationSec: 210,
    thumbnail: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=800&auto=format&fit=crop&q=80',
    views: '1.2M+',
    previewAudioUrl: null,
    audioQualities: defaultAudioQualities,
    videoQualities: defaultVideoQualities,
  });
});

// 3. EXECUTE DOWNLOAD AND STREAM TO USER BROWSER
router.get('/file', async (req, res) => {
  const { id, url, format = 'mp3', quality = '320', title = 'groovy_download', artist = '', query = '', thumbnail = '' } = req.query;

  const isMp3 = format.toLowerCase() === 'mp3';
  const outExt = isMp3 ? 'mp3' : 'mp4';
  const finalFilename = sanitizeFilename(title || `${artist} - ${query || 'musica'}`, outExt);

  console.log(`[Downloader] Download requested: "${finalFilename}" (${outExt.toUpperCase()}, ${quality})`);

  // 1. Determine target YouTube URL
  let targetUrl = url;
  const ytId = extractYouTubeId(url || id);
  if (ytId) {
    targetUrl = `https://www.youtube.com/watch?v=${ytId}`;
  } else {
    // If not a direct YouTube ID, find corresponding YouTube video ID via search
    const searchQuery = (query || `${title} ${artist}`).trim();
    if (searchQuery) {
      console.log(`[Downloader] Resolving YouTube video for search: "${searchQuery}"`);
      targetUrl = await resolveYouTubeSearch(searchQuery);
    }
  }

  if (!targetUrl) {
    targetUrl = `https://www.youtube.com/watch?v=k2qgadSvNyU`;
  }

  console.log(`[Downloader] Target URL: "${targetUrl}"`);

  // 2. Primary: Loader.to cloud resolver (fast & reliable without YouTube bot blocks), Secondary: Cobalt
  const streamUrl = (await resolveCloudStreamUrl(targetUrl, format, quality)) || (await resolveCobalt(targetUrl, format, quality));
  if (streamUrl) {
    try {
      console.log(`[Downloader] Streaming direct cloud media from: ${streamUrl.slice(0, 70)}...`);
      const upstream = await fetch(streamUrl, {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
      });

      if (upstream.ok) {
        const asciiFilename = finalFilename.replace(/[^\x20-\x7E]/g, '_');
        const { Readable } = require('stream');

        // For video (MP4), stream directly to browser immediately — 0 latency, no buffering delay
        if (!isMp3) {
          res.setHeader('Access-Control-Expose-Headers', 'Content-Disposition, Content-Length');
          res.setHeader('Content-Disposition', `attachment; filename="${asciiFilename}"; filename*=UTF-8''${encodeURIComponent(finalFilename)}`);
          res.setHeader('Content-Type', 'video/mp4');
          const cl = upstream.headers.get('content-length');
          if (cl) res.setHeader('Content-Length', cl);
          res.setHeader('Cache-Control', 'no-cache');

          const nodeStream = Readable.fromWeb(upstream.body);
          nodeStream.pipe(res);
          return;
        }

        // For audio (MP3), buffer and tag ID3 metadata with cover art
        const tempRawPath = path.join(TEMP_DIR, `raw_${Date.now()}_${Math.random().toString(36).substring(2, 7)}.${outExt}`);
        const fileStream = fs.createWriteStream(tempRawPath);
        const nodeStream = Readable.fromWeb(upstream.body);

        await new Promise((resolve, reject) => {
          nodeStream.pipe(fileStream);
          fileStream.on('finish', resolve);
          fileStream.on('error', reject);
          nodeStream.on('error', reject);
        });

        let finalSendPath = tempRawPath;

        if (thumbnail || title || artist) {
          console.log(`[Downloader] Injecting cover art & ID3 metadata for "${finalFilename}"...`);
          const tempTaggedPath = path.join(TEMP_DIR, `tagged_${Date.now()}_${Math.random().toString(36).substring(2, 7)}.mp3`);
          const songTitle = title || query || 'Música';
          const songArtist = artist || 'Groovy Music';
          const tagged = await embedMetadataAndCover(tempRawPath, tempTaggedPath, { title: songTitle, artist: songArtist, thumbnail });
          if (tagged && fs.existsSync(tempTaggedPath)) {
            finalSendPath = tempTaggedPath;
          }
        }

        const stat = fs.statSync(finalSendPath);
        res.setHeader('Access-Control-Expose-Headers', 'Content-Disposition, Content-Length');
        res.setHeader('Content-Disposition', `attachment; filename="${asciiFilename}"; filename*=UTF-8''${encodeURIComponent(finalFilename)}`);
        res.setHeader('Content-Type', 'audio/mpeg');
        res.setHeader('Content-Length', stat.size);
        res.setHeader('Cache-Control', 'no-cache');

        const outStream = fs.createReadStream(finalSendPath);
        outStream.pipe(res);
        outStream.on('end', () => {
          try { if (fs.existsSync(tempRawPath)) fs.unlinkSync(tempRawPath); } catch (e) {}
          if (finalSendPath !== tempRawPath) {
            try { if (fs.existsSync(finalSendPath)) fs.unlinkSync(finalSendPath); } catch (e) {}
          }
        });
        return;
      }
    } catch (streamErr) {
      console.warn('[Cloud Stream fetch failed, attempting local fallback]:', streamErr.message);
    }
  }

  // 3. Subprocess Fallback with yt-dlp + ffmpeg
  const ytdlpPath = getYtDlpPath();
  const ffmpegPath = getFfmpegPath();
  const timestamp = Date.now();
  const tempOutputBase = path.join(TEMP_DIR, `dl_${timestamp}_${Math.random().toString(36).substring(2, 8)}`);
  const tempOutputFile = `${tempOutputBase}.${outExt}`;

  const args = [
    '--ffmpeg-location', ffmpegPath,
    '--no-playlist',
    '--no-warnings',
    '--extractor-args', 'youtube:player_client=tv_embedded,web',
    '--retries', '3',
    '--fragment-retries', '3',
    '-o', `${tempOutputBase}.%(ext)s`,
  ];

  if (isMp3) {
    args.push('-x', '--audio-format', 'mp3');
    if (quality === '320') args.push('--audio-quality', '320k');
    else if (quality === '256') args.push('--audio-quality', '256k');
    else if (quality === '192') args.push('--audio-quality', '192k');
    else args.push('--audio-quality', '128k');
  } else {
    const h = parseInt(quality, 10) || 1080;
    args.push(
      '-f', `bestvideo[height<=${h}][ext=mp4]+bestaudio[ext=m4a]/bestvideo[height<=${h}]+bestaudio/best[height<=${h}]/best`,
      '--merge-output-format', 'mp4'
    );
  }

  args.push(targetUrl);

  const proc = spawn(ytdlpPath, args);
  let stderr = '';
  proc.stderr.on('data', d => { stderr += d; });

  req.on('close', () => {
    if (!proc.killed) {
      try { proc.kill('SIGTERM'); } catch (e) {}
    }
  });

  proc.on('close', async (code) => {
    let generatedFile = tempOutputFile;
    if (!fs.existsSync(generatedFile)) {
      const matches = fs.readdirSync(TEMP_DIR).filter(f => f.startsWith(path.basename(tempOutputBase)));
      if (matches.length > 0) generatedFile = path.join(TEMP_DIR, matches[0]);
    }

    if (code !== 0 || !fs.existsSync(generatedFile)) {
      console.error('[Downloader Error Code]:', code, stderr.slice(-300));
      if (!res.headersSent) {
        return res.status(500).send(`Error al procesar el archivo.`);
      }
      return;
    }

    let finalSendFile = generatedFile;
    if (isMp3 && (thumbnail || title || artist)) {
      const taggedFile = path.join(TEMP_DIR, `tagged_${Date.now()}_${Math.random().toString(36).substring(2, 7)}.mp3`);
      const songTitle = title || query || 'Música';
      const songArtist = artist || 'Groovy Music';
      const tagged = await embedMetadataAndCover(generatedFile, taggedFile, { title: songTitle, artist: songArtist, thumbnail });
      if (tagged && fs.existsSync(taggedFile)) {
        try { fs.unlinkSync(generatedFile); } catch (e) {}
        finalSendFile = taggedFile;
      }
    }

    const stat = fs.statSync(finalSendFile);
    res.setHeader('Access-Control-Expose-Headers', 'Content-Disposition, Content-Length');
    res.setHeader('Content-Disposition', `attachment; filename="${encodeURIComponent(finalFilename)}"; filename*=UTF-8''${encodeURIComponent(finalFilename)}`);
    res.setHeader('Content-Type', isMp3 ? 'audio/mpeg' : 'video/mp4');
    res.setHeader('Content-Length', stat.size);
    res.setHeader('Cache-Control', 'no-cache');

    const readStream = fs.createReadStream(finalSendFile);
    readStream.pipe(res);
    readStream.on('end', () => {
      try {
        if (fs.existsSync(finalSendFile)) fs.unlinkSync(finalSendFile);
      } catch (e) {}
    });
  });
});

module.exports = router;
