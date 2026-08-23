import React, { useState } from 'react';
import { Play, Pause, ChevronRight, Clock, Stars, Zap, Music2, Sparkles } from 'lucide-react';
import { usePlayer } from '../../context/PlayerContext';
import { useLibrary } from '../../context/LibraryContext';
import { useAuth } from '../../context/AuthContext';
import { useRecommendations } from '../../hooks/useRecommendations';
import { SongCard } from '../ui/SongCard';

/* Greeting based on time */
const getGreeting = () => {
  const h = new Date().getHours();
  if (h < 12) return 'Buenos días';
  if (h < 17) return 'Buenas tardes';
  return 'Buenas noches';
};

/* Horizontal scroll song strip (Quick Picks / Mix rows) */
const SongStrip = ({ songs, label, icon: Icon, iconColor = '#FA243C' }) => {
  const { currentSong, isPlaying, playSong, togglePlay } = usePlayer();

  if (!songs || songs.length === 0) return null;

  return (
    <div style={{ marginBottom: '28px' }}>
      {/* Header */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '14px', padding: '0 2px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          {Icon && <Icon size={20} style={{ color: iconColor }} />}
          <h2 style={{ fontSize: '20px', fontWeight: 700, letterSpacing: '-0.3px' }}>{label}</h2>
        </div>
        <button
          onClick={() => playSong(songs[0], songs)}
          style={{ display: 'flex', alignItems: 'center', gap: '4px', color: '#B3B3B3', fontSize: '12px', fontWeight: 600 }}
          onMouseEnter={e => e.currentTarget.style.color = '#fff'}
          onMouseLeave={e => e.currentTarget.style.color = '#B3B3B3'}
        >
          Reproducir todo <ChevronRight size={14} />
        </button>
      </div>

      {/* Horizontal card scroll */}
      <div style={{ display: 'flex', gap: '12px', overflowX: 'auto', paddingBottom: '8px', scrollbarWidth: 'none' }}>
        {songs.slice(0, 12).map((song) => {
          const isCurrent = currentSong?.id === song.id;
          return (
            <div
              key={song.id}
              onClick={() => isCurrent ? togglePlay() : playSong(song, songs)}
              style={{
                flexShrink: 0, width: '150px', cursor: 'pointer',
                borderRadius: '8px', padding: '10px',
                background: isCurrent ? 'rgba(250,36,60,0.12)' : '#181818',
                border: `0.5px solid ${isCurrent ? 'rgba(250,36,60,0.3)' : '#282828'}`,
                transition: 'background 0.15s',
              }}
              onMouseEnter={e => { if (!isCurrent) e.currentTarget.style.background = '#282828'; }}
              onMouseLeave={e => { if (!isCurrent) e.currentTarget.style.background = '#181818'; }}
            >
              <div style={{ position: 'relative', width: '100%', aspectRatio: '1/1', borderRadius: '6px', overflow: 'hidden', marginBottom: '10px', background: '#282828' }}>
                <img
                  src={song.coverArt || ''}
                  alt={song.title}
                  style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                  onError={e => e.target.style.display = 'none'}
                />
                {/* Play overlay */}
                <div style={{
                  position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center',
                  background: 'rgba(0,0,0,0.4)', opacity: 0, transition: 'opacity 0.15s',
                }}
                  className="song-play-overlay"
                >
                  {isCurrent && isPlaying
                    ? <Pause size={28} style={{ fill: '#fff', color: '#fff' }} />
                    : <Play size={28} style={{ fill: '#fff', color: '#fff', marginLeft: '3px' }} />}
                </div>
                {/* Equalizer bars if playing */}
                {isCurrent && isPlaying && (
                  <div style={{ position: 'absolute', bottom: '6px', right: '6px', display: 'flex', alignItems: 'flex-end', gap: '2px', height: '16px' }}>
                    <div className="eq-bar" />
                    <div className="eq-bar" />
                    <div className="eq-bar" />
                  </div>
                )}
              </div>
              <p style={{ fontSize: '13px', fontWeight: 600, color: isCurrent ? '#FA243C' : '#fff', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                {song.title}
              </p>
              <p style={{ fontSize: '11px', color: '#B3B3B3', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', marginTop: '2px' }}>
                {song.artist}
              </p>
            </div>
          );
        })}
      </div>
    </div>
  );
};

/* Quick Access Grid (recent items — like the top grid in Android) */
const QuickAccessGrid = ({ items }) => {
  const { playSong } = usePlayer();
  if (!items || items.length === 0) return null;

  return (
    <div style={{ marginBottom: '24px' }}>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: '8px' }}>
        {items.map((song) => (
          <div
            key={song.id}
            onClick={() => playSong(song, items)}
            style={{
              display: 'flex', alignItems: 'center', gap: '10px',
              background: '#181818', borderRadius: '8px', overflow: 'hidden',
              cursor: 'pointer', border: '0.5px solid #282828', transition: 'background 0.15s',
              height: '54px',
            }}
            onMouseEnter={e => e.currentTarget.style.background = '#282828'}
            onMouseLeave={e => e.currentTarget.style.background = '#181818'}
          >
            <div style={{ width: '54px', height: '54px', flexShrink: 0, background: '#282828', position: 'relative' }}>
              {song.coverArt ? (
                <img src={song.coverArt} alt={song.title} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
              ) : (
                <div style={{ width: '100%', height: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <Music2 size={20} style={{ color: '#6B6B6B' }} />
                </div>
              )}
            </div>
            <span style={{ fontSize: '13px', fontWeight: 600, color: '#fff', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', flex: 1, paddingRight: '10px' }}>
              {song.title}
            </span>
          </div>
        ))}
      </div>
    </div>
  );
};

export const HomeView = ({ setActiveTab }) => {
  const { history, currentSong, isPlaying, playSong, togglePlay } = usePlayer();
  const { favorites } = useLibrary();
  const { isAuthenticated } = useAuth();
  const { forYou, quickPicks, mixes } = useRecommendations();

  const hasData = history.length > 0 || favorites.length > 0;

  /* Quick access: last 6 unique songs from history */
  const quickAccessSongs = (() => {
    const seen = new Set();
    return history.filter(s => {
      if (!s?.id || seen.has(s.id)) return false;
      // Skip songs with no meaningful album/title
      if (!s.title || s.title === '[Unknown Album]') return false;
      seen.add(s.id);
      return true;
    }).slice(0, 6);
  })();

  return (
    <div style={{ paddingBottom: '148px' }}>
      {/* Header with greeting */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '20px' }}>
        <h1 style={{ fontSize: '28px', fontWeight: 700, letterSpacing: '-0.5px' }}>{getGreeting()}</h1>
        <button
          onClick={() => setActiveTab('library')}
          style={{ color: '#B3B3B3', padding: '8px', borderRadius: '50%' }}
          title="Historial"
          onMouseEnter={e => e.currentTarget.style.color = '#fff'}
          onMouseLeave={e => e.currentTarget.style.color = '#B3B3B3'}
        >
          <Clock size={22} />
        </button>
      </div>

      {/* Quick Access Grid (recent items) — hidden when empty */}
      {quickAccessSongs.length > 0 && (
        <QuickAccessGrid items={quickAccessSongs} />
      )}

      {/* Empty state if no history yet */}
      {!hasData && (
        <div style={{ textAlign: 'center', padding: '60px 24px', color: '#6B6B6B' }}>
          <Sparkles size={48} style={{ margin: '0 auto 16px', color: '#FA243C', opacity: 0.4 }} />
          <p style={{ fontSize: '17px', fontWeight: 600, color: '#fff', marginBottom: '8px' }}>Empieza a escuchar</p>
          <p style={{ fontSize: '14px', maxWidth: '320px', margin: '0 auto 20px' }}>
            Las secciones «Para Ti», «Selección Rápida» y los Mixes se generan en base a lo que escuchas.
          </p>
          <button
            onClick={() => setActiveTab('search')}
            style={{ padding: '12px 24px', borderRadius: '12px', background: '#FA243C', color: '#fff', fontWeight: 700, fontSize: '14px' }}
          >
            Explorar música
          </button>
        </div>
      )}

      {/* Para Ti */}
      {forYou.length > 0 && (
        <SongStrip songs={forYou} label="Para Ti" icon={Stars} iconColor="#FA243C" />
      )}

      {/* Selección Rápida */}
      {quickPicks.length > 0 && (
        <SongStrip songs={quickPicks} label="Selección Rápida" icon={Zap} iconColor="#FF9F0A" />
      )}

      {/* Mixes (artist / genre / time-based) */}
      {mixes.map(({ name, songs }) => (
        <SongStrip key={name} songs={songs} label={name} icon={Music2} iconColor="#BF5AF2" />
      ))}

      {/* If logged in but has data — show full list button */}
      {hasData && (
        <div style={{ marginTop: '8px' }}>
          <div style={{ height: '0.5px', background: '#282828', marginBottom: '20px' }} />
          <div style={{ display: 'flex', flexDirection: 'column', gap: '0' }}>
            {history.slice(0, 8).filter(s => s?.title && s.title !== '[Unknown Album]').map((s, i) => (
              <div
                key={`${s.id}-${i}`}
                onClick={() => currentSong?.id === s.id ? togglePlay() : playSong(s, history)}
                style={{
                  display: 'flex', alignItems: 'center', gap: '12px', padding: '8px 10px',
                  borderRadius: '8px', cursor: 'pointer',
                  background: currentSong?.id === s.id ? 'rgba(250,36,60,0.1)' : 'transparent',
                  transition: 'background 0.15s',
                }}
                onMouseEnter={e => { if (currentSong?.id !== s.id) e.currentTarget.style.background = 'rgba(255,255,255,0.04)'; }}
                onMouseLeave={e => { if (currentSong?.id !== s.id) e.currentTarget.style.background = 'transparent'; }}
              >
                <div style={{ width: '40px', height: '40px', borderRadius: '6px', overflow: 'hidden', flexShrink: 0, background: '#282828', position: 'relative' }}>
                  {s.coverArt && <img src={s.coverArt} alt={s.title} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />}
                  {currentSong?.id === s.id && isPlaying && (
                    <div style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.5)', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '2px' }}>
                      <div className="eq-bar" style={{ height: '12px' }} />
                      <div className="eq-bar" style={{ height: '12px' }} />
                      <div className="eq-bar" style={{ height: '12px' }} />
                    </div>
                  )}
                </div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <p style={{ fontSize: '14px', fontWeight: 500, color: currentSong?.id === s.id ? '#FA243C' : '#fff', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{s.title}</p>
                  <p style={{ fontSize: '12px', color: '#B3B3B3', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{s.artist}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
};
