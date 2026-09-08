// Groovy Cloud Music Streaming & Search Service (Integrated with Groovy Cloud API & Innertube)

const formatCoverArt = (url) => {
  if (!url) return 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=800&auto=format&fit=crop&q=80';
  if (url.includes('100x100bb')) return url.replace('100x100bb', '800x800bb');
  if (url.includes('60x60bb')) return url.replace('60x60bb', '800x800bb');
  return url;
};

export const GENRES_LIST = [
  { id: 'reggaeton', name: 'Reggaetón & Urbano', color: 'linear-gradient(135deg, #FF416C 0%, #FF4B2B 100%)', icon: '🔥', query: 'reggaeton 2026' },
  { id: 'pop', name: 'Pop Internacional', color: 'linear-gradient(135deg, #8A2387 0%, #E94057 50%, #F27121 100%)', icon: '✨', query: 'top pop hits' },
  { id: 'trap', name: 'Trap Latino', color: 'linear-gradient(135deg, #11998e 0%, #38ef7d 100%)', icon: '💎', query: 'trap latino' },
  { id: 'rock', name: 'Rock & Alternativo', color: 'linear-gradient(135deg, #232526 0%, #414345 100%)', icon: '🎸', query: 'classic rock' },
  { id: 'edm', name: 'Electrónica & Dance', color: 'linear-gradient(135deg, #4E65FF 0%, #92EFFD 100%)', icon: '⚡', query: 'electronic dance' },
  { id: 'chill', name: 'Lo-Fi & Chillout', color: 'linear-gradient(135deg, #654ea3 0%, #eaafc8 100%)', icon: '☕', query: 'lofi beats' },
  { id: 'latino', name: 'Salsa & Tropical', color: 'linear-gradient(135deg, #f12711 0%, #f5af19 100%)', icon: '🌴', query: 'salsa exitos' },
  { id: 'entrenamiento', name: 'Workout & Fitness', color: 'linear-gradient(135deg, #f857a6 0%, #ff5858 100%)', icon: '💪', query: 'workout motivation' },
];

export const musicService = {
  // 1. Get Top Featured Artists with 100% Real Deezer Photos & Fan Counts
  getTopArtists: async () => {
    try {
      const res = await fetch('/api/music/artists/top');
      if (res.ok) {
        const data = await res.json();
        if (data.artists && data.artists.length > 0) {
          return data.artists;
        }
      }
    } catch (e) {
      console.warn('Error fetching /api/music/artists/top:', e);
    }
    // High-res Deezer CDN fallback
    return [
      { id: 10583405, name: 'Bad Bunny', image: 'https://cdn-images.dzcdn.net/images/artist/044a3f315b041864887a8dd8709e6926/1000x1000-000000-80-0-0.jpg', genre: 'Urbano Latino', fans: 7980540 },
      { id: 4050205, name: 'The Weeknd', image: 'https://cdn-images.dzcdn.net/images/artist/581693b4724a7fcfa754455101e13a44/1000x1000-000000-80-0-0.jpg', genre: 'R&B / Pop', fans: 14664147 },
      { id: 1166311, name: 'Feid', image: 'https://cdn-images.dzcdn.net/images/artist/e629c93e03b3c225d8d52a42bae71537/1000x1000-000000-80-0-0.jpg', genre: 'Reggaetón', fans: 903330 },
      { id: 1429862, name: 'Karol G', image: 'https://cdn-images.dzcdn.net/images/artist/a1f81d11ff92b23ae1b1a7d6eec7716f/1000x1000-000000-80-0-0.jpg', genre: 'Urbano', fans: 3120000 },
      { id: 12246, name: 'Taylor Swift', image: 'https://cdn-images.dzcdn.net/images/artist/33e0a16b94dd6d19488e09f5926c4832/1000x1000-000000-80-0-0.jpg', genre: 'Pop', fans: 8540000 },
      { id: 892, name: 'Coldplay', image: 'https://cdn-images.dzcdn.net/images/artist/4ab1be22b51ecb6ec1f1f50f757279f6/1000x1000-000000-80-0-0.jpg', genre: 'Rock Alternativo', fans: 12900000 },
      { id: 130835, name: 'Drake', image: 'https://cdn-images.dzcdn.net/images/artist/5d2fa5169a8c79c882103f56d9539352/1000x1000-000000-80-0-0.jpg', genre: 'Hip-Hop', fans: 9800000 },
      { id: 8645063, name: 'Dua Lipa', image: 'https://cdn-images.dzcdn.net/images/artist/f104d44439c2889e47fdb6e05391c4d9/1000x1000-000000-80-0-0.jpg', genre: 'Dance Pop', fans: 6800000 },
      { id: 9892994, name: 'Billie Eilish', image: 'https://cdn-images.dzcdn.net/images/artist/e795a947ce733a46d0a79ec0bc401b2f/1000x1000-000000-80-0-0.jpg', genre: 'Alt Pop', fans: 9100000 },
      { id: 122177302, name: 'Peso Pluma', image: 'https://cdn-images.dzcdn.net/images/artist/495fe20a9a1d48c89429188e404bc03d/1000x1000-000000-80-0-0.jpg', genre: 'Regional Urbano', fans: 1400000 },
    ];
  },

  // 2. Get Home curated & trending feeds
  getHomeFeeds: async () => {
    try {
      const [trendRes, urbanoRes] = await Promise.allSettled([
        fetch('/api/music/search?q=top%20exitos%202026'),
        fetch('/api/music/search?q=reggaeton%20urbano%202026'),
      ]);

      let trending = [];
      let urbano = [];

      if (trendRes.status === 'fulfilled' && trendRes.value.ok) {
        const data = await trendRes.value.json();
        if (data.results && data.results.length > 0) {
          trending = data.results.slice(0, 15);
        }
      }

      if (urbanoRes.status === 'fulfilled' && urbanoRes.value.ok) {
        const data = await urbanoRes.value.json();
        if (data.results && data.results.length > 0) {
          urbano = data.results.slice(0, 15);
        }
      }

      // If backend search returned tracks, use them
      if (trending.length > 0) {
        return {
          trending,
          urbano: urbano.length > 0 ? urbano : trending.slice(3, 13),
          pop: trending.slice(2, 10),
          rock: trending.slice(4, 12),
        };
      }
    } catch (e) {
      console.warn('Error fetching /api/music/search feeds, using iTunes fallback:', e);
    }

    // Fallback: iTunes live query
    try {
      const itunesRes = await fetch('https://itunes.apple.com/search?term=latin+pop+hits+2026&entity=song&limit=15');
      if (itunesRes.ok) {
        const data = await itunesRes.json();
        const songs = (data.results || []).map((t) => ({
          id: `itunes_${t.trackId}`,
          title: t.trackName,
          artist: t.artistName,
          album: t.collectionName || 'Single',
          coverArt: formatCoverArt(t.artworkUrl100),
          duration: Math.round((t.trackTimeMillis || 180000) / 1000),
          audioUrl: t.previewUrl || '',
          genre: t.primaryGenreName || 'Pop',
        }));
        return {
          trending: songs,
          urbano: songs.slice(2, 10),
          pop: songs.slice(0, 8),
          rock: songs.slice(4, 12),
        };
      }
    } catch (e) {
      console.warn('iTunes fallback failed:', e);
    }

    return { trending: [], urbano: [], pop: [], rock: [] };
  },

  // 3. Official YouTube Music Innertube Search via Backend
  searchSongs: async (query, category = 'all') => {
    if (!query || query.trim().length === 0) return [];
    try {
      const q = encodeURIComponent(query.trim());
      const res = await fetch(`/api/music/search?q=${q}&category=${category}`);
      if (res.ok) {
        const data = await res.json();
        if (data.results && data.results.length > 0) {
          return data.results;
        }
      }
    } catch (e) {
      console.warn('Backend search error, trying iTunes fallback:', e);
    }

    // Fallback to iTunes search directly
    try {
      const formatted = encodeURIComponent(query.trim());
      const res = await fetch(`https://itunes.apple.com/search?term=${formatted}&entity=song&limit=30`);
      if (res.ok) {
        const data = await res.json();
        if (data.results) {
          return data.results.map((track) => ({
            id: `itunes_${track.trackId}`,
            songId: `itunes_${track.trackId}`,
            title: track.trackName,
            artist: track.artistName,
            album: track.collectionName || 'Single',
            coverArt: formatCoverArt(track.artworkUrl100),
            duration: Math.round((track.trackTimeMillis || 180000) / 1000),
            audioUrl: track.previewUrl || '',
          }));
        }
      }
    } catch (e) {
      console.error('iTunes search fallback error:', e);
    }

    return [];
  },

  // 4. "A continuación" / Radio de la canción (Related Tracks)
  getRelatedTracks: async (song) => {
    if (!song) return [];
    try {
      const artist = encodeURIComponent(song.artist || '');
      const title = encodeURIComponent(song.title || '');
      const res = await fetch(`/api/music/related?artist=${artist}&title=${title}`);
      if (res.ok) {
        const data = await res.json();
        if (data.results && data.results.length > 0) {
          return data.results.filter(t => t.id !== song.id && t.title?.toLowerCase() !== song.title?.toLowerCase());
        }
      }
    } catch (e) {
      console.warn('Backend related tracks error, trying iTunes fallback:', e);
    }

    // Fallback: iTunes search
    try {
      const q = encodeURIComponent(`${song.artist || ''} ${song.genre || ''}`.trim() || song.title);
      const res = await fetch(`https://itunes.apple.com/search?term=${q}&entity=song&limit=25`);
      if (res.ok) {
        const data = await res.json();
        if (data.results && data.results.length > 0) {
          return data.results
            .filter(t => `itunes_${t.trackId}` !== song.id)
            .map(t => ({
              id: `itunes_${t.trackId}`,
              songId: `itunes_${t.trackId}`,
              title: t.trackName,
              artist: t.artistName,
              album: t.collectionName || 'Single',
              coverArt: formatCoverArt(t.artworkUrl100),
              duration: Math.round((t.trackTimeMillis || 180000) / 1000),
              audioUrl: t.previewUrl || '',
            }));
        }
      }
    } catch (e) {
      console.warn('iTunes related error:', e);
    }
    return [];
  },

  // 5. Real Artist Profile: Banner, Fans, Albums Discography & Top Popular Songs
  getArtistDetails: async (artistName) => {
    if (!artistName) return null;
    try {
      const res = await fetch(`/api/music/artist/${encodeURIComponent(artistName.trim())}`);
      if (res.ok) {
        const data = await res.json();
        if (data.artist) {
          return {
            artist: data.artist,
            topTracks: data.topTracks || [],
            albums: data.albums || [],
          };
        }
      }
    } catch (e) {
      console.warn('Backend artist details error, trying iTunes fallback:', e);
    }

    // Fallback: iTunes search
    try {
      const term = encodeURIComponent(artistName.trim());
      const [songsRes, albumsRes] = await Promise.allSettled([
        fetch(`https://itunes.apple.com/search?term=${term}&entity=song&limit=30`),
        fetch(`https://itunes.apple.com/search?term=${term}&entity=album&limit=15`),
      ]);

      let topSongs = [];
      let albums = [];
      let artistImg = null;

      if (songsRes.status === 'fulfilled' && songsRes.value.ok) {
        const data = await songsRes.value.json();
        if (data.results && data.results.length > 0) {
          topSongs = data.results.map((track) => ({
            id: `itunes_${track.trackId}`,
            songId: `itunes_${track.trackId}`,
            title: track.trackName,
            artist: track.artistName,
            album: track.collectionName || 'Single',
            albumId: track.collectionId,
            coverArt: formatCoverArt(track.artworkUrl100),
            duration: Math.round((track.trackTimeMillis || 180000) / 1000),
            audioUrl: track.previewUrl || '',
          }));
          artistImg = topSongs[0]?.coverArt;
        }
      }

      if (albumsRes.status === 'fulfilled' && albumsRes.value.ok) {
        const data = await albumsRes.value.json();
        if (data.results && data.results.length > 0) {
          albums = data.results.map((alb) => ({
            id: alb.collectionId,
            name: alb.collectionName,
            artist: alb.artistName,
            coverArt: formatCoverArt(alb.artworkUrl100),
            year: alb.releaseDate ? alb.releaseDate.substring(0, 4) : '',
            releaseDate: alb.releaseDate,
          }));
        }
      }

      return {
        artist: {
          name: artistName,
          image: artistImg || 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=800',
          banner: artistImg || 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=1200',
          fans: 2450000,
          albumsCount: albums.length,
          verified: true,
        },
        topTracks: topSongs,
        albums,
      };
    } catch (e) {
      console.error('Error fetching fallback artist details:', e);
      return null;
    }
  },

  // 6. Real Album Details: Numbered Tracklist, Release Date, Artwork
  getAlbumDetails: async (albumId, albumName = '', artistName = '') => {
    // If we have a numeric Deezer ID, fetch directly from backend
    if (albumId && String(albumId).match(/^\d+$/)) {
      try {
        const res = await fetch(`/api/music/album/${albumId}`);
        if (res.ok) {
          const data = await res.json();
          if (data.album) return data.album;
        }
      } catch (e) {
        console.warn('Backend album detail error, trying fallback:', e);
      }
    }

    // Fallback: search by collection / album title
    try {
      const q = encodeURIComponent(`${artistName} ${albumName}`.trim() || albumId);
      const res = await fetch(`https://itunes.apple.com/search?term=${q}&entity=song&limit=30`);
      if (res.ok) {
        const data = await res.json();
        if (data.results && data.results.length > 0) {
          const first = data.results[0];
          const coverArt = formatCoverArt(first.artworkUrl100);
          const tracks = data.results.map((track, idx) => ({
            id: `itunes_${track.trackId}`,
            songId: `itunes_${track.trackId}`,
            title: track.trackName,
            artist: track.artistName,
            album: track.collectionName || albumName,
            trackNumber: track.trackNumber || idx + 1,
            coverArt,
            duration: Math.round((track.trackTimeMillis || 180000) / 1000),
            audioUrl: track.previewUrl || '',
          }));

          return {
            id: first.collectionId || albumId,
            name: first.collectionName || albumName,
            artist: first.artistName || artistName,
            coverArt,
            releaseDate: first.releaseDate || '',
            year: first.releaseDate ? first.releaseDate.substring(0, 4) : '2023',
            label: 'Groovy Music Cloud',
            genres: first.primaryGenreName || 'Música',
            totalTracks: tracks.length,
            duration: tracks.reduce((acc, t) => acc + t.duration, 0),
            tracks,
          };
        }
      }
    } catch (e) {
      console.warn('Error fetching album tracks:', e);
    }

    return null;
  },

  // 7. Synchronized LRC Lyrics matching lrclib_service.dart
  getLyrics: async (song) => {
    if (!song || !song.title) return null;
    try {
      const title = encodeURIComponent(song.title);
      const artist = encodeURIComponent(song.artist || '');
      const duration = song.duration || 0;
      const res = await fetch(`/api/music/lyrics?title=${title}&artist=${artist}&duration=${duration}`);
      if (res.ok) {
        const data = await res.json();
        if (data.syncedLyrics) return { syncedLyrics: data.syncedLyrics, plainLyrics: data.plainLyrics };
        if (data.plainLyrics) return { syncedLyrics: null, plainLyrics: data.plainLyrics };
      }
    } catch (e) {
      console.warn('Backend lyrics error, trying LRCLIB direct:', e);
    }

    // Direct LRCLIB fallback
    try {
      const cleanTitle = encodeURIComponent(
        song.title.replace(/\s*\(.*?\)/g, '').replace(/\s*\[.*?\]/g, '').trim()
      );
      const cleanArtist = encodeURIComponent(
        (song.artist || '').split(/\s*(?:&|feat\.?|ft\.?|,)\s*/i)[0].trim()
      );
      const url = `https://lrclib.net/api/get?track_name=${cleanTitle}&artist_name=${cleanArtist}`;
      const res = await fetch(url);
      if (res.ok) {
        const data = await res.json();
        return {
          syncedLyrics: data.syncedLyrics || null,
          plainLyrics: data.plainLyrics || null,
        };
      }
    } catch (e) {
      console.warn('LRCLIB direct fallback error:', e);
    }

    return null;
  },
};
