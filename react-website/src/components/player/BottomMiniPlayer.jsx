import React, { useState } from 'react';
import {
  Play, Pause, SkipForward, SkipBack, Heart, Volume2, VolumeX,
  Maximize2, Shuffle, Repeat, Repeat1, Mic, ListMusic, Tv
} from 'lucide-react';
import { usePlayer } from '../../context/PlayerContext';
import { useLibrary } from '../../context/LibraryContext';
import { useAuth } from '../../context/AuthContext';

const fmt = (secs) => {
  if (!secs || isNaN(secs)) return '0:00';
  const m = Math.floor(secs / 60);
  const s = Math.floor(secs % 60);
  return `${m}:${s < 10 ? '0' : ''}${s}`;
};

export const BottomMiniPlayer = () => {
  const {
    currentSong, isPlaying, currentTime, duration, volume, isMuted,
    isShuffle, repeatMode,
    togglePlay, nextTrack, prevTrack, seekTo, changeVolume, toggleMute,
    toggleShuffle, toggleRepeat, openFullPlayer, openArtist,
  } = usePlayer();
  const { isFavorite, toggleFavorite } = useLibrary();
  const { isAuthenticated, openAuthModal } = useAuth();
  const [isHovered, setIsHovered] = useState(false);

  if (!currentSong) return null;
  const pct = duration > 0 ? (currentTime / duration) * 100 : 0;
  const isFav = isFavorite(currentSong.id);

  const handleSeek = (e) => {
    const rect = e.currentTarget.getBoundingClientRect();
    const pos = Math.max(0, Math.min(1, (e.clientX - rect.left) / rect.width));
    seekTo(pos * duration);
  };

  return (
    <div
      style={{
        position: 'fixed',
        bottom: 0,
        left: 0,
        right: 0,
        zIndex: 50,
        height: '84px',
        background: '#0c0d10',
        borderTop: '0.5px solid #1f2024',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        padding: '0 24px',
        userSelect: 'none',
      }}
      className="desktop-player-bar"
    >
      {/* 1. LEFT: Artwork + Song Title & Artist + Heart */}
      <div style={{
        display: 'flex',
        alignItems: 'center',
        gap: '14px',
        width: '280px',
        minWidth: 0,
      }}>
        {/* Cover */}
        <div
          onClick={() => openFullPlayer('art')}
          style={{
            width: '52px',
            height: '52px',
            borderRadius: '8px',
            overflow: 'hidden',
            flexShrink: 0,
            cursor: 'pointer',
            background: '#1c1d22',
            boxShadow: '0 4px 12px rgba(0,0,0,0.5)',
          }}
        >
          <img
            src={currentSong.coverArt || ''}
            alt={currentSong.title}
            style={{ width: '100%', height: '100%', objectFit: 'cover' }}
            onError={e => { e.target.src = 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600'; }}
          />
        </div>

        {/* Info */}
        <div style={{ minWidth: 0, flex: 1 }}>
          <h4
            onClick={() => openFullPlayer('art')}
            style={{
              fontSize: '14px',
              fontWeight: 700,
              color: '#fff',
              margin: '0 0 2px 0',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
              whiteSpace: 'nowrap',
              cursor: 'pointer',
            }}
          >
            {currentSong.title}
          </h4>
          <p
            onClick={(e) => {
              e.stopPropagation();
              if (openArtist && currentSong.artist) openArtist(currentSong.artist);
            }}
            style={{
              fontSize: '12px',
              color: '#8E8E93',
              margin: 0,
              overflow: 'hidden',
              textOverflow: 'ellipsis',
              whiteSpace: 'nowrap',
              cursor: 'pointer',
            }}
            onMouseEnter={e => e.currentTarget.style.color = '#fff'}
            onMouseLeave={e => e.currentTarget.style.color = '#8E8E93'}
          >
            {currentSong.artist}
          </p>
        </div>

        {/* Heart */}
        <button
          onClick={() => isAuthenticated ? toggleFavorite(currentSong) : openAuthModal()}
          style={{
            background: 'transparent',
            border: 'none',
            color: isFav ? '#FA243C' : '#888',
            cursor: 'pointer',
            padding: '6px',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            flexShrink: 0,
            transition: 'color 0.15s',
          }}
          title={isFav ? 'Quitar de favoritos' : 'Guardar en favoritos'}
          onMouseEnter={e => { if (!isFav) e.currentTarget.style.color = '#fff'; }}
          onMouseLeave={e => { if (!isFav) e.currentTarget.style.color = '#888'; }}
        >
          <Heart size={18} style={{ fill: isFav ? '#FA243C' : 'none' }} />
        </button>
      </div>

      {/* 2. CENTER: Playback Controls & Progress Scrubber */}
      <div style={{
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        gap: '6px',
        maxWidth: '560px',
        width: '100%',
        margin: '0 20px',
      }}>
        {/* Buttons Row */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '20px' }}>
          {/* Shuffle */}
          <button
            onClick={toggleShuffle}
            style={{
              background: 'transparent', border: 'none', cursor: 'pointer',
              color: isShuffle ? '#FA243C' : '#888', padding: '4px',
              display: 'flex', alignItems: 'center',
            }}
            title="Modo aleatorio"
          >
            <Shuffle size={17} />
          </button>

          {/* Previous */}
          <button
            onClick={prevTrack}
            style={{
              background: 'transparent', border: 'none', cursor: 'pointer',
              color: '#fff', padding: '4px', display: 'flex', alignItems: 'center',
            }}
            title="Anterior"
          >
            <SkipBack size={20} />
          </button>

          {/* Big White Circular Play/Pause Button */}
          <button
            onClick={togglePlay}
            style={{
              width: '38px',
              height: '38px',
              borderRadius: '50%',
              background: '#fff',
              border: 'none',
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              boxShadow: '0 4px 14px rgba(255,255,255,0.2)',
              transition: 'transform 0.1s ease',
            }}
            onMouseDown={e => e.currentTarget.style.transform = 'scale(0.92)'}
            onMouseUp={e => e.currentTarget.style.transform = 'scale(1)'}
          >
            {isPlaying ? (
              <Pause size={18} style={{ fill: '#000', color: '#000' }} />
            ) : (
              <Play size={18} style={{ fill: '#000', color: '#000', marginLeft: '2px' }} />
            )}
          </button>

          {/* Next */}
          <button
            onClick={nextTrack}
            style={{
              background: 'transparent', border: 'none', cursor: 'pointer',
              color: '#fff', padding: '4px', display: 'flex', alignItems: 'center',
            }}
            title="Siguiente"
          >
            <SkipForward size={20} />
          </button>

          {/* Repeat */}
          <button
            onClick={toggleRepeat}
            style={{
              background: 'transparent', border: 'none', cursor: 'pointer',
              color: repeatMode !== 'off' ? '#FA243C' : '#888', padding: '4px',
              display: 'flex', alignItems: 'center',
            }}
            title="Repetir"
          >
            {repeatMode === 'one' ? <Repeat1 size={17} /> : <Repeat size={17} />}
          </button>
        </div>

        {/* Scrubber Row: 0:00 [ =======O=========== ] 3:52 */}
        <div style={{
          display: 'flex',
          alignItems: 'center',
          gap: '10px',
          width: '100%',
        }}>
          <span style={{ fontSize: '11px', color: '#888', minWidth: '32px', textAlign: 'right', fontWeight: 500 }}>
            {fmt(currentTime)}
          </span>

          {/* Progress Bar Container */}
          <div
            onClick={handleSeek}
            onMouseEnter={() => setIsHovered(true)}
            onMouseLeave={() => setIsHovered(false)}
            style={{
              flex: 1,
              height: '14px',
              display: 'flex',
              alignItems: 'center',
              cursor: 'pointer',
              position: 'relative',
            }}
          >
            <div style={{
              width: '100%',
              height: isHovered ? '5px' : '3.5px',
              borderRadius: '3px',
              background: '#28292d',
              position: 'relative',
              transition: 'height 0.1s ease',
            }}>
              {/* Active Red Progress */}
              <div style={{
                height: '100%',
                width: `${pct}%`,
                borderRadius: '3px',
                background: '#FA243C',
                position: 'relative',
              }}>
                {/* Thumb Knob */}
                <div style={{
                  position: 'absolute',
                  right: '-5px',
                  top: isHovered ? '-3.5px' : '-4px',
                  width: isHovered ? '12px' : '11px',
                  height: isHovered ? '12px' : '11px',
                  borderRadius: '50%',
                  background: '#fff',
                  boxShadow: '0 2px 6px rgba(0,0,0,0.6)',
                }} />
              </div>
            </div>
          </div>

          <span style={{ fontSize: '11px', color: '#888', minWidth: '32px', fontWeight: 500 }}>
            {fmt(duration)}
          </span>
        </div>
      </div>

      {/* 3. RIGHT: Extra Tools & Volume */}
      <div style={{
        display: 'flex',
        alignItems: 'center',
        gap: '14px',
        width: '280px',
        justifyContent: 'flex-end',
      }}>
        {/* Tv / Cast */}
        <button
          onClick={() => {}}
          style={{
            background: 'transparent', border: 'none', color: '#888',
            cursor: 'pointer', padding: '4px', display: 'flex', alignItems: 'center',
          }}
          title="AirPlay / Dispositivos"
          onMouseEnter={e => e.currentTarget.style.color = '#fff'}
          onMouseLeave={e => e.currentTarget.style.color = '#888'}
        >
          <Tv size={17} />
        </button>

        {/* Lyrics Mic */}
        <button
          onClick={() => openFullPlayer('lyrics')}
          style={{
            background: 'transparent', border: 'none', color: '#888',
            cursor: 'pointer', padding: '4px', display: 'flex', alignItems: 'center',
          }}
          title="Letras (Karaoke)"
          onMouseEnter={e => e.currentTarget.style.color = '#fff'}
          onMouseLeave={e => e.currentTarget.style.color = '#888'}
        >
          <Mic size={17} />
        </button>

        {/* Queue */}
        <button
          onClick={() => openFullPlayer('queue')}
          style={{
            background: 'transparent', border: 'none', color: '#888',
            cursor: 'pointer', padding: '4px', display: 'flex', alignItems: 'center',
          }}
          title="Cola de reproducción"
          onMouseEnter={e => e.currentTarget.style.color = '#fff'}
          onMouseLeave={e => e.currentTarget.style.color = '#888'}
        >
          <ListMusic size={17} />
        </button>

        {/* Fullscreen */}
        <button
          onClick={() => openFullPlayer('art')}
          style={{
            background: 'transparent', border: 'none', color: '#888',
            cursor: 'pointer', padding: '4px', display: 'flex', alignItems: 'center',
          }}
          title="Pantalla completa"
          onMouseEnter={e => e.currentTarget.style.color = '#fff'}
          onMouseLeave={e => e.currentTarget.style.color = '#888'}
        >
          <Maximize2 size={17} />
        </button>

        {/* Volume */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginLeft: '4px' }}>
          <button
            onClick={toggleMute}
            style={{
              background: 'transparent', border: 'none', color: '#888',
              cursor: 'pointer', padding: '2px', display: 'flex', alignItems: 'center',
            }}
            onMouseEnter={e => e.currentTarget.style.color = '#fff'}
            onMouseLeave={e => e.currentTarget.style.color = '#888'}
          >
            {isMuted || volume === 0 ? <VolumeX size={17} /> : <Volume2 size={17} />}
          </button>

          <input
            type="range"
            min="0"
            max="1"
            step="0.01"
            value={isMuted ? 0 : volume}
            onChange={e => changeVolume(parseFloat(e.target.value))}
            style={{
              width: '90px',
              accentColor: '#FA243C',
              cursor: 'pointer',
              height: '4px',
            }}
          />
        </div>
      </div>
    </div>
  );
};
