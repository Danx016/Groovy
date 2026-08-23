import React, { useState } from 'react';
import { Heart, ListMusic, History, Play, Plus, LogIn } from 'lucide-react';
import { useLibrary } from '../../context/LibraryContext';
import { usePlayer } from '../../context/PlayerContext';
import { useAuth } from '../../context/AuthContext';
import { SongCard } from '../ui/SongCard';
import { PlaylistCard } from '../ui/PlaylistCard';

export const LibraryView = ({ onSelectPlaylist, onOpenCreatePlaylist }) => {
  const { favorites, playlists, history, isLoading } = useLibrary();
  const { playSong } = usePlayer();
  const { isAuthenticated, openAuthModal } = useAuth();
  const [tab, setTab] = useState('favorites');

  if (!isAuthenticated) {
    return (
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', minHeight: '60vh', padding: '32px', textAlign: 'center' }}>
        <div style={{ width: '72px', height: '72px', borderRadius: '16px', overflow: 'hidden', marginBottom: '20px', boxShadow: '0 8px 24px rgba(0,0,0,0.5)' }}>
          <img src="./logo.png" alt="Groovy" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
        </div>
        <h2 style={{ fontSize: '22px', fontWeight: 700, letterSpacing: '-0.3px' }}>Tu Biblioteca</h2>
        <p style={{ fontSize: '15px', color: '#B3B3B3', marginTop: '8px', maxWidth: '380px' }}>
          Inicia sesión con tu cuenta para ver tus canciones favoritas, playlists e historial sincronizados con MySQL.
        </p>
        <button
          onClick={openAuthModal}
          style={{
            marginTop: '24px', padding: '14px 28px', borderRadius: '12px',
            background: '#FA243C', color: '#fff', fontWeight: 700, fontSize: '15px',
            display: 'flex', alignItems: 'center', gap: '8px',
          }}
        >
          <LogIn size={18} />
          <span>Iniciar Sesión / Crear Cuenta</span>
        </button>
      </div>
    );
  }

  /* Filter pills (iOS/Spotify style) */
  const TABS = [
    { id: 'favorites', label: `Faves (${favorites.length})`, icon: Heart },
    { id: 'playlists', label: `Albums (${playlists.length})`, icon: ListMusic },
    { id: 'history', label: 'Reciente', icon: History },
  ];

  return (
    <div style={{ paddingBottom: '148px' }}>
      {/* Header */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '16px' }}>
        <h1 style={{ fontSize: '28px', fontWeight: 700, letterSpacing: '-0.5px' }}>Tu Biblioteca</h1>
        {tab === 'favorites' && favorites.length > 0 && (
          <button
            onClick={() => playSong(favorites[0], favorites)}
            style={{
              display: 'flex', alignItems: 'center', gap: '6px', padding: '8px 16px',
              borderRadius: '20px', background: '#FA243C', color: '#fff', fontWeight: 700, fontSize: '13px',
            }}
          >
            <Play size={14} style={{ fill: '#fff' }} /> Reproducir
          </button>
        )}
        {tab === 'playlists' && (
          <button
            onClick={onOpenCreatePlaylist}
            style={{
              display: 'flex', alignItems: 'center', gap: '6px', padding: '8px 16px',
              borderRadius: '20px', background: '#282828', color: '#fff', fontWeight: 600, fontSize: '13px',
              border: '0.5px solid #404040',
            }}
          >
            <Plus size={14} /> Nueva
          </button>
        )}
      </div>

      {/* Filter pills */}
      <div style={{ display: 'flex', gap: '8px', marginBottom: '20px', overflowX: 'auto', paddingBottom: '4px' }}>
        {TABS.map(({ id, label }) => (
          <button
            key={id}
            onClick={() => setTab(id)}
            style={{
              padding: '7px 14px', borderRadius: '20px', fontSize: '13px', fontWeight: 600,
              whiteSpace: 'nowrap', flexShrink: 0, transition: 'all 0.15s',
              background: tab === id ? '#FA243C' : '#282828',
              color: tab === id ? '#fff' : '#B3B3B3',
              border: `0.5px solid ${tab === id ? '#FA243C' : '#404040'}`,
            }}
          >
            {label}
          </button>
        ))}
      </div>

      {/* Content */}
      {tab === 'favorites' && (
        <div style={{ display: 'flex', flexDirection: 'column' }}>
          {favorites.map(s => <SongCard key={s.id} song={s} queue={favorites} />)}
          {favorites.length === 0 && !isLoading && (
            <EmptyState icon={<Heart size={40} style={{ color: '#6B6B6B' }} />}
              title="Sin canciones favoritas" sub="Presiona ❤️ en cualquier canción para guardarla aquí." />
          )}
        </div>
      )}

      {tab === 'playlists' && (
        <div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(160px, 1fr))', gap: '16px' }}>
            {playlists.map(pl => (
              <PlaylistCard key={pl.id} playlist={pl} onClick={() => onSelectPlaylist?.(pl)} />
            ))}
          </div>
          {playlists.length === 0 && !isLoading && (
            <EmptyState icon={<ListMusic size={40} style={{ color: '#6B6B6B' }} />}
              title="Sin playlists" sub="Crea tu primera playlist para organizar tu música." >
              <button onClick={onOpenCreatePlaylist} style={{ marginTop: '16px', padding: '12px 24px', borderRadius: '12px', background: '#FA243C', color: '#fff', fontWeight: 700, fontSize: '14px' }}>
                <Plus size={16} style={{ display: 'inline', marginRight: '6px' }} />Crear Playlist
              </button>
            </EmptyState>
          )}
        </div>
      )}

      {tab === 'history' && (
        <div style={{ display: 'flex', flexDirection: 'column' }}>
          {history.map((s, i) => <SongCard key={`${s.id}-${i}`} song={s} queue={history} />)}
          {history.length === 0 && !isLoading && (
            <EmptyState icon={<History size={40} style={{ color: '#6B6B6B' }} />}
              title="Sin historial" sub="Las canciones que escuches aparecerán aquí." />
          )}
        </div>
      )}
    </div>
  );
};

function EmptyState({ icon, title, sub, children }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', padding: '60px 24px', textAlign: 'center' }}>
      {icon}
      <p style={{ fontSize: '17px', fontWeight: 600, color: '#fff', marginTop: '16px' }}>{title}</p>
      <p style={{ fontSize: '14px', color: '#B3B3B3', marginTop: '6px', maxWidth: '300px' }}>{sub}</p>
      {children}
    </div>
  );
}
