import React, { useState, useEffect } from 'react';
import { ArrowLeft, Play, Trash2, ListMusic, Music, Clock } from 'lucide-react';
import { libraryApi } from '../../services/api';
import { useLibrary } from '../../context/LibraryContext';
import { usePlayer } from '../../context/PlayerContext';
import { SongCard } from '../ui/SongCard';

export const PlaylistDetailView = ({ playlist, onBack }) => {
  const [songs, setSongs] = useState([]);
  const [loading, setLoading] = useState(true);
  const { deletePlaylist, removeSongFromPlaylist } = useLibrary();
  const { playSong } = usePlayer();

  useEffect(() => {
    const fetchSongs = async () => {
      if (!playlist) return;
      try {
        const res = await libraryApi.getPlaylistSongs(playlist.id);
        if (res.songs) {
          setSongs(
            res.songs.map((s) => ({
              id: s.song_id,
              title: s.title,
              artist: s.artist,
              album: s.album,
              coverArt: s.cover_art,
              duration: s.duration,
            }))
          );
        }
      } catch (e) {
        console.error('Error fetching playlist songs:', e);
      } finally {
        setLoading(false);
      }
    };
    fetchSongs();
  }, [playlist]);

  if (!playlist) return null;

  const handlePlayAll = () => {
    if (songs.length > 0) {
      playSong(songs[0], songs);
    }
  };

  const handleDeleteSong = async (songId) => {
    try {
      setSongs((prev) => prev.filter((s) => s.id !== songId));
      await removeSongFromPlaylist(playlist.id, songId);
    } catch (e) {
      console.error(e);
    }
  };

  return (
    <div className="space-y-6 pb-28">
      {/* Back Button */}
      <button
        onClick={onBack}
        className="inline-flex items-center gap-2 rounded-full border border-white/10 bg-white/5 px-4 py-2 text-xs font-semibold text-slate-300 hover:bg-white/10 hover:text-white"
      >
        <ArrowLeft size={16} />
        <span>Volver a Biblioteca</span>
      </button>

      {/* Playlist Hero Banner */}
      <div className="flex flex-col gap-6 rounded-3xl border border-white/10 bg-gradient-to-r from-emerald-600/20 via-teal-700/10 to-transparent p-6 backdrop-blur-xl sm:flex-row sm:items-center">
        <div className="flex h-32 w-32 shrink-0 items-center justify-center rounded-2xl bg-gradient-to-tr from-emerald-500 to-teal-700 text-white shadow-xl shadow-emerald-500/10">
          <ListMusic size={60} className="text-white/90" />
        </div>

        <div className="flex-1 min-w-0">
          <span className="text-[11px] font-bold tracking-wider text-emerald-400 uppercase">
            Playlist
          </span>
          <h1 className="font-display text-3xl font-black text-white truncate mt-1">
            {playlist.name}
          </h1>
          <p className="mt-1 text-sm text-slate-300">
            {playlist.description || 'Playlist de usuario'}
          </p>
          <p className="mt-2 text-xs text-slate-400">
            {songs.length} {songs.length === 1 ? 'canción' : 'canciones'}
          </p>

          <div className="mt-4 flex items-center gap-3">
            {songs.length > 0 && (
              <button
                onClick={handlePlayAll}
                className="flex items-center gap-2 rounded-full bg-gradient-to-r from-[#1db954] to-[#10b981] px-6 py-2.5 text-xs font-bold text-black shadow-lg hover:scale-105 transition-transform"
              >
                <Play size={16} className="fill-black" />
                <span>Reproducir Todo</span>
              </button>
            )}

            <button
              onClick={() => {
                if (confirm(`¿Eliminar la playlist "${playlist.name}"?`)) {
                  deletePlaylist(playlist.id);
                  onBack();
                }
              }}
              className="flex items-center gap-1.5 rounded-full border border-red-500/20 bg-red-500/10 px-4 py-2.5 text-xs font-semibold text-red-400 hover:bg-red-500/20"
            >
              <Trash2 size={14} />
              <span>Eliminar</span>
            </button>
          </div>
        </div>
      </div>

      {/* Songs in playlist */}
      <div className="space-y-2">
        {songs.map((song) => (
          <div key={song.id} className="relative group">
            <SongCard song={song} queue={songs} />
            <button
              onClick={() => handleDeleteSong(song.id)}
              title="Quitar de playlist"
              className="absolute right-12 top-1/2 -translate-y-1/2 rounded-full p-2 text-slate-500 opacity-0 group-hover:opacity-100 hover:text-red-400 hover:bg-white/10 transition-all"
            >
              <Trash2 size={15} />
            </button>
          </div>
        ))}

        {songs.length === 0 && !loading && (
          <div className="rounded-3xl border border-dashed border-white/10 p-12 text-center text-slate-400">
            <Music size={40} className="mx-auto mb-3 text-slate-600" />
            <p className="font-semibold text-white">Esta playlist está vacía</p>
            <p className="mt-1 text-xs text-slate-500">
              Busca canciones en la sección Explorar y presiona los 3 puntos para añadirlas aquí.
            </p>
          </div>
        )}
      </div>
    </div>
  );
};
