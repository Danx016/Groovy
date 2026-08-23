import React, { createContext, useContext, useState, useEffect, useCallback } from 'react';
import { libraryApi } from '../services/api';
import { useAuth } from './AuthContext';

const LibraryContext = createContext(null);

export const LibraryProvider = ({ children }) => {
  const { isAuthenticated } = useAuth();
  const [favorites, setFavorites] = useState([]);
  const [playlists, setPlaylists] = useState([]);
  const [history, setHistory] = useState([]);
  const [isLoading, setIsLoading] = useState(false);

  // Fetch all user library items when authenticated
  const fetchLibrary = useCallback(async () => {
    if (!isAuthenticated) {
      setFavorites([]);
      setPlaylists([]);
      setHistory([]);
      return;
    }
    setIsLoading(true);
    try {
      const [favRes, playRes, histRes] = await Promise.allSettled([
        libraryApi.getFavorites(),
        libraryApi.getPlaylists(),
        libraryApi.getHistory(),
      ]);

      if (favRes.status === 'fulfilled' && favRes.value.favorites) {
        setFavorites(
          favRes.value.favorites.map((f) => ({
            id: f.song_id,
            title: f.title,
            artist: f.artist,
            album: f.album,
            coverArt: f.cover_art,
            duration: f.duration,
          }))
        );
      }

      if (playRes.status === 'fulfilled' && playRes.value.playlists) {
        setPlaylists(playRes.value.playlists);
      }

      if (histRes.status === 'fulfilled' && histRes.value.history) {
        setHistory(
          histRes.value.history.map((h) => ({
            id: h.song_id,
            title: h.title,
            artist: h.artist,
            album: h.album,
            coverArt: h.cover_art,
            duration: h.duration,
            playedAt: h.played_at,
          }))
        );
      }
    } catch (e) {
      console.error('Error fetching library from MySQL:', e);
    } finally {
      setIsLoading(false);
    }
  }, [isAuthenticated]);

  useEffect(() => {
    fetchLibrary();
  }, [fetchLibrary]);

  const isFavorite = (songId) => {
    return favorites.some((f) => f.id === songId);
  };

  const toggleFavorite = async (song) => {
    if (!isAuthenticated) return false;
    const exists = isFavorite(song.id);
    try {
      if (exists) {
        setFavorites((prev) => prev.filter((f) => f.id !== song.id));
        await libraryApi.removeFavorite(song.id);
      } else {
        setFavorites((prev) => [song, ...prev]);
        await libraryApi.addFavorite(song);
      }
      return !exists;
    } catch (e) {
      console.error('Error toggling favorite:', e);
      // Revert if error
      fetchLibrary();
      return exists;
    }
  };

  const createPlaylist = async (name, description = '') => {
    if (!isAuthenticated) return null;
    try {
      const res = await libraryApi.createPlaylist(name, description);
      await fetchLibrary();
      return res.playlist;
    } catch (e) {
      console.error('Error creating playlist:', e);
      throw e;
    }
  };

  const deletePlaylist = async (id) => {
    if (!isAuthenticated) return;
    try {
      setPlaylists((prev) => prev.filter((p) => p.id !== id));
      await libraryApi.deletePlaylist(id);
    } catch (e) {
      console.error('Error deleting playlist:', e);
      fetchLibrary();
    }
  };

  const addSongToPlaylist = async (playlistId, song) => {
    if (!isAuthenticated) return;
    try {
      await libraryApi.addSongToPlaylist(playlistId, song);
      await fetchLibrary();
    } catch (e) {
      console.error('Error adding song to playlist:', e);
      throw e;
    }
  };

  const removeSongFromPlaylist = async (playlistId, songId) => {
    if (!isAuthenticated) return;
    try {
      await libraryApi.removeSongFromPlaylist(playlistId, songId);
      await fetchLibrary();
    } catch (e) {
      console.error('Error removing song from playlist:', e);
    }
  };

  const recordPlayHistory = async (song) => {
    if (!isAuthenticated || !song) return;
    try {
      await libraryApi.addToHistory(song);
      setHistory((prev) => [song, ...prev.slice(0, 49)]);
    } catch (e) {
      // Quiet fail for history
    }
  };

  return (
    <LibraryContext.Provider
      value={{
        favorites,
        playlists,
        history,
        isLoading,
        isFavorite,
        toggleFavorite,
        createPlaylist,
        deletePlaylist,
        addSongToPlaylist,
        removeSongFromPlaylist,
        recordPlayHistory,
        refreshLibrary: fetchLibrary,
      }}
    >
      {children}
    </LibraryContext.Provider>
  );
};

export const useLibrary = () => {
  const context = useContext(LibraryContext);
  if (!context) {
    throw new Error('useLibrary must be used within a LibraryProvider');
  }
  return context;
};
