import React, { useState } from 'react';
import { X, ListMusic, Plus } from 'lucide-react';
import { useLibrary } from '../../context/LibraryContext';

export const CreatePlaylistModal = ({ isOpen, onClose }) => {
  const { createPlaylist } = useLibrary();
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [loading, setLoading] = useState(false);

  if (!isOpen) return null;

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!name.trim()) return;
    setLoading(true);
    try {
      await createPlaylist(name.trim(), description.trim());
      setName('');
      setDescription('');
      onClose();
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div onClick={onClose} className="absolute inset-0 bg-black/80 backdrop-blur-md" />
      <div className="relative w-full max-w-md rounded-3xl border border-white/10 bg-[#121824] p-6 shadow-2xl backdrop-blur-xl">
        <button
          onClick={onClose}
          className="absolute right-5 top-5 rounded-full p-2 text-slate-400 hover:bg-white/10 hover:text-white"
        >
          <X size={18} />
        </button>

        <div className="flex items-center gap-3 mb-6">
          <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-gradient-to-tr from-emerald-500 to-teal-400 text-black">
            <ListMusic size={24} />
          </div>
          <div>
            <h3 className="font-display text-xl font-bold text-white">Nueva Playlist</h3>
            <p className="text-xs text-slate-400">Guarda tus canciones favoritas en MySQL</p>
          </div>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="mb-1.5 block text-xs font-medium text-slate-300">
              Nombre de la playlist
            </label>
            <input
              type="text"
              required
              autoFocus
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="Ej. Éxitos 2026, Gym, Relax"
              className="w-full rounded-xl border border-white/10 bg-white/5 py-2.5 px-4 text-sm text-white placeholder-slate-500 focus:border-emerald-500 focus:bg-white/10"
            />
          </div>

          <div>
            <label className="mb-1.5 block text-xs font-medium text-slate-300">
              Descripción (opcional)
            </label>
            <textarea
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              placeholder="¿De qué trata esta lista?"
              rows={3}
              className="w-full rounded-xl border border-white/10 bg-white/5 py-2.5 px-4 text-sm text-white placeholder-slate-500 focus:border-emerald-500 focus:bg-white/10"
            />
          </div>

          <button
            type="submit"
            disabled={loading || !name.trim()}
            className="mt-4 flex w-full items-center justify-center gap-2 rounded-xl bg-gradient-to-r from-[#1db954] to-[#10b981] py-3 text-sm font-bold text-black shadow-lg shadow-[#1db954]/25 hover:scale-[1.02] active:scale-[0.98] disabled:opacity-50"
          >
            {loading ? (
              <div className="h-5 w-5 animate-spin rounded-full border-2 border-black border-t-transparent" />
            ) : (
              <>
                <Plus size={18} />
                <span>Crear Playlist</span>
              </>
            )}
          </button>
        </form>
      </div>
    </div>
  );
};
