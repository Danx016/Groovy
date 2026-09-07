// Groovy Cloud MySQL API Service
const getBaseUrl = () => {
  if (typeof window !== 'undefined') {
    // If running on the VPS or localhost behind Nginx, use relative /api
    if (window.location.hostname === '157.137.233.119' || window.location.hostname.includes('duckdns.org')) {
      return '/api';
    }
  }
  return 'http://157.137.233.119/api';
};

export const API_BASE = getBaseUrl();

export const getAuthToken = () => {
  return localStorage.getItem('groovy_auth_token') || null;
};

export const setAuthToken = (token) => {
  if (token) {
    localStorage.setItem('groovy_auth_token', token);
  } else {
    localStorage.removeItem('groovy_auth_token');
  }
};

export const authFetch = async (endpoint, options = {}) => {
  const token = getAuthToken();
  const headers = {
    'Content-Type': 'application/json',
    ...(options.headers || {}),
  };

  if (token) {
    headers['Authorization'] = `Bearer ${token}`;
  }

  const url = endpoint.startsWith('http') ? endpoint : `${API_BASE}${endpoint}`;

  const response = await fetch(url, {
    ...options,
    headers,
  });

  const data = await response.json().catch(() => ({}));

  if (!response.ok) {
    throw new Error(data.error || data.message || `Request failed (${response.status})`);
  }

  return data;
};

// Auth API Endpoints
export const authApi = {
  login: (email, password) =>
    authFetch('/auth/login', {
      method: 'POST',
      body: JSON.stringify({ email, password }),
    }),

  register: (name, email, password) =>
    authFetch('/auth/register', {
      method: 'POST',
      body: JSON.stringify({ name, email, password }),
    }),

  getProfile: () => authFetch('/auth/profile'),
};

// Library API Endpoints (MySQL)
export const libraryApi = {
  getFavorites: () => authFetch('/library/favorites'),

  addFavorite: (song) =>
    authFetch('/library/favorites', {
      method: 'POST',
      body: JSON.stringify({
        song_id: song.id,
        title: song.title,
        artist: song.artist,
        album: song.album || '',
        cover_art: song.coverArt || '',
        duration: song.duration || 0,
      }),
    }),

  removeFavorite: (songId) =>
    authFetch(`/library/favorites/${encodeURIComponent(songId)}`, {
      method: 'DELETE',
    }),

  getPlaylists: () => authFetch('/library/playlists'),

  createPlaylist: (name, description = '') =>
    authFetch('/library/playlists', {
      method: 'POST',
      body: JSON.stringify({ name, description }),
    }),

  deletePlaylist: (id) =>
    authFetch(`/library/playlists/${id}`, {
      method: 'DELETE',
    }),

  getPlaylistSongs: (playlistId) =>
    authFetch(`/library/playlists/${playlistId}/songs`),

  addSongToPlaylist: (playlistId, song) =>
    authFetch(`/library/playlists/${playlistId}/songs`, {
      method: 'POST',
      body: JSON.stringify({
        song_id: song.id,
        title: song.title,
        artist: song.artist,
        album: song.album || '',
        cover_art: song.coverArt || '',
        duration: song.duration || 0,
      }),
    }),

  removeSongFromPlaylist: (playlistId, songId) =>
    authFetch(`/library/playlists/${playlistId}/songs/${encodeURIComponent(songId)}`, {
      method: 'DELETE',
    }),

  getHistory: () => authFetch('/library/history'),

  addToHistory: (song) =>
    authFetch('/library/history', {
      method: 'POST',
      body: JSON.stringify({
        song_id: song.id,
        title: song.title,
        artist: song.artist,
        album: song.album || '',
        cover_art: song.coverArt || '',
        duration: song.duration || 0,
      }),
    }),
};

// Admin API Endpoints (MySQL Telemetry & Control)
export const adminApi = {
  getMetrics: () => authFetch('/admin/metrics'),

  getUsers: (params = {}) => {
    const query = new URLSearchParams();
    if (params.q) query.append('q', params.q);
    if (params.role) query.append('role', params.role);
    if (params.status) query.append('status', params.status);
    const queryString = query.toString();
    return authFetch(`/admin/users${queryString ? `?${queryString}` : ''}`);
  },

  getUserDetails: (userId) => authFetch(`/admin/users/${userId}`),

  updateUser: (userId, data) =>
    authFetch(`/admin/users/${userId}`, {
      method: 'PUT',
      body: JSON.stringify(data),
    }),

  toggleBanUser: (userId, isBanned) =>
    authFetch(`/admin/users/${userId}/ban`, {
      method: 'PUT',
      body: JSON.stringify({ isBanned }),
    }),

  deleteUser: (userId) =>
    authFetch(`/admin/users/${userId}`, {
      method: 'DELETE',
    }),

  getSessions: (limit = 100) => authFetch(`/admin/sessions?limit=${limit}`),
};
