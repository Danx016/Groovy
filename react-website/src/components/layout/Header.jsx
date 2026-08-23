import React from 'react';
import { Search, Library, User, Settings } from 'lucide-react';
import { useAuth } from '../../context/AuthContext';
import { useLibrary } from '../../context/LibraryContext';

export const Header = ({ onSearchClick, activeTab, setActiveTab }) => {
  const { user, isAuthenticated, openAuthModal } = useAuth();
  const { favorites } = useLibrary();

  return (
    <header style={{
      position: 'sticky', top: 0, zIndex: 30,
      display: 'flex', height: '56px', width: '100%',
      alignItems: 'center', justifyContent: 'space-between',
      padding: '0 20px',
      background: 'rgba(0,0,0,0.92)',
      backdropFilter: 'blur(20px)',
      borderBottom: '0.5px solid #282828',
    }}>
      {/* Mobile brand */}
      <div className="mobile-brand" style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
        <div style={{ width: '32px', height: '32px', borderRadius: '8px', overflow: 'hidden' }}>
          <img src="./logo.png" alt="Groovy" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
        </div>
        <span style={{ fontWeight: 700, fontSize: '17px', letterSpacing: '-0.3px' }}>Groovy</span>
      </div>

      {/* Desktop search bar */}
      <div
        onClick={() => { setActiveTab('search'); if (onSearchClick) onSearchClick(); }}
        className="desktop-search"
        style={{
          flex: 1, maxWidth: '440px', margin: '0 24px',
          display: 'flex', alignItems: 'center', gap: '10px',
          background: '#282828', borderRadius: '8px', padding: '8px 14px',
          cursor: 'pointer', border: '0.5px solid #404040',
          transition: 'all 0.2s',
        }}
        onMouseEnter={e => e.currentTarget.style.background = '#333'}
        onMouseLeave={e => e.currentTarget.style.background = '#282828'}
      >
        <Search size={15} style={{ color: '#B3B3B3' }} />
        <span style={{ fontSize: '14px', color: '#6B6B6B' }}>Buscar canciones, artistas...</span>
      </div>

      {/* Right: status + user */}
      <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
        {/* Online indicator */}
        <div style={{
          display: 'flex', alignItems: 'center', gap: '6px',
          background: '#181818', border: '0.5px solid #404040',
          borderRadius: '20px', padding: '5px 10px',
          fontSize: '11px', color: '#B3B3B3',
        }}>
          <div style={{ position: 'relative', width: '8px', height: '8px' }}>
            <div className="animate-ping" style={{ position: 'absolute', inset: 0, borderRadius: '50%', background: '#34C759', opacity: 0.6 }} />
            <div style={{ position: 'absolute', inset: 0, borderRadius: '50%', background: '#34C759' }} />
          </div>
          <span style={{ fontWeight: 500 }}>MySQL Cloud</span>
        </div>

        {/* Account */}
        {isAuthenticated ? (
          <button
            onClick={() => setActiveTab('account')}
            style={{
              display: 'flex', alignItems: 'center', gap: '8px',
              background: activeTab === 'account' ? '#282828' : '#181818',
              border: `0.5px solid ${activeTab === 'account' ? '#FA243C' : '#404040'}`,
              borderRadius: '20px', padding: '5px 12px 5px 5px',
              color: '#fff', fontSize: '13px', fontWeight: 600,
              transition: 'all 0.2s',
            }}
          >
            <div style={{
              width: '26px', height: '26px', borderRadius: '50%', background: '#FA243C',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              fontWeight: 700, fontSize: '13px', color: '#fff',
            }}>
              {user?.name ? user.name.charAt(0).toUpperCase() : 'U'}
            </div>
            <span style={{ maxWidth: '90px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
              {user?.name || 'Mi Cuenta'}
            </span>
          </button>
        ) : (
          <button
            onClick={openAuthModal}
            style={{
              background: '#FA243C', color: '#fff', fontWeight: 700, fontSize: '13px',
              borderRadius: '20px', padding: '7px 16px', transition: 'all 0.2s',
            }}
            onMouseEnter={e => e.currentTarget.style.background = '#c41c2e'}
            onMouseLeave={e => e.currentTarget.style.background = '#FA243C'}
          >
            Iniciar Sesión
          </button>
        )}
      </div>
    </header>
  );
};
