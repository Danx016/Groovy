import React from 'react';
import { Home, Compass, Library, User, ShieldCheck } from 'lucide-react';
import { useAuth } from '../../context/AuthContext';

const tabs = [
  { id: 'home', label: 'Inicio', icon: Home },
  { id: 'search', label: 'Explorar', icon: Compass },
  { id: 'library', label: 'Biblioteca', icon: Library },
  { id: 'account', label: 'Cuenta', icon: User },
];

export const BottomNav = ({ activeTab, setActiveTab }) => {

  return (
    <nav style={{
      position: 'fixed', bottom: 0, left: 0, right: 0, zIndex: 40,
      display: 'flex', height: '64px', alignItems: 'center', justifyContent: 'space-around',
      background: '#1C1C1E',
      borderTop: '0.5px solid #282828',
      paddingBottom: 'env(safe-area-inset-bottom)',
    }} className="bottom-nav">
      {tabs.map(({ id, label, icon: Icon }) => {
        const isActive = activeTab === id;
        return (
          <button
            key={id}
            onClick={() => setActiveTab(id)}
            style={{
              display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '3px',
              padding: '6px 12px', flex: 1,
              color: isActive ? '#FA243C' : (id === 'admin' ? '#FF9500' : '#B3B3B3'),
              transition: 'color 0.15s',
              background: 'none', border: 'none', cursor: 'pointer',
            }}
          >
            <Icon size={22} strokeWidth={isActive ? 2.5 : 1.8} />
            <span style={{ fontSize: '10px', fontWeight: isActive ? 700 : 500 }}>{label}</span>
          </button>
        );
      })}
    </nav>
  );
};
