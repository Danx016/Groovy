import React, { useState } from 'react';
import { Play, Pause, Heart, MoreVertical, Plus } from 'lucide-react';
import { usePlayer } from '../../context/PlayerContext';
import { useLibrary } from '../../context/LibraryContext';
import { useAuth } from '../../context/AuthContext';

export const SongCard = ({ song, queue = [] }) => {
  const { currentSong, isPlaying, playSong, togglePlay } = usePlayer();
  const { isFavorite, toggleFavorite, playlists, addSongToPlaylist } = useLibrary();
  const { isAuthenticated, openAuthModal } = useAuth();
  const [showMenu, setShowMenu] = useState(false);

  const isCurrent = currentSong?.id === song.id;
  const isFav = isFavorite(song.id);

  const handlePlay = (e) => {
    e.stopPropagation();
    if (isCurrent) { togglePlay(); } else { playSong(song, queue.length > 0 ? queue : [song]); }
  };

  const handleHeart = (e) => {
    e.stopPropagation();
    if (!isAuthenticated) { openAuthModal(); } else { toggleFavorite(song); }
  };

  const handleAddToPlaylist = async (plId) => {
    try { await addSongToPlaylist(plId, song); setShowMenu(false); } catch (e) { console.error(e); }
  };

  const fmt = (s) => { if (!s) return ''; const m = Math.floor(s / 60); const sec = Math.floor(s % 60); return `${m}:${sec < 10 ? '0' : ''}${sec}`; };

  return (
    <div
      onClick={handlePlay}
      style={{
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        padding: '8px 12px', borderRadius: '8px', cursor: 'pointer',
        background: isCurrent ? 'rgba(250,36,60,0.1)' : 'transparent',
        border: `0.5px solid ${isCurrent ? 'rgba(250,36,60,0.2)' : 'transparent'}`,
        transition: 'background 0.15s',
      }}
      onMouseEnter={e => { if (!isCurrent) e.currentTarget.style.background = 'rgba(255,255,255,0.04)'; }}
      onMouseLeave={e => { if (!isCurrent) e.currentTarget.style.background = 'transparent'; }}
    >
      {/* Cover + equalizer overlay */}
      <div style={{ position: 'relative', width: '44px', height: '44px', borderRadius: '6px', overflow: 'hidden', flexShrink: 0, background: '#282828' }}>
        <img src={song.coverArt} alt={song.title} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
        {isCurrent && isPlaying && (
          <div style={{
            position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.55)',
            display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '2px',
          }}>
            <div className="eq-bar" />
            <div className="eq-bar" />
            <div className="eq-bar" />
          </div>
        )}
      </div>

      {/* Text */}
      <div style={{ flex: 1, minWidth: 0, padding: '0 12px' }}>
        <p style={{
          fontSize: '15px', fontWeight: 500, color: isCurrent ? '#FA243C' : '#fff',
          overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
        }}>{song.title}</p>
        <p style={{ fontSize: '13px', color: '#B3B3B3', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
          {song.artist}{song.album ? ` · ${song.album}` : ''}
        </p>
      </div>

      {/* Duration */}
      <span style={{ fontSize: '12px', color: '#6B6B6B', flexShrink: 0, marginRight: '8px' }}>{fmt(song.duration)}</span>

      {/* Heart */}
      <button onClick={handleHeart} style={{ color: isFav ? '#FA243C' : '#B3B3B3', padding: '6px', flexShrink: 0 }}>
        <Heart size={17} style={{ fill: isFav ? '#FA243C' : 'none' }} />
      </button>

      {/* More menu */}
      <div style={{ position: 'relative', flexShrink: 0 }}>
        <button
          onClick={e => { e.stopPropagation(); setShowMenu(!showMenu); }}
          style={{ color: '#B3B3B3', padding: '6px' }}
          onMouseEnter={e => e.currentTarget.style.color = '#fff'}
          onMouseLeave={e => e.currentTarget.style.color = '#B3B3B3'}
        >
          <MoreVertical size={17} />
        </button>
        {showMenu && (
          <div
            onClick={e => e.stopPropagation()}
            style={{
              position: 'absolute', right: 0, top: '32px', zIndex: 20,
              background: '#282828', border: '0.5px solid #404040',
              borderRadius: '10px', padding: '6px', minWidth: '180px',
              boxShadow: '0 8px 24px rgba(0,0,0,0.6)',
            }}
          >
            <p style={{ fontSize: '11px', fontWeight: 700, color: '#B3B3B3', padding: '4px 10px 6px', textTransform: 'uppercase', letterSpacing: '0.06em' }}>
              Añadir a playlist
            </p>
            {playlists.map(pl => (
              <button
                key={pl.id}
                onClick={() => handleAddToPlaylist(pl.id)}
                style={{
                  display: 'flex', alignItems: 'center', gap: '8px', width: '100%',
                  padding: '8px 10px', borderRadius: '6px', fontSize: '14px',
                  color: '#fff', textAlign: 'left',
                }}
                onMouseEnter={e => e.currentTarget.style.background = 'rgba(255,255,255,0.08)'}
                onMouseLeave={e => e.currentTarget.style.background = 'transparent'}
              >
                <Plus size={14} />
                <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{pl.name}</span>
              </button>
            ))}
            {playlists.length === 0 && (
              <p style={{ padding: '8px 10px', fontSize: '12px', color: '#6B6B6B' }}>Sin playlists</p>
            )}
          </div>
        )}
      </div>
    </div>
  );
};
