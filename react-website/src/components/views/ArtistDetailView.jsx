import React, { useState, useEffect } from 'react';
import { Play, Pause, Heart, Shuffle, ArrowLeft, Disc3, Plus, Music2 } from 'lucide-react';
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

export const ArtistDetailView = ({ artistName, onBack, onSelectAlbum }) => {
  const { currentSong, isPlaying, playSong, togglePlay, addToQueue } = usePlayer();
  const { isFavorite, toggleFavorite } = useLibrary();
  const { isAuthenticated, openAuthModal } = useAuth();

  const [artistData, setArtistData] = useState(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isFollowing, setIsFollowing] = useState(false);

  useEffect(() => {
    let isMounted = true;
    setIsLoading(true);
    musicService.getArtistDetails(artistName).then(data => {
      if (isMounted) {
        setArtistData(data);
        setIsLoading(false);
      }
    }).catch(err => {
      console.error('Error loading artist details:', err);
      if (isMounted) setIsLoading(false);
    });
    return () => { isMounted = false; };
  }, [artistName]);

  if (isLoading) {
    return (
      <div style={{ padding: '60px 20px', textAlign: 'center', color: '#888' }}>
        <p style={{ fontSize: '15px' }}>Cargando información del artista...</p>
      </div>
    );
  }

  const name = artistData?.artist?.name || artistData?.name || artistName;
  const image = artistData?.artist?.image || artistData?.artist?.banner || artistData?.artistImageUrl || '';
  const topSongs = artistData?.topTracks || artistData?.topSongs || [];
  const albums = artistData?.albums || [];
  const fansCount = artistData?.artist?.fans ? Number(artistData.artist.fans).toLocaleString() : null;

  return (
    <div style={{ paddingBottom: '140px', minHeight: '100%' }}>
      {/* 1. Header Banner */}
      <div style={{
        position: 'relative',
        height: '320px',
        borderRadius: '16px',
        overflow: 'hidden',
        marginBottom: '28px',
        display: 'flex',
        flexDirection: 'column',
        justifyContent: 'flex-end',
        padding: '32px',
        boxShadow: '0 12px 36px rgba(0,0,0,0.6)',
      }}>
        {/* Background photo with gradient overlays */}
        <div style={{
          position: 'absolute', inset: 0,
          backgroundImage: `url(${image})`,
          backgroundSize: 'cover',
          backgroundPosition: 'center 20%',
          filter: 'brightness(0.75)',
        }} />
        <div style={{
          position: 'absolute', inset: 0,
          background: 'linear-gradient(to top, rgba(12,13,16,1) 0%, rgba(12,13,16,0.5) 45%, rgba(12,13,16,0.2) 100%)',
        }} />

        {/* Back Button */}
        {onBack && (
          <button
            onClick={onBack}
            style={{
              position: 'absolute', top: '20px', left: '20px', zIndex: 10,
              width: '38px', height: '38px', borderRadius: '50%',
              background: 'rgba(0,0,0,0.5)', border: '1px solid rgba(255,255,255,0.2)',
              color: '#fff', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center',
            }}
            title="Atrás"
          >
            <ArrowLeft size={20} />
          </button>
        )}

        {/* Artist Name & Stats */}
        <div style={{ position: 'relative', zIndex: 2 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '10px' }}>
            <div style={{
              display: 'inline-flex', alignItems: 'center', gap: '6px',
              background: 'rgba(250,36,60,0.2)', border: '1px solid rgba(250,36,60,0.4)',
              padding: '4px 10px', borderRadius: '20px',
            }}>
              <span style={{ fontSize: '11px', fontWeight: 800, color: '#FA243C', letterSpacing: '0.04em' }}>
                ARTISTA VERIFICADO
              </span>
            </div>
            {fansCount && (
              <span style={{ fontSize: '12px', color: '#B3B3B3', fontWeight: 600 }}>
                {fansCount} fans
              </span>
            )}
          </div>

          <h1 style={{
            fontSize: '44px', fontWeight: 900, letterSpacing: '-1.2px',
            color: '#fff', margin: '0 0 14px', textShadow: '0 2px 10px rgba(0,0,0,0.6)',
          }}>
            {name}
          </h1>

          {/* Action buttons row */}
          <div style={{ display: 'flex', alignItems: 'center', gap: '14px' }}>
            {topSongs.length > 0 && (
              <button
                onClick={() => playSong(topSongs[0], topSongs)}
                style={{
                  display: 'flex', alignItems: 'center', gap: '8px',
                  padding: '12px 28px', borderRadius: '24px',
                  background: '#FA243C', color: '#fff', fontWeight: 800, fontSize: '14px',
                  border: 'none', cursor: 'pointer', boxShadow: '0 4px 20px rgba(250,36,60,0.4)',
                  transition: 'transform 0.15s',
                }}
                onMouseEnter={e => e.currentTarget.style.transform = 'scale(1.03)'}
                onMouseLeave={e => e.currentTarget.style.transform = 'scale(1)'}
              >
                <Play size={18} style={{ fill: '#fff' }} />
                <span>Reproducir</span>
              </button>
            )}

            <button
              onClick={() => setIsFollowing(!isFollowing)}
              style={{
                display: 'flex', alignItems: 'center', gap: '8px',
                padding: '12px 22px', borderRadius: '24px',
                background: isFollowing ? 'rgba(255,255,255,0.15)' : 'transparent',
                border: '1.5px solid rgba(255,255,255,0.3)',
                color: '#fff', fontWeight: 700, fontSize: '13px',
                cursor: 'pointer',
              }}
            >
              <Heart size={16} style={{ fill: isFollowing ? '#FA243C' : 'none', color: isFollowing ? '#FA243C' : '#fff' }} />
              <span>{isFollowing ? 'Siguiendo' : 'Seguir'}</span>
            </button>
          </div>
        </div>
      </div>

      {/* 2. Top Popular Songs */}
      <div style={{ marginBottom: '40px' }}>
        <h2 style={{ fontSize: '22px', fontWeight: 800, color: '#fff', marginBottom: '16px' }}>
          Canciones populares
        </h2>

        <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
          {topSongs.slice(0, 10).map((song, idx) => {
            const isCurrent = currentSong?.id === song.id;
            const isFav = isFavorite(song.id);

            return (
              <div
                key={`${song.id}-${idx}`}
                style={{
                  display: 'flex', alignItems: 'center', gap: '14px',
                  padding: '10px 14px', borderRadius: '10px',
                  background: isCurrent ? 'rgba(250,36,60,0.12)' : 'transparent',
                  cursor: 'pointer', transition: 'background 0.15s',
                }}
                onMouseEnter={e => { if (!isCurrent) e.currentTarget.style.background = '#18181b'; }}
                onMouseLeave={e => { if (!isCurrent) e.currentTarget.style.background = 'transparent'; }}
              >
                {/* Index / Play */}
                <div
                  onClick={() => isCurrent ? togglePlay() : playSong(song, topSongs, idx)}
                  style={{ width: '28px', textAlign: 'center', color: isCurrent ? '#FA243C' : '#888', fontWeight: 700, fontSize: '14px' }}
                >
                  {isCurrent && isPlaying ? <Pause size={18} style={{ fill: '#FA243C' }} /> : idx + 1}
                </div>

                {/* Cover */}
                <div
                  onClick={() => isCurrent ? togglePlay() : playSong(song, topSongs, idx)}
                  style={{ width: '44px', height: '44px', borderRadius: '6px', overflow: 'hidden', flexShrink: 0 }}
                >
                  <img src={song.coverArt} alt={song.title} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                </div>

                {/* Title */}
                <div
                  onClick={() => isCurrent ? togglePlay() : playSong(song, topSongs, idx)}
                  style={{ flex: 1, minWidth: 0 }}
                >
                  <p style={{ fontSize: '14px', fontWeight: 700, color: isCurrent ? '#FA243C' : '#fff', margin: '0 0 2px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                    {song.title}
                  </p>
                  <p style={{ fontSize: '12px', color: '#8E8E93', margin: 0, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                    {song.album || name}
                  </p>
                </div>

                {/* Heart & Add */}
                <button
                  onClick={(e) => {
                    e.stopPropagation();
                    addToQueue(song);
                  }}
                  style={{ background: 'transparent', border: 'none', color: '#888', cursor: 'pointer', padding: '6px' }}
                  title="Añadir a la cola"
                >
                  <Plus size={18} />
                </button>

                <button
                  onClick={(e) => {
                    e.stopPropagation();
                    if (isAuthenticated) toggleFavorite(song);
                    else openAuthModal();
                  }}
                  style={{ background: 'transparent', border: 'none', color: isFav ? '#FA243C' : '#888', cursor: 'pointer', padding: '6px' }}
                >
                  <Heart size={18} style={{ fill: isFav ? '#FA243C' : 'none' }} />
                </button>

                <span style={{ fontSize: '12px', color: '#888', minWidth: '36px', textAlign: 'right' }}>
                  {fmt(song.duration)}
                </span>
              </div>
            );
          })}
        </div>
      </div>

      {/* 3. Discography / Albums */}
      {albums.length > 0 && (
        <div>
          <h2 style={{ fontSize: '22px', fontWeight: 800, color: '#fff', marginBottom: '16px' }}>
            Álbumes y Sencillos
          </h2>

          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(160px, 1fr))', gap: '16px' }}>
            {albums.map((album, idx) => (
              <div
                key={`${album.id}-${idx}`}
                onClick={() => onSelectAlbum?.(album)}
                style={{
                  background: '#18181b', borderRadius: '12px', padding: '12px',
                  cursor: 'pointer', transition: 'transform 0.15s, background 0.15s',
                }}
                onMouseEnter={e => {
                  e.currentTarget.style.transform = 'translateY(-4px)';
                  e.currentTarget.style.background = '#222';
                }}
                onMouseLeave={e => {
                  e.currentTarget.style.transform = 'translateY(0)';
                  e.currentTarget.style.background = '#18181b';
                }}
              >
                <div style={{
                  width: '100%', aspectRatio: '1/1', borderRadius: '8px',
                  overflow: 'hidden', marginBottom: '10px', background: '#282828',
                }}>
                  <img src={album.coverArt} alt={album.name} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                </div>
                <h4 style={{ fontSize: '13.5px', fontWeight: 700, color: '#fff', margin: '0 0 4px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                  {album.name}
                </h4>
                <p style={{ fontSize: '12px', color: '#8E8E93', margin: 0 }}>
                  {album.year || 'Álbum'} • {album.trackCount} {album.trackCount === 1 ? 'canción' : 'canciones'}
                </p>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
};
