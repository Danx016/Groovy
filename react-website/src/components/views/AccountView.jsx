import React from 'react';
import { User, Database, Server, ShieldCheck, LogOut, Mail, Calendar, RefreshCw, Heart, ListMusic } from 'lucide-react';
import { useAuth } from '../../context/AuthContext';
import { useLibrary } from '../../context/LibraryContext';

export const AccountView = () => {
  const { user, logout, openAuthModal, isAuthenticated } = useAuth();
  const { favorites, playlists, refreshLibrary, isLoading } = useLibrary();

  if (!isAuthenticated) {
    return (
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', minHeight: '60vh', padding: '32px', textAlign: 'center' }}>
        <div style={{ width: '72px', height: '72px', borderRadius: '16px', overflow: 'hidden', marginBottom: '20px' }}>
          <img src="./logo.png" alt="Groovy" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
        </div>
        <h2 style={{ fontSize: '22px', fontWeight: 700 }}>Mi Cuenta</h2>
        <p style={{ fontSize: '15px', color: '#B3B3B3', marginTop: '8px', maxWidth: '360px' }}>
          Inicia sesión para gestionar tu información personal, sincronización de la base de datos y estadísticas.
        </p>
        <button onClick={openAuthModal} style={{ marginTop: '24px', padding: '14px 28px', borderRadius: '12px', background: '#FA243C', color: '#fff', fontWeight: 700, fontSize: '15px' }}>
          Iniciar Sesión / Crear Cuenta
        </button>
      </div>
    );
  }

  const StatCard = ({ label, value, icon }) => (
    <div style={{ background: '#181818', borderRadius: '12px', padding: '16px', border: '0.5px solid #282828', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
      <div>
        <p style={{ fontSize: '13px', color: '#B3B3B3', marginBottom: '4px' }}>{label}</p>
        <p style={{ fontSize: '26px', fontWeight: 700, color: '#fff' }}>{value}</p>
      </div>
      {icon}
    </div>
  );

  const InfoRow = ({ label, value, accent }) => (
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '12px 16px', background: '#181818', borderRadius: '8px', border: '0.5px solid #282828' }}>
      <span style={{ fontSize: '14px', color: '#B3B3B3' }}>{label}</span>
      <span style={{ fontSize: '14px', fontWeight: 600, color: accent || '#fff', fontFamily: accent ? 'monospace' : 'inherit' }}>{value}</span>
    </div>
  );

  return (
    <div style={{ maxWidth: '640px', paddingBottom: '148px' }}>
      <h1 style={{ fontSize: '28px', fontWeight: 700, letterSpacing: '-0.5px', marginBottom: '24px' }}>Mi Cuenta</h1>

      {/* Profile card */}
      <div style={{ background: '#181818', borderRadius: '16px', border: '0.5px solid #282828', padding: '24px', display: 'flex', flexDirection: 'column', gap: '16px', marginBottom: '20px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
          <div style={{
            width: '64px', height: '64px', borderRadius: '50%', background: '#FA243C',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            fontSize: '26px', fontWeight: 700, color: '#fff', flexShrink: 0,
            boxShadow: '0 4px 16px rgba(250,36,60,0.4)',
          }}>
            {user?.name?.charAt(0).toUpperCase() || 'U'}
          </div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <h2 style={{ fontSize: '20px', fontWeight: 700, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{user?.name || 'Usuario'}</h2>
              <span style={{ background: 'rgba(52,199,89,0.15)', border: '0.5px solid rgba(52,199,89,0.3)', borderRadius: '20px', padding: '2px 8px', fontSize: '11px', fontWeight: 700, color: '#34C759', whiteSpace: 'nowrap' }}>
                ● Activo
              </span>
            </div>
            <p style={{ fontSize: '13px', color: '#B3B3B3', marginTop: '3px', display: 'flex', alignItems: 'center', gap: '5px' }}>
              <Mail size={13} /> {user?.email}
            </p>
            {user?.created_at && (
              <p style={{ fontSize: '12px', color: '#6B6B6B', marginTop: '2px', display: 'flex', alignItems: 'center', gap: '5px' }}>
                <Calendar size={12} /> Desde {new Date(user.created_at).toLocaleDateString()}
              </p>
            )}
          </div>
          <button
            onClick={logout}
            style={{ display: 'flex', alignItems: 'center', gap: '6px', padding: '8px 14px', borderRadius: '8px', background: 'rgba(255,59,48,0.1)', border: '0.5px solid rgba(255,59,48,0.2)', color: '#FF3B30', fontSize: '13px', fontWeight: 600, flexShrink: 0 }}
          >
            <LogOut size={15} /> Salir
          </button>
        </div>
      </div>

      {/* Stats */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px', marginBottom: '20px' }}>
        <StatCard label="Canciones Favoritas" value={favorites.length} icon={<Heart size={22} style={{ color: '#FF375F' }} />} />
        <StatCard label="Playlists Creadas" value={playlists.length} icon={<ListMusic size={22} style={{ color: '#FA243C' }} />} />
      </div>

      {/* MySQL Status */}
      <div style={{ background: '#181818', borderRadius: '16px', border: '0.5px solid #282828', padding: '20px' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '16px' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
            <Database size={20} style={{ color: '#FA243C' }} />
            <div>
              <h3 style={{ fontSize: '16px', fontWeight: 700 }}>Base de Datos MySQL</h3>
              <p style={{ fontSize: '12px', color: '#B3B3B3' }}>Servidor VPS propio</p>
            </div>
          </div>
          <button onClick={refreshLibrary} disabled={isLoading} style={{ display: 'flex', alignItems: 'center', gap: '5px', padding: '7px 12px', borderRadius: '8px', background: '#282828', border: '0.5px solid #404040', color: '#B3B3B3', fontSize: '12px', fontWeight: 600 }}>
            <RefreshCw size={13} className={isLoading ? 'animate-spin' : ''} /> Sincronizar
          </button>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
          <InfoRow label="Servidor Host:" value="157.137.233.119" accent="#34C759" />
          <InfoRow label="Motor de BD:" value="MySQL 8.0 Community" />
          <InfoRow label="Puerto API:" value=":4000 → Nginx /api" />
          <InfoRow label="Estado:" value="● Conectado y Sincronizado" accent="#34C759" />
        </div>
      </div>
    </div>
  );
};
