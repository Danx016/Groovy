import React, { useState, useEffect } from 'react';
import { Play, Pause, Heart, Shuffle, ArrowLeft, Plus, Clock, Disc3 } from 'lucide-react';
import { usePlayer } from '../../context/PlayerContext';
import { useLibrary } from '../../context/LibraryContext';
import { useAuth } from '../../context/AuthContext';
import { musicService } from '../../services/musicService';

const fmt = (secs) => {
  if (!secs || isNaN(secs)) return '3:00';
  const m = Math.floor(secs / 60);
  const s = Math.floor(secs % 60);
  return `${m}:${s < 10 ? '0' : ''}${s}`;
};

export const AlbumDetailView = ({ album, onBack, onSelectArtist }) => {
  const { currentSong, isPlaying, playSong, togglePlay, addToQueue } = usePlayer();
  const { isFavorite, toggleFavorite } = useLibrary();
  const { isAuthenticated, openAuthModal } = useAuth();

  const [albumData, setAlbumData] = useState(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    let isMounted = true;
    setIsLoading(true);
    const albumId = album?.id || '';
    const albumName = album?.name || album?.title || '';
    const artistName = album?.artist || '';

    musicService.getAlbumDetails(albumId, albumName, artistName).then(data => {
      if (isMounted) {
        setAlbumData(data);
        setIsLoading(false);
      }
    }).catch(err => {
      console.error('Error loading album details:', err);
      if (isMounted) setIsLoading(false);
    });

    return () => { isMounted = false; };
  }, [album]);

  if (isLoading) {
    return (
      <div style={{ padding: '60px 20px', textAlign: 'center', color: '#888' }}>
        <p style={{ fontSize: '15px' }}>Cargando álbum...</p>
      </div>
    );
  }

  const meta = albumData?.album || albumData || album;
  const songs = albumData?.tracks || albumData?.songs || [];
  const totalDuration = meta?.duration || songs.reduce((acc, s) => acc + (s.duration || 0), 0);

  return (
    <div style={{ padding: '8px 24px 140px', minHeight: '100%' }}>
      {/* Back Button */}
      {onBack && (
        <button
          onClick={onBack}
          style={{
            background: 'transparent', border: 'none', color: '#FA243C',
            cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '6px',
            fontSize: '14px', fontWeight: 600, padding: '4px 0', marginBottom: '20px',
          }}
        >
          <ArrowLeft size={20} />
          <span>Volver</span>
        </button>
      )}

      {/* 1. Header Box */}
      <div style={{
        display: 'flex', alignItems: 'flex-end', gap: '28px',
        marginBottom: '32px', flexWrap: 'wrap',
      }}>
        {/* Cover Art */}
        <div style={{
          width: '200px', height: '200px', borderRadius: '12px',
          overflow: 'hidden', flexShrink: 0, background: '#222',
          boxShadow: '0 12px 32px rgba(0,0,0,0.6)',
        }}>
          <img
            src={meta?.coverArt || album?.coverArt}
            alt={meta?.title || meta?.name}
            style={{ width: '100%', height: '100%', objectFit: 'cover' }}
          />
        </div>

        {/* Text Details */}
        <div style={{ flex: 1, minWidth: '240px' }}>
          <span style={{ fontSize: '12px', fontWeight: 800, color: '#FA243C', letterSpacing: '0.06em', textTransform: 'uppercase' }}>
            ÁLBUM
          </span>
          <h1 style={{ fontSize: '36px', fontWeight: 900, color: '#fff', letterSpacing: '-0.8px', margin: '4px 0 10px' }}>
            {meta?.title || meta?.name}
          </h1>

          <div style={{ display: 'flex', alignItems: 'center', gap: '8px', fontSize: '14px', color: '#8E8E93', marginBottom: '20px' }}>
            <span
              onClick={() => onSelectArtist?.(meta?.artist)}
              style={{ color: '#fff', fontWeight: 700, cursor: 'pointer', textDecoration: 'underline' }}
            >
              {meta?.artist}
            </span>
            <span>•</span>
            {meta?.year && <span>{meta.year}</span>}
            <span>•</span>
            <span>{songs.length} canciones, {Math.round(totalDuration / 60)} min</span>
          </div>

          {/* Buttons */}
          <div style={{ display: 'flex', alignItems: 'center', gap: '14px' }}>
            {songs.length > 0 && (
              <button
                onClick={() => playSong(songs[0], songs)}
                style={{
                  display: 'flex', alignItems: 'center', gap: '8px',
                  padding: '12px 28px', borderRadius: '24px',
                  background: '#FA243C', color: '#fff', fontWeight: 800, fontSize: '14px',
                  border: 'none', cursor: 'pointer', boxShadow: '0 4px 16px rgba(250,36,60,0.4)',
                }}
              >
                <Play size={18} style={{ fill: '#fff' }} />
                <span>Reproducir Todo</span>
              </button>
            )}

            {songs.length > 1 && (
              <button
                onClick={() => {
                  const shuffled = [...songs].sort(() => Math.random() - 0.5);
                  playSong(shuffled[0], shuffled);
                }}
                style={{
                  display: 'flex', alignItems: 'center', gap: '8px',
                  padding: '12px 22px', borderRadius: '24px',
                  background: 'rgba(255,255,255,0.08)', border: '1px solid rgba(255,255,255,0.15)',
                  color: '#fff', fontWeight: 700, fontSize: '14px',
                  cursor: 'pointer',
                }}
              >
                <Shuffle size={16} />
                <span>Aleatorio</span>
              </button>
            )}
          </div>
        </div>
      </div>

      {/* 2. Tracklist */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: '2px' }}>
        <div style={{
          display: 'flex', alignItems: 'center', padding: '10px 16px',
          borderBottom: '1px solid #222', fontSize: '12px', fontWeight: 700,
          color: '#666', textTransform: 'uppercase', letterSpacing: '0.04em',
        }}>
          <span style={{ width: '32px' }}>#</span>
          <span style={{ flex: 1 }}>TÍTULO</span>
          <Clock size={15} style={{ minWidth: '40px', textAlign: 'right' }} />
        </div>

        {songs.map((track, idx) => {
          const isCurrent = currentSong?.id === track.id;
          const isFav = isFavorite(track.id);

          return (
            <div
              key={`${track.id}-${idx}`}
              onClick={() => isCurrent ? togglePlay() : playSong(track, songs, idx)}
              style={{
                display: 'flex', alignItems: 'center', gap: '14px',
                padding: '10px 16px', borderRadius: '8px',
                background: isCurrent ? 'rgba(250,36,60,0.12)' : 'transparent',
                cursor: 'pointer', transition: 'background 0.15s',
              }}
              onMouseEnter={e => { if (!isCurrent) e.currentTarget.style.background = '#18181b'; }}
              onMouseLeave={e => { if (!isCurrent) e.currentTarget.style.background = 'transparent'; }}
            >
              {/* Number or Play */}
              <div style={{
                width: '32px', textAlign: 'left',
                color: isCurrent ? '#FA243C' : '#888',
                fontWeight: 700, fontSize: '13px',
              }}>
                {isCurrent && isPlaying ? <Pause size={16} style={{ fill: '#FA243C' }} /> : idx + 1}
              </div>

              {/* Title & Artist */}
              <div style={{ flex: 1, minWidth: 0 }}>
                <p style={{
                  fontSize: '14px', fontWeight: 700,
                  color: isCurrent ? '#FA243C' : '#fff',
                  margin: '0 0 2px',
                  overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
                }}>
                  {track.title}
                </p>
                <p style={{
                  fontSize: '12px', color: '#8E8E93', margin: 0,
                  overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
                }}>
                  {track.artist}
                </p>
              </div>

              {/* Actions */}
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <button
                  onClick={(e) => {
                    e.stopPropagation();
                    addToQueue(track);
                  }}
                  style={{ background: 'transparent', border: 'none', color: '#888', cursor: 'pointer', padding: '6px' }}
                  title="Añadir a la cola"
                >
                  <Plus size={17} />
                </button>

                <button
                  onClick={(e) => {
                    e.stopPropagation();
                    if (isAuthenticated) toggleFavorite(track);
                    else openAuthModal();
                  }}
                  style={{ background: 'transparent', border: 'none', color: isFav ? '#FA243C' : '#888', cursor: 'pointer', padding: '6px' }}
                >
                  <Heart size={17} style={{ fill: isFav ? '#FA243C' : 'none' }} />
                </button>

                <span style={{ fontSize: '12px', color: '#888', minWidth: '40px', textAlign: 'right' }}>
                  {fmt(track.duration)}
                </span>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
};
