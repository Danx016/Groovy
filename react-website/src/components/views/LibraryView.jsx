import React, { useState } from 'react';
import { Heart, ListMusic, History, Play, Plus, LogIn, CloudCheck, Music, Sparkles } from 'lucide-react';
import { useLibrary } from '../../context/LibraryContext';
import { usePlayer } from '../../context/PlayerContext';
import { useAuth } from '../../context/AuthContext';
import { SongCard } from '../ui/SongCard';
import { PlaylistCard } from '../ui/PlaylistCard';

export const LibraryView = ({ onSelectPlaylist, onOpenCreatePlaylist }) => {
  const { favorites = [], playlists = [], history = [], isLoading } = useLibrary();
  const { playSong } = usePlayer();
  const { isAuthenticated, user, openAuthModal } = useAuth();
  const [tab, setTab] = useState('favorites'); // 'favorites' | 'playlists' | 'history'

  const TABS = [
    { id: 'favorites', label: `Favoritos (${favorites.length})`, icon: Heart },
    { id: 'playlists', label: `Playlists (${playlists.length})`, icon: ListMusic },
    { id: 'history', label: `Historial (${history.length})`, icon: History },
  ];

  return (
    <div style={{ paddingBottom: '140px' }}>
      {/* Cloud Sync Status Banner if not authenticated */}
      {!isAuthenticated && (
        <div style={{
          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          background: 'linear-gradient(90deg, rgba(250,36,60,0.15) 0%, rgba(255,149,0,0.12) 100%)',
          border: '1px solid rgba(250,36,60,0.3)', borderRadius: '14px',
          padding: '14px 18px', marginBottom: '22px',
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
            <div style={{ width: '36px', height: '36px', borderRadius: '50%', background: '#FA243C', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <LogIn size={18} style={{ color: '#fff' }} />
            </div>
            <div>
              <p style={{ fontSize: '14px', fontWeight: 700, color: '#fff', marginBottom: '2px' }}>
                Sincroniza tu música en la nube
              </p>
              <p style={{ fontSize: '12px', color: '#B3B3B3' }}>
                Inicia sesión para guardar tus favoritos y playlists en MySQL y acceder desde Windows y Android.
              </p>
            </div>
          </div>
          <button
            onClick={openAuthModal}
            style={{
              padding: '8px 18px', borderRadius: '20px',
              background: '#FA243C', color: '#fff', fontWeight: 700, fontSize: '13px',
              border: 'none', cursor: 'pointer', flexShrink: 0,
            }}
          >
            Iniciar Sesión
          </button>
        </div>
      )}

      {/* Header */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '18px' }}>
        <div>
          <h1 style={{ fontSize: '28px', fontWeight: 800, letterSpacing: '-0.6px', color: '#fff' }}>
            Tu Biblioteca
          </h1>
          <p style={{ fontSize: '13px', color: '#A1A1A6', marginTop: '2px' }}>
            {isAuthenticated ? `Conectado como ${user?.name || user?.email}` : 'Modo local sin conexión a cuenta'}
          </p>
        </div>

        {tab === 'favorites' && favorites.length > 0 && (
          <button
            onClick={() => playSong(favorites[0], favorites)}
            style={{
              display: 'flex', alignItems: 'center', gap: '6px', padding: '9px 18px',
              borderRadius: '20px', background: '#FA243C', color: '#fff', fontWeight: 700, fontSize: '13px',
              border: 'none', cursor: 'pointer', boxShadow: '0 4px 14px rgba(250,36,60,0.4)',
            }}
          >
            <Play size={14} style={{ fill: '#fff' }} /> Reproducir Todo
          </button>
        )}

        {tab === 'playlists' && (
          <button
            onClick={isAuthenticated ? onOpenCreatePlaylist : openAuthModal}
            style={{
              display: 'flex', alignItems: 'center', gap: '6px', padding: '9px 18px',
              borderRadius: '20px', background: '#FA243C', color: '#fff', fontWeight: 700, fontSize: '13px',
              border: 'none', cursor: 'pointer',
            }}
          >
            <Plus size={16} /> Nueva Playlist
          </button>
        )}
      </div>

      {/* Filter Tabs */}
      <div style={{ display: 'flex', gap: '8px', marginBottom: '20px', overflowX: 'auto', paddingBottom: '4px' }}>
        {TABS.map(({ id, label, icon: Icon }) => (
          <button
            key={id}
            onClick={() => setTab(id)}
            style={{
              display: 'flex', alignItems: 'center', gap: '6px',
              padding: '8px 16px', borderRadius: '20px', fontSize: '13px', fontWeight: 600,
              whiteSpace: 'nowrap', flexShrink: 0, transition: 'all 0.15s',
              background: tab === id ? '#FA243C' : '#222',
              color: tab === id ? '#fff' : '#B3B3B3',
              border: `0.5px solid ${tab === id ? '#FA243C' : '#333'}`,
              cursor: 'pointer',
            }}
          >
            <Icon size={14} style={{ color: tab === id ? '#fff' : '#FA243C' }} />
            {label}
          </button>
        ))}
      </div>

      {/* 1. FAVORITOS */}
      {tab === 'favorites' && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
          {favorites.map(s => <SongCard key={s.id} song={s} queue={favorites} />)}
          {favorites.length === 0 && !isLoading && (
            <div style={{ textAlign: 'center', padding: '60px 24px', color: '#6B6B6B' }}>
              <Heart size={48} style={{ margin: '0 auto 14px', color: '#FA243C', opacity: 0.4 }} />
              <p style={{ fontSize: '17px', fontWeight: 700, color: '#fff', marginBottom: '6px' }}>Sin canciones favoritas aún</p>
              <p style={{ fontSize: '14px', maxWidth: '320px', margin: '0 auto' }}>
                Toca el icono de ❤️ en cualquier canción para guardarla en tus favoritos.
              </p>
            </div>
          )}
        </div>
      )}

      {/* 2. PLAYLISTS */}
      {tab === 'playlists' && (
        <div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(170px, 1fr))', gap: '16px' }}>
            {playlists.map(pl => (
              <PlaylistCard key={pl.id} playlist={pl} onClick={() => onSelectPlaylist?.(pl)} />
            ))}
          </div>

          {playlists.length === 0 && !isLoading && (
            <div style={{ textAlign: 'center', padding: '60px 24px', color: '#6B6B6B' }}>
              <ListMusic size={48} style={{ margin: '0 auto 14px', color: '#FA243C', opacity: 0.4 }} />
              <p style={{ fontSize: '17px', fontWeight: 700, color: '#fff', marginBottom: '6px' }}>Sin playlists creadas</p>
              <p style={{ fontSize: '14px', maxWidth: '320px', margin: '0 auto 20px' }}>
                Crea tu primera playlist para organizar tus canciones favoritas.
              </p>
              <button
                onClick={isAuthenticated ? onOpenCreatePlaylist : openAuthModal}
                style={{
                  padding: '12px 24px', borderRadius: '12px',
                  background: '#FA243C', color: '#fff', fontWeight: 700, fontSize: '14px',
                  border: 'none', cursor: 'pointer',
                }}
              >
                <Plus size={16} style={{ display: 'inline', marginRight: '6px' }} />
                Crear Primera Playlist
              </button>
            </div>
          )}
        </div>
      )}

      {/* 3. HISTORIAL */}
      {tab === 'history' && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
          {history.map((s, i) => <SongCard key={`${s.id}-${i}`} song={s} queue={history} />)}
          {history.length === 0 && !isLoading && (
            <div style={{ textAlign: 'center', padding: '60px 24px', color: '#6B6B6B' }}>
              <History size={48} style={{ margin: '0 auto 14px', color: '#FA243C', opacity: 0.4 }} />
              <p style={{ fontSize: '17px', fontWeight: 700, color: '#fff', marginBottom: '6px' }}>Sin historial reciente</p>
              <p style={{ fontSize: '14px', maxWidth: '320px', margin: '0 auto' }}>
                Las canciones que reproduzcas se guardarán automáticamente aquí.
              </p>
            </div>
          )}
        </div>
      )}
    </div>
  );
};
