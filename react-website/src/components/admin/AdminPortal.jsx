import React, { useState, useEffect, useCallback } from 'react';
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
} from 'lucide-react';
import { adminApi } from '../../services/api';
import { useAuth } from '../../context/AuthContext';

export const AdminPortal = ({ onBackToPlayer }) => {
  const { user: currentUser, isAdmin, isAuthenticated, login, logout } = useAuth();

  // Navigation tab in Admin Sidebar: 'users' | 'sessions' | 'metrics'
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
  const [isLoading, setIsLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [roleFilter, setRoleFilter] = useState('all');
  const [statusFilter, setStatusFilter] = useState('all');

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

  const fetchData = useCallback(async () => {
    if (!isAuthorized) return;
    setIsLoading(true);
    setActionMessage(null);
    try {
      const [metricsRes, usersRes, sessionsRes] = await Promise.all([
        adminApi.getMetrics().catch(() => ({ metrics: null })),
        adminApi.getUsers({ q: searchQuery, role: roleFilter, status: statusFilter }).catch(() => ({ users: [] })),
        adminApi.getSessions(100).catch(() => ({ sessions: [] })),
      ]);

      if (metricsRes?.metrics) setMetrics(metricsRes.metrics);
      if (usersRes?.users) setUsers(usersRes.users);
      if (sessionsRes?.sessions) setSessions(sessionsRes.sessions);
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
    }
  }, [isAuthorized, fetchData]);

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
      setActionMessage({ type: 'success', text: `Usuario ${userToDelete.name} eliminado.` });
      fetchData();
    } catch (err) {
      alert('Error al eliminar: ' + err.message);
    } finally {
      setIsSubmitting(false);
    }
  };

  const getDeviceIcon = (os = '', browser = '', deviceType = '') => {
    const osLower = (os || '').toLowerCase();
    if (osLower.includes('android') || osLower.includes('ios') || osLower.includes('iphone') || deviceType === 'Mobile') {
      return <Smartphone size={16} style={{ color: '#FA243C' }} />;
    }
    if (osLower.includes('ipad') || deviceType === 'Tablet') {
      return <Tablet size={16} style={{ color: '#FA243C' }} />;
    }
    if (osLower.includes('windows') || osLower.includes('mac') || osLower.includes('linux')) {
      return <Laptop size={16} style={{ color: '#FA243C' }} />;
    }
    return <Globe size={16} style={{ color: '#B3B3B3' }} />;
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
            Inicia sesión con tu cuenta de administrador de Groovy para acceder a la gestión de usuarios.
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

  return (
    <div style={{ display: 'flex', minHeight: '100vh', background: '#000000', color: '#ffffff' }}>
      {/* 1. GROOVY NATIVE SIDEBAR (Matches Sidebar.jsx exactly) */}
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
            <p style={{ fontSize: '11px', color: '#B3B3B3', marginTop: '1px' }}>Gestión de Nube</p>
          </div>
        </div>

        {/* Section Label */}
        <div style={{ padding: '4px 12px 8px' }}>
          <span style={{ fontSize: '11px', fontWeight: 700, letterSpacing: '0.06em', color: '#6B6B6B', textTransform: 'uppercase' }}>
            Panel de Control
          </span>
        </div>

        {/* Navigation Items (Exact Groovy style) */}
        <nav style={{ display: 'flex', flexDirection: 'column', gap: '2px', marginBottom: '16px' }}>
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
        {onBackToPlayer && (
          <button
            onClick={onBackToPlayer}
            style={{
              display: 'flex', alignItems: 'center', gap: '12px',
              width: '100%', padding: '10px 12px', borderRadius: '8px',
              fontSize: '14px', fontWeight: 500, color: '#B3B3B3',
              background: 'transparent', textAlign: 'left', transition: 'all 0.15s',
            }}
            onMouseEnter={e => { e.currentTarget.style.color = '#fff'; e.currentTarget.style.background = '#181818'; }}
            onMouseLeave={e => { e.currentTarget.style.color = '#B3B3B3'; e.currentTarget.style.background = 'transparent'; }}
          >
            <ArrowLeft size={18} style={{ color: '#FA243C', flexShrink: 0 }} />
            <span>Volver a Groovy</span>
          </button>
        )}

        {/* Bottom: Current Admin Profile Card */}
        <div style={{ marginTop: 'auto', padding: '12px 8px', borderTop: '0.5px solid #282828' }}>
          <div style={{
            display: 'flex', alignItems: 'center', justifyContent: 'space-between',
            padding: '8px 10px', background: '#181818', borderRadius: '10px',
            border: '0.5px solid #282828',
          }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '10px', minWidth: 0 }}>
              <div style={{
                width: '32px', height: '32px', borderRadius: '50%', background: '#FA243C',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                fontWeight: 700, fontSize: '13px', color: '#fff', flexShrink: 0,
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
        {/* Top Header (Matches Header.jsx exactly) */}
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
          {/* Search bar (styled exactly like desktop-search in Header.jsx) */}
          <div style={{
            flex: 1, maxWidth: '420px',
            display: 'flex', alignItems: 'center', gap: '10px',
            background: '#282828', borderRadius: '8px', padding: '8px 14px',
            border: '0.5px solid #404040',
          }}>
            <Search size={15} style={{ color: '#B3B3B3', flexShrink: 0 }} />
            <input
              type="text"
              placeholder="Buscar por nombre, correo, IP o dispositivo..."
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
            {/* Live VPS MySQL Connection Status pill */}
            <div style={{
              display: 'flex', alignItems: 'center', gap: '6px',
              background: '#181818', border: '0.5px solid #404040',
              borderRadius: '20px', padding: '5px 12px',
              fontSize: '12px', color: '#B3B3B3',
            }}>
              <div style={{ width: '8px', height: '8px', borderRadius: '50%', background: '#34C759' }} />
              <span style={{ fontWeight: 500 }}>MySQL Cloud Conectado</span>
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
        <main style={{ padding: '32px', maxWidth: '1200px', width: '100%', margin: '0 auto', boxSizing: 'border-box' }}>
          {/* Header Title Section */}
          <div style={{ marginBottom: '24px' }}>
            <h1 style={{ fontSize: '28px', fontWeight: 700, letterSpacing: '-0.5px', marginBottom: '6px' }}>
              {activeTab === 'users' && 'Usuarios Registrados'}
              {activeTab === 'sessions' && 'Auditoría de Dispositivos e IPs'}
              {activeTab === 'metrics' && 'Top Canciones en Streaming'}
            </h1>
            <p style={{ fontSize: '14px', color: '#B3B3B3' }}>
              Base de datos en tiempo real de Groovy en el servidor de producción.
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

          {/* GROOVY METRICS STRIP (Cohesive & Clean, Apple Music / Spotify for Artists style) */}
          <div style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
            gap: '12px',
            marginBottom: '28px',
          }}>
            <div style={{
              background: '#181818', borderRadius: '12px', border: '0.5px solid #282828',
              padding: '18px 20px',
            }}>
              <span style={{ fontSize: '12px', color: '#B3B3B3', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.04em' }}>
                Usuarios Totales
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
                Sesiones Registradas
              </span>
              <div style={{ fontSize: '28px', fontWeight: 700, color: '#fff', marginTop: '6px' }}>
                {metrics?.totalSessions ?? sessions.length}
              </div>
              <p style={{ fontSize: '12px', color: '#B3B3B3', marginTop: '4px' }}>
                Inicios de sesión con IP y dispositivo
              </p>
            </div>

            <div style={{
              background: '#181818', borderRadius: '12px', border: '0.5px solid #282828',
              padding: '18px 20px',
            }}>
              <span style={{ fontSize: '12px', color: '#B3B3B3', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.04em' }}>
                Favoritos en Nube
              </span>
              <div style={{ fontSize: '28px', fontWeight: 700, color: '#fff', marginTop: '6px' }}>
                {metrics?.totalFavorites ?? 0}
              </div>
              <p style={{ fontSize: '12px', color: '#B3B3B3', marginTop: '4px' }}>
                Canciones guardadas por usuarios
              </p>
            </div>

            <div style={{
              background: '#181818', borderRadius: '12px', border: '0.5px solid #282828',
              padding: '18px 20px',
            }}>
              <span style={{ fontSize: '12px', color: '#B3B3B3', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.04em' }}>
                Reproducciones
              </span>
              <div style={{ fontSize: '28px', fontWeight: 700, color: '#fff', marginTop: '6px' }}>
                {metrics?.totalPlays ?? 0}
              </div>
              <p style={{ fontSize: '12px', color: '#B3B3B3', marginTop: '4px' }}>
                Streams totales sincronizados
              </p>
            </div>
          </div>

          {/* TAB 1: USERS */}
          {activeTab === 'users' && (
            <div>
              {/* Segmented Filter Pills (exact Apple Music / LibraryView style) */}
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

                <div style={{ display: 'flex', gap: '8px' }}>
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
              </div>

              {/* Users List (Styled as Groovy Music Rows / Apple Music Tracklist) */}
              <div style={{
                background: '#181818',
                borderRadius: '16px',
                border: '0.5px solid #282828',
                overflow: 'hidden',
              }}>
                {/* List Header */}
                <div style={{
                  display: 'grid',
                  gridTemplateColumns: 'minmax(220px, 2fr) 130px 180px 140px 160px',
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
                  <div>Última IP y Dispositivo</div>
                  <div>Biblioteca</div>
                  <div style={{ textAlign: 'right' }}>Acciones</div>
                </div>

                {/* User Rows */}
                {users.map((u) => (
                  <div
                    key={u.id}
                    style={{
                      display: 'grid',
                      gridTemplateColumns: 'minmax(220px, 2fr) 130px 180px 140px 160px',
                      alignItems: 'center',
                      padding: '14px 20px',
                      borderBottom: '0.5px solid #202020',
                      transition: 'background 0.15s',
                    }}
                    onMouseEnter={e => e.currentTarget.style.background = '#202020'}
                    onMouseLeave={e => e.currentTarget.style.background = 'transparent'}
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

                    {/* IP & Device */}
                    <div style={{ minWidth: 0, paddingRight: '12px' }}>
                      {u.lastLoginIp ? (
                        <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                          <span style={{
                            fontFamily: 'monospace', fontSize: '12px', background: '#282828',
                            padding: '2px 6px', borderRadius: '4px', color: '#fff',
                          }}>
                            {u.lastLoginIp}
                          </span>
                          <button
                            onClick={() => copyToClipboard(u.lastLoginIp)}
                            title="Copiar dirección IP"
                            style={{ color: '#6B6B6B', padding: '2px' }}
                            onMouseEnter={e => e.currentTarget.style.color = '#fff'}
                            onMouseLeave={e => e.currentTarget.style.color = '#6B6B6B'}
                          >
                            {copiedIp === u.lastLoginIp ? <Check size={12} style={{ color: '#34C759' }} /> : <Copy size={12} />}
                          </button>
                        </div>
                      ) : (
                        <span style={{ fontSize: '12px', color: '#6B6B6B' }}>Sin registros</span>
                      )}

                      <div style={{ display: 'flex', alignItems: 'center', gap: '6px', marginTop: '3px' }}>
                        {getDeviceIcon(u.lastDevice)}
                        <span style={{ fontSize: '12px', color: '#B3B3B3', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                          {u.lastDevice || 'Dispositivo no reg.'}
                        </span>
                      </div>
                    </div>

                    {/* Library Stats */}
                    <div style={{ display: 'flex', alignItems: 'center', gap: '10px', fontSize: '12px', color: '#B3B3B3' }}>
                      <span title="Favoritos" style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
                        <Heart size={13} style={{ color: '#FF375F' }} /> {u.stats?.favorites || 0}
                      </span>
                      <span title="Playlists" style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
                        <ListMusic size={13} style={{ color: '#FA243C' }} /> {u.stats?.playlists || 0}
                      </span>
                      <span title="Plays" style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
                        <Music size={13} style={{ color: '#AF52DE' }} /> {u.stats?.plays || 0}
                      </span>
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
                ))}

                {users.length === 0 && !isLoading && (
                  <div style={{ padding: '48px 24px', textAlign: 'center', color: '#6B6B6B' }}>
                    <Users size={32} style={{ margin: '0 auto 12px', opacity: 0.4 }} />
                    <p style={{ fontSize: '15px', fontWeight: 600, color: '#B3B3B3' }}>No se encontraron usuarios</p>
                    <p style={{ fontSize: '13px', marginTop: '4px' }}>Prueba con otro término de búsqueda o cambia los filtros.</p>
                  </div>
                )}
              </div>
            </div>
          )}

          {/* TAB 2: SESSIONS & IP AUDIT */}
          {activeTab === 'sessions' && (
            <div style={{
              background: '#181818',
              borderRadius: '16px',
              border: '0.5px solid #282828',
              overflow: 'hidden',
            }}>
              <div style={{ padding: '18px 24px', borderBottom: '0.5px solid #282828' }}>
                <h3 style={{ fontSize: '16px', fontWeight: 700, letterSpacing: '-0.3px' }}>Registro de Conexiones en Vivo</h3>
                <p style={{ fontSize: '13px', color: '#B3B3B3', marginTop: '3px' }}>
                  Auditoría completa de direcciones IP, sistemas operativos, navegadores y marcas de tiempo de cada usuario.
                </p>
              </div>

              {/* Table header */}
              <div style={{
                display: 'grid',
                gridTemplateColumns: 'minmax(200px, 1.8fr) 160px 180px 140px 160px',
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
                <div>Dispositivo & SO</div>
                <div>Navegador</div>
                <div>Fecha y Hora</div>
              </div>

              {/* Sessions list */}
              {sessions.map((s) => (
                <div
                  key={s.id}
                  style={{
                    display: 'grid',
                    gridTemplateColumns: 'minmax(200px, 1.8fr) 160px 180px 140px 160px',
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

                  {/* Device & OS */}
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px', minWidth: 0 }}>
                    {getDeviceIcon(s.device_os, s.browser, s.device_type)}
                    <span style={{ fontSize: '13px', color: '#B3B3B3', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                      {s.device_os || 'Desconocido'}
                    </span>
                  </div>

                  {/* Browser */}
                  <div style={{ fontSize: '13px', color: '#B3B3B3' }}>
                    {s.browser || 'Web Client'}
                  </div>

                  {/* Timestamp */}
                  <div style={{ fontSize: '12px', color: '#6B6B6B' }}>
                    {s.created_at ? new Date(s.created_at).toLocaleString() : '—'}
                  </div>
                </div>
              ))}

              {sessions.length === 0 && (
                <div style={{ padding: '48px 24px', textAlign: 'center', color: '#6B6B6B' }}>
                  <Activity size={32} style={{ margin: '0 auto 12px', opacity: 0.4 }} />
                  <p style={{ fontSize: '15px', fontWeight: 600, color: '#B3B3B3' }}>Sin conexiones registradas</p>
                  <p style={{ fontSize: '13px', marginTop: '4px' }}>Los inicios de sesión quedarán auditados aquí automáticamente.</p>
                </div>
              )}
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

      {/* 3. CUPERTINO MODAL: USER DETAILS INSPECTOR ("Ver Todo") */}
      {selectedUser && (
        <div style={{
          position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.85)', backdropFilter: 'blur(20px)',
          display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 100, padding: '20px',
        }}>
          <div style={{
            background: '#181818', border: '0.5px solid #282828', borderRadius: '20px',
            width: '100%', maxWidth: '720px', maxHeight: '88vh', overflowY: 'auto', padding: '28px',
            boxShadow: '0 24px 60px rgba(0,0,0,0.8)',
          }}>
            {/* Header */}
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '24px' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
                <div style={{
                  width: '52px', height: '52px', borderRadius: '50%', background: '#FA243C',
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  fontSize: '22px', fontWeight: 700, color: '#fff',
                }}>
                  {selectedUser.user.name?.charAt(0).toUpperCase() || 'U'}
                </div>
                <div>
                  <h2 style={{ fontSize: '20px', fontWeight: 700, letterSpacing: '-0.3px' }}>{selectedUser.user.name}</h2>
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

            {/* Quick Meta Grid */}
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '10px', marginBottom: '24px' }}>
              <div style={{ background: '#282828', padding: '12px 14px', borderRadius: '10px' }}>
                <span style={{ fontSize: '11px', color: '#B3B3B3', textTransform: 'uppercase', fontWeight: 600 }}>Rol</span>
                <p style={{ fontSize: '14px', fontWeight: 700, marginTop: '3px', color: selectedUser.user.role === 'admin' ? '#FA243C' : '#fff' }}>
                  {selectedUser.user.role === 'admin' ? 'Administrador' : 'Usuario'}
                </p>
              </div>
              <div style={{ background: '#282828', padding: '12px 14px', borderRadius: '10px' }}>
                <span style={{ fontSize: '11px', color: '#B3B3B3', textTransform: 'uppercase', fontWeight: 600 }}>Estado</span>
                <p style={{ fontSize: '14px', fontWeight: 700, marginTop: '3px', color: selectedUser.user.isBanned ? '#FF3B30' : '#34C759' }}>
                  {selectedUser.user.isBanned ? 'Suspendido' : 'Activo'}
                </p>
              </div>
              <div style={{ background: '#282828', padding: '12px 14px', borderRadius: '10px' }}>
                <span style={{ fontSize: '11px', color: '#B3B3B3', textTransform: 'uppercase', fontWeight: 600 }}>Última IP</span>
                <p style={{ fontSize: '13px', fontWeight: 700, marginTop: '3px', fontFamily: 'monospace' }}>
                  {selectedUser.user.lastLoginIp || '—'}
                </p>
              </div>
              <div style={{ background: '#282828', padding: '12px 14px', borderRadius: '10px' }}>
                <span style={{ fontSize: '11px', color: '#B3B3B3', textTransform: 'uppercase', fontWeight: 600 }}>Registro</span>
                <p style={{ fontSize: '13px', fontWeight: 700, marginTop: '3px' }}>
                  {new Date(selectedUser.user.createdAt).toLocaleDateString()}
                </p>
              </div>
            </div>

            {/* Sessions / Devices list */}
            <div style={{ marginBottom: '24px' }}>
              <h4 style={{ fontSize: '12px', fontWeight: 700, color: '#B3B3B3', textTransform: 'uppercase', letterSpacing: '0.06em', marginBottom: '10px' }}>
                Dispositivos e IPs Utilizados ({selectedUser.sessions?.length || 0})
              </h4>
              <div style={{ background: '#282828', borderRadius: '10px', maxHeight: '160px', overflowY: 'auto' }}>
                {selectedUser.sessions?.map((s) => (
                  <div key={s.id} style={{
                    display: 'flex', alignItems: 'center', justifyContent: 'space-between',
                    padding: '10px 14px', borderBottom: '0.5px solid #333', fontSize: '13px',
                  }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                      {getDeviceIcon(s.device_os)}
                      <span style={{ fontWeight: 600, color: '#fff' }}>{s.device_os || 'Dispositivo'}</span>
                      <span style={{ color: '#B3B3B3', fontSize: '12px' }}>({s.browser || 'Web'})</span>
                    </div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                      <code style={{ fontSize: '12px', background: '#181818', padding: '2px 6px', borderRadius: '4px' }}>{s.ip_address}</code>
                      <span style={{ color: '#6B6B6B', fontSize: '11px' }}>{new Date(s.created_at).toLocaleDateString()}</span>
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
