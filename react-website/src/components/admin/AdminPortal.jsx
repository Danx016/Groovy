import React, { useState, useEffect, useCallback, useRef } from 'react';
import {
  Users,
  Radio,
  Music,
  ListMusic,
  Heart,
  Laptop,
  Smartphone,
  Tablet,
  Globe,
  Search,
  RefreshCw,
  Edit2,
  Trash2,
  Ban,
  Check,
  Copy,
  Mail,
  X,
  Activity,
  ArrowLeft,
  Shield,
  ShieldCheck,
  AlertCircle,
  Database,
  Calendar,
  Clock,
  ChevronRight,
  ExternalLink,
  Info,
  Play,
  Volume2,
} from 'lucide-react';
import { adminApi } from '../../services/api';
import { useAuth } from '../../context/AuthContext';

export const AdminPortal = ({ onBackToPlayer }) => {
  const { user: currentUser, isAdmin, isAuthenticated, login, logout } = useAuth();

  // Navigation tab: 'live' | 'users' | 'sessions' | 'metrics'
  const [activeTab, setActiveTab] = useState('users');

  // Login form state
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loginError, setLoginError] = useState(null);
  const [isLoggingIn, setIsLoggingIn] = useState(false);

  // Data state
  const [metrics, setMetrics] = useState(null);
  const [users, setUsers] = useState([]);
  const [sessions, setSessions] = useState([]);
  const [liveListeners, setLiveListeners] = useState([]);
  const [connectedUsers, setConnectedUsers] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [roleFilter, setRoleFilter] = useState('all');
  const [statusFilter, setStatusFilter] = useState('all');
  const [platformFilter, setPlatformFilter] = useState('all'); // 'all' | 'mobile' | 'windows' | 'web'

  // Modals / Inspector
  const [selectedUser, setSelectedUser] = useState(null);
  const [isLoadingDetail, setIsLoadingDetail] = useState(false);
  const [editingUser, setEditingUser] = useState(null);
  const [editFormData, setEditFormData] = useState({ name: '', email: '', role: 'user', password: '' });
  const [userToDelete, setUserToDelete] = useState(null);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [actionMessage, setActionMessage] = useState(null);
  const [copiedIp, setCopiedIp] = useState(null);

  const isAuthorized = isAdmin || currentUser?.email === 'danilorodelo355@gmail.com';

  const copyToClipboard = (text) => {
    if (!text) return;
    navigator.clipboard?.writeText(text);
    setCopiedIp(text);
    setTimeout(() => setCopiedIp(null), 2000);
  };

  const handleLoginSubmit = async (e) => {
    e.preventDefault();
    setLoginError(null);
    setIsLoggingIn(true);
    try {
      await login(email.trim(), password);
    } catch (err) {
      setLoginError(err.message || 'Error al iniciar sesión.');
    } finally {
      setIsLoggingIn(false);
    }
  };

  const fetchLivePlayback = useCallback(async () => {
    if (!isAuthorized) return;
    try {
      const res = await adminApi.getLivePlayback().catch(() => ({ listeners: [], connectedUsers: [] }));
      if (res?.listeners) setLiveListeners(res.listeners);
      if (res?.connectedUsers) setConnectedUsers(res.connectedUsers);
    } catch (e) {
      console.warn('Error fetching live playback:', e);
    }
  }, [isAuthorized]);

  const fetchData = useCallback(async () => {
    if (!isAuthorized) return;
    setIsLoading(true);
    setActionMessage(null);
    try {
      const [metricsRes, usersRes, sessionsRes, liveRes] = await Promise.all([
        adminApi.getMetrics().catch(() => ({ metrics: null })),
        adminApi.getUsers({ q: searchQuery, role: roleFilter, status: statusFilter }).catch(() => ({ users: [] })),
        adminApi.getSessions(100).catch(() => ({ sessions: [] })),
        adminApi.getLivePlayback().catch(() => ({ listeners: [], connectedUsers: [] })),
      ]);

      if (metricsRes?.metrics) setMetrics(metricsRes.metrics);
      if (usersRes?.users) setUsers(usersRes.users);
      if (sessionsRes?.sessions) setSessions(sessionsRes.sessions);
      if (liveRes?.listeners) setLiveListeners(liveRes.listeners);
      if (liveRes?.connectedUsers) setConnectedUsers(liveRes.connectedUsers);
    } catch (err) {
      console.error('Error fetching admin data:', err);
      setActionMessage({ type: 'error', text: 'Error al conectar con la base de datos: ' + err.message });
    } finally {
      setIsLoading(false);
    }
  }, [isAuthorized, searchQuery, roleFilter, statusFilter]);

  useEffect(() => {
    if (isAuthorized) {
      fetchData();
      // Auto-refresh live presence every 10 seconds
      const interval = setInterval(() => {
        fetchLivePlayback();
      }, 10000);
      return () => clearInterval(interval);
    }
  }, [isAuthorized, fetchData, fetchLivePlayback]);

  const handleOpenUserDetail = async (userId) => {
    setIsLoadingDetail(true);
    setSelectedUser(null);
    try {
      const data = await adminApi.getUserDetails(userId);
      setSelectedUser(data);
    } catch (err) {
      alert('Error al cargar información: ' + err.message);
    } finally {
      setIsLoadingDetail(false);
    }
  };

  const handleOpenEdit = (user) => {
    setEditingUser(user);
    setEditFormData({
      name: user.name || '',
      email: user.email || '',
      role: user.role || 'user',
      password: '',
    });
  };

  const handleSaveEdit = async (e) => {
    e.preventDefault();
    if (!editingUser) return;
    setIsSubmitting(true);
    try {
      const payload = {
        name: editFormData.name.trim(),
        email: editFormData.email.trim(),
        role: editFormData.role,
      };
      if (editFormData.password.trim()) {
        payload.password = editFormData.password.trim();
      }
      await adminApi.updateUser(editingUser.id, payload);
      setEditingUser(null);
      setActionMessage({ type: 'success', text: 'Usuario actualizado exitosamente.' });
      fetchData();
    } catch (err) {
      setActionMessage({ type: 'error', text: err.message });
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleToggleBan = async (user) => {
    const nextStatus = !user.isBanned;
    const confirmMsg = nextStatus
      ? `¿Suspender el acceso a la cuenta de ${user.name}?`
      : `¿Reactivar la cuenta de ${user.name}?`;
    if (!window.confirm(confirmMsg)) return;

    try {
      await adminApi.toggleBanUser(user.id, nextStatus);
      fetchData();
      if (selectedUser?.user?.id === user.id) {
        handleOpenUserDetail(user.id);
      }
    } catch (err) {
      alert('Error: ' + err.message);
    }
  };

  const handleConfirmDelete = async () => {
    if (!userToDelete) return;
    setIsSubmitting(true);
    try {
      await adminApi.deleteUser(userToDelete.id);
      setUserToDelete(null);
      if (selectedUser?.user?.id === userToDelete.id) {
        setSelectedUser(null);
      }
      setActionMessage({ type: 'success', text: `Usuario ${userToDelete.name} eliminado permanentemente.` });
      fetchData();
    } catch (err) {
      alert('Error al eliminar: ' + err.message);
    } finally {
      setIsSubmitting(false);
    }
  };

  const renderCountryFlag = (country = '', countryCode = '') => {
    let code = (countryCode || '').toLowerCase();
    if (!code || code === 'xx') {
      const match = (country || '').match(/\b([A-Za-z]{2})\b/);
      if (match) code = match[1].toLowerCase();
    }
    if (code && code.length === 2 && code !== 'xx' && code !== 'la') {
      return (
        <img
          src={`https://flagcdn.com/20x15/${code}.png`}
          alt={code.toUpperCase()}
          style={{ width: '18px', height: '13px', borderRadius: '2px', objectFit: 'cover', display: 'inline-block', verticalAlign: 'middle', marginRight: '6px' }}
          onError={(e) => { e.currentTarget.style.display = 'none'; }}
        />
      );
    }
    return <span style={{ marginRight: '5px' }}>🌐</span>;
  };

  const formatCountryName = (country = '') => {
    if (!country) return 'Desconocido';
    return country
      .replace(/^[\u{1F1E6}-\u{1F1FF}]{2}\s*/u, '')
      .replace(/^🌐\s*/, '')
      .replace(/^[a-zA-Z]{2}\s+/i, '')
      .trim() || country;
  };

  const getDeviceIcon = (os = '', browser = '', deviceType = '') => {
    const str = `${os} ${browser} ${deviceType}`.toLowerCase();
    if (str.includes('android')) {
      return <Smartphone size={16} style={{ color: '#34C759' }} />;
    }
    if (str.includes('ios') || str.includes('iphone')) {
      return <Smartphone size={16} style={{ color: '#007AFF' }} />;
    }
    if (str.includes('ipad') || str.includes('tablet')) {
      return <Tablet size={16} style={{ color: '#007AFF' }} />;
    }
    if (str.includes('windows')) {
      return <Laptop size={16} style={{ color: '#00A4EF' }} />;
    }
    if (str.includes('mac') || str.includes('darwin')) {
      return <Laptop size={16} style={{ color: '#fff' }} />;
    }
    return <Globe size={16} style={{ color: '#B3B3B3' }} />;
  };

  const isWebClient = (platform = '', device = '', browser = '') => {
    const str = `${platform || ''} ${device || ''} ${browser || ''}`.toLowerCase().trim();
    if (!str) return false;
    if (str === 'web' || str.startsWith('web ') || str.includes('web player') || str.includes('web browser') || str.includes('web client')) {
      return true;
    }
    return false;
  };

  const isNativeApp = (platform = '', device = '', browser = '') => {
    if (isWebClient(platform, device, browser)) return false;
    const str = `${platform || ''} ${device || ''} ${browser || ''}`.toLowerCase();
    return (
      str.includes('android') ||
      str.includes('windows') ||
      str.includes('ios') ||
      str.includes('iphone') ||
      str.includes('mac') ||
      str.includes('linux') ||
      str.includes('groovy') ||
      str.includes('flutter') ||
      (!str.includes('web') && !str.includes('browser'))
    );
  };

  const formatListeningTime = (totalSeconds = 0) => {
    const sec = parseInt(totalSeconds, 10) || 0;
    if (sec < 60) return `${sec} seg`;
    const hours = Math.floor(sec / 3600);
    const minutes = Math.floor((sec % 3600) / 60);
    if (hours > 0) {
      return `${hours} h ${minutes} min`;
    }
    return `${minutes} min`;
  };

  const formatSessionDuration = (seconds = 0) => {
    const sec = parseInt(seconds, 10) || 0;
    if (sec < 60) return '< 1 min';
    const hours = Math.floor(sec / 3600);
    const minutes = Math.floor((sec % 3600) / 60);
    if (hours > 0) return `${hours} h ${minutes} min`;
    return `${minutes} min`;
  };

  const formatDateTime = (dateStr) => {
    if (!dateStr) return '—';
    try {
      const d = new Date(dateStr);
      if (isNaN(d.getTime())) return '—';
      return d.toLocaleString('es-ES', {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit',
        hour12: true,
      });
    } catch {
      return '—';
    }
  };

  // Auth Guard Screen (matches Groovy's AccountView / AuthModal)
  if (!isAuthenticated || !isAuthorized) {
    return (
      <div style={{
        minHeight: '100vh',
        background: '#000000',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        padding: '24px',
      }}>
        <div style={{
          width: '100%',
          maxWidth: '400px',
          background: '#181818',
          border: '0.5px solid #282828',
          borderRadius: '16px',
          padding: '36px 30px',
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          textAlign: 'center',
          boxShadow: '0 16px 40px rgba(0,0,0,0.6)',
        }}>
          <div style={{ width: '64px', height: '64px', borderRadius: '14px', overflow: 'hidden', marginBottom: '20px' }}>
            <img src="./logo.png" alt="Groovy" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
          </div>

          <h1 style={{ fontSize: '24px', fontWeight: 700, letterSpacing: '-0.4px', color: '#fff' }}>
            Panel de Administración
          </h1>
          <p style={{ fontSize: '14px', color: '#B3B3B3', marginTop: '8px', marginBottom: '24px', lineHeight: 1.4 }}>
            Inicia sesión con tu cuenta de administrador de Groovy para acceder a la gestión y telemetría.
          </p>

          {loginError && (
            <div style={{
              width: '100%', padding: '10px 14px', borderRadius: '8px',
              background: 'rgba(250,36,60,0.12)', border: '0.5px solid rgba(250,36,60,0.3)',
              color: '#FA243C', fontSize: '13px', marginBottom: '16px', textAlign: 'left',
              display: 'flex', alignItems: 'center', gap: '8px',
            }}>
              <AlertCircle size={15} style={{ flexShrink: 0 }} />
              <span>{loginError}</span>
            </div>
          )}

          <form onSubmit={handleLoginSubmit} style={{ width: '100%', display: 'flex', flexDirection: 'column', gap: '14px' }}>
            <div style={{ textAlign: 'left' }}>
              <label style={{ display: 'block', fontSize: '12px', color: '#B3B3B3', marginBottom: '6px', fontWeight: 500 }}>
                Correo electrónico
              </label>
              <input
                type="email"
                required
                placeholder="nombre@ejemplo.com"
                value={email}
                onChange={e => setEmail(e.target.value)}
                style={{
                  width: '100%', background: '#282828', border: '0.5px solid #404040',
                  borderRadius: '8px', padding: '12px 14px', color: '#fff', fontSize: '14px',
                  outline: 'none',
                }}
              />
            </div>

            <div style={{ textAlign: 'left' }}>
              <label style={{ display: 'block', fontSize: '12px', color: '#B3B3B3', marginBottom: '6px', fontWeight: 500 }}>
                Contraseña
              </label>
              <input
                type="password"
                required
                placeholder="••••••••"
                value={password}
                onChange={e => setPassword(e.target.value)}
                style={{
                  width: '100%', background: '#282828', border: '0.5px solid #404040',
                  borderRadius: '8px', padding: '12px 14px', color: '#fff', fontSize: '14px',
                  outline: 'none',
                }}
              />
            </div>

            <button
              type="submit"
              disabled={isLoggingIn}
              style={{
                marginTop: '10px', width: '100%', padding: '14px', borderRadius: '12px',
                background: '#FA243C', color: '#fff', fontWeight: 700, fontSize: '15px',
                cursor: 'pointer', transition: 'background 0.15s',
              }}
              onMouseEnter={e => e.currentTarget.style.background = '#c41c2e'}
              onMouseLeave={e => e.currentTarget.style.background = '#FA243C'}
            >
              {isLoggingIn ? 'Verificando credenciales...' : 'Iniciar Sesión'}
            </button>
          </form>

          {onBackToPlayer && (
            <button
              onClick={onBackToPlayer}
              style={{
                marginTop: '24px', display: 'flex', alignItems: 'center', gap: '6px',
                color: '#B3B3B3', fontSize: '13px', cursor: 'pointer',
              }}
              onMouseEnter={e => e.currentTarget.style.color = '#fff'}
              onMouseLeave={e => e.currentTarget.style.color = '#B3B3B3'}
            >
              <ArrowLeft size={14} /> Volver a Groovy Música
            </button>
          )}
        </div>
      </div>
    );
  }

  const activeLiveCount = liveListeners.filter(l => l.isPlaying).length;
  const activeConnectedCount = connectedUsers.length;
  const totalOnlineAppCount = activeLiveCount + connectedUsers.filter(u => !liveListeners.some(l => l.isPlaying && l.userId === u.userId)).length;

  return (
    <div style={{ display: 'flex', minHeight: '100vh', background: '#000000', color: '#ffffff' }}>
      {/* 1. GROOVY NATIVE SIDEBAR (Matches Sidebar.jsx) */}
      <aside style={{
        width: '240px',
        flexShrink: 0,
        background: '#000000',
        borderRight: '0.5px solid #282828',
        height: '100vh',
        position: 'sticky',
        top: 0,
        display: 'flex',
        flexDirection: 'column',
        padding: '16px 8px',
        boxSizing: 'border-box',
        zIndex: 20,
      }}>
        {/* Brand */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px', padding: '8px 12px', marginBottom: '16px' }}>
          <div style={{ width: '36px', height: '36px', borderRadius: '8px', overflow: 'hidden', flexShrink: 0 }}>
            <img src="./logo.png" alt="Groovy" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
          </div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
              <h1 style={{ fontSize: '17px', fontWeight: 700, color: '#fff', letterSpacing: '-0.3px' }}>Groovy</h1>
              <span style={{ fontSize: '10px', color: '#FA243C', fontWeight: 700, background: 'rgba(250,36,60,0.15)', padding: '1px 6px', borderRadius: '10px' }}>
                ADMIN
              </span>
            </div>
            <p style={{ fontSize: '11px', color: '#B3B3B3', marginTop: '1px' }}>Telemetría en Vivo</p>
          </div>
        </div>

        {/* Section Label */}
        <div style={{ padding: '4px 12px 8px' }}>
          <span style={{ fontSize: '11px', fontWeight: 700, letterSpacing: '0.06em', color: '#6B6B6B', textTransform: 'uppercase' }}>
            Panel de Control
          </span>
        </div>

        {/* Navigation Items */}
        <nav style={{ display: 'flex', flexDirection: 'column', gap: '2px', marginBottom: '16px' }}>
          {/* Live Now Listening Tab */}
          <button
            onClick={() => setActiveTab('live')}
            style={{
              display: 'flex', alignItems: 'center', justifyContent: 'space-between',
              width: '100%', padding: '10px 12px', borderRadius: '8px',
              fontSize: '14px', fontWeight: activeTab === 'live' ? 700 : 500,
              color: activeTab === 'live' ? '#fff' : '#B3B3B3',
              background: activeTab === 'live' ? '#282828' : 'transparent',
              textAlign: 'left', transition: 'all 0.15s',
            }}
            onMouseEnter={e => { if (activeTab !== 'live') e.currentTarget.style.color = '#fff'; }}
            onMouseLeave={e => { if (activeTab !== 'live') e.currentTarget.style.color = '#B3B3B3'; }}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
              <Radio size={19} style={{ color: activeTab === 'live' ? '#34C759' : '#34C759', flexShrink: 0 }} />
              <span>Escuchando Ahora</span>
            </div>
            {totalOnlineAppCount > 0 ? (
              <span style={{
                fontSize: '11px', fontWeight: 700, padding: '1px 7px', borderRadius: '10px',
                background: '#34C759', color: '#000',
              }}>
                {totalOnlineAppCount} EN VIVO
              </span>
            ) : (
              <span style={{ fontSize: '11px', color: '#6B6B6B' }}>0</span>
            )}
          </button>

          <button
            onClick={() => setActiveTab('users')}
            style={{
              display: 'flex', alignItems: 'center', justifyContent: 'space-between',
              width: '100%', padding: '10px 12px', borderRadius: '8px',
              fontSize: '14px', fontWeight: activeTab === 'users' ? 700 : 500,
              color: activeTab === 'users' ? '#fff' : '#B3B3B3',
              background: activeTab === 'users' ? '#282828' : 'transparent',
              textAlign: 'left', transition: 'all 0.15s',
            }}
            onMouseEnter={e => { if (activeTab !== 'users') e.currentTarget.style.color = '#fff'; }}
            onMouseLeave={e => { if (activeTab !== 'users') e.currentTarget.style.color = '#B3B3B3'; }}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
              <Users size={19} style={{ color: activeTab === 'users' ? '#FA243C' : '#B3B3B3', flexShrink: 0 }} />
              <span>Usuarios</span>
            </div>
            <span style={{
              fontSize: '11px', fontWeight: 600, padding: '1px 7px', borderRadius: '10px',
              background: activeTab === 'users' ? '#FA243C' : '#181818',
              color: '#fff',
            }}>
              {users.length}
            </span>
          </button>

          <button
            onClick={() => setActiveTab('sessions')}
            style={{
              display: 'flex', alignItems: 'center', justifyContent: 'space-between',
              width: '100%', padding: '10px 12px', borderRadius: '8px',
              fontSize: '14px', fontWeight: activeTab === 'sessions' ? 700 : 500,
              color: activeTab === 'sessions' ? '#fff' : '#B3B3B3',
              background: activeTab === 'sessions' ? '#282828' : 'transparent',
              textAlign: 'left', transition: 'all 0.15s',
            }}
            onMouseEnter={e => { if (activeTab !== 'sessions') e.currentTarget.style.color = '#fff'; }}
            onMouseLeave={e => { if (activeTab !== 'sessions') e.currentTarget.style.color = '#B3B3B3'; }}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
              <Activity size={19} style={{ color: activeTab === 'sessions' ? '#FA243C' : '#B3B3B3', flexShrink: 0 }} />
              <span>Dispositivos & IPs</span>
            </div>
            <span style={{
              fontSize: '11px', fontWeight: 600, padding: '1px 7px', borderRadius: '10px',
              background: activeTab === 'sessions' ? '#FA243C' : '#181818',
              color: '#fff',
            }}>
              {sessions.length}
            </span>
          </button>

          <button
            onClick={() => setActiveTab('metrics')}
            style={{
              display: 'flex', alignItems: 'center', gap: '12px',
              width: '100%', padding: '10px 12px', borderRadius: '8px',
              fontSize: '14px', fontWeight: activeTab === 'metrics' ? 700 : 500,
              color: activeTab === 'metrics' ? '#fff' : '#B3B3B3',
              background: activeTab === 'metrics' ? '#282828' : 'transparent',
              textAlign: 'left', transition: 'all 0.15s',
            }}
            onMouseEnter={e => { if (activeTab !== 'metrics') e.currentTarget.style.color = '#fff'; }}
            onMouseLeave={e => { if (activeTab !== 'metrics') e.currentTarget.style.color = '#B3B3B3'; }}
          >
            <Music size={19} style={{ color: activeTab === 'metrics' ? '#FA243C' : '#B3B3B3', flexShrink: 0 }} />
            <span>Top Canciones</span>
          </button>
        </nav>

        {/* Divider */}
        <div style={{ height: '0.5px', background: '#282828', margin: '0 12px 16px' }} />

        {/* Return to Music Player action */}
        <div style={{ padding: '0 8px', marginBottom: 'auto' }}>
          <a
            href="/"
            style={{
              display: 'flex', alignItems: 'center', gap: '10px',
              padding: '9px 12px', borderRadius: '8px', fontSize: '13px',
              color: '#B3B3B3', textDecoration: 'none', transition: 'all 0.15s',
            }}
            onMouseEnter={e => { e.currentTarget.style.color = '#fff'; e.currentTarget.style.background = '#181818'; }}
            onMouseLeave={e => { e.currentTarget.style.color = '#B3B3B3'; e.currentTarget.style.background = 'transparent'; }}
          >
            <ArrowLeft size={16} />
            <span>Abrir Reproductor Web</span>
          </a>
        </div>

        {/* Current Admin User Footprint */}
        <div style={{
          padding: '12px', borderRadius: '10px', background: '#181818',
          border: '0.5px solid #282828',
        }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '10px' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '10px', minWidth: 0 }}>
              <div style={{
                width: '32px', height: '32px', borderRadius: '50%', background: '#FA243C',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                fontSize: '13px', fontWeight: 700, color: '#fff', flexShrink: 0,
              }}>
                {currentUser?.name?.charAt(0).toUpperCase() || 'A'}
              </div>
              <div style={{ minWidth: 0 }}>
                <p style={{ fontSize: '13px', fontWeight: 600, color: '#fff', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                  {currentUser?.name || 'Administrador'}
                </p>
                <p style={{ fontSize: '11px', color: '#B3B3B3', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                  {currentUser?.email || ''}
                </p>
              </div>
            </div>
            <button
              onClick={logout}
              title="Cerrar sesión"
              style={{ color: '#B3B3B3', padding: '4px', flexShrink: 0 }}
              onMouseEnter={e => e.currentTarget.style.color = '#FF3B30'}
              onMouseLeave={e => e.currentTarget.style.color = '#B3B3B3'}
            >
              <X size={16} />
            </button>
          </div>
        </div>
      </aside>

      {/* 2. MAIN CONTENT AREA */}
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', minWidth: 0, height: '100vh', overflowY: 'auto' }}>
        {/* Top Header */}
        <header style={{
          height: '56px',
          background: 'rgba(0,0,0,0.92)',
          backdropFilter: 'blur(20px)',
          borderBottom: '0.5px solid #282828',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          padding: '0 32px',
          position: 'sticky',
          top: 0,
          zIndex: 10,
        }}>
          {/* Search bar */}
          <div style={{
            flex: 1, maxWidth: '420px',
            display: 'flex', alignItems: 'center', gap: '10px',
            background: '#282828', borderRadius: '8px', padding: '8px 14px',
          }}>
            <Search size={16} style={{ color: '#6B6B6B', flexShrink: 0 }} />
            <input
              type="text"
              placeholder="Buscar por usuario, IP, correo o dispositivo..."
              value={searchQuery}
              onChange={e => setSearchQuery(e.target.value)}
              style={{
                background: 'transparent', border: 'none', color: '#fff', fontSize: '13px',
                width: '100%', outline: 'none',
              }}
            />
            {searchQuery && (
              <button onClick={() => setSearchQuery('')} style={{ color: '#B3B3B3', padding: '2px' }}>
                <X size={14} />
              </button>
            )}
          </div>

          {/* Right Header items */}
          <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
            {/* Live Streaming Pill */}
            {totalOnlineAppCount > 0 && (
              <div style={{
                display: 'flex', alignItems: 'center', gap: '6px',
                background: 'rgba(52,199,89,0.15)', border: '0.5px solid rgba(52,199,89,0.4)',
                borderRadius: '20px', padding: '5px 12px',
                fontSize: '12px', color: '#34C759', fontWeight: 600,
              }}>
                <div style={{ display: 'flex', alignItems: 'flex-end', gap: '2px', height: '12px' }}>
                  <div className="eq-bar" style={{ background: '#34C759', width: '2px' }} />
                  <div className="eq-bar" style={{ background: '#34C759', width: '2px' }} />
                  <div className="eq-bar" style={{ background: '#34C759', width: '2px' }} />
                </div>
                <span>{totalOnlineAppCount} en la App en Vivo</span>
              </div>
            )}

            {/* Live VPS MySQL Connection Status pill */}
            <div style={{
              display: 'flex', alignItems: 'center', gap: '6px',
              background: '#181818', border: '0.5px solid #404040',
              borderRadius: '20px', padding: '5px 12px',
              fontSize: '12px', color: '#B3B3B3',
            }}>
              <span style={{ width: '7px', height: '7px', borderRadius: '50%', background: '#34C759', display: 'inline-block' }} />
              <span>VPS MySQL Online</span>
            </div>

            {/* Refresh Button */}
            <button
              onClick={fetchData}
              disabled={isLoading}
              title="Actualizar datos"
              style={{
                display: 'flex', alignItems: 'center', gap: '6px',
                background: '#282828', border: '0.5px solid #404040',
                borderRadius: '8px', padding: '7px 14px',
                color: '#fff', fontSize: '13px', fontWeight: 600,
                cursor: 'pointer', transition: 'all 0.15s',
              }}
              onMouseEnter={e => e.currentTarget.style.background = '#333'}
              onMouseLeave={e => e.currentTarget.style.background = '#282828'}
            >
              <RefreshCw size={13} className={isLoading ? 'animate-spin' : ''} />
              <span>{isLoading ? 'Cargando...' : 'Actualizar'}</span>
            </button>
          </div>
        </header>

        {/* Content Body */}
        <main style={{ padding: '32px', maxWidth: '1240px', width: '100%', margin: '0 auto', boxSizing: 'border-box' }}>
          {/* Header Title Section */}
          <div style={{ marginBottom: '24px' }}>
            <h1 style={{ fontSize: '28px', fontWeight: 700, letterSpacing: '-0.5px', marginBottom: '6px' }}>
              {activeTab === 'live' && 'En Vivo: Telemetría y Streaming en Tiempo Real'}
              {activeTab === 'users' && 'Usuarios y Telemetría de Dispositivos'}
              {activeTab === 'sessions' && 'Auditoría de Inicios de Sesión e IPs'}
              {activeTab === 'metrics' && 'Top Canciones en Streaming'}
            </h1>
            <p style={{ fontSize: '14px', color: '#B3B3B3' }}>
              Monitoreo en tiempo real de usuarios, dispositivos Windows / Android, IPs y tiempos de escucha.
            </p>
          </div>

          {/* Action Message Banner */}
          {actionMessage && (
            <div style={{
              padding: '12px 18px', borderRadius: '10px', marginBottom: '24px',
              background: actionMessage.type === 'success' ? 'rgba(52,199,89,0.12)' : 'rgba(255,59,48,0.12)',
              border: `0.5px solid ${actionMessage.type === 'success' ? 'rgba(52,199,89,0.3)' : 'rgba(255,59,48,0.3)'}`,
              color: actionMessage.type === 'success' ? '#34C759' : '#FF3B30',
              fontSize: '13px', display: 'flex', alignItems: 'center', justifyContent: 'space-between',
            }}>
              <span>{actionMessage.text}</span>
              <button onClick={() => setActionMessage(null)} style={{ color: 'inherit', padding: '2px' }}>
                <X size={14} />
              </button>
            </div>
          )}

          {/* GROOVY METRICS STRIP (Expanded with Listening Time & Live Listeners) */}
          <div style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fit, minmax(210px, 1fr))',
            gap: '12px',
            marginBottom: '28px',
          }}>
            <div style={{
              background: '#181818', borderRadius: '12px', border: '0.5px solid #282828',
              padding: '18px 20px',
            }}>
              <span style={{ fontSize: '12px', color: '#B3B3B3', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.04em' }}>
                Usuarios Registrados
              </span>
              <div style={{ fontSize: '28px', fontWeight: 700, color: '#fff', marginTop: '6px' }}>
                {metrics?.totalUsers ?? users.length}
              </div>
              <p style={{ fontSize: '12px', color: '#34C759', marginTop: '4px', display: 'flex', alignItems: 'center', gap: '4px' }}>
                ● {metrics?.activeToday ?? 0} activos hoy
              </p>
            </div>

            <div style={{
              background: '#181818', borderRadius: '12px', border: '0.5px solid #282828',
              padding: '18px 20px',
            }}>
              <span style={{ fontSize: '12px', color: '#B3B3B3', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.04em' }}>
                En Vivo en la App
              </span>
              <div style={{ fontSize: '28px', fontWeight: 700, color: totalOnlineAppCount > 0 ? '#34C759' : '#fff', marginTop: '6px' }}>
                {totalOnlineAppCount}
              </div>
              <p style={{ fontSize: '12px', color: '#B3B3B3', marginTop: '4px' }}>
                {activeLiveCount > 0 ? `${activeLiveCount} reproduciendo música` : totalOnlineAppCount > 0 ? 'Conectados en la app' : 'Sin usuarios activos'}
              </p>
            </div>

            <div style={{
              background: '#181818', borderRadius: '12px', border: '0.5px solid #282828',
              padding: '18px 20px',
            }}>
              <span style={{ fontSize: '12px', color: '#B3B3B3', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.04em' }}>
                Tiempo Total de Música
              </span>
              <div style={{ fontSize: '24px', fontWeight: 700, color: '#fff', marginTop: '6px' }}>
                {formatListeningTime(metrics?.totalListenSeconds ?? 0)}
              </div>
              <p style={{ fontSize: '12px', color: '#B3B3B3', marginTop: '4px' }}>
                Reproducido por los usuarios
              </p>
            </div>

            <div style={{
              background: '#181818', borderRadius: '12px', border: '0.5px solid #282828',
              padding: '18px 20px',
            }}>
              <span style={{ fontSize: '12px', color: '#B3B3B3', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.04em' }}>
                Canciones Reproducidas
              </span>
              <div style={{ fontSize: '28px', fontWeight: 700, color: '#fff', marginTop: '6px' }}>
                {metrics?.totalPlays ?? 0}
              </div>
              <p style={{ fontSize: '12px', color: '#B3B3B3', marginTop: '4px' }}>
                Historial de reproducciones en nube
              </p>
            </div>
          </div>

          {/* TAB 0: LIVE STREAMING & ESCUCHANDO AHORA (Only visible when activeTab === 'live') */}
          {activeTab === 'live' && (() => {
            const activeLiveListeners = liveListeners.filter(l => l.isPlaying);
            const playingUserIds = new Set(activeLiveListeners.map(l => l.userId));
            const browsingUsers = connectedUsers.filter(u => !playingUserIds.has(u.userId));
            const hasAnyLive = activeLiveListeners.length > 0 || browsingUsers.length > 0;

            return (
              <div style={{
                background: '#181818',
                borderRadius: '16px',
                border: '0.5px solid #282828',
                padding: '24px',
                marginBottom: '28px',
              }}>
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '16px', flexWrap: 'wrap', gap: '10px' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                    <div style={{ display: 'flex', alignItems: 'flex-end', gap: '2px', height: '16px' }}>
                      <div className="eq-bar" style={{ width: '3px' }} />
                      <div className="eq-bar" style={{ width: '3px' }} />
                      <div className="eq-bar" style={{ width: '3px' }} />
                      <div className="eq-bar" style={{ width: '3px' }} />
                    </div>
                    <h3 style={{ fontSize: '17px', fontWeight: 700, letterSpacing: '-0.3px' }}>
                      En Vivo: Actividad en Tiempo Real
                    </h3>
                  </div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                    <span style={{ fontSize: '11px', background: 'rgba(52,199,89,0.15)', color: '#34C759', padding: '3px 9px', borderRadius: '12px', fontWeight: 700 }}>
                      🟢 Actualización en tiempo real (cada 10s)
                    </span>
                  </div>
                </div>

                {/* Sub-section 1: Streaming Audio */}
                {activeLiveListeners.length > 0 && (
                  <div style={{ marginBottom: browsingUsers.length > 0 ? '24px' : '0' }}>
                    <h4 style={{ fontSize: '12px', fontWeight: 700, color: '#34C759', textTransform: 'uppercase', letterSpacing: '0.06em', marginBottom: '10px', display: 'flex', alignItems: 'center', gap: '6px' }}>
                      <span style={{ width: '8px', height: '8px', borderRadius: '50%', background: '#34C759', display: 'inline-block' }} />
                      Reproduciendo Música Ahora ({activeLiveListeners.length})
                    </h4>
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
                      {activeLiveListeners.map((item, idx) => (
                        <div
                          key={`${item.userId}_${item.platform}_${item.deviceModel || item.deviceName || idx}`}
                          style={{
                            display: 'flex', alignItems: 'center', justifyContent: 'space-between',
                            background: '#202020', borderRadius: '12px', padding: '14px 18px',
                            border: '0.5px solid rgba(52,199,89,0.3)',
                          }}
                        >
                          {/* User Profile */}
                          <div style={{ display: 'flex', alignItems: 'center', gap: '14px', minWidth: '220px' }}>
                            <div style={{
                              width: '44px', height: '44px', borderRadius: '50%', background: '#FA243C',
                              display: 'flex', alignItems: 'center', justifyContent: 'center',
                              fontSize: '16px', fontWeight: 700, color: '#fff',
                            }}>
                              {item.userName?.charAt(0).toUpperCase() || 'U'}
                            </div>
                            <div>
                              <p style={{ fontSize: '15px', fontWeight: 700, color: '#fff' }}>{item.userName}</p>
                              <p style={{ fontSize: '12px', color: '#B3B3B3' }}>{item.userEmail}</p>
                            </div>
                          </div>

                          {/* Song Playing */}
                          <div style={{ display: 'flex', alignItems: 'center', gap: '12px', flex: 1, margin: '0 24px', minWidth: 0 }}>
                            {item.coverArt ? (
                              <img src={item.coverArt} alt={item.title} style={{ width: '44px', height: '44px', borderRadius: '8px', objectFit: 'cover' }} />
                            ) : (
                              <div style={{ width: '44px', height: '44px', borderRadius: '8px', background: '#282828', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                                <Music size={20} style={{ color: '#FA243C' }} />
                              </div>
                            )}
                            <div style={{ minWidth: 0 }}>
                              <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                                <p style={{ fontSize: '14px', fontWeight: 600, color: '#fff', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                                  {item.title}
                                </p>
                                <span style={{ fontSize: '10px', color: '#34C759', fontWeight: 700, background: 'rgba(52,199,89,0.15)', padding: '1px 6px', borderRadius: '4px' }}>
                                  EN REPRODUCCIÓN
                                </span>
                              </div>
                              <p style={{ fontSize: '12px', color: '#B3B3B3', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                                {item.artist}
                              </p>
                            </div>
                          </div>

                          {/* Device, OS & Location */}
                          <div style={{ textAlign: 'right', display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: '3px' }}>
                            <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                              {getDeviceIcon(item.platform, item.deviceName)}
                              <span style={{ fontSize: '13px', fontWeight: 600, color: '#fff' }}>
                                {item.deviceModel || item.deviceName || `${item.platform} App`}
                              </span>
                            </div>
                            <div style={{ fontSize: '11px', color: '#B3B3B3' }}>
                              {item.osVersion ? `${item.platform} · ${item.osVersion}` : `${item.platform} App`}
                            </div>
                            <div style={{ display: 'flex', alignItems: 'center', gap: '6px', marginTop: '2px' }}>
                              {item.country && (
                                <span style={{ fontSize: '11px', color: '#9E9E9E', display: 'flex', alignItems: 'center' }}>
                                  {renderCountryFlag(item.country, item.countryCode)}
                                  {formatCountryName(item.country)}{item.city ? ` · ${item.city}` : ''}
                                </span>
                              )}
                              <code style={{ fontSize: '11px', background: '#181818', padding: '2px 6px', borderRadius: '4px', color: '#B3B3B3', fontFamily: 'monospace' }}>
                                {item.ipAddress || 'IP no reg.'}
                              </code>
                              <span style={{ fontSize: '11px', color: '#6B6B6B' }}>
                                hace {item.secondsSincePing || 0}s
                              </span>
                            </div>
                          </div>

                          {/* View Details Button */}
                          <button
                            onClick={() => handleOpenUserDetail(item.userId)}
                            style={{
                              marginLeft: '16px', padding: '7px 14px', borderRadius: '8px',
                              background: '#282828', border: '0.5px solid #404040', color: '#fff',
                              fontSize: '12px', fontWeight: 600, cursor: 'pointer',
                            }}
                            onMouseEnter={e => e.currentTarget.style.background = '#333'}
                            onMouseLeave={e => e.currentTarget.style.background = '#282828'}
                          >
                            Ver Usuario
                          </button>
                        </div>
                      ))}
                    </div>
                  </div>
                )}

                {/* Sub-section 2: Connected Users in App (Browsing / Online) */}
                {browsingUsers.length > 0 && (
                  <div>
                    <h4 style={{ fontSize: '12px', fontWeight: 700, color: '#007AFF', textTransform: 'uppercase', letterSpacing: '0.06em', marginBottom: '10px', display: 'flex', alignItems: 'center', gap: '6px' }}>
                      <span style={{ width: '8px', height: '8px', borderRadius: '50%', background: '#007AFF', display: 'inline-block' }} />
                      Usuarios Conectados en la App ({browsingUsers.length})
                    </h4>
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
                      {browsingUsers.map((item, idx) => (
                        <div
                          key={`${item.userId}_${item.platform}_${item.deviceModel || idx}`}
                          style={{
                            display: 'flex', alignItems: 'center', justifyContent: 'space-between',
                            background: '#202020', borderRadius: '12px', padding: '14px 18px',
                            border: '0.5px solid rgba(0,122,255,0.3)',
                          }}
                        >
                          {/* User Profile */}
                          <div style={{ display: 'flex', alignItems: 'center', gap: '14px', minWidth: '220px' }}>
                            <div style={{
                              width: '44px', height: '44px', borderRadius: '50%', background: '#007AFF',
                              display: 'flex', alignItems: 'center', justifyContent: 'center',
                              fontSize: '16px', fontWeight: 700, color: '#fff',
                            }}>
                              {item.userName?.charAt(0).toUpperCase() || 'U'}
                            </div>
                            <div>
                              <p style={{ fontSize: '15px', fontWeight: 700, color: '#fff' }}>{item.userName}</p>
                              <p style={{ fontSize: '12px', color: '#B3B3B3' }}>{item.userEmail}</p>
                            </div>
                          </div>

                          {/* App Status */}
                          <div style={{ display: 'flex', alignItems: 'center', gap: '10px', flex: 1, margin: '0 24px', minWidth: 0 }}>
                            <span style={{ fontSize: '11px', color: '#007AFF', fontWeight: 700, background: 'rgba(0,122,255,0.15)', padding: '3px 8px', borderRadius: '6px' }}>
                              📱 ACTIVO EN LA APP
                            </span>
                            <span style={{ fontSize: '12px', color: '#B3B3B3' }}>
                              Navegando · Sesión activa: {formatSessionDuration(item.durationSeconds || 0)}
                            </span>
                          </div>

                          {/* Device, OS & Location */}
                          <div style={{ textAlign: 'right', display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: '3px' }}>
                            <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                              {getDeviceIcon(item.platform, item.deviceModel)}
                              <span style={{ fontSize: '13px', fontWeight: 600, color: '#fff' }}>
                                {item.deviceModel || `${item.platform} App`}
                              </span>
                            </div>
                            <div style={{ fontSize: '11px', color: '#B3B3B3' }}>
                              {item.osVersion ? `${item.platform} · ${item.osVersion}` : `${item.platform} App`}
                            </div>
                            <div style={{ display: 'flex', alignItems: 'center', gap: '6px', marginTop: '2px' }}>
                              {item.country && (
                                <span style={{ fontSize: '11px', color: '#9E9E9E', display: 'flex', alignItems: 'center' }}>
                                  {renderCountryFlag(item.country, item.countryCode)}
                                  {formatCountryName(item.country)}{item.city ? ` · ${item.city}` : ''}
                                </span>
                              )}
                              <code style={{ fontSize: '11px', background: '#181818', padding: '2px 6px', borderRadius: '4px', color: '#B3B3B3', fontFamily: 'monospace' }}>
                                {item.ipAddress || 'IP no reg.'}
                              </code>
                              <span style={{ fontSize: '11px', color: '#6B6B6B' }}>
                                hace {item.secondsSinceActive || 0}s
                              </span>
                            </div>
                          </div>

                          {/* View Details Button */}
                          <button
                            onClick={() => handleOpenUserDetail(item.userId)}
                            style={{
                              marginLeft: '16px', padding: '7px 14px', borderRadius: '8px',
                              background: '#282828', border: '0.5px solid #404040', color: '#fff',
                              fontSize: '12px', fontWeight: 600, cursor: 'pointer',
                            }}
                            onMouseEnter={e => e.currentTarget.style.background = '#333'}
                            onMouseLeave={e => e.currentTarget.style.background = '#282828'}
                          >
                            Ver Usuario
                          </button>
                        </div>
                      ))}
                    </div>
                  </div>
                )}

                {/* Empty State */}
                {!hasAnyLive && (
                  <div style={{ textAlign: 'center', padding: '28px', color: '#6B6B6B' }}>
                    <Radio size={28} style={{ margin: '0 auto 8px', opacity: 0.4 }} />
                    <p style={{ fontSize: '14px', color: '#B3B3B3' }}>No hay usuarios activos en la app en este momento.</p>
                    <p style={{ fontSize: '12px', marginTop: '4px', color: '#8E8E93' }}>
                      Cuando alguien abra la app en Android o Windows o reproduzca una canción, aparecerá aquí inmediatamente en tiempo real.
                    </p>
                  </div>
                )}
              </div>
            );
          })()}

          {/* TAB 1: USERS LIST & TELEMETRY */}
          {activeTab === 'users' && (
            <div>
              {/* Segmented Filter Pills */}
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '12px', marginBottom: '16px', flexWrap: 'wrap' }}>
                <div style={{ display: 'flex', gap: '8px' }}>
                  {[
                    { id: 'all', label: 'Todos' },
                    { id: 'admin', label: 'Administradores' },
                    { id: 'user', label: 'Usuarios Estándar' },
                  ].map(filter => (
                    <button
                      key={filter.id}
                      onClick={() => setRoleFilter(filter.id)}
                      style={{
                        padding: '7px 16px', borderRadius: '20px', fontSize: '13px', fontWeight: 600,
                        background: roleFilter === filter.id ? '#FA243C' : '#282828',
                        color: roleFilter === filter.id ? '#fff' : '#B3B3B3',
                        border: `0.5px solid ${roleFilter === filter.id ? '#FA243C' : '#404040'}`,
                        transition: 'all 0.15s',
                      }}
                    >
                      {filter.label}
                    </button>
                  ))}
                </div>

                <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
                  {[
                    { id: 'all', label: 'Cualquier Estado' },
                    { id: 'active', label: 'Activos' },
                    { id: 'banned', label: 'Suspendidos' },
                  ].map(filter => (
                    <button
                      key={filter.id}
                      onClick={() => setStatusFilter(filter.id)}
                      style={{
                        padding: '7px 14px', borderRadius: '20px', fontSize: '12px', fontWeight: 600,
                        background: statusFilter === filter.id ? '#282828' : 'transparent',
                        color: statusFilter === filter.id ? '#fff' : '#6B6B6B',
                        border: `0.5px solid ${statusFilter === filter.id ? '#FA243C' : '#333'}`,
                        transition: 'all 0.15s',
                      }}
                    >
                      {filter.label}
                    </button>
                  ))}
                </div>

                {/* Platform Filter */}
                <div style={{ display: 'flex', alignItems: 'center', gap: '6px', flexWrap: 'wrap' }}>
                  <span style={{ fontSize: '11px', color: '#8E8E93', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.04em' }}>Plataforma:</span>
                  {[
                    { id: 'all', label: 'Todas las Plataformas' },
                    { id: 'mobile', label: '📱 Solo Android' },
                    { id: 'windows', label: '💻 Solo Windows' },
                    { id: 'web', label: '🌐 Solo Web' },
                  ].map(p => (
                    <button
                      key={p.id}
                      onClick={() => setPlatformFilter(p.id)}
                      style={{
                        padding: '5px 12px', borderRadius: '16px', fontSize: '11px', fontWeight: 600,
                        background: platformFilter === p.id ? '#FA243C' : '#282828',
                        color: platformFilter === p.id ? '#fff' : '#B3B3B3',
                        border: `0.5px solid ${platformFilter === p.id ? '#FA243C' : '#404040'}`,
                        cursor: 'pointer',
                        transition: 'all 0.15s',
                      }}
                    >
                      {p.label}
                    </button>
                  ))}
                </div>
              </div>

              {/* Users List (Styled as Groovy Music Rows) */}
              <div style={{
                background: '#181818',
                borderRadius: '16px',
                border: '0.5px solid #282828',
                overflow: 'hidden',
              }}>
                {/* List Header */}
                <div style={{
                  display: 'grid',
                  gridTemplateColumns: 'minmax(210px, 2fr) 130px 170px 140px 130px 140px',
                  padding: '12px 20px',
                  borderBottom: '0.5px solid #282828',
                  fontSize: '11px',
                  fontWeight: 700,
                  color: '#6B6B6B',
                  textTransform: 'uppercase',
                  letterSpacing: '0.06em',
                }}>
                  <div>Usuario</div>
                  <div>Rol y Estado</div>
                  <div>Última Actividad</div>
                  <div>Tiempo de Escucha</div>
                  <div>Canciones</div>
                  <div style={{ textAlign: 'right' }}>Acciones</div>
                </div>

                {/* User Rows */}
                {(() => {
                  const filteredUsers = users.filter(u => {
                    if (platformFilter === 'mobile') {
                      const s = `${u.lastDeviceModel} ${u.lastDevice} ${u.lastOsVersion}`.toLowerCase();
                      return s.includes('android') || s.includes('ios') || s.includes('iphone');
                    }
                    if (platformFilter === 'windows') {
                      const s = `${u.lastDeviceModel} ${u.lastDevice} ${u.lastOsVersion}`.toLowerCase();
                      return s.includes('windows');
                    }
                    if (platformFilter === 'web') {
                      return isWebClient(u.lastDeviceModel || u.lastDevice, '', u.lastOsVersion);
                    }
                    return true;
                  });

                  if (filteredUsers.length === 0 && !isLoading) {
                    return (
                      <div style={{ padding: '48px 24px', textAlign: 'center', color: '#6B6B6B' }}>
                        <Users size={32} style={{ margin: '0 auto 12px', opacity: 0.4 }} />
                        <p style={{ fontSize: '15px', fontWeight: 600, color: '#B3B3B3' }}>No se encontraron usuarios para este filtro</p>
                        <p style={{ fontSize: '13px', marginTop: '4px' }}>
                          Prueba cambiando los filtros de plataforma o estado.
                        </p>
                      </div>
                    );
                  }

                  return filteredUsers.map((u) => {
                  const isLive = u.livePlayback?.isPlaying;
                  return (
                    <div
                      key={u.id}
                      style={{
                        display: 'grid',
                        gridTemplateColumns: 'minmax(210px, 2fr) 130px 170px 140px 130px 140px',
                        alignItems: 'center',
                        padding: '14px 20px',
                        borderBottom: '0.5px solid #202020',
                        transition: 'background 0.15s',
                        background: isLive ? 'rgba(52,199,89,0.03)' : 'transparent',
                      }}
                      onMouseEnter={e => e.currentTarget.style.background = isLive ? 'rgba(52,199,89,0.06)' : '#202020'}
                      onMouseLeave={e => e.currentTarget.style.background = isLive ? 'rgba(52,199,89,0.03)' : 'transparent'}
                    >
                      {/* User profile & email */}
                      <div style={{ display: 'flex', alignItems: 'center', gap: '14px', minWidth: 0, paddingRight: '12px' }}>
                        <div style={{
                          width: '40px', height: '40px', borderRadius: '50%',
                          background: u.role === 'admin' ? '#FA243C' : '#282828',
                          display: 'flex', alignItems: 'center', justifyContent: 'center',
                          fontSize: '15px', fontWeight: 700, color: '#fff', flexShrink: 0,
                          border: u.role === 'admin' ? '2px solid rgba(250,36,60,0.5)' : '1px solid #333',
                        }}>
                          {u.name?.charAt(0).toUpperCase() || 'U'}
                        </div>
                        <div style={{ minWidth: 0 }}>
                          <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                            <span style={{ fontSize: '15px', fontWeight: 600, color: '#fff', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                              {u.name}
                            </span>
                            {currentUser?.id === u.id && (
                              <span style={{ fontSize: '10px', color: '#B3B3B3', background: '#282828', padding: '1px 6px', borderRadius: '4px', fontWeight: 600 }}>
                                Tú
                              </span>
                            )}
                            {isLive && (
                              <span style={{
                                fontSize: '10px', color: '#34C759', background: 'rgba(52,199,89,0.15)',
                                padding: '1px 6px', borderRadius: '4px', fontWeight: 700,
                              }}>
                                ● En Vivo
                              </span>
                            )}
                          </div>
                          <p style={{ fontSize: '13px', color: '#B3B3B3', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', marginTop: '2px' }}>
                            {u.email}
                          </p>
                        </div>
                      </div>

                      {/* Role & Status */}
                      <div>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                          <span style={{
                            fontSize: '11px', fontWeight: 700, padding: '2px 8px', borderRadius: '12px',
                            background: u.role === 'admin' ? 'rgba(250,36,60,0.15)' : '#282828',
                            color: u.role === 'admin' ? '#FA243C' : '#B3B3B3',
                            border: `0.5px solid ${u.role === 'admin' ? 'rgba(250,36,60,0.3)' : '#333'}`,
                          }}>
                            {u.role === 'admin' ? 'Admin' : 'Usuario'}
                          </span>
                        </div>
                        <div style={{ fontSize: '12px', marginTop: '4px', display: 'flex', alignItems: 'center', gap: '5px', color: u.isBanned ? '#FF3B30' : '#34C759' }}>
                          <span style={{ width: '6px', height: '6px', borderRadius: '50%', background: u.isBanned ? '#FF3B30' : '#34C759' }} />
                          <span>{u.isBanned ? 'Suspendido' : 'Activo'}</span>
                        </div>
                      </div>

                      {/* Last Active Timestamp, Device & Geolocation */}
                      <div style={{ minWidth: 0, paddingRight: '10px' }}>
                        <div style={{ fontSize: '12px', fontWeight: 600, color: '#fff' }}>
                          {formatDateTime(u.lastActiveAt || u.lastLoginAt)}
                        </div>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '5px', marginTop: '3px' }}>
                          {getDeviceIcon(u.lastDeviceModel || u.lastDevice)}
                          <span style={{ fontSize: '11px', color: '#B3B3B3', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                            {u.lastDeviceModel || u.lastDevice || 'Sin dispositivo'}
                          </span>
                        </div>
                        {(u.lastCountry || u.lastOsVersion) && (
                          <div style={{ display: 'flex', alignItems: 'center', gap: '5px', marginTop: '2px', fontSize: '11px', color: '#8E8E93', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                            {u.lastCountry && (
                              <span style={{ display: 'flex', alignItems: 'center' }}>
                                {renderCountryFlag(u.lastCountry, u.lastCountryCode)}
                                {formatCountryName(u.lastCountry)}{u.lastCity ? ` (${u.lastCity})` : ''}
                              </span>
                            )}
                            {u.lastOsVersion && <span>· {u.lastOsVersion}</span>}
                          </div>
                        )}
                      </div>

                      {/* Listening Time */}
                      <div>
                        <div style={{ fontSize: '13px', fontWeight: 700, color: '#fff', display: 'flex', alignItems: 'center', gap: '5px' }}>
                          <Clock size={13} style={{ color: '#FA243C' }} />
                          <span>{formatListeningTime(u.totalListenSeconds)}</span>
                        </div>
                        <span style={{ fontSize: '11px', color: '#6B6B6B' }}>
                          tiempo acumulado
                        </span>
                      </div>

                      {/* Total Songs Listened */}
                      <div>
                        <div style={{ fontSize: '13px', fontWeight: 700, color: '#fff', display: 'flex', alignItems: 'center', gap: '5px' }}>
                          <Music size={13} style={{ color: '#34C759' }} />
                          <span>{u.stats?.plays || 0} canciones</span>
                        </div>
                        <div style={{ fontSize: '11px', color: '#B3B3B3', display: 'flex', gap: '8px', marginTop: '2px' }}>
                          <span>❤️ {u.stats?.favorites || 0}</span>
                          <span>📁 {u.stats?.playlists || 0}</span>
                        </div>
                      </div>

                      {/* Actions */}
                      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'flex-end', gap: '6px' }}>
                        <button
                          onClick={() => handleOpenUserDetail(u.id)}
                          style={{
                            padding: '6px 12px', borderRadius: '8px', background: '#282828',
                            border: '0.5px solid #404040', color: '#fff', fontSize: '12px', fontWeight: 600,
                          }}
                          onMouseEnter={e => e.currentTarget.style.background = '#333'}
                          onMouseLeave={e => e.currentTarget.style.background = '#282828'}
                        >
                          Detalles
                        </button>

                        <button
                          onClick={() => handleOpenEdit(u)}
                          title="Editar usuario"
                          style={{
                            padding: '7px', borderRadius: '8px', background: '#282828',
                            border: '0.5px solid #404040', color: '#B3B3B3',
                          }}
                          onMouseEnter={e => e.currentTarget.style.color = '#fff'}
                          onMouseLeave={e => e.currentTarget.style.color = '#B3B3B3'}
                        >
                          <Edit2 size={13} />
                        </button>

                        {currentUser?.id !== u.id && (
                          <button
                            onClick={() => handleToggleBan(u)}
                            title={u.isBanned ? 'Reactivar acceso' : 'Suspender acceso'}
                            style={{
                              padding: '7px', borderRadius: '8px', background: '#282828',
                              border: '0.5px solid #404040', color: u.isBanned ? '#34C759' : '#FF9500',
                            }}
                          >
                            <Ban size={13} />
                          </button>
                        )}

                        {currentUser?.id !== u.id && (
                          <button
                            onClick={() => setUserToDelete(u)}
                            title="Eliminar usuario"
                            style={{
                              padding: '7px', borderRadius: '8px', background: 'rgba(255,59,48,0.1)',
                              border: '0.5px solid rgba(255,59,48,0.25)', color: '#FF3B30',
                            }}
                          >
                            <Trash2 size={13} />
                          </button>
                        )}
                      </div>
                    </div>
                  );
                });
              })()}
              </div>
            </div>
          )}

          {/* TAB 2: SESSIONS & IP AUDIT (With Session Duration & Exact Timestamps) */}
          {activeTab === 'sessions' && (
            <div style={{
              background: '#181818',
              borderRadius: '16px',
              border: '0.5px solid #282828',
              overflow: 'hidden',
            }}>
              <div style={{ padding: '18px 24px', borderBottom: '0.5px solid #282828', display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: '12px' }}>
                <div>
                  <h3 style={{ fontSize: '16px', fontWeight: 700, letterSpacing: '-0.3px' }}>Registro de Conexiones en Vivo</h3>
                  <p style={{ fontSize: '13px', color: '#B3B3B3', marginTop: '3px' }}>
                    Auditoría completa con marcas de tiempo exactas, duración de cada inicio de sesión, hardware real (Android / Windows) y dirección IP.
                  </p>
                </div>

                <div style={{ display: 'flex', alignItems: 'center', gap: '6px', flexWrap: 'wrap' }}>
                  <span style={{ fontSize: '11px', color: '#8E8E93', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.04em' }}>Plataforma:</span>
                  {[
                    { id: 'all', label: 'Todas las Conexiones' },
                    { id: 'mobile', label: '📱 Solo Android' },
                    { id: 'windows', label: '💻 Solo Windows' },
                    { id: 'web', label: '🌐 Solo Web' },
                  ].map(p => (
                    <button
                      key={p.id}
                      onClick={() => setPlatformFilter(p.id)}
                      style={{
                        padding: '5px 12px', borderRadius: '16px', fontSize: '11px', fontWeight: 600,
                        background: platformFilter === p.id ? '#FA243C' : '#282828',
                        color: platformFilter === p.id ? '#fff' : '#B3B3B3',
                        border: `0.5px solid ${platformFilter === p.id ? '#FA243C' : '#404040'}`,
                        cursor: 'pointer',
                        transition: 'all 0.15s',
                      }}
                    >
                      {p.label}
                    </button>
                  ))}
                </div>
              </div>

              {/* Table header */}
              <div style={{
                display: 'grid',
                gridTemplateColumns: 'minmax(160px, 1.3fr) 130px 160px 160px 180px 100px 140px',
                padding: '12px 24px',
                borderBottom: '0.5px solid #282828',
                fontSize: '11px',
                fontWeight: 700,
                color: '#6B6B6B',
                textTransform: 'uppercase',
                letterSpacing: '0.06em',
              }}>
                <div>Usuario</div>
                <div>Dirección IP</div>
                <div>Dispositivo</div>
                <div>Sistema Operativo</div>
                <div>Ubicación & ISP</div>
                <div>Duración</div>
                <div>Fecha y Hora</div>
              </div>

              {/* Sessions list */}
              {(() => {
                const filteredSessions = sessions.filter(s => {
                  if (platformFilter === 'mobile') {
                    const str = `${s.client_platform} ${s.device_os} ${s.device_model}`.toLowerCase();
                    return str.includes('android') || str.includes('ios') || str.includes('iphone') || s.device_type === 'Mobile';
                  }
                  if (platformFilter === 'windows') {
                    const str = `${s.client_platform} ${s.device_os} ${s.device_model}`.toLowerCase();
                    return str.includes('windows');
                  }
                  if (platformFilter === 'web') {
                    return isWebClient(s.client_platform || s.device_os, s.device_model || s.device_os, s.browser);
                  }
                  return true;
                });

                if (filteredSessions.length === 0 && !isLoading) {
                  return (
                    <div style={{ padding: '48px 24px', textAlign: 'center', color: '#6B6B6B' }}>
                      <Activity size={32} style={{ margin: '0 auto 12px', opacity: 0.4 }} />
                      <p style={{ fontSize: '15px', fontWeight: 600, color: '#B3B3B3' }}>Sin conexiones registradas para este filtro</p>
                      <p style={{ fontSize: '13px', marginTop: '4px' }}>
                        Prueba cambiando el filtro de plataforma.
                      </p>
                    </div>
                  );
                }

                return filteredSessions.map((s) => (
                <div
                  key={s.id}
                  style={{
                    display: 'grid',
                    gridTemplateColumns: 'minmax(160px, 1.3fr) 130px 160px 160px 180px 100px 140px',
                    alignItems: 'center',
                    padding: '14px 24px',
                    borderBottom: '0.5px solid #202020',
                    transition: 'background 0.15s',
                  }}
                  onMouseEnter={e => e.currentTarget.style.background = '#202020'}
                  onMouseLeave={e => e.currentTarget.style.background = 'transparent'}
                >
                  {/* User */}
                  <div style={{ minWidth: 0, paddingRight: '12px' }}>
                    <p style={{ fontSize: '14px', fontWeight: 600, color: '#fff', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                      {s.user_name}
                    </p>
                    <p style={{ fontSize: '12px', color: '#B3B3B3', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                      {s.user_email}
                    </p>
                  </div>

                  {/* IP */}
                  <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                    <span style={{
                      fontFamily: 'monospace', fontSize: '12px', background: '#282828',
                      padding: '3px 7px', borderRadius: '4px', color: '#fff',
                    }}>
                      {s.ip_address}
                    </span>
                    <button
                      onClick={() => copyToClipboard(s.ip_address)}
                      title="Copiar IP"
                      style={{ color: '#6B6B6B', padding: '2px' }}
                      onMouseEnter={e => e.currentTarget.style.color = '#fff'}
                      onMouseLeave={e => e.currentTarget.style.color = '#6B6B6B'}
                    >
                      {copiedIp === s.ip_address ? <Check size={12} style={{ color: '#34C759' }} /> : <Copy size={12} />}
                    </button>
                  </div>

                  {/* Device & Hardware */}
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px', minWidth: 0 }}>
                    {getDeviceIcon(s.device_os, s.browser, s.device_type)}
                    <div style={{ minWidth: 0 }}>
                      <p style={{ fontSize: '13px', fontWeight: 600, color: '#fff', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                        {s.device_model || (s.device_type === 'Mobile' ? 'Dispositivo Móvil' : 'PC / Laptop')}
                      </p>
                      <p style={{ fontSize: '11px', color: '#B3B3B3', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                        {s.client_platform || s.device_type || 'App'}
                      </p>
                    </div>
                  </div>

                  {/* OS & Version */}
                  <div style={{ minWidth: 0 }}>
                    <p style={{ fontSize: '13px', fontWeight: 600, color: '#fff', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                      {s.os_version || s.device_os || 'Desconocido'}
                    </p>
                    <p style={{ fontSize: '11px', color: '#B3B3B3', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                      {(s.client_platform?.includes('Android') || s.device_os === 'Android') ? 'Groovy Android App' : (s.client_platform?.includes('Windows') && s.browser?.includes('Native') ? 'Groovy Windows App' : `${s.browser || 'Web Client'} ${s.browser_version ? `v${s.browser_version}` : ''}`)}
                    </p>
                  </div>

                  {/* Geolocation & ISP */}
                  <div style={{ minWidth: 0, paddingRight: '8px' }}>
                    <p style={{ fontSize: '13px', fontWeight: 600, color: '#fff', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', display: 'flex', alignItems: 'center' }}>
                      {renderCountryFlag(s.country, s.country_code)}
                      <span>{s.country ? `${formatCountryName(s.country)}${s.city ? ` · ${s.city}` : ''}` : 'Ubicación no reg.'}</span>
                    </p>
                    <p style={{ fontSize: '11px', color: '#8E8E93', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                      {s.isp || s.region || 'Red Privada / LAN'}
                    </p>
                  </div>

                  {/* Session Duration */}
                  <div style={{ fontSize: '13px', color: '#34C759', fontWeight: 600 }}>
                    {formatSessionDuration(s.session_duration_seconds)}
                  </div>

                  {/* Exact Timestamp */}
                  <div style={{ fontSize: '12px', color: '#B3B3B3' }}>
                    {formatDateTime(s.created_at)}
                  </div>
                </div>
              ));
            })()}
            </div>
          )}

          {/* TAB 3: POPULAR SONGS & STREAMING METRICS */}
          {activeTab === 'metrics' && (
            <div style={{
              background: '#181818',
              borderRadius: '16px',
              border: '0.5px solid #282828',
              padding: '24px',
            }}>
              <h3 style={{ fontSize: '18px', fontWeight: 700, letterSpacing: '-0.4px', marginBottom: '6px' }}>
                Canciones Más Populares
              </h3>
              <p style={{ fontSize: '13px', color: '#B3B3B3', marginBottom: '20px' }}>
                Ranking global de canciones más escuchadas en Groovy Cloud por todos los usuarios.
              </p>

              <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                {metrics?.topSongs?.map((song, i) => (
                  <div
                    key={song.song_id || i}
                    style={{
                      display: 'flex', alignItems: 'center', gap: '16px',
                      padding: '10px 14px', borderRadius: '10px',
                      background: 'transparent', transition: 'background 0.15s',
                    }}
                    onMouseEnter={e => e.currentTarget.style.background = '#282828'}
                    onMouseLeave={e => e.currentTarget.style.background = 'transparent'}
                  >
                    <span style={{ fontSize: '15px', fontWeight: 700, color: i < 3 ? '#FA243C' : '#6B6B6B', width: '24px', textAlign: 'center' }}>
                      {i + 1}
                    </span>
                    {song.cover_art ? (
                      <img src={song.cover_art} alt={song.title} style={{ width: '44px', height: '44px', borderRadius: '8px', objectFit: 'cover' }} />
                    ) : (
                      <div style={{ width: '44px', height: '44px', borderRadius: '8px', background: '#282828', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                        <Music size={20} style={{ color: '#6B6B6B' }} />
                      </div>
                    )}
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <p style={{ fontSize: '15px', fontWeight: 600, color: '#fff', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                        {song.title}
                      </p>
                      <p style={{ fontSize: '13px', color: '#B3B3B3', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', marginTop: '2px' }}>
                        {song.artist}
                      </p>
                    </div>
                    <div style={{
                      fontSize: '13px', fontWeight: 700, color: '#34C759',
                      background: 'rgba(52,199,89,0.1)', padding: '4px 10px', borderRadius: '12px',
                    }}>
                      {song.play_count} reproducciones
                    </div>
                  </div>
                ))}

                {(!metrics?.topSongs || metrics.topSongs.length === 0) && (
                  <div style={{ padding: '36px', textAlign: 'center', color: '#6B6B6B' }}>
                    <Music size={32} style={{ margin: '0 auto 12px', opacity: 0.4 }} />
                    <p style={{ fontSize: '14px', color: '#B3B3B3' }}>Aún no hay reproducciones registradas en la nube.</p>
                  </div>
                )}
              </div>
            </div>
          )}
        </main>
      </div>

      {/* 3. CUPERTINO MODAL: USER DETAILS INSPECTOR ("Ver Todo / Detalles") */}
      {selectedUser && (
        <div style={{
          position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.85)', backdropFilter: 'blur(20px)',
          display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 100, padding: '20px',
        }}>
          <div style={{
            background: '#181818', border: '0.5px solid #282828', borderRadius: '20px',
            width: '100%', maxWidth: '820px', maxHeight: '90vh', overflowY: 'auto', padding: '28px',
            boxShadow: '0 24px 60px rgba(0,0,0,0.8)',
          }}>
            {/* Header */}
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '20px' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
                <div style={{
                  width: '56px', height: '56px', borderRadius: '50%', background: '#FA243C',
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  fontSize: '24px', fontWeight: 700, color: '#fff',
                }}>
                  {selectedUser.user.name?.charAt(0).toUpperCase() || 'U'}
                </div>
                <div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <h2 style={{ fontSize: '22px', fontWeight: 700, letterSpacing: '-0.3px' }}>{selectedUser.user.name}</h2>
                    {selectedUser.livePlayback?.isPlaying && (
                      <span style={{
                        fontSize: '11px', color: '#34C759', background: 'rgba(52,199,89,0.15)',
                        padding: '2px 8px', borderRadius: '6px', fontWeight: 700,
                      }}>
                        ● Escuchando Ahora
                      </span>
                    )}
                  </div>
                  <p style={{ fontSize: '13px', color: '#B3B3B3', marginTop: '2px' }}>{selectedUser.user.email}</p>
                </div>
              </div>
              <button
                onClick={() => setSelectedUser(null)}
                style={{ color: '#B3B3B3', padding: '6px', borderRadius: '8px' }}
                onMouseEnter={e => e.currentTarget.style.color = '#fff'}
                onMouseLeave={e => e.currentTarget.style.color = '#B3B3B3'}
              >
                <X size={20} />
              </button>
            </div>

            {/* Live Playback Banner(s) in Modal */}
            {(selectedUser.livePlaybacks?.length > 0 ? selectedUser.livePlaybacks : (selectedUser.livePlayback ? [selectedUser.livePlayback] : []))
              .filter(lp => lp?.isPlaying)
              .map((lp, idx) => (
                <div key={idx} style={{
                  background: 'linear-gradient(135deg, rgba(52,199,89,0.15), rgba(24,24,24,0.9))',
                  border: '1px solid rgba(52,199,89,0.4)', borderRadius: '12px',
                  padding: '14px 18px', marginBottom: '14px', display: 'flex', alignItems: 'center', justifyContent: 'space-between',
                }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                    {lp.coverArt ? (
                      <img src={lp.coverArt} alt="" style={{ width: '42px', height: '42px', borderRadius: '8px', objectFit: 'cover' }} />
                    ) : (
                      <div style={{ width: '42px', height: '42px', borderRadius: '8px', background: '#282828', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                        <Music size={20} color="#34C759" />
                      </div>
                    )}
                    <div>
                      <span style={{ fontSize: '11px', color: '#34C759', fontWeight: 700, textTransform: 'uppercase' }}>
                        🟢 Reproduciendo en vivo en {lp.platform} {lp.deviceModel ? `· ${lp.deviceModel}` : ''}
                      </span>
                      <p style={{ fontSize: '15px', fontWeight: 700, color: '#fff' }}>{lp.title}</p>
                      <p style={{ fontSize: '12px', color: '#B3B3B3' }}>{lp.artist}</p>
                    </div>
                  </div>
                  <div style={{ textAlign: 'right' }}>
                    <span style={{ fontSize: '12px', color: '#B3B3B3' }}>IP: <code>{lp.ipAddress}</code></span>
                  </div>
                </div>
              ))}

            {/* Detailed Metadata Grid */}
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '10px', marginBottom: '20px' }}>
              <div style={{ background: '#282828', padding: '12px 14px', borderRadius: '10px' }}>
                <span style={{ fontSize: '11px', color: '#B3B3B3', textTransform: 'uppercase', fontWeight: 600 }}>Tiempo Total</span>
                <p style={{ fontSize: '15px', fontWeight: 700, marginTop: '3px', color: '#fff' }}>
                  {formatListeningTime(selectedUser.user.totalListenSeconds)}
                </p>
              </div>

              <div style={{ background: '#282828', padding: '12px 14px', borderRadius: '10px' }}>
                <span style={{ fontSize: '11px', color: '#B3B3B3', textTransform: 'uppercase', fontWeight: 600 }}>Canciones Escuchadas</span>
                <p style={{ fontSize: '15px', fontWeight: 700, marginTop: '3px', color: '#34C759' }}>
                  {selectedUser.stats?.plays ?? selectedUser.user?.totalPlays ?? selectedUser.history?.length ?? 0} canciones
                </p>
              </div>

              <div style={{ background: '#282828', padding: '12px 14px', borderRadius: '10px' }}>
                <span style={{ fontSize: '11px', color: '#B3B3B3', textTransform: 'uppercase', fontWeight: 600 }}>Última Actividad</span>
                <p style={{ fontSize: '12px', fontWeight: 600, marginTop: '4px', color: '#fff' }}>
                  {formatDateTime(selectedUser.user.lastActiveAt || selectedUser.user.lastLoginAt)}
                </p>
              </div>

              <div style={{ background: '#282828', padding: '12px 14px', borderRadius: '10px' }}>
                <span style={{ fontSize: '11px', color: '#B3B3B3', textTransform: 'uppercase', fontWeight: 600 }}>Fecha Registro</span>
                <p style={{ fontSize: '12px', fontWeight: 600, marginTop: '4px', color: '#fff' }}>
                  {formatDateTime(selectedUser.user.createdAt)}
                </p>
              </div>
            </div>

            {/* Geolocation & Device Deep-Dive Cards */}
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px', marginBottom: '20px' }}>
              {/* Geolocation Card */}
              <div style={{ background: '#222222', border: '0.5px solid #333333', borderRadius: '12px', padding: '16px' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '12px' }}>
                  <Globe size={16} style={{ color: '#007AFF' }} />
                  <h4 style={{ fontSize: '12px', fontWeight: 700, color: '#fff', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
                    Ubicación Geográfica & Conexión IP
                  </h4>
                </div>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', fontSize: '13px' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <span style={{ color: '#8E8E93' }}>País & Bandera:</span>
                    <span style={{ color: '#fff', fontWeight: 600, display: 'flex', alignItems: 'center' }}>
                      {renderCountryFlag(selectedUser.user.lastCountry || selectedUser.sessions?.[0]?.country, selectedUser.user.lastCountryCode || selectedUser.sessions?.[0]?.country_code)}
                      <span>{formatCountryName(selectedUser.user.lastCountry || selectedUser.sessions?.[0]?.country || 'Desconocido')}</span>
                    </span>
                  </div>
                  <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                    <span style={{ color: '#8E8E93' }}>Ciudad / Región:</span>
                    <span style={{ color: '#fff', fontWeight: 600 }}>
                      {selectedUser.user.lastCity || selectedUser.sessions?.[0]?.city || '—'}
                      {(selectedUser.user.lastRegion || selectedUser.sessions?.[0]?.region) ? `, ${selectedUser.user.lastRegion || selectedUser.sessions?.[0]?.region}` : ''}
                    </span>
                  </div>
                  <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                    <span style={{ color: '#8E8E93' }}>Proveedor de Red (ISP):</span>
                    <span style={{ color: '#34C759', fontWeight: 600 }}>
                      {selectedUser.user.lastIsp || selectedUser.sessions?.[0]?.isp || 'Red Local / ISP'}
                    </span>
                  </div>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <span style={{ color: '#8E8E93' }}>Dirección IP:</span>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                      <code style={{ fontSize: '12px', background: '#181818', padding: '2px 6px', borderRadius: '4px', color: '#fff' }}>
                        {selectedUser.user.lastLoginIp || selectedUser.sessions?.[0]?.ip_address || '—'}
                      </code>
                      <button
                        onClick={() => copyToClipboard(selectedUser.user.lastLoginIp || selectedUser.sessions?.[0]?.ip_address)}
                        style={{ color: '#8E8E93', padding: '2px' }}
                      >
                        <Copy size={12} />
                      </button>
                    </div>
                  </div>
                </div>
              </div>

              {/* Hardware & OS Card */}
              <div style={{ background: '#222222', border: '0.5px solid #333333', borderRadius: '12px', padding: '16px' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '12px' }}>
                  <Laptop size={16} style={{ color: '#FA243C' }} />
                  <h4 style={{ fontSize: '12px', fontWeight: 700, color: '#fff', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
                    Hardware & Sistema Operativo
                  </h4>
                </div>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', fontSize: '13px' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                    <span style={{ color: '#8E8E93' }}>Modelo de Dispositivo:</span>
                    <span style={{ color: '#fff', fontWeight: 600 }}>
                      {selectedUser.user.lastDeviceModel || selectedUser.sessions?.[0]?.device_model || selectedUser.user.lastDevice || 'Dispositivo Estándar'}
                    </span>
                  </div>
                  <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                    <span style={{ color: '#8E8E93' }}>Sistema Operativo:</span>
                    <span style={{ color: '#fff', fontWeight: 600 }}>
                      {selectedUser.user.lastOsVersion || selectedUser.sessions?.[0]?.os_version || '—'}
                    </span>
                  </div>
                  <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                    <span style={{ color: '#8E8E93' }}>Navegador / App:</span>
                    <span style={{ color: '#fff', fontWeight: 600 }}>
                      {selectedUser.sessions?.[0]?.browser ? `${selectedUser.sessions[0].browser} ${selectedUser.sessions[0].browser_version ? `v${selectedUser.sessions[0].browser_version}` : ''}` : 'Groovy App Client'}
                    </span>
                  </div>
                  <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                    <span style={{ color: '#8E8E93' }}>Tipo de Cliente:</span>
                    <span style={{ color: '#007AFF', fontWeight: 600 }}>
                      {selectedUser.sessions?.[0]?.client_platform || 'Groovy Cloud Player'}
                    </span>
                  </div>
                </div>
              </div>
            </div>

            {/* Playback History Table (Exact Songs Listened) */}
            <div style={{ marginBottom: '20px' }}>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '10px' }}>
                <h4 style={{ fontSize: '12px', fontWeight: 700, color: '#B3B3B3', textTransform: 'uppercase', letterSpacing: '0.06em' }}>
                  Historial de Canciones Escuchadas ({selectedUser.stats?.plays ?? selectedUser.user?.totalPlays ?? selectedUser.history?.length ?? 0} totales registradas)
                </h4>
              </div>
              <div style={{ background: '#282828', borderRadius: '10px', maxHeight: '170px', overflowY: 'auto' }}>
                {selectedUser.history?.map((h) => (
                  <div key={h.id} style={{
                    display: 'flex', alignItems: 'center', justifyContent: 'space-between',
                    padding: '8px 14px', borderBottom: '0.5px solid #333', fontSize: '13px',
                  }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '10px', minWidth: 0, flex: 1 }}>
                      {h.cover_art ? (
                        <img src={h.cover_art} alt="" style={{ width: '32px', height: '32px', borderRadius: '6px', objectFit: 'cover' }} />
                      ) : (
                        <div style={{ width: '32px', height: '32px', borderRadius: '6px', background: '#202020', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                          <Music size={14} color="#B3B3B3" />
                        </div>
                      )}
                      <div style={{ minWidth: 0 }}>
                        <p style={{ fontWeight: 600, color: '#fff', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                          {h.title}
                        </p>
                        <p style={{ fontSize: '11px', color: '#B3B3B3', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                          {h.artist}
                        </p>
                      </div>
                    </div>

                    <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                      <span style={{ fontSize: '11px', background: '#181818', padding: '2px 7px', borderRadius: '10px', color: '#B3B3B3' }}>
                        {h.platform || 'Groovy App'}
                      </span>
                      <span style={{ color: '#6B6B6B', fontSize: '12px' }}>
                        {formatDateTime(h.played_at)}
                      </span>
                    </div>
                  </div>
                ))}
                {(!selectedUser.history || selectedUser.history.length === 0) && (
                  <p style={{ padding: '18px', textAlign: 'center', color: '#6B6B6B', fontSize: '13px' }}>
                    Sin historial de reproducciones registrado.
                  </p>
                )}
              </div>
            </div>

            {/* Sessions / Devices list (Exact Login & Duration) */}
            <div style={{ marginBottom: '20px' }}>
              <h4 style={{ fontSize: '12px', fontWeight: 700, color: '#B3B3B3', textTransform: 'uppercase', letterSpacing: '0.06em', marginBottom: '10px' }}>
                Historial de Inicios de Sesión & Dispositivos ({selectedUser.sessions?.length || 0})
              </h4>
              <div style={{ background: '#282828', borderRadius: '10px', maxHeight: '180px', overflowY: 'auto' }}>
                {selectedUser.sessions?.map((s) => (
                  <div key={s.id} style={{
                    display: 'flex', alignItems: 'center', justifyContent: 'space-between',
                    padding: '10px 14px', borderBottom: '0.5px solid #333', fontSize: '13px',
                  }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                      {getDeviceIcon(s.device_os, s.browser, s.device_type)}
                      <div>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                          <span style={{ fontWeight: 600, color: '#fff' }}>{s.device_model || s.device_os || 'Dispositivo'}</span>
                          <span style={{ color: '#B3B3B3', fontSize: '11px' }}>({s.os_version || s.client_platform || s.browser || 'App'})</span>
                        </div>
                        {s.country && (
                          <span style={{ fontSize: '11px', color: '#8E8E93', display: 'flex', alignItems: 'center', marginTop: '2px' }}>
                            {renderCountryFlag(s.country, s.country_code)}
                            {formatCountryName(s.country)}{s.city ? ` · ${s.city}` : ''} {s.isp ? `(${s.isp})` : ''}
                          </span>
                        )}
                      </div>
                    </div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                      <span style={{ fontSize: '12px', color: '#34C759', fontWeight: 600 }}>
                        {formatSessionDuration(s.session_duration_seconds)}
                      </span>
                      <code style={{ fontSize: '12px', background: '#181818', padding: '2px 6px', borderRadius: '4px' }}>
                        {s.ip_address}
                      </code>
                      <span style={{ color: '#6B6B6B', fontSize: '11px' }}>
                        {formatDateTime(s.created_at)}
                      </span>
                    </div>
                  </div>
                ))}
                {(!selectedUser.sessions || selectedUser.sessions.length === 0) && (
                  <p style={{ padding: '16px', textAlign: 'center', color: '#6B6B6B', fontSize: '13px' }}>Sin registros de conexiones.</p>
                )}
              </div>
            </div>

            {/* Favorites & Playlists */}
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '14px', marginBottom: '24px' }}>
              <div>
                <h4 style={{ fontSize: '12px', fontWeight: 700, color: '#B3B3B3', textTransform: 'uppercase', letterSpacing: '0.06em', marginBottom: '8px' }}>
                  Canciones Favoritas ({selectedUser.favorites?.length || 0})
                </h4>
                <div style={{ background: '#282828', borderRadius: '10px', padding: '8px', maxHeight: '130px', overflowY: 'auto' }}>
                  {selectedUser.favorites?.map(fav => (
                    <div key={fav.id} style={{ padding: '6px 8px', borderBottom: '0.5px solid #333' }}>
                      <p style={{ fontSize: '13px', fontWeight: 600, color: '#fff' }}>{fav.title}</p>
                      <p style={{ fontSize: '11px', color: '#B3B3B3' }}>{fav.artist}</p>
                    </div>
                  ))}
                  {(!selectedUser.favorites || selectedUser.favorites.length === 0) && (
                    <p style={{ padding: '12px', textAlign: 'center', color: '#6B6B6B', fontSize: '12px' }}>Sin canciones en favoritos</p>
                  )}
                </div>
              </div>

              <div>
                <h4 style={{ fontSize: '12px', fontWeight: 700, color: '#B3B3B3', textTransform: 'uppercase', letterSpacing: '0.06em', marginBottom: '8px' }}>
                  Playlists ({selectedUser.playlists?.length || 0})
                </h4>
                <div style={{ background: '#282828', borderRadius: '10px', padding: '8px', maxHeight: '130px', overflowY: 'auto' }}>
                  {selectedUser.playlists?.map(pl => (
                    <div key={pl.id} style={{ padding: '6px 8px', borderBottom: '0.5px solid #333' }}>
                      <p style={{ fontSize: '13px', fontWeight: 600, color: '#fff' }}>{pl.name}</p>
                      <p style={{ fontSize: '11px', color: '#B3B3B3' }}>{new Date(pl.created_at).toLocaleDateString()}</p>
                    </div>
                  ))}
                  {(!selectedUser.playlists || selectedUser.playlists.length === 0) && (
                    <p style={{ padding: '12px', textAlign: 'center', color: '#6B6B6B', fontSize: '12px' }}>Sin playlists creadas</p>
                  )}
                </div>
              </div>
            </div>

            {/* Bottom Actions */}
            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '10px' }}>
              <button
                onClick={() => setSelectedUser(null)}
                style={{
                  padding: '9px 20px', borderRadius: '10px', background: '#FA243C',
                  color: '#fff', fontWeight: 700, fontSize: '13px', cursor: 'pointer',
                }}
              >
                Cerrar
              </button>
            </div>
          </div>
        </div>
      )}

      {/* 4. EDIT USER MODAL */}
      {editingUser && (
        <div style={{
          position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.85)', backdropFilter: 'blur(20px)',
          display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 100, padding: '20px',
        }}>
          <form onSubmit={handleSaveEdit} style={{
            background: '#181818', border: '0.5px solid #282828', borderRadius: '20px',
            width: '100%', maxWidth: '440px', padding: '28px',
            boxShadow: '0 24px 60px rgba(0,0,0,0.8)',
          }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '20px' }}>
              <h3 style={{ fontSize: '18px', fontWeight: 700, letterSpacing: '-0.3px' }}>Editar Usuario</h3>
              <button type="button" onClick={() => setEditingUser(null)} style={{ color: '#B3B3B3' }}>
                <X size={18} />
              </button>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
              <div>
                <label style={{ display: 'block', fontSize: '12px', color: '#B3B3B3', marginBottom: '6px', fontWeight: 500 }}>
                  Nombre
                </label>
                <input
                  type="text"
                  required
                  value={editFormData.name}
                  onChange={e => setEditFormData({ ...editFormData, name: e.target.value })}
                  style={{
                    width: '100%', background: '#282828', border: '0.5px solid #404040',
                    borderRadius: '8px', padding: '11px 14px', color: '#fff', fontSize: '14px', outline: 'none',
                  }}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '12px', color: '#B3B3B3', marginBottom: '6px', fontWeight: 500 }}>
                  Correo Electrónico
                </label>
                <input
                  type="email"
                  required
                  value={editFormData.email}
                  onChange={e => setEditFormData({ ...editFormData, email: e.target.value })}
                  style={{
                    width: '100%', background: '#282828', border: '0.5px solid #404040',
                    borderRadius: '8px', padding: '11px 14px', color: '#fff', fontSize: '14px', outline: 'none',
                  }}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '12px', color: '#B3B3B3', marginBottom: '6px', fontWeight: 500 }}>
                  Rol de Cuenta
                </label>
                <select
                  value={editFormData.role}
                  onChange={e => setEditFormData({ ...editFormData, role: e.target.value })}
                  style={{
                    width: '100%', background: '#282828', border: '0.5px solid #404040',
                    borderRadius: '8px', padding: '11px 14px', color: '#fff', fontSize: '14px', outline: 'none', cursor: 'pointer',
                  }}
                >
                  <option value="user">Usuario Regular</option>
                  <option value="admin">Administrador</option>
                </select>
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '12px', color: '#B3B3B3', marginBottom: '6px', fontWeight: 500 }}>
                  Nueva Contraseña (opcional)
                </label>
                <input
                  type="password"
                  placeholder="Dejar vacío para no cambiar"
                  value={editFormData.password}
                  onChange={e => setEditFormData({ ...editFormData, password: e.target.value })}
                  style={{
                    width: '100%', background: '#282828', border: '0.5px solid #404040',
                    borderRadius: '8px', padding: '11px 14px', color: '#fff', fontSize: '14px', outline: 'none',
                  }}
                />
              </div>
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '10px', marginTop: '24px' }}>
              <button
                type="button"
                onClick={() => setEditingUser(null)}
                style={{
                  padding: '9px 18px', borderRadius: '10px', background: '#282828',
                  color: '#B3B3B3', fontSize: '13px', fontWeight: 600,
                }}
              >
                Cancelar
              </button>
              <button
                type="submit"
                disabled={isSubmitting}
                style={{
                  padding: '9px 20px', borderRadius: '10px', background: '#FA243C',
                  color: '#fff', fontSize: '13px', fontWeight: 700,
                }}
              >
                {isSubmitting ? 'Guardando...' : 'Guardar Cambios'}
              </button>
            </div>
          </form>
        </div>
      )}

      {/* 5. DELETE CONFIRMATION DIALOG */}
      {userToDelete && (
        <div style={{
          position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.85)', backdropFilter: 'blur(20px)',
          display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 100, padding: '20px',
        }}>
          <div style={{
            background: '#181818', border: '0.5px solid #282828', borderRadius: '20px',
            width: '100%', maxWidth: '400px', padding: '28px', textAlign: 'center',
            boxShadow: '0 24px 60px rgba(0,0,0,0.8)',
          }}>
            <div style={{
              width: '48px', height: '48px', borderRadius: '50%', background: 'rgba(255,59,48,0.15)',
              display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 16px',
            }}>
              <Trash2 size={24} style={{ color: '#FF3B30' }} />
            </div>

            <h3 style={{ fontSize: '19px', fontWeight: 700, letterSpacing: '-0.3px', marginBottom: '8px' }}>
              ¿Eliminar usuario?
            </h3>
            <p style={{ fontSize: '14px', color: '#B3B3B3', marginBottom: '24px', lineHeight: 1.4 }}>
              Se eliminará permanentemente la cuenta de <strong style={{ color: '#fff' }}>{userToDelete.name}</strong> ({userToDelete.email}) y todas sus playlists y favoritos en MySQL.
            </p>

            <div style={{ display: 'flex', justifyContent: 'center', gap: '10px' }}>
              <button
                onClick={() => setUserToDelete(null)}
                disabled={isSubmitting}
                style={{
                  padding: '10px 18px', borderRadius: '10px', background: '#282828',
                  color: '#B3B3B3', fontSize: '13px', fontWeight: 600,
                }}
              >
                Cancelar
              </button>
              <button
                onClick={handleConfirmDelete}
                disabled={isSubmitting}
                style={{
                  padding: '10px 20px', borderRadius: '10px', background: '#FF3B30',
                  color: '#fff', fontSize: '13px', fontWeight: 700,
                }}
              >
                {isSubmitting ? 'Eliminando...' : 'Eliminar Cuenta'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
