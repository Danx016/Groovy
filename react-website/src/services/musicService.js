// Groovy Music Search & Streaming Service

// Curated Top Hits / Genres for instant explore
const TRENDING_CATALOG = [
  {
    id: 'yt_1',
    title: 'Starboy',
    artist: 'The Weeknd ft. Daft Punk',
    album: 'Starboy',
    coverArt: 'https://images.unsplash.com/photo-1614613535308-eb5fbd3d2c17?w=600&auto=format&fit=crop&q=80',
    duration: 230,
    audioUrl: 'https://cdn.freesound.org/previews/612/612642_5674468-lq.mp3',
  },
  {
    id: 'yt_2',
    title: 'Monaco',
    artist: 'Bad Bunny',
    album: 'Nadie Sabe Lo Que Va A Pasar Mañana',
    coverArt: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&auto=format&fit=crop&q=80',
    duration: 267,
    audioUrl: 'https://cdn.freesound.org/previews/682/682245_14625902-lq.mp3',
  },
  {
    id: 'yt_3',
    title: 'Blinding Lights',
    artist: 'The Weeknd',
    album: 'After Hours',
    coverArt: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&auto=format&fit=crop&q=80',
    duration: 200,
    audioUrl: 'https://cdn.freesound.org/previews/530/530415_11861866-lq.mp3',
  },
  {
    id: 'yt_4',
    title: 'QLONA',
    artist: 'KAROL G & Peso Pluma',
    album: 'MAÑANA SERÁ BONITO',
    coverArt: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=600&auto=format&fit=crop&q=80',
    duration: 172,
    audioUrl: 'https://cdn.freesound.org/previews/612/612642_5674468-lq.mp3',
  },
  {
    id: 'yt_5',
    title: 'Flowers',
    artist: 'Miley Cyrus',
    album: 'Endless Summer Vacation',
    coverArt: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=600&auto=format&fit=crop&q=80',
    duration: 200,
    audioUrl: 'https://cdn.freesound.org/previews/682/682245_14625902-lq.mp3',
  },
  {
    id: 'yt_6',
    title: 'As It Was',
    artist: 'Harry Styles',
    album: "Harry's House",
    coverArt: 'https://images.unsplash.com/photo-1487180144351-b8472da7d491?w=600&auto=format&fit=crop&q=80',
    duration: 167,
    audioUrl: 'https://cdn.freesound.org/previews/530/530415_11861866-lq.mp3',
  },
  {
    id: 'yt_7',
    title: 'Columbia',
    artist: 'Quevedo',
    album: 'Columbia Single',
    coverArt: 'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=600&auto=format&fit=crop&q=80',
    duration: 186,
    audioUrl: 'https://cdn.freesound.org/previews/612/612642_5674468-lq.mp3',
  },
  {
    id: 'yt_8',
    title: 'LALA',
    artist: 'Myke Towers',
    album: 'LA VIDA ES UNA',
    coverArt: 'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=600&auto=format&fit=crop&q=80',
    duration: 198,
    audioUrl: 'https://cdn.freesound.org/previews/682/682245_14625902-lq.mp3',
  },
];

export const musicService = {
  // Get Trending Songs
  getTrendingSongs: async () => {
    try {
      // Fetch top hits from iTunes API for live streaming previews
      const res = await fetch(
        'https://itunes.apple.com/search?term=latin+pop+hits&entity=song&limit=15'
      );
      if (res.ok) {
        const data = await res.json();
        if (data.results && data.results.length > 0) {
          return data.results.map((track) => ({
            id: `itunes_${track.trackId}`,
            title: track.trackName,
            artist: track.artistName,
            album: track.collectionName || 'Single',
            coverArt: track.artworkUrl100
              ? track.artworkUrl100.replace('100x100bb', '600x600bb')
              : 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600',
            duration: Math.round((track.trackTimeMillis || 180000) / 1000),
            audioUrl: track.previewUrl || '',
          }));
        }
      }
    } catch (e) {
      console.warn('Live trending fetch failed, fallback to catalog:', e);
    }
    return TRENDING_CATALOG;
  },

  // Search songs by keyword
  searchSongs: async (query) => {
    if (!query || query.trim().length === 0) return [];
    try {
      const formatted = encodeURIComponent(query.trim());
      const res = await fetch(
        `https://itunes.apple.com/search?term=${formatted}&entity=song&limit=25`
      );
      if (res.ok) {
        const data = await res.json();
        if (data.results) {
          return data.results.map((track) => ({
            id: `itunes_${track.trackId}`,
            title: track.trackName,
            artist: track.artistName,
            album: track.collectionName || 'Single',
            coverArt: track.artworkUrl100
              ? track.artworkUrl100.replace('100x100bb', '600x600bb')
              : 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600',
            duration: Math.round((track.trackTimeMillis || 180000) / 1000),
            audioUrl: track.previewUrl || '',
          }));
        }
      }
    } catch (e) {
      console.error('Search error:', e);
    }
    // Filter static catalog if offline
    return TRENDING_CATALOG.filter(
      (s) =>
        s.title.toLowerCase().includes(query.toLowerCase()) ||
        s.artist.toLowerCase().includes(query.toLowerCase())
    );
  },

  // Fetch lyrics from LRCLIB
  getLyrics: async (artist, title) => {
    try {
      const q = encodeURIComponent(`${title} ${artist}`);
      const res = await fetch(`https://lrclib.net/api/search?q=${q}`);
      if (res.ok) {
        const list = await res.json();
        if (Array.isArray(list) && list.length > 0) {
          const match = list[0];
          return {
            syncedLyrics: match.syncedLyrics || null,
            plainLyrics: match.plainLyrics || null,
          };
        }
      }
    } catch (e) {
      console.warn('Lyrics fetch failed:', e);
    }
    return { syncedLyrics: null, plainLyrics: null };
  },
};
