import React from 'react';
import { Play, Pause, SkipForward, SkipBack, Heart, Volume2, VolumeX, Maximize2, Shuffle, Repeat, Repeat1 } from 'lucide-react';
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
    toggleShuffle, toggleRepeat, openFullPlayer,
  } = usePlayer();
  const { isFavorite, toggleFavorite } = useLibrary();
  const { isAuthenticated, openAuthModal } = useAuth();

  if (!currentSong) return null;
  const pct = duration > 0 ? (currentTime / duration) * 100 : 0;
  const isFav = isFavorite(currentSong.id);

  const handleSeek = (e) => {
    const rect = e.currentTarget.getBoundingClientRect();
    seekTo(((e.clientX - rect.left) / rect.width) * duration);
  };

  return (
    /* Positioned above bottom nav on mobile, full-width on desktop (left: 240px) */
    <div style={{
      position: 'fixed', bottom: '64px', left: 0, right: 0, zIndex: 30,
      background: 'transparent',
    }} className="mini-player-wrapper">
      {/* Progress bar */}
      <div onClick={handleSeek} style={{ height: '2px', background: '#404040', cursor: 'pointer', width: '100%' }}>
        <div style={{ height: '100%', background: '#FA243C', width: `${pct}%`, transition: 'width 0.5s linear' }} />
      </div>

      {/* Player bar */}
      <div style={{
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        height: '68px', padding: '0 16px',
        background: '#181818', borderTop: '0.5px solid #282828',
      }}>
        {/* Left: cover + info + heart */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px', minWidth: 0, maxWidth: '30%' }}>
          <div onClick={openFullPlayer} style={{ width: '44px', height: '44px', borderRadius: '6px', overflow: 'hidden', cursor: 'pointer', flexShrink: 0 }}>
            <img src={currentSong.coverArt || ''} alt={currentSong.title} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
          </div>
          <div onClick={openFullPlayer} style={{ minWidth: 0, cursor: 'pointer', flex: 1 }}>
            <p style={{ fontSize: '14px', fontWeight: 600, color: '#fff', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
              {currentSong.title}
            </p>
            <p style={{ fontSize: '12px', color: '#B3B3B3', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
              {currentSong.artist}
            </p>
          </div>
          <button
            onClick={() => isAuthenticated ? toggleFavorite(currentSong) : openAuthModal()}
            style={{ color: isFav ? '#FA243C' : '#B3B3B3', padding: '6px', flexShrink: 0 }}
          >
            <Heart size={18} style={{ fill: isFav ? '#FA243C' : 'none' }} />
          </button>
        </div>

        {/* Center: controls */}
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '2px' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
            <button onClick={toggleShuffle} style={{ color: isShuffle ? '#FA243C' : '#B3B3B3', display: 'none' }} className="desktop-ctrl">
              <Shuffle size={16} />
            </button>
            <button onClick={prevTrack} style={{ color: '#fff' }}><SkipBack size={22} /></button>
            <button
              onClick={togglePlay}
              style={{
                width: '38px', height: '38px', borderRadius: '50%', background: '#fff',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                transition: 'transform 0.1s',
              }}
              onMouseDown={e => e.currentTarget.style.transform = 'scale(0.94)'}
              onMouseUp={e => e.currentTarget.style.transform = 'scale(1)'}
            >
              {isPlaying
                ? <Pause size={18} style={{ fill: '#000', color: '#000' }} />
                : <Play size={18} style={{ fill: '#000', color: '#000', marginLeft: '2px' }} />}
            </button>
            <button onClick={nextTrack} style={{ color: '#fff' }}><SkipForward size={22} /></button>
            <button onClick={toggleRepeat} style={{ color: repeatMode !== 'off' ? '#FA243C' : '#B3B3B3', display: 'none' }} className="desktop-ctrl">
              {repeatMode === 'one' ? <Repeat1 size={16} /> : <Repeat size={16} />}
            </button>
          </div>
          <div style={{ fontSize: '11px', color: '#6B6B6B', display: 'none' }} className="desktop-ctrl">
            {fmt(currentTime)} / {fmt(duration)}
          </div>
        </div>

        {/* Right: volume + expand */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
          <div style={{ alignItems: 'center', gap: '8px', display: 'none' }} className="desktop-ctrl">
            <button onClick={toggleMute} style={{ color: '#B3B3B3' }}>
              {isMuted || volume === 0 ? <VolumeX size={17} /> : <Volume2 size={17} />}
            </button>
            <input
              type="range" min="0" max="1" step="0.01"
              value={isMuted ? 0 : volume}
              onChange={e => changeVolume(parseFloat(e.target.value))}
              style={{ width: '80px', accentColor: '#FA243C', cursor: 'pointer' }}
            />
          </div>
          <button onClick={openFullPlayer} style={{ color: '#B3B3B3', padding: '6px', borderRadius: '6px' }}
            onMouseEnter={e => e.currentTarget.style.color = '#fff'}
            onMouseLeave={e => e.currentTarget.style.color = '#B3B3B3'}>
            <Maximize2 size={18} />
          </button>
        </div>
      </div>
    </div>
  );
};
