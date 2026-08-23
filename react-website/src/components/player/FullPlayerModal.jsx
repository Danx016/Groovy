import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { ChevronDown, Play, Pause, SkipForward, SkipBack, Heart, Shuffle, Repeat, Repeat1, Volume2, VolumeX, ListMusic, FileText, Sparkles } from 'lucide-react';
import { usePlayer } from '../../context/PlayerContext';
import { useLibrary } from '../../context/LibraryContext';
import { useAuth } from '../../context/AuthContext';

const fmt = (secs) => {
  if (!secs || isNaN(secs)) return '0:00';
  const m = Math.floor(secs / 60);
  const s = Math.floor(secs % 60);
  return `${m}:${s < 10 ? '0' : ''}${s}`;
};

export const FullPlayerModal = () => {
  const {
    currentSong, isPlaying, currentTime, duration, volume, isMuted,
    isShuffle, repeatMode, lyrics, isLyricsLoading, isFullPlayerOpen, closeFullPlayer,
    togglePlay, nextTrack, prevTrack, seekTo, changeVolume, toggleMute,
    toggleShuffle, toggleRepeat, queue, playSong,
  } = usePlayer();
  const { isFavorite, toggleFavorite } = useLibrary();
  const { isAuthenticated, openAuthModal } = useAuth();
  const [tab, setTab] = useState('art');

  if (!isFullPlayerOpen || !currentSong) return null;
  const pct = duration > 0 ? (currentTime / duration) * 100 : 0;
  const isFav = isFavorite(currentSong.id);

  const handleSeek = (e) => {
    const rect = e.currentTarget.getBoundingClientRect();
    seekTo(((e.clientX - rect.left) / rect.width) * duration);
  };

  const TAB_STYLE = (active) => ({
    padding: '7px 16px', borderRadius: '20px', fontSize: '13px', fontWeight: active ? 700 : 500,
    color: active ? '#fff' : '#B3B3B3', background: active ? '#282828' : 'transparent',
    transition: 'all 0.15s', display: 'flex', alignItems: 'center', gap: '5px',
  });

  return (
    <AnimatePresence>
      <motion.div
        initial={{ y: '100%' }}
        animate={{ y: 0 }}
        exit={{ y: '100%' }}
        transition={{ type: 'spring', damping: 28, stiffness: 220 }}
        style={{
          position: 'fixed', inset: 0, zIndex: 50,
          display: 'flex', flexDirection: 'column',
          background: '#000', overflow: 'hidden',
        }}
      >
        {/* Dynamic blurred background from cover art */}
        <div style={{
          position: 'absolute', inset: 0,
          backgroundImage: `url(${currentSong.coverArt})`,
          backgroundSize: 'cover', backgroundPosition: 'center',
          opacity: 0.15, filter: 'blur(40px)', transform: 'scale(1.3)',
        }} />
        <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(to bottom, rgba(0,0,0,0.5) 0%, rgba(0,0,0,0.95) 100%)' }} />

        {/* Top bar */}
        <div style={{ position: 'relative', zIndex: 1, display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '16px 20px' }}>
          <button onClick={closeFullPlayer} style={{ padding: '8px', color: '#fff', borderRadius: '50%', background: 'rgba(255,255,255,0.1)' }}>
            <ChevronDown size={22} />
          </button>

          {/* Tabs */}
          <div style={{ display: 'flex', background: 'rgba(255,255,255,0.07)', borderRadius: '24px', padding: '4px', gap: '2px' }}>
            <button onClick={() => setTab('art')} style={TAB_STYLE(tab === 'art')}>Reproductor</button>
            <button onClick={() => setTab('lyrics')} style={TAB_STYLE(tab === 'lyrics')}><FileText size={13} />Letra</button>
            <button onClick={() => setTab('queue')} style={TAB_STYLE(tab === 'queue')}><ListMusic size={13} />Cola</button>
          </div>

          <button
            onClick={() => isAuthenticated ? toggleFavorite(currentSong) : openAuthModal()}
            style={{ padding: '8px', borderRadius: '50%', background: 'rgba(255,255,255,0.1)', color: isFav ? '#FA243C' : '#fff' }}
          >
            <Heart size={20} style={{ fill: isFav ? '#FA243C' : 'none' }} />
          </button>
        </div>

        {/* Content area */}
        <div style={{ position: 'relative', zIndex: 1, flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', overflowY: 'auto', padding: '0 24px 8px' }}>
          {/* ARTWORK TAB */}
          {tab === 'art' && (
            <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', width: '100%', maxWidth: '340px' }}>
              <div style={{
                width: '100%', aspectRatio: '1/1', maxWidth: '280px', borderRadius: '12px', overflow: 'hidden',
                boxShadow: '0 24px 60px rgba(0,0,0,0.7)', marginBottom: '28px',
                transition: 'transform 0.4s ease',
                transform: isPlaying ? 'scale(1.04)' : 'scale(0.96)',
              }}>
                <img src={currentSong.coverArt} alt={currentSong.title} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
              </div>
              <div style={{ textAlign: 'center', width: '100%' }}>
                <h2 style={{ fontSize: '22px', fontWeight: 700, color: '#fff', letterSpacing: '-0.3px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                  {currentSong.title}
                </h2>
                <p style={{ fontSize: '16px', color: '#B3B3B3', marginTop: '4px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                  {currentSong.artist}
                </p>
                {currentSong.album && (
                  <p style={{ fontSize: '13px', color: '#6B6B6B', marginTop: '2px' }}>{currentSong.album}</p>
                )}
              </div>
            </div>
          )}

          {/* LYRICS TAB */}
          {tab === 'lyrics' && (
            <div style={{ width: '100%', maxWidth: '480px', textAlign: 'center', paddingBottom: '20px' }}>
              {isLyricsLoading ? (
                <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', padding: '40px', gap: '12px' }}>
                  <div className="animate-spin" style={{ width: '32px', height: '32px', border: '2px solid #FA243C', borderTopColor: 'transparent', borderRadius: '50%' }} />
                  <p style={{ color: '#B3B3B3', fontSize: '13px' }}>Buscando letra...</p>
                </div>
              ) : (lyrics.plainLyrics || lyrics.syncedLyrics) ? (
                <div style={{ lineHeight: 2, color: '#B3B3B3', fontSize: '15px', fontWeight: 500 }}>
                  {(lyrics.plainLyrics || lyrics.syncedLyrics).split('\n').map((line, i) => (
                    <p key={i} style={{ marginBottom: '4px' }}>{line.replace(/\[\d+:\d+\.\d+\]/g, '')}</p>
                  ))}
                </div>
              ) : (
                <div style={{ padding: '40px 0', color: '#6B6B6B' }}>
                  <Sparkles size={36} style={{ margin: '0 auto 12px', color: '#FA243C', opacity: 0.4 }} />
                  <p style={{ fontSize: '15px', color: '#B3B3B3', fontWeight: 600 }}>Sin letra disponible</p>
                </div>
              )}
            </div>
          )}

          {/* QUEUE TAB */}
          {tab === 'queue' && (
            <div style={{ width: '100%', maxWidth: '480px' }}>
              <p style={{ fontSize: '11px', fontWeight: 700, letterSpacing: '0.06em', color: '#B3B3B3', textTransform: 'uppercase', marginBottom: '12px' }}>
                Cola ({queue.length})
              </p>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                {queue.map((song, idx) => (
                  <div
                    key={`${song.id}-${idx}`}
                    onClick={() => playSong(song)}
                    style={{
                      display: 'flex', alignItems: 'center', gap: '12px', padding: '10px',
                      borderRadius: '8px', cursor: 'pointer',
                      background: currentSong.id === song.id ? 'rgba(250,36,60,0.15)' : 'rgba(255,255,255,0.04)',
                      border: `0.5px solid ${currentSong.id === song.id ? 'rgba(250,36,60,0.3)' : 'transparent'}`,
                    }}
                  >
                    <img src={song.coverArt} alt={song.title} style={{ width: '40px', height: '40px', borderRadius: '6px', objectFit: 'cover' }} />
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <p style={{ fontSize: '13px', fontWeight: 600, color: currentSong.id === song.id ? '#FA243C' : '#fff', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{song.title}</p>
                      <p style={{ fontSize: '12px', color: '#B3B3B3', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{song.artist}</p>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>

        {/* Controls */}
        <div style={{ position: 'relative', zIndex: 1, padding: '16px 32px 32px' }}>
          {/* Progress */}
          <div onClick={handleSeek} style={{ height: '3px', background: '#404040', borderRadius: '2px', cursor: 'pointer', marginBottom: '8px' }}>
            <div style={{ height: '100%', background: '#FA243C', width: `${pct}%`, borderRadius: '2px' }} />
          </div>
          <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '20px' }}>
            <span style={{ fontSize: '11px', color: '#6B6B6B' }}>{fmt(currentTime)}</span>
            <span style={{ fontSize: '11px', color: '#6B6B6B' }}>{fmt(duration)}</span>
          </div>

          {/* Main controls */}
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '20px' }}>
            <button onClick={toggleShuffle} style={{ color: isShuffle ? '#FA243C' : '#B3B3B3' }}><Shuffle size={22} /></button>
            <button onClick={prevTrack} style={{ color: '#fff' }}><SkipBack size={30} /></button>
            <button
              onClick={togglePlay}
              style={{
                width: '64px', height: '64px', borderRadius: '50%', background: '#fff',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                boxShadow: '0 4px 20px rgba(0,0,0,0.4)',
              }}
            >
              {isPlaying
                ? <Pause size={26} style={{ fill: '#000', color: '#000' }} />
                : <Play size={26} style={{ fill: '#000', color: '#000', marginLeft: '3px' }} />}
            </button>
            <button onClick={nextTrack} style={{ color: '#fff' }}><SkipForward size={30} /></button>
            <button onClick={toggleRepeat} style={{ color: repeatMode !== 'off' ? '#FA243C' : '#B3B3B3' }}>
              {repeatMode === 'one' ? <Repeat1 size={22} /> : <Repeat size={22} />}
            </button>
          </div>

          {/* Volume */}
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '10px' }}>
            <button onClick={toggleMute} style={{ color: '#B3B3B3' }}>
              {isMuted || volume === 0 ? <VolumeX size={18} /> : <Volume2 size={18} />}
            </button>
            <input
              type="range" min="0" max="1" step="0.01"
              value={isMuted ? 0 : volume}
              onChange={e => changeVolume(parseFloat(e.target.value))}
              style={{ width: '180px', accentColor: '#FA243C', cursor: 'pointer' }}
            />
          </div>
        </div>
      </motion.div>
    </AnimatePresence>
  );
};
