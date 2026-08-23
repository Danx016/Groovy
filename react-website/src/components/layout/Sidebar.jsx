import React from 'react';
import { Home, Compass, Library, User, Settings, PlusCircle, Heart, ListMusic } from 'lucide-react';
import { useAuth } from '../../context/AuthContext';
import { useLibrary } from '../../context/LibraryContext';
import { usePlayer } from '../../context/PlayerContext';

const NAV_ITEMS = [
  { id: 'home', label: 'Inicio', icon: Home },
  { id: 'library', label: 'Tu Biblioteca', icon: Library },
  { id: 'search', label: 'Explorar', icon: Compass },
  { id: 'account', label: 'Mi Cuenta', icon: User },
  { id: 'settings', label: 'Preferencias', icon: Settings },
];

export const Sidebar = ({ activeTab, setActiveTab, onOpenCreatePlaylist }) => {
  const { isAuthenticated, openAuthModal } = useAuth();
  const { playlists, favorites } = useLibrary();
  const { isPlaying } = usePlayer();

  return (
    <aside style={{
      display: 'none', /* hidden on mobile; shown via CSS below */
      width: '240px', flexShrink: 0,
      flexDirection: 'column',
      background: '#000000',
      borderRight: '0.5px solid #282828',
      height: '100vh', position: 'sticky', top: 0,
      overflowY: 'auto', padding: '16px 8px',
      gap: 0,
    }} className="sidebar">

      {/* Brand */}
      <div style={{ display: 'flex', alignItems: 'center', gap: '12px', padding: '8px 12px', marginBottom: '8px' }}>
        <div style={{ width: '36px', height: '36px', borderRadius: '8px', overflow: 'hidden', flexShrink: 0 }}>
          <img src="./logo.png" alt="Groovy" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
        </div>
        <div>
          <h1 style={{ fontSize: '17px', fontWeight: 700, color: '#fff', letterSpacing: '-0.3px' }}>Groovy</h1>
          <p style={{ fontSize: '11px', color: '#B3B3B3', marginTop: '1px' }}>Cloud Music</p>
        </div>
        {/* Equalizer if playing */}
        {isPlaying && (
          <div style={{ display: 'flex', alignItems: 'flex-end', gap: '2px', height: '16px', marginLeft: 'auto' }}>
            <div className="eq-bar" />
            <div className="eq-bar" />
            <div className="eq-bar" />
            <div className="eq-bar" />
          </div>
        )}
      </div>

      {/* Main Nav */}
      <nav style={{ marginBottom: '16px' }}>
        {NAV_ITEMS.map(({ id, label, icon: Icon }) => {
          const isActive = activeTab === id;
          return (
            <button
              key={id}
              onClick={() => setActiveTab(id)}
              style={{
                display: 'flex', alignItems: 'center', gap: '12px',
                width: '100%', padding: '10px 12px', borderRadius: '8px',
                fontSize: '14px', fontWeight: isActive ? 700 : 500,
                color: isActive ? '#fff' : '#B3B3B3',
                background: isActive ? '#282828' : 'transparent',
                textAlign: 'left', transition: 'all 0.15s',
              }}
              onMouseEnter={e => { if (!isActive) e.currentTarget.style.color = '#fff'; }}
              onMouseLeave={e => { if (!isActive) e.currentTarget.style.color = '#B3B3B3'; }}
            >
              <Icon size={20} style={{ color: isActive ? '#FA243C' : '#B3B3B3', flexShrink: 0 }} />
              {label}
            </button>
          );
        })}
      </nav>

      {/* Divider */}
      <div style={{ height: '0.5px', background: '#282828', margin: '0 12px 12px' }} />

      {/* Playlists section */}
      <div style={{ flex: 1, overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '4px 12px 8px' }}>
          <span style={{ fontSize: '11px', fontWeight: 700, letterSpacing: '0.06em', color: '#B3B3B3', textTransform: 'uppercase' }}>
            Playlists
          </span>
          <button
            onClick={() => isAuthenticated ? onOpenCreatePlaylist?.() : openAuthModal()}
            style={{ color: '#B3B3B3', padding: '2px', borderRadius: '4px' }}
            onMouseEnter={e => e.currentTarget.style.color = '#fff'}
            onMouseLeave={e => e.currentTarget.style.color = '#B3B3B3'}
          >
            <PlusCircle size={16} />
          </button>
        </div>

        {/* Favorites shortcut */}
        <button
          onClick={() => setActiveTab('library')}
          style={{
            display: 'flex', alignItems: 'center', gap: '10px',
            padding: '8px 12px', borderRadius: '6px', width: '100%',
            fontSize: '13px', fontWeight: 500, color: '#B3B3B3',
            textAlign: 'left', transition: 'color 0.15s',
          }}
          onMouseEnter={e => e.currentTarget.style.color = '#fff'}
          onMouseLeave={e => e.currentTarget.style.color = '#B3B3B3'}
        >
          <div style={{
            width: '28px', height: '28px', borderRadius: '6px', flexShrink: 0,
            background: 'linear-gradient(135deg,#e91e63,#c2185b)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <Heart size={14} style={{ fill: '#fff', color: '#fff' }} />
          </div>
          <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', flex: 1 }}>Canciones Favoritas</span>
          <span style={{ fontSize: '11px', color: '#6B6B6B' }}>{favorites.length}</span>
        </button>

        {/* User playlists */}
        <div style={{ flex: 1, overflowY: 'auto', paddingRight: '2px' }}>
          {playlists.map(pl => (
            <button
              key={pl.id}
              onClick={() => setActiveTab('library')}
              style={{
                display: 'flex', alignItems: 'center', gap: '10px',
                padding: '8px 12px', borderRadius: '6px', width: '100%',
                fontSize: '13px', fontWeight: 500, color: '#B3B3B3',
                textAlign: 'left', transition: 'color 0.15s',
              }}
              onMouseEnter={e => e.currentTarget.style.color = '#fff'}
              onMouseLeave={e => e.currentTarget.style.color = '#B3B3B3'}
            >
              <div style={{
                width: '28px', height: '28px', borderRadius: '6px', flexShrink: 0,
                background: '#282828', display: 'flex', alignItems: 'center', justifyContent: 'center',
              }}>
                <ListMusic size={13} style={{ color: '#B3B3B3' }} />
              </div>
              <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', flex: 1 }}>{pl.name}</span>
            </button>
          ))}
          {playlists.length === 0 && isAuthenticated && (
            <p style={{ padding: '12px', fontSize: '12px', color: '#6B6B6B', textAlign: 'center' }}>
              Sin playlists aún.
            </p>
          )}
        </div>
      </div>
    </aside>
  );
};
