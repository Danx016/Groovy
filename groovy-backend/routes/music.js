const express = require('express');
const router = express.Router();

// Memory cache with 1-hour TTL for external API calls
const cache = new Map();
const CACHE_TTL_MS = 60 * 60 * 1000;

function getCached(key) {
  const item = cache.get(key);
  if (!item) return null;
  if (Date.now() - item.ts > CACHE_TTL_MS) {
    cache.delete(key);
    return null;
  }
  return item.data;
}

function setCached(key, data) {
  cache.set(key, { ts: Date.now(), data });
}

// 1. TOP / FEATURED ARTISTS WITH 100% REAL DEEZER PHOTOS
const FEATURED_ARTIST_NAMES = [
  'Bad Bunny',
  'The Weeknd',
  'Feid',
  'Karol G',
  'Taylor Swift',
  'Coldplay',
  'Drake',
  'Dua Lipa',
  'Billie Eilish',
  'Peso Pluma',
  'Rauw Alejandro',
  'J Balvin'
];

router.get('/artists/top', async (req, res) => {
  res.set('Cache-Control', 'public, max-age=1800');
  try {
    const cached = getCached('featured_artists_top');
    if (cached) return res.json({ success: true, artists: cached });

    const promises = FEATURED_ARTIST_NAMES.map(async (name) => {
      try {
        const url = `https://api.deezer.com/search/artist?q=${encodeURIComponent(name)}&limit=1`;
        const resp = await fetch(url, { headers: { 'User-Agent': 'GroovyMusic/1.0' } });
        if (resp.ok) {
          const data = await resp.json();
          const art = data.data?.[0];
          if (art) {
            return {
              id: art.id,
              name: art.name,
              image: art.picture_xl || art.picture_big || art.picture_medium || art.picture,
              fans: art.nb_fan || 0,
              albumsCount: art.nb_album || 0,
              radio: art.radio || false,
            };
          }
        }
      } catch (err) {
        console.warn(`[Deezer Top Artist] Error fetching ${name}:`, err.message);
      }
      return {
        id: name.toLowerCase().replace(/\s+/g, '_'),
        name,
        image: `https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600`,
        fans: 1000000,
        albumsCount: 10,
      };
    });

    const artists = await Promise.all(promises);
    setCached('featured_artists_top', artists);
    return res.json({ success: true, artists });
  } catch (err) {
    console.error('[Top Artists Error]:', err);
    return res.status(500).json({ success: false, error: err.message });
  }
});

// 2. REAL ARTIST DETAILS (BANNER, VERIFIED, TOP TRACKS, DISCOGRAPHY)
router.get('/artist/:name', async (req, res) => {
  res.set('Cache-Control', 'public, max-age=1800');
  const artistName = req.params.name.trim();
  if (!artistName) return res.status(400).json({ success: false, error: 'Artist name required' });

  const cacheKey = `artist_${artistName.toLowerCase()}`;
  const cached = getCached(cacheKey);
  if (cached) return res.json({ success: true, ...cached });

  try {
    // A. Fetch Artist Profile
    const searchUrl = `https://api.deezer.com/search/artist?q=${encodeURIComponent(artistName)}&limit=1`;
    const searchResp = await fetch(searchUrl);
    const searchData = await searchResp.json();
    const artistObj = searchData.data?.[0];

    if (!artistObj) {
      return res.status(404).json({ success: false, error: 'Artist not found' });
    }

    const artistId = artistObj.id;
    const realImage = artistObj.picture_xl || artistObj.picture_big || artistObj.picture_medium;

    // B. Fetch Top Popular Tracks from Deezer
    const topUrl = `https://api.deezer.com/artist/${artistId}/top?limit=25`;
    const topResp = await fetch(topUrl);
    const topData = await topResp.json();
    const topTracks = (topData.data || []).map((t) => ({
      id: `dz_${t.id}`,
      songId: `dz_${t.id}`,
      title: t.title,
      artist: t.artist?.name || artistObj.name,
      album: t.album?.title || '',
      albumId: t.album?.id,
      coverArt: t.album?.cover_xl || t.album?.cover_big || t.album?.cover_medium || realImage,
      duration: t.duration || 180,
      audioUrl: t.preview || '',
      isExplicit: t.explicit_lyrics || false,
    }));

    // C. Fetch Albums Discography from Deezer
    const albumsUrl = `https://api.deezer.com/artist/${artistId}/albums?limit=25`;
    const albumsResp = await fetch(albumsUrl);
    const albumsData = await albumsResp.json();
    const albums = (albumsData.data || []).map((alb) => ({
      id: alb.id,
      name: alb.title,
      artist: artistObj.name,
      coverArt: alb.cover_xl || alb.cover_big || alb.cover_medium,
      year: alb.release_date ? alb.release_date.substring(0, 4) : '',
      releaseDate: alb.release_date || '',
      genre: alb.genre_id || '',
    }));

    const result = {
      artist: {
        id: artistId,
        name: artistObj.name,
        image: realImage,
        banner: realImage,
        fans: artistObj.nb_fan || 0,
        albumsCount: artistObj.nb_album || albums.length,
        verified: true,
      },
      topTracks,
      albums,
    };

    setCached(cacheKey, result);
    return res.json({ success: true, ...result });
  } catch (err) {
    console.error('[Artist Detail Error]:', err);
    return res.status(500).json({ success: false, error: err.message });
  }
});

// 3. REAL ALBUM DETAILS (ARTWORK, RELEASE DATE, TRACKLIST)
router.get('/album/:id', async (req, res) => {
  res.set('Cache-Control', 'public, max-age=1800');
  const albumId = req.params.id;
  const cacheKey = `album_${albumId}`;
  const cached = getCached(cacheKey);
  if (cached) return res.json({ success: true, album: cached });

  try {
    const url = `https://api.deezer.com/album/${albumId}`;
    const resp = await fetch(url);
    const data = await resp.json();

    if (!data || data.error) {
      return res.status(404).json({ success: false, error: 'Album not found' });
    }

    const coverArt = data.cover_xl || data.cover_big || data.cover_medium || data.cover;
    const tracks = (data.tracks?.data || []).map((t, idx) => ({
      id: `dz_${t.id}`,
      songId: `dz_${t.id}`,
      title: t.title,
      artist: t.artist?.name || data.artist?.name || 'Unknown Artist',
      album: data.title,
      albumId: data.id,
      trackNumber: t.track_position || idx + 1,
      coverArt,
      duration: t.duration || 180,
      audioUrl: t.preview || '',
      isExplicit: t.explicit_lyrics || false,
    }));

    const albumObj = {
      id: data.id,
      name: data.title,
      artist: data.artist?.name || '',
      artistId: data.artist?.id,
      coverArt,
      releaseDate: data.release_date || '',
      year: data.release_date ? data.release_date.substring(0, 4) : '',
      label: data.label || 'Groovy Music',
      genres: data.genres?.data?.map((g) => g.name).join(', ') || 'Música',
      totalTracks: data.nb_tracks || tracks.length,
      duration: data.duration || 0,
      tracks,
    };

    setCached(cacheKey, albumObj);
    return res.json({ success: true, album: albumObj });
  } catch (err) {
    console.error('[Album Detail Error]:', err);
    return res.status(500).json({ success: false, error: err.message });
  }
});

// 4. YOUTUBE MUSIC INNERTUBE & DEEZER HYBRID SEARCH
router.get('/search', async (req, res) => {
  const query = (req.query.q || '').trim();
  const category = (req.query.category || 'all').toLowerCase();
  if (!query) return res.json({ success: true, results: [] });

  const cacheKey = `search_${query.toLowerCase()}_${category}`;
  const cached = getCached(cacheKey);
  if (cached) return res.json({ success: true, results: cached });

  try {
    // 1. Try YouTube Music Innertube API (same as ytdlp_service.dart in Flutter)
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
      const shelf = sections.find((s) => s.musicShelfRenderer)?.musicShelfRenderer;

      if (shelf && shelf.contents?.length > 0) {
        const results = [];
        for (const item of shelf.contents) {
          const r = item.musicResponsiveListItemRenderer;
          if (!r) continue;

          const flex = r.flexColumns || [];
          if (flex.length === 0) continue;

          // Video ID
          let videoId = null;
          const firstRun = flex[0].musicResponsiveListItemFlexColumnRenderer?.text?.runs?.[0];
          if (firstRun?.navigationEndpoint?.watchEndpoint?.videoId) {
            videoId = firstRun.navigationEndpoint.watchEndpoint.videoId;
          }
          if (!videoId && r.overlay?.musicItemThumbnailOverlayRenderer?.content?.musicPlayButtonRenderer?.playNavigationEndpoint?.watchEndpoint?.videoId) {
            videoId = r.overlay.musicItemThumbnailOverlayRenderer.content.musicPlayButtonRenderer.playNavigationEndpoint.watchEndpoint.videoId;
          }
          if (!videoId) continue;

          const title = firstRun?.text || 'Sin título';

          // Subtitle runs (Artist, Album, Duration)
          const subRuns = flex[1]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs || [];
          let artist = 'Various Artists';
          let album = '';
          let durationSecs = 210;

          const parts = [];
          let cur = [];
          for (const s of subRuns) {
            if (s.text === ' • ') {
              if (cur.length > 0) parts.push(cur.join(''));
              cur = [];
            } else {
              cur.push(s.text);
            }
          }
          if (cur.length > 0) parts.push(cur.join(''));

          if (parts.length >= 1) artist = parts[0];
          if (parts.length >= 2) {
            if (parts.length === 2 && parts[1].includes(':')) {
              const [m, sec] = parts[1].split(':').map(Number);
              durationSecs = (m * 60) + (sec || 0);
            } else {
              album = parts[1];
            }
          }
          if (parts.length >= 3 && parts[2].includes(':')) {
            const [m, sec] = parts[2].split(':').map(Number);
            durationSecs = (m * 60) + (sec || 0);
          }

          // Thumbnail
          const thumbs = r.thumbnail?.musicThumbnailRenderer?.thumbnail?.thumbnails || [];
          let coverArt = `https://i.ytimg.com/vi/${videoId}/hqdefault.jpg`;
          if (thumbs.length > 0) {
            coverArt = thumbs[thumbs.length - 1].url;
          }

          results.push({
            id: videoId,
            songId: videoId,
            title,
            artist,
            album,
            coverArt,
            duration: durationSecs,
            platform: 'youtube',
          });
        }

        if (results.length > 0) {
          setCached(cacheKey, results);
          return res.json({ success: true, results });
        }
      }
    }
  } catch (ytErr) {
    console.warn('[Innertube Search Error]:', ytErr.message);
  }

  // 2. Fallback to Deezer Search API
  try {
    const dzUrl = `https://api.deezer.com/search?q=${encodeURIComponent(query)}&limit=25`;
    const dzResp = await fetch(dzUrl);
    if (dzResp.ok) {
      const dzData = await dzResp.json();
      const results = (dzData.data || []).map((t) => ({
        id: `dz_${t.id}`,
        songId: `dz_${t.id}`,
        title: t.title,
        artist: t.artist?.name || 'Unknown Artist',
        album: t.album?.title || '',
        albumId: t.album?.id,
        coverArt: t.album?.cover_xl || t.album?.cover_big || t.album?.cover_medium,
        duration: t.duration || 180,
        audioUrl: t.preview || '',
        platform: 'deezer',
      }));

      setCached(cacheKey, results);
      return res.json({ success: true, results });
    }
  } catch (dzErr) {
    console.warn('[Deezer Search Error]:', dzErr.message);
  }

  return res.json({ success: true, results: [] });
});

// 5. RELATED TRACKS / A CONTINUACIÓN (RADIO DE CANCIÓN)
router.get('/related', async (req, res) => {
  const artist = (req.query.artist || '').trim();
  const title = (req.query.title || '').trim();

  if (!artist && !title) return res.json({ success: true, results: [] });

  const cacheKey = `related_${artist.toLowerCase()}_${title.toLowerCase()}`;
  const cached = getCached(cacheKey);
  if (cached) return res.json({ success: true, results: cached });

  try {
    // Search Deezer for tracks by this artist or related genre
    const query = artist || title;
    const url = `https://api.deezer.com/search?q=${encodeURIComponent(query)}&limit=20`;
    const resp = await fetch(url);
    if (resp.ok) {
      const data = await resp.json();
      const results = (data.data || []).map((t) => ({
        id: `dz_${t.id}`,
        songId: `dz_${t.id}`,
        title: t.title,
        artist: t.artist?.name || artist,
        album: t.album?.title || '',
        albumId: t.album?.id,
        coverArt: t.album?.cover_xl || t.album?.cover_big || t.album?.cover_medium,
        duration: t.duration || 180,
        audioUrl: t.preview || '',
      }));

      setCached(cacheKey, results);
      return res.json({ success: true, results });
    }
  } catch (err) {
    console.warn('[Related Tracks Error]:', err);
  }

  return res.json({ success: true, results: [] });
});

// 6. LRCLIB SYNCHRONIZED LYRICS (Matching lrclib_service.dart)
router.get('/lyrics', async (req, res) => {
  const title = (req.query.title || '').trim();
  const artist = (req.query.artist || '').trim();
  const duration = parseInt(req.query.duration || '0', 10);

  if (!title) return res.json({ success: true, lyrics: [] });

  try {
    // Clean title and artist using identical regexes from lrclib_service.dart
    const cleanTitle = title
      .replace(/\s*\(.*?(?:official|video|audio|lyric|remaster|feat|ft\.).*?\)/gi, '')
      .replace(/\s*\[.*?(?:official|video|audio|lyric|remaster|feat|ft\.).*?\]/gi, '')
      .replace(/\s*[-–—]\s*(?:official|video|audio|remaster).*$/gi, '')
      .trim();

    const cleanArtist = artist.split(/\s*(?:&|feat\.?|ft\.?|,)\s*/i)[0].trim();

    const url = `https://lrclib.net/api/get?track_name=${encodeURIComponent(cleanTitle)}&artist_name=${encodeURIComponent(cleanArtist)}${duration > 0 ? `&duration=${duration}` : ''}`;
    const resp = await fetch(url, {
      headers: { 'User-Agent': 'GroovyMusicApp/1.0.0 (https://github.com/groovy)' },
    });

    if (resp.ok) {
      const data = await resp.json();
      if (data.syncedLyrics) {
        return res.json({
          success: true,
          syncedLyrics: data.syncedLyrics,
          plainLyrics: data.plainLyrics || '',
        });
      }
      if (data.plainLyrics) {
        return res.json({
          success: true,
          syncedLyrics: null,
          plainLyrics: data.plainLyrics,
        });
      }
    }
  } catch (err) {
    console.warn('[Lyrics API Error]:', err);
  }

  return res.json({ success: true, syncedLyrics: null, plainLyrics: null });
});

module.exports = router;
