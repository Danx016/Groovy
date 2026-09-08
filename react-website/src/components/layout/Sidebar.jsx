import React, { useState } from 'react';
import {
  Home, Search, Clock, Mic2, Disc3, Music2,
  LayoutGrid, Star, Plus, ChevronUp, ChevronDown,
  ChevronsLeft, ChevronsRight, Heart, ListMusic, User, Settings, Download
} from 'lucide-react';
import { useAuth } from '../../context/AuthContext';
import { useLibrary } from '../../context/LibraryContext';
import { usePlayer } from '../../context/PlayerContext';

export const Sidebar = ({ activeTab, setActiveTab, onOpenCreatePlaylist }) => {
  const { user, isAuthenticated, openAuthModal } = useAuth();
  const { playlists, favorites } = useLibrary();
  const { isPlaying } = usePlayer();

  const [isLibraryOpen, setIsLibraryOpen] = useState(true);
  const [isPlaylistsOpen, setIsPlaylistsOpen] = useState(true);
  const [isCollapsed, setIsCollapsed] = useState(false);

  const userName = user?.name || user?.username || 'Danilo Gómez';

  return (
    <aside
      style={{
        display: 'none', /* Shown via CSS on desktop */
        width: isCollapsed ? '72px' : '260px',
        flexShrink: 0,
        flexDirection: 'column',
        background: '#0c0d10',
        borderRight: '0.5px solid #1f2024',
        height: '100vh',
        position: 'sticky',
        top: 0,
        overflowY: 'auto',
        padding: isCollapsed ? '16px 8px' : '16px 12px 100px',
        gap: '4px',
        userSelect: 'none',
        transition: 'width 0.2s ease',
      }}
      className="sidebar"
    >
      {/* 1. Brand */}
      <div style={{
        display: 'flex', alignItems: 'center', gap: '12px',
        padding: '6px 10px 14px', marginBottom: '4px',
      }}>
        <div style={{
          width: '34px', height: '34px', borderRadius: '8px',
          overflow: 'hidden', flexShrink: 0,
          background: 'linear-gradient(135deg, #222, #111)',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          boxShadow: '0 4px 12px rgba(0,0,0,0.5)',
        }}>
          <img src="./logo.png" alt="Groovy" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
        </div>

        {!isCollapsed && (
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flex: 1 }}>
            <h1 style={{ fontSize: '18px', fontWeight: 800, color: '#fff', letterSpacing: '-0.4px' }}>
              Groovy
            </h1>
            {isPlaying && (
              <div style={{ display: 'flex', alignItems: 'flex-end', gap: '2px', height: '14px' }}>
                <div className="eq-bar" />
                <div className="eq-bar" />
                <div className="eq-bar" />
              </div>
            )}
          </div>
        )}
      </div>

      {/* 2. Top Nav: Inicio & Búsqueda */}
      <nav style={{ display: 'flex', flexDirection: 'column', gap: '2px', marginBottom: '14px' }}>
        {/* Inicio */}
        <button
          onClick={() => setActiveTab('home')}
          style={{
            display: 'flex', alignItems: 'center', gap: '14px',
            width: '100%', padding: '10px 12px', borderRadius: '8px',
            fontSize: '14px', fontWeight: activeTab === 'home' ? 700 : 500,
            color: activeTab === 'home' ? '#fff' : '#b3b3b3',
            background: activeTab === 'home' ? 'rgba(255,255,255,0.08)' : 'transparent',
            textAlign: 'left', border: 'none', cursor: 'pointer', transition: 'all 0.15s',
          }}
          onMouseEnter={e => { if (activeTab !== 'home') e.currentTarget.style.color = '#fff'; }}
          onMouseLeave={e => { if (activeTab !== 'home') e.currentTarget.style.color = '#b3b3b3'; }}
        >
          <Home size={19} style={{ color: activeTab === 'home' ? '#FA243C' : '#b3b3b3', flexShrink: 0 }} />
          {!isCollapsed && <span>Inicio</span>}
        </button>

        {/* Búsqueda */}
        <button
          onClick={() => setActiveTab('search')}
          style={{
            display: 'flex', alignItems: 'center', gap: '14px',
            width: '100%', padding: '10px 12px', borderRadius: '8px',
            fontSize: '14px', fontWeight: activeTab === 'search' ? 700 : 500,
            color: activeTab === 'search' ? '#fff' : '#b3b3b3',
            background: activeTab === 'search' ? 'rgba(255,255,255,0.08)' : 'transparent',
            textAlign: 'left', border: 'none', cursor: 'pointer', transition: 'all 0.15s',
          }}
          onMouseEnter={e => { if (activeTab !== 'search') e.currentTarget.style.color = '#fff'; }}
          onMouseLeave={e => { if (activeTab !== 'search') e.currentTarget.style.color = '#b3b3b3'; }}
        >
          <Search size={19} style={{ color: activeTab === 'search' ? '#FA243C' : '#b3b3b3', flexShrink: 0 }} />
          {!isCollapsed && <span>Búsqueda</span>}
        </button>
      </nav>

      {/* 3. Section: Biblioteca */}
      {!isCollapsed ? (
        <div style={{ marginBottom: '14px' }}>
          <div
            onClick={() => setIsLibraryOpen(!isLibraryOpen)}
            style={{
              display: 'flex', alignItems: 'center', justifyContent: 'space-between',
              padding: '6px 12px', cursor: 'pointer', color: '#fff', fontSize: '13px',
              fontWeight: 700, letterSpacing: '-0.2px',
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
              <LayoutGrid size={16} style={{ color: '#fff' }} />
              <span>Biblioteca</span>
            </div>
            {isLibraryOpen ? <ChevronUp size={15} style={{ color: '#888' }} /> : <ChevronDown size={15} style={{ color: '#888' }} />}
          </div>

          {isLibraryOpen && (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '1px', marginTop: '4px', paddingLeft: '8px' }}>
              <button
                onClick={() => setActiveTab('library')}
                style={{
                  display: 'flex', alignItems: 'center', gap: '12px',
                  width: '100%', padding: '8px 12px', borderRadius: '6px',
                  fontSize: '13px', fontWeight: 500, color: '#a0a0a0',
                  background: 'transparent', border: 'none', cursor: 'pointer', textAlign: 'left',
                }}
                onMouseEnter={e => e.currentTarget.style.color = '#fff'}
                onMouseLeave={e => e.currentTarget.style.color = '#a0a0a0'}
              >
                <Clock size={16} style={{ flexShrink: 0 }} />
                <span>Agregado recientemente</span>
              </button>

              <button
                onClick={() => setActiveTab('search')}
                style={{
                  display: 'flex', alignItems: 'center', gap: '12px',
                  width: '100%', padding: '8px 12px', borderRadius: '6px',
                  fontSize: '13px', fontWeight: 500, color: '#a0a0a0',
                  background: 'transparent', border: 'none', cursor: 'pointer', textAlign: 'left',
                }}
                onMouseEnter={e => e.currentTarget.style.color = '#fff'}
                onMouseLeave={e => e.currentTarget.style.color = '#a0a0a0'}
              >
                <Mic2 size={16} style={{ flexShrink: 0 }} />
                <span>Artistas</span>
              </button>

              <button
                onClick={() => setActiveTab('search')}
                style={{
                  display: 'flex', alignItems: 'center', gap: '12px',
                  width: '100%', padding: '8px 12px', borderRadius: '6px',
                  fontSize: '13px', fontWeight: 500, color: '#a0a0a0',
                  background: 'transparent', border: 'none', cursor: 'pointer', textAlign: 'left',
                }}
                onMouseEnter={e => e.currentTarget.style.color = '#fff'}
                onMouseLeave={e => e.currentTarget.style.color = '#a0a0a0'}
              >
                <Disc3 size={16} style={{ flexShrink: 0 }} />
                <span>Álbumes</span>
              </button>

              <button
                onClick={() => setActiveTab('library')}
                style={{
                  display: 'flex', alignItems: 'center', gap: '12px',
                  width: '100%', padding: '8px 12px', borderRadius: '6px',
                  fontSize: '13px', fontWeight: 500, color: '#a0a0a0',
                  background: 'transparent', border: 'none', cursor: 'pointer', textAlign: 'left',
                }}
                onMouseEnter={e => e.currentTarget.style.color = '#fff'}
                onMouseLeave={e => e.currentTarget.style.color = '#a0a0a0'}
              >
                <Music2 size={16} style={{ flexShrink: 0 }} />
                <span>Canciones</span>
              </button>
            </div>
          )}
        </div>
      ) : null}

      {/* 4. Section: Playlists */}
      {!isCollapsed ? (
        <div style={{ marginBottom: '14px' }}>
          <div
            style={{
              display: 'flex', alignItems: 'center', justifyContent: 'space-between',
              padding: '6px 12px', color: '#fff', fontSize: '13px',
              fontWeight: 700, letterSpacing: '-0.2px',
            }}
          >
            <div
              onClick={() => setIsPlaylistsOpen(!isPlaylistsOpen)}
              style={{ display: 'flex', alignItems: 'center', gap: '10px', cursor: 'pointer', flex: 1 }}
            >
              <ListMusic size={16} style={{ color: '#fff' }} />
              <span>Playlists</span>
            </div>

            <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
              <button
                onClick={() => isAuthenticated ? onOpenCreatePlaylist?.() : openAuthModal()}
                style={{
                  background: 'transparent', border: 'none', color: '#888',
                  cursor: 'pointer', padding: '2px', display: 'flex', alignItems: 'center',
                }}
                onMouseEnter={e => e.currentTarget.style.color = '#fff'}
                onMouseLeave={e => e.currentTarget.style.color = '#888'}
                title="Crear playlist"
              >
                <Plus size={16} />
              </button>
              <div onClick={() => setIsPlaylistsOpen(!isPlaylistsOpen)} style={{ cursor: 'pointer', display: 'flex' }}>
                {isPlaylistsOpen ? <ChevronUp size={15} style={{ color: '#888' }} /> : <ChevronDown size={15} style={{ color: '#888' }} />}
              </div>
            </div>
          </div>

          {isPlaylistsOpen && (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '1px', marginTop: '4px', paddingLeft: '8px' }}>
              <button
                onClick={() => setActiveTab('library')}
                style={{
                  display: 'flex', alignItems: 'center', gap: '12px',
                  width: '100%', padding: '8px 12px', borderRadius: '6px',
                  fontSize: '13px', fontWeight: 500, color: '#a0a0a0',
                  background: 'transparent', border: 'none', cursor: 'pointer', textAlign: 'left',
                }}
                onMouseEnter={e => e.currentTarget.style.color = '#fff'}
                onMouseLeave={e => e.currentTarget.style.color = '#a0a0a0'}
              >
                <LayoutGrid size={16} style={{ flexShrink: 0 }} />
                <span>Todas las playlists</span>
              </button>

              <button
                onClick={() => setActiveTab('library')}
                style={{
                  display: 'flex', alignItems: 'center', gap: '12px',
                  width: '100%', padding: '8px 12px', borderRadius: '6px',
                  fontSize: '13px', fontWeight: 500, color: '#a0a0a0',
                  background: 'transparent', border: 'none', cursor: 'pointer', textAlign: 'left',
                }}
                onMouseEnter={e => e.currentTarget.style.color = '#fff'}
                onMouseLeave={e => e.currentTarget.style.color = '#a0a0a0'}
              >
                <Star size={16} style={{ flexShrink: 0 }} />
                <span>Canciones favoritas</span>
              </button>

              {playlists.map(pl => (
                <button
                  key={pl.id}
                  onClick={() => setActiveTab('library')}
                  style={{
                    display: 'flex', alignItems: 'center', gap: '12px',
                    width: '100%', padding: '7px 12px', borderRadius: '6px',
                    fontSize: '13px', fontWeight: 500, color: '#888',
                    background: 'transparent', border: 'none', cursor: 'pointer', textAlign: 'left',
                    overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
                  }}
                  onMouseEnter={e => e.currentTarget.style.color = '#fff'}
                  onMouseLeave={e => e.currentTarget.style.color = '#888'}
                >
                  <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{pl.name}</span>
                </button>
              ))}
            </div>
          )}
        </div>
      ) : null}

      {/* 5. Bottom Controls (Collapse + User Profile) */}
      <div style={{ marginTop: 'auto', display: 'flex', flexDirection: 'column', gap: '8px', paddingTop: '16px' }}>
        {/* Contraer Toggle */}
        <button
          onClick={() => setIsCollapsed(!isCollapsed)}
          style={{
            display: 'flex', alignItems: 'center', gap: '10px',
            padding: '8px 12px', background: 'transparent', border: 'none',
            color: '#888', fontSize: '13px', fontWeight: 600,
            cursor: 'pointer', borderRadius: '6px', textAlign: 'left',
          }}
          onMouseEnter={e => e.currentTarget.style.color = '#fff'}
          onMouseLeave={e => e.currentTarget.style.color = '#888'}
        >
          {isCollapsed ? <ChevronsRight size={16} /> : <ChevronsLeft size={16} />}
          {!isCollapsed && <span>Contraer</span>}
        </button>

        {/* User Profile Bar */}
        <div
          onClick={() => isAuthenticated ? setActiveTab('account') : openAuthModal()}
          style={{
            display: 'flex', alignItems: 'center', gap: '12px',
            padding: '8px 10px', borderRadius: '8px',
            background: 'rgba(255,255,255,0.04)',
            cursor: 'pointer', transition: 'background 0.2s',
          }}
          onMouseEnter={e => e.currentTarget.style.background = 'rgba(255,255,255,0.08)'}
          onMouseLeave={e => e.currentTarget.style.background = 'rgba(255,255,255,0.04)'}
        >
          <div style={{
            width: '32px', height: '32px', borderRadius: '50%',
            overflow: 'hidden', flexShrink: 0, background: '#333',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            border: '1.5px solid rgba(255,255,255,0.2)',
          }}>
            <img
              src="https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100"
              alt={userName}
              style={{ width: '100%', height: '100%', objectFit: 'cover' }}
            />
          </div>
          {!isCollapsed && (
            <span style={{ fontSize: '13px', fontWeight: 600, color: '#fff', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
              {userName}
            </span>
          )}
        </div>
      </div>
    </aside>
  );
};
