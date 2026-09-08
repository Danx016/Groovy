import React, { useState, useEffect, useRef } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import {
  ChevronDown, Play, Pause, SkipForward, SkipBack, Heart, Shuffle,
  Repeat, Repeat1, Volume2, VolumeX, ListMusic, FileText, Sparkles,
  Trash2, X, Music, Radio, Disc3, Plus
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

export const FullPlayerModal = () => {
  const {
    currentSong, isPlaying, currentTime, duration, volume, isMuted,
    isShuffle, repeatMode, lyrics, isLyricsLoading, isFullPlayerOpen,
    activePlayerTab, setActivePlayerTab, closeFullPlayer,
    togglePlay, nextTrack, prevTrack, seekTo, changeVolume, toggleMute,
    toggleShuffle, toggleRepeat, queue, queueIndex, playSong, removeFromQueue, clearQueue,
    upNext = [], addToQueue, openArtist, openAlbum,
  } = usePlayer();
  const { isFavorite, toggleFavorite } = useLibrary();
  const { isAuthenticated, openAuthModal } = useAuth();

  const activeLyricRef = useRef(null);
  const lyricsContainerRef = useRef(null);

  // Find active synchronized lyric index
  const activeLyricIndex = (() => {
    if (!lyrics?.parsedLyrics || lyrics.parsedLyrics.length === 0) return -1;
    let activeIdx = -1;
    for (let i = 0; i < lyrics.parsedLyrics.length; i++) {
      if (currentTime >= lyrics.parsedLyrics[i].time - 0.25) {
        activeIdx = i;
      } else {
        break;
      }
    }
    return activeIdx;
  })();

  // Auto-scroll lyrics when line changes
  useEffect(() => {
    if (activePlayerTab === 'lyrics' && activeLyricRef.current && lyricsContainerRef.current) {
      activeLyricRef.current.scrollIntoView({
        behavior: 'smooth',
        block: 'center',
      });
    }
  }, [activeLyricIndex, activePlayerTab]);

  const pct = (duration && duration > 0) ? (currentTime / duration) * 100 : 0;
  const isFav = currentSong ? isFavorite(currentSong.id) : false;

  const handleSeek = (e) => {
    if (!duration) return;
    const rect = e.currentTarget.getBoundingClientRect();
    const pos = Math.max(0, Math.min(1, (e.clientX - rect.left) / rect.width));
    seekTo(pos * duration);
  };

  const TAB_BTN = (tabKey, label, Icon) => {
    const active = activePlayerTab === tabKey;
    return (
      <button
        type="button"
        onClick={() => setActivePlayerTab(tabKey)}
        style={{
          padding: '8px 18px', borderRadius: '24px', fontSize: '13px',
          fontWeight: active ? 700 : 500,
          color: active ? '#fff' : '#A1A1A6',
          background: active ? 'rgba(255,255,255,0.15)' : 'transparent',
          border: 'none', cursor: 'pointer', transition: 'all 0.2s',
          display: 'flex', alignItems: 'center', gap: '6px',
        }}
      >
        {Icon && <Icon size={14} style={{ color: active ? '#FA243C' : '#A1A1A6' }} />}
        {label}
      </button>
    );
  };

  return (
    <AnimatePresence>
      {isFullPlayerOpen && currentSong && (
        <motion.div
          initial={{ y: '100%', opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          exit={{ y: '100%', opacity: 0 }}
          transition={{ type: 'spring', damping: 26, stiffness: 220 }}
          style={{
            position: 'fixed', inset: 0, zIndex: 100,
            display: 'flex', flexDirection: 'column',
            background: '#0B0B0B', overflow: 'hidden',
          }}
        >
        {/* Dynamic Blurred Glow Ambient Background */}
        <div style={{
          position: 'absolute', inset: 0,
          backgroundImage: `url(${currentSong.coverArt})`,
          backgroundSize: 'cover', backgroundPosition: 'center',
          opacity: 0.28, filter: 'blur(70px)', transform: 'scale(1.4)',
        }} />
        <div style={{
          position: 'absolute', inset: 0,
          background: 'linear-gradient(180deg, rgba(11,11,11,0.4) 0%, rgba(11,11,11,0.85) 60%, rgba(11,11,11,0.98) 100%)',
        }} />

        {/* Top Header Bar */}
        <div style={{
          position: 'relative', zIndex: 2,
          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          padding: '18px 24px',
        }}>
          <button
            onClick={closeFullPlayer}
            style={{
              width: '38px', height: '38px', borderRadius: '50%',
              background: 'rgba(255,255,255,0.08)', border: 'none',
              color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center',
              cursor: 'pointer', transition: 'background 0.2s',
            }}
            onMouseEnter={e => e.currentTarget.style.background = 'rgba(255,255,255,0.16)'}
            onMouseLeave={e => e.currentTarget.style.background = 'rgba(255,255,255,0.08)'}
          >
            <ChevronDown size={22} />
          </button>

          {/* Switcher Tabs */}
          <div style={{
            display: 'flex', background: 'rgba(0,0,0,0.4)',
            backdropFilter: 'blur(12px)',
            borderRadius: '28px', padding: '4px', border: '0.5px solid rgba(255,255,255,0.1)',
          }}>
            {TAB_BTN('art', 'Reproductor', Disc3)}
            {TAB_BTN('lyrics', 'Letra', FileText)}
            {TAB_BTN('queue', `Cola (${queue.length})`, ListMusic)}
          </div>

          <button
            onClick={() => isAuthenticated ? toggleFavorite(currentSong) : openAuthModal()}
            style={{
              width: '38px', height: '38px', borderRadius: '50%',
              background: isFav ? 'rgba(250,36,60,0.15)' : 'rgba(255,255,255,0.08)',
              border: 'none', color: isFav ? '#FA243C' : '#fff',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              cursor: 'pointer', transition: 'all 0.2s',
            }}
          >
            <Heart size={20} style={{ fill: isFav ? '#FA243C' : 'none' }} />
          </button>
        </div>

        {/* Main Body */}
        <div style={{
          position: 'relative', zIndex: 2, flex: 1,
          display: 'flex', flexDirection: 'column', alignItems: 'center',
          overflowY: 'auto', padding: '0 24px 12px',
        }}>
          {/* 1. ARTWORK & SONG INFO TAB */}
          {activePlayerTab === 'art' && (
            <div style={{
              display: 'flex', flexDirection: 'column', alignItems: 'center',
              width: '100%', maxWidth: '380px', margin: 'auto 0',
            }}>
              <div style={{
                position: 'relative', width: '100%', aspectRatio: '1/1',
                maxWidth: '320px', borderRadius: '18px', overflow: 'hidden',
                boxShadow: '0 24px 60px rgba(0,0,0,0.85), 0 0 40px rgba(250,36,60,0.2)',
                marginBottom: '32px',
                transition: 'transform 0.4s cubic-bezier(0.34, 1.56, 0.64, 1)',
                transform: isPlaying ? 'scale(1.03)' : 'scale(0.96)',
              }}>
                <img
                  src={currentSong.coverArt}
                  alt={currentSong.title}
                  style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                  onError={e => { e.target.src = 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600'; }}
                />
              </div>

              <div style={{ textAlign: 'center', width: '100%' }}>
                <h2 style={{
                  fontSize: '24px', fontWeight: 800, color: '#fff',
                  letterSpacing: '-0.5px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
                  marginBottom: '6px',
                }}>
                  {currentSong.title}
                </h2>
                <p
                  onClick={() => openArtist?.(currentSong.artist)}
                  style={{
                    fontSize: '16px', fontWeight: 600, color: '#FA243C',
                    overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
                    marginBottom: '4px', cursor: 'pointer', textDecoration: 'underline',
                  }}
                >
                  {currentSong.artist}
                </p>
                {currentSong.album && (
                  <p
                    onClick={() => openAlbum?.({ name: currentSong.album, artist: currentSong.artist, coverArt: currentSong.coverArt })}
                    style={{ fontSize: '13px', color: '#A1A1A6', cursor: 'pointer', margin: 0 }}
                  >
                    {currentSong.album}
                  </p>
                )}
              </div>
            </div>
          )}

          {/* 2. SYNCHRONIZED KARAOKE LYRICS TAB */}
          {activePlayerTab === 'lyrics' && (
            <div
              ref={lyricsContainerRef}
              style={{
                width: '100%', maxWidth: '600px', flex: 1,
                overflowY: 'auto', textAlign: 'center', padding: '20px 10px',
                scrollbarWidth: 'none',
              }}
            >
              {isLyricsLoading ? (
                <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', height: '100%', gap: '14px' }}>
                  <div className="animate-spin" style={{ width: '36px', height: '36px', border: '3px solid #FA243C', borderTopColor: 'transparent', borderRadius: '50%' }} />
                  <p style={{ color: '#A1A1A6', fontSize: '14px', fontWeight: 600 }}>Cargando letra sincronizada...</p>
                </div>
              ) : lyrics.parsedLyrics && lyrics.parsedLyrics.length > 0 ? (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '20px', padding: '60px 0' }}>
                  {lyrics.parsedLyrics.map((line, idx) => {
                    const isActive = idx === activeLyricIndex;
                    return (
                      <p
                        key={idx}
                        ref={isActive ? activeLyricRef : null}
                        onClick={() => seekTo(line.time)}
                        style={{
                          fontSize: isActive ? '24px' : '18px',
                          fontWeight: isActive ? 800 : 500,
                          color: isActive ? '#fff' : '#6B6B6B',
                          textShadow: isActive ? '0 0 20px rgba(255,255,255,0.7)' : 'none',
                          transform: isActive ? 'scale(1.05)' : 'scale(1)',
                          transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
                          cursor: 'pointer', margin: 0, lineHeight: 1.4,
                        }}
                        onMouseEnter={e => { if (!isActive) e.currentTarget.style.color = '#B3B3B3'; }}
                        onMouseLeave={e => { if (!isActive) e.currentTarget.style.color = '#6B6B6B'; }}
                      >
                        {line.text}
                      </p>
                    );
                  })}
                </div>
              ) : lyrics.plainLyrics ? (
                <div style={{ lineHeight: 2.2, color: '#E5E5EA', fontSize: '16px', fontWeight: 500, padding: '40px 0' }}>
                  {lyrics.plainLyrics.split('\n').map((line, i) => (
                    <p key={i} style={{ margin: '6px 0' }}>{line}</p>
                  ))}
                </div>
              ) : (
                <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', height: '100%', color: '#6B6B6B' }}>
                  <Sparkles size={48} style={{ color: '#FA243C', opacity: 0.4, marginBottom: '12px' }} />
                  <p style={{ fontSize: '18px', color: '#fff', fontWeight: 700, marginBottom: '4px' }}>Letra no disponible</p>
                  <p style={{ fontSize: '13px', color: '#A1A1A6' }}>Disfruta de la reproducción en alta fidelidad.</p>
                </div>
              )}
            </div>
          )}

          {/* 3. QUEUE MANAGER TAB */}
          {activePlayerTab === 'queue' && (
            <div style={{ width: '100%', maxWidth: '520px', flex: 1, overflowY: 'auto', padding: '10px 0' }}>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '16px', padding: '0 4px' }}>
                <p style={{ fontSize: '13px', fontWeight: 700, letterSpacing: '0.06em', color: '#A1A1A6', textTransform: 'uppercase' }}>
                  En Reproducción & A continuación ({queue.length})
                </p>
                {queue.length > 1 && (
                  <button
                    onClick={clearQueue}
                    style={{
                      display: 'flex', alignItems: 'center', gap: '4px',
                      color: '#FF453A', background: 'transparent', border: 'none',
                      fontSize: '12px', fontWeight: 600, cursor: 'pointer',
                    }}
                  >
                    <Trash2 size={13} /> Limpiar cola
                  </button>
                )}
              </div>

              <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                {queue.map((song, idx) => {
                  const isCurrent = currentSong.id === song.id;
                  return (
                    <div
                      key={`${song.id}-${idx}`}
                      style={{
                        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
                        padding: '10px 12px', borderRadius: '10px',
                        background: isCurrent ? 'rgba(250,36,60,0.15)' : 'rgba(255,255,255,0.04)',
                        border: `0.5px solid ${isCurrent ? 'rgba(250,36,60,0.35)' : 'transparent'}`,
                        transition: 'background 0.15s',
                      }}
                    >
                      <div
                        onClick={() => playSong(song)}
                        style={{ display: 'flex', alignItems: 'center', gap: '12px', flex: 1, minWidth: 0, cursor: 'pointer' }}
                      >
                        <img
                          src={song.coverArt}
                          alt={song.title}
                          style={{ width: '42px', height: '42px', borderRadius: '6px', objectFit: 'cover' }}
                        />
                        <div style={{ flex: 1, minWidth: 0 }}>
                          <p style={{
                            fontSize: '13px', fontWeight: 700,
                            color: isCurrent ? '#FA243C' : '#fff',
                            overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
                          }}>
                            {song.title}
                          </p>
                          <p style={{ fontSize: '11px', color: '#A1A1A6', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                            {song.artist}
                          </p>
                        </div>
                      </div>

                      <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                        {queue.length > 1 && (
                          <button
                            onClick={() => removeFromQueue(idx)}
                            style={{ background: 'transparent', border: 'none', color: '#6B6B6B', cursor: 'pointer', padding: '4px' }}
                            title="Quitar de la cola"
                          >
                            <X size={15} />
                          </button>
                        )}
                      </div>
                    </div>
                  );
                })}
              </div>

              {/* Up Next / A continuación (Radio de la canción) */}
              {upNext && upNext.length > 0 && (
                <div style={{ marginTop: '24px' }}>
                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '12px', padding: '0 4px' }}>
                    <p style={{ fontSize: '13px', fontWeight: 800, letterSpacing: '0.06em', color: '#FA243C', textTransform: 'uppercase' }}>
                      A continuación (Radio recomendada)
                    </p>
                  </div>
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                    {upNext.map((song, i) => (
                      <div
                        key={`upnext-${song.id}-${i}`}
                        style={{
                          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
                          padding: '10px 12px', borderRadius: '10px',
                          background: 'rgba(255,255,255,0.03)',
                          border: '0.5px solid rgba(255,255,255,0.06)',
                          transition: 'background 0.15s',
                        }}
                      >
                        <div
                          onClick={() => playSong(song)}
                          style={{ display: 'flex', alignItems: 'center', gap: '12px', flex: 1, minWidth: 0, cursor: 'pointer' }}
                        >
                          <img
                            src={song.coverArt}
                            alt={song.title}
                            style={{ width: '42px', height: '42px', borderRadius: '6px', objectFit: 'cover' }}
                          />
                          <div style={{ flex: 1, minWidth: 0 }}>
                            <p style={{ fontSize: '13px', fontWeight: 700, color: '#fff', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', margin: '0 0 2px' }}>
                              {song.title}
                            </p>
                            <p style={{ fontSize: '11px', color: '#A1A1A6', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', margin: 0 }}>
                              {song.artist}
                            </p>
                          </div>
                        </div>

                        <button
                          onClick={() => addToQueue(song)}
                          style={{
                            background: 'transparent', border: 'none', color: '#FA243C',
                            cursor: 'pointer', padding: '6px', display: 'flex', alignItems: 'center', gap: '4px',
                            fontSize: '12px', fontWeight: 700,
                          }}
                          title="Añadir a la cola"
                        >
                          <Plus size={16} /> Añadir
                        </button>
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </div>
          )}
        </div>

        {/* Bottom Controls Bar */}
        <div style={{
          position: 'relative', zIndex: 2,
          padding: '14px 28px 28px', maxWidth: '600px', width: '100%', margin: '0 auto',
        }}>
          {/* Progress Bar & Scrubber */}
          <div
            onClick={handleSeek}
            style={{
              height: '5px', background: 'rgba(255,255,255,0.18)',
              borderRadius: '3px', cursor: 'pointer', marginBottom: '8px',
              position: 'relative',
            }}
          >
            <div style={{
              height: '100%', background: '#FA243C',
              width: `${pct}%`, borderRadius: '3px',
              position: 'relative',
            }}>
              <div style={{
                position: 'absolute', right: '-5px', top: '-3px',
                width: '11px', height: '11px', borderRadius: '50%',
                background: '#fff', boxShadow: '0 2px 6px rgba(0,0,0,0.6)',
              }} />
            </div>
          </div>

          <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '16px' }}>
            <span style={{ fontSize: '12px', fontWeight: 600, color: '#A1A1A6' }}>{fmt(currentTime)}</span>
            <span style={{ fontSize: '12px', fontWeight: 600, color: '#A1A1A6' }}>{fmt(duration)}</span>
          </div>

          {/* Main Playback Buttons */}
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '18px' }}>
            <button
              onClick={toggleShuffle}
              style={{
                color: isShuffle ? '#FA243C' : '#A1A1A6',
                background: 'transparent', border: 'none', cursor: 'pointer', padding: '8px',
              }}
              title="Modo aleatorio"
            >
              <Shuffle size={20} />
            </button>

            <button
              onClick={prevTrack}
              style={{
                color: '#fff', background: 'transparent', border: 'none',
                cursor: 'pointer', padding: '8px', transition: 'transform 0.1s',
              }}
              onMouseDown={e => e.currentTarget.style.transform = 'scale(0.92)'}
              onMouseUp={e => e.currentTarget.style.transform = 'scale(1)'}
            >
              <SkipBack size={28} />
            </button>

            <button
              onClick={togglePlay}
              style={{
                width: '64px', height: '64px', borderRadius: '50%',
                background: '#FA243C', color: '#fff', border: 'none',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                boxShadow: '0 8px 26px rgba(250,36,60,0.6)',
                cursor: 'pointer', transition: 'transform 0.15s',
              }}
              onMouseDown={e => e.currentTarget.style.transform = 'scale(0.92)'}
              onMouseUp={e => e.currentTarget.style.transform = 'scale(1)'}
            >
              {isPlaying
                ? <Pause size={28} style={{ fill: '#fff', color: '#fff' }} />
                : <Play size={28} style={{ fill: '#fff', color: '#fff', marginLeft: '3px' }} />}
            </button>

            <button
              onClick={nextTrack}
              style={{
                color: '#fff', background: 'transparent', border: 'none',
                cursor: 'pointer', padding: '8px', transition: 'transform 0.1s',
              }}
              onMouseDown={e => e.currentTarget.style.transform = 'scale(0.92)'}
              onMouseUp={e => e.currentTarget.style.transform = 'scale(1)'}
            >
              <SkipForward size={28} />
            </button>

            <button
              onClick={toggleRepeat}
              style={{
                color: repeatMode !== 'off' ? '#FA243C' : '#A1A1A6',
                background: 'transparent', border: 'none', cursor: 'pointer', padding: '8px',
              }}
              title="Repetición"
            >
              {repeatMode === 'one' ? <Repeat1 size={20} /> : <Repeat size={20} />}
            </button>
          </div>

          {/* Volume Slider */}
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '12px' }}>
            <button
              onClick={toggleMute}
              style={{ color: '#A1A1A6', background: 'transparent', border: 'none', cursor: 'pointer' }}
            >
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
      )}
    </AnimatePresence>
  );
};
