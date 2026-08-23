import React from 'react';
import { ListMusic, Play, Trash2 } from 'lucide-react';
import { useLibrary } from '../../context/LibraryContext';

export const PlaylistCard = ({ playlist, onClick }) => {
  const { deletePlaylist } = useLibrary();

  const gradients = [
    'from-emerald-500 to-teal-700',
    'from-purple-500 to-indigo-700',
    'from-rose-500 to-pink-700',
    'from-amber-500 to-orange-700',
    'from-blue-500 to-cyan-700',
  ];
  const gradient = gradients[playlist.id % gradients.length];

  const handleDelete = (e) => {
    e.stopPropagation();
    if (confirm(`¿Eliminar playlist "${playlist.name}"?`)) {
      deletePlaylist(playlist.id);
    }
  };

  return (
    <div
      onClick={onClick}
      className="group relative flex flex-col overflow-hidden rounded-3xl border border-white/5 bg-white/5 p-4 cursor-pointer transition-all hover:border-white/20 hover:bg-white/10 hover:shadow-xl"
    >
      {/* Dynamic Gradient Cover */}
      <div
        className={`relative aspect-square w-full rounded-2xl bg-gradient-to-tr ${gradient} p-5 flex flex-col justify-between shadow-lg shadow-black/30 overflow-hidden`}
      >
        <ListMusic size={32} className="text-white/80" />

        {/* Hover play button */}
        <div className="absolute right-4 bottom-4 flex h-12 w-12 items-center justify-center rounded-full bg-black/80 text-white shadow-xl opacity-0 group-hover:opacity-100 transition-all group-hover:scale-105">
          <Play size={20} className="fill-white ml-0.5" />
        </div>
      </div>

      {/* Info & Delete */}
      <div className="mt-3.5 flex items-center justify-between">
        <div className="min-w-0 flex-1">
          <h4 className="truncate text-sm font-bold text-white group-hover:text-emerald-400 transition-colors">
            {playlist.name}
          </h4>
          <p className="text-xs text-slate-400">
            {playlist.description || 'Playlist personalizada'}
          </p>
        </div>

        <button
          onClick={handleDelete}
          className="rounded-full p-2 text-slate-500 opacity-0 group-hover:opacity-100 hover:text-red-400 hover:bg-white/10 transition-all"
        >
          <Trash2 size={16} />
        </button>
      </div>
    </div>
  );
};
