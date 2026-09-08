import React from 'react';
import { Clock, Play, Pause, Trash2, ArrowLeft, Music, Heart, ListPlus } from 'lucide-react';
import { useLibrary } from '../../context/LibraryContext';
import { usePlayer } from '../../context/PlayerContext';
import { useAuth } from '../../context/AuthContext';

const formatDuration = (secs) => {
  if (!secs || isNaN(secs)) return '3:30';
  const m = Math.floor(secs / 60);
  const s = Math.floor(secs % 60);
  return `${m}:${s < 10 ? '0' : ''}${s}`;
};

export const HistoryView = ({ onBack, onSelectArtist, onSelectAlbum }) => {
  const { history = [], clearHistory, isFavorite, toggleFavorite } = useLibrary();
  const { currentSong, isPlaying, playSong, togglePlay, addToQueue, openArtist, openAlbum } = usePlayer();
  const { isAuthenticated, openAuthModal } = useAuth();

  const handleOpenArtist = (name) => {
    if (onSelectArtist) onSelectArtist(name);
    else if (openArtist) openArtist(name);
  };

  const handleOpenAlbum = (albumObj) => {
    if (onSelectAlbum) onSelectAlbum(albumObj);
    else if (openAlbum) openAlbum(albumObj);
  };

  return (
    <div style={{ padding: '8px 24px 140px', minHeight: '100%' }}>
      {/* Header */}
      <div style={{
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        marginBottom: '24px', paddingTop: '8px',
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '14px' }}>
          {onBack && (
            <button
              onClick={onBack}
              style={{
                background: 'transparent', border: 'none', color: '#FA243C',
                cursor: 'pointer', display: 'flex', alignItems: 'center', padding: '4px',
              }}
              title="Atrás"
            >
              <ArrowLeft size={24} />
            </button>
          )}
          <div>
            <h1 style={{ fontSize: '28px', fontWeight: 900, letterSpacing: '-0.6px', color: '#fff', margin: 0 }}>
              Historial de reproducción
            </h1>
            <p style={{ fontSize: '13px', color: '#8E8E93', margin: '4px 0 0' }}>
              {history.length} {history.length === 1 ? 'canción reproducida' : 'canciones reproducidas'}
            </p>
          </div>
        </div>

        {history.length > 0 && (
          <button
            onClick={clearHistory}
            style={{
              display: 'flex', alignItems: 'center', gap: '6px',
              padding: '8px 14px', borderRadius: '8px',
              background: 'rgba(255,59,48,0.1)', border: '0.5px solid rgba(255,59,48,0.25)',
              color: '#FF3B30', fontSize: '13px', fontWeight: 600,
              cursor: 'pointer', transition: 'all 0.15s',
            }}
            onMouseEnter={e => e.currentTarget.style.background = 'rgba(255,59,48,0.2)'}
            onMouseLeave={e => e.currentTarget.style.background = 'rgba(255,59,48,0.1)'}
          >
            <Trash2 size={15} />
            <span>Borrar historial</span>
          </button>
        )}
      </div>

      {/* History List */}
      {history.length === 0 ? (
        <div style={{
          display: 'flex', flexDirection: 'column', alignItems: 'center',
          justifyContent: 'center', minHeight: '40vh', color: '#8E8E93',
          textAlign: 'center', gap: '12px',
        }}>
          <Clock size={48} style={{ color: '#444' }} />
          <h3 style={{ fontSize: '18px', fontWeight: 700, color: '#fff', margin: 0 }}>
            Sin reproducciones recientes
          </h3>
          <p style={{ fontSize: '13px', maxWidth: '320px', margin: 0 }}>
            Las canciones que escuches en Groovy aparecerán aquí automáticamente.
          </p>
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
          {history.map((song, idx) => {
            const isCurrent = currentSong?.id === song.id;
            const isFav = isFavorite(song.id);

            return (
              <div
                key={`${song.id}-${idx}`}
                style={{
                  display: 'flex', alignItems: 'center', gap: '14px',
                  padding: '10px 14px', borderRadius: '10px',
                  background: isCurrent ? 'rgba(250,36,60,0.1)' : 'transparent',
                  border: `0.5px solid ${isCurrent ? 'rgba(250,36,60,0.3)' : 'transparent'}`,
                  transition: 'background 0.15s',
                  cursor: 'pointer',
                }}
                onMouseEnter={e => {
                  if (!isCurrent) e.currentTarget.style.background = '#18181b';
                }}
                onMouseLeave={e => {
                  if (!isCurrent) e.currentTarget.style.background = 'transparent';
                }}
              >
                {/* Index / Play indicator */}
                <div
                  onClick={() => isCurrent ? togglePlay() : playSong(song, history, idx)}
                  style={{
                    width: '32px', height: '32px', borderRadius: '6px',
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                    flexShrink: 0, color: isCurrent ? '#FA243C' : '#888',
                  }}
                >
                  {isCurrent && isPlaying ? (
                    <Pause size={18} style={{ fill: '#FA243C' }} />
                  ) : (
                    <Play size={18} style={{ fill: isCurrent ? '#FA243C' : 'none' }} />
                  )}
                </div>

                {/* Artwork */}
                <div
                  onClick={() => isCurrent ? togglePlay() : playSong(song, history, idx)}
                  style={{
                    width: '44px', height: '44px', borderRadius: '6px',
                    overflow: 'hidden', flexShrink: 0, background: '#222',
                  }}
                >
                  <img
                    src={song.coverArt || ''}
                    alt={song.title}
                    style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                    onError={e => { e.target.src = 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600'; }}
                  />
                </div>

                {/* Title & Artist */}
                <div
                  onClick={() => isCurrent ? togglePlay() : playSong(song, history, idx)}
                  style={{ flex: 1, minWidth: 0 }}
                >
                  <p style={{
                    fontSize: '14px', fontWeight: 700,
                    color: isCurrent ? '#FA243C' : '#fff',
                    margin: '0 0 2px',
                    overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
                  }}>
                    {song.title}
                  </p>
                  <p style={{
                    fontSize: '12px', color: '#8E8E93', margin: 0,
                    overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
                  }}>
                    <span
                      onClick={(e) => {
                        e.stopPropagation();
                        handleOpenArtist(song.artist);
                      }}
                      style={{ cursor: 'pointer' }}
                      onMouseEnter={e => e.currentTarget.style.color = '#fff'}
                      onMouseLeave={e => e.currentTarget.style.color = '#8E8E93'}
                    >
                      {song.artist}
                    </span>
                    {song.album && (
                      <>
                        {' • '}
                        <span
                          onClick={(e) => {
                            e.stopPropagation();
                            handleOpenAlbum({ id: song.albumId || song.id, name: song.album, artist: song.artist, coverArt: song.coverArt });
                          }}
                          style={{ cursor: 'pointer' }}
                          onMouseEnter={e => e.currentTarget.style.color = '#fff'}
                          onMouseLeave={e => e.currentTarget.style.color = '#8E8E93'}
                        >
                          {song.album}
                        </span>
                      </>
                    )}
                  </p>
                </div>

                {/* Actions */}
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      addToQueue(song);
                    }}
                    style={{
                      background: 'transparent', border: 'none', color: '#888',
                      cursor: 'pointer', padding: '6px', display: 'flex',
                    }}
                    title="Añadir a la cola"
                    onMouseEnter={e => e.currentTarget.style.color = '#fff'}
                    onMouseLeave={e => e.currentTarget.style.color = '#888'}
                  >
                    <ListPlus size={17} />
                  </button>

                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      if (isAuthenticated) toggleFavorite(song);
                      else openAuthModal();
                    }}
                    style={{
                      background: 'transparent', border: 'none',
                      color: isFav ? '#FA243C' : '#888',
                      cursor: 'pointer', padding: '6px', display: 'flex',
                    }}
                    title={isFav ? 'Quitar de favoritos' : 'Guardar en favoritos'}
                    onMouseEnter={e => { if (!isFav) e.currentTarget.style.color = '#fff'; }}
                    onMouseLeave={e => { if (!isFav) e.currentTarget.style.color = '#888'; }}
                  >
                    <Heart size={17} style={{ fill: isFav ? '#FA243C' : 'none' }} />
                  </button>

                  <span style={{ fontSize: '12px', color: '#666', minWidth: '36px', textAlign: 'right' }}>
                    {formatDuration(song.duration)}
                  </span>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
};
