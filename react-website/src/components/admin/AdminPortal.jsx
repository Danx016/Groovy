import React, { useState, useEffect, useCallback } from 'react';
import {
  ShieldCheck,
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
  Edit3,
  Trash2,
  Ban,
  CheckCircle2,
  XCircle,
  Copy,
  Check,
  Calendar,
  Clock,
  Key,
  Mail,
  User,
  AlertTriangle,
  X,
  Play,
  History,
  Activity,
  ChevronRight,
  TrendingUp,
  LogOut,
  ArrowLeft,
  ExternalLink,
  ShieldAlert,
} from 'lucide-react';
import { adminApi } from '../../services/api';
import { useAuth } from '../../context/AuthContext';

export const AdminPortal = ({ onBackToPlayer }) => {
  const { user: currentUser, isAdmin, isAuthenticated, login, logout } = useAuth();

  // Navigation inside Admin Portal
  const [adminTab, setAdminTab] = useState('users'); // 'users' | 'sessions' | 'metrics'

  // Admin login form state
  const [adminEmail, setAdminEmail] = useState('');
  const [adminPassword, setAdminPassword] = useState('');
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

  // Modals & Action State
  const [selectedUserDetail, setSelectedUserDetail] = useState(null);
  const [isLoadingDetail, setIsLoadingDetail] = useState(false);
  const [editingUser, setEditingUser] = useState(null);
  const [editFormData, setEditFormData] = useState({ name: '', email: '', role: 'user', password: '' });
  const [userToDelete, setUserToDelete] = useState(null);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [actionMessage, setActionMessage] = useState(null);
  const [copiedIp, setCopiedIp] = useState(null);

  // Check if current user is admin or primary admin email
  const isAuthorized = isAdmin || currentUser?.email === 'danilorodelo355@gmail.com';

  const copyToClipboard = (text) => {
    navigator.clipboard?.writeText(text);
    setCopiedIp(text);
    setTimeout(() => setCopiedIp(null), 2000);
  };

  const handleLoginSubmit = async (e) => {
    e.preventDefault();
    setLoginError(null);
    setIsLoggingIn(true);
    try {
      await login(adminEmail.trim(), adminPassword);
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
        adminApi.getMetrics().catch(err => {
          console.warn('[Admin API] metrics error:', err.message);
          return { error: err.message };
        }),
        adminApi.getUsers({ q: searchQuery, role: roleFilter, status: statusFilter }).catch(err => {
          console.warn('[Admin API] users error:', err.message);
          return { error: err.message, users: [] };
        }),
        adminApi.getSessions(100).catch(err => {
          console.warn('[Admin API] sessions error:', err.message);
          return { error: err.message, sessions: [] };
        }),
      ]);

      if (usersRes?.error && usersRes.error.includes('404')) {
        setActionMessage({
          type: 'error',
          text: 'El backend en el servidor VPS aún no tiene desplegado el módulo de administración (/api/admin). Realiza un git pull y reinicia el servicio en el VPS.',
        });
      }

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
    setSelectedUserDetail(null);
    try {
      const data = await adminApi.getUserDetails(userId);
      setSelectedUserDetail(data);
    } catch (err) {
      alert('Error al cargar detalles del usuario: ' + err.message);
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
        name: editFormData.name,
        email: editFormData.email,
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
      ? `¿Estás seguro de suspender el acceso a ${user.name} (${user.email})?`
      : `¿Deseas reactivar la cuenta de ${user.name}?`;
    if (!window.confirm(confirmMsg)) return;

    try {
      await adminApi.toggleBanUser(user.id, nextStatus);
      fetchData();
      if (selectedUserDetail?.user?.id === user.id) {
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
      if (selectedUserDetail?.user?.id === userToDelete.id) {
        setSelectedUserDetail(null);
      }
      setActionMessage({ type: 'success', text: `Usuario ${userToDelete.name} eliminado permanentemente.` });
      fetchData();
    } catch (err) {
      alert('Error al eliminar usuario: ' + err.message);
    } finally {
      setIsSubmitting(false);
    }
  };

  const getDeviceIcon = (os = '', browser = '', deviceType = '') => {
    const osLower = (os || '').toLowerCase();
    if (osLower.includes('android') || osLower.includes('ios') || deviceType === 'Mobile') {
      return <Smartphone size={16} style={{ color: '#30D158' }} />;
    }
    if (osLower.includes('ipad') || deviceType === 'Tablet') {
      return <Tablet size={16} style={{ color: '#0A84FF' }} />;
    }
    if (osLower.includes('windows')) {
      return <Laptop size={16} style={{ color: '#0078D7' }} />;
    }
    if (osLower.includes('mac')) {
      return <Laptop size={16} style={{ color: '#E0E0E0' }} />;
    }
    if (osLower.includes('linux')) {
      return <Laptop size={16} style={{ color: '#FF9500' }} />;
    }
    return <Globe size={16} style={{ color: '#999999' }} />;
  };

  // If not authorized / not logged in: Dedicated Standalone Admin Login Page
  if (!isAuthenticated || !isAuthorized) {
    return (
      <div style={{
        minHeight: '100vh', width: '100vw', background: '#09090B', color: '#fff',
        display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
        padding: '24px', fontFamily: 'system-ui, -apple-system, sans-serif',
      }}>
        <div style={{
          background: '#141417', border: '1px solid #27272A', borderRadius: '24px',
          width: '100%', maxWidth: '440px', padding: '36px 32px',
          boxShadow: '0 25px 60px rgba(0,0,0,0.7)',
        }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '12px', marginBottom: '20px' }}>
            <div style={{
              width: '50px', height: '50px', borderRadius: '14px',
              background: 'linear-gradient(135deg, #FF9500, #FA243C)',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              boxShadow: '0 6px 20px rgba(250,36,60,0.4)',
            }}>
              <ShieldCheck size={28} color="#fff" />
            </div>
            <div>
              <h1 style={{ fontSize: '22px', fontWeight: 800, letterSpacing: '-0.4px' }}>Groovy Admin</h1>
              <p style={{ fontSize: '12px', color: '#A1A1AA' }}>Portal de Control y Auditoría</p>
            </div>
          </div>

          {isAuthenticated && !isAuthorized ? (
            <div style={{
              background: 'rgba(255,69,58,0.12)', border: '1px solid rgba(255,69,58,0.25)',
              borderRadius: '12px', padding: '16px', marginBottom: '20px', textAlign: 'center',
            }}>
              <ShieldAlert size={26} color="#FF453A" style={{ margin: '0 auto 8px' }} />
              <h3 style={{ fontSize: '15px', fontWeight: 700, color: '#FF453A' }}>Acceso Restringido</h3>
              <p style={{ fontSize: '13px', color: '#D4D4D8', marginTop: '4px' }}>
                Tu cuenta ({currentUser?.email}) no tiene permisos de administrador. Por favor inicia sesión con las credenciales maestras.
              </p>
              <button
                onClick={logout}
                style={{
                  marginTop: '14px', padding: '8px 16px', borderRadius: '8px',
                  background: '#27272A', color: '#fff', border: 'none', fontSize: '12px', fontWeight: 600, cursor: 'pointer',
                }}
              >
                Cerrar sesión e ingresar como Admin
              </button>
            </div>
          ) : (
            <>
              <p style={{ fontSize: '14px', color: '#A1A1AA', textAlign: 'center', marginBottom: '24px' }}>
                Ingresa con tu cuenta de administrador para acceder al panel de gestión y monitoreo.
              </p>

              {loginError && (
                <div style={{
                  padding: '12px', borderRadius: '10px', background: 'rgba(255,59,48,0.15)',
                  border: '1px solid rgba(255,59,48,0.3)', color: '#FF453A', fontSize: '13px',
                  marginBottom: '18px', textAlign: 'left',
                }}>
                  {loginError}
                </div>
              )}

              <form onSubmit={handleLoginSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 600, color: '#D4D4D8', marginBottom: '6px' }}>
                    Correo Electrónico
                  </label>
                  <input
                    type="email"
                    required
                    placeholder="ej. danilorodelo355@gmail.com"
                    value={adminEmail}
                    onChange={e => setAdminEmail(e.target.value)}
                    style={{
                      width: '100%', background: '#09090B', border: '1px solid #3F3F46',
                      borderRadius: '10px', padding: '12px 14px', color: '#fff', fontSize: '14px',
                      outline: 'none', boxSizing: 'border-box',
                    }}
                  />
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: 600, color: '#D4D4D8', marginBottom: '6px' }}>
                    Contraseña
                  </label>
                  <input
                    type="password"
                    required
                    placeholder="••••••••"
                    value={adminPassword}
                    onChange={e => setAdminPassword(e.target.value)}
                    style={{
                      width: '100%', background: '#09090B', border: '1px solid #3F3F46',
                      borderRadius: '10px', padding: '12px 14px', color: '#fff', fontSize: '14px',
                      outline: 'none', boxSizing: 'border-box',
                    }}
                  />
                </div>

                <button
                  type="submit"
                  disabled={isLoggingIn}
                  style={{
                    marginTop: '8px', width: '100%', padding: '14px', borderRadius: '12px',
                    background: 'linear-gradient(135deg, #FA243C, #FF375F)', color: '#fff',
                    fontWeight: 700, fontSize: '15px', border: 'none', cursor: 'pointer',
                    boxShadow: '0 4px 20px rgba(250,36,60,0.35)', transition: 'all 0.2s',
                  }}
                >
                  {isLoggingIn ? 'Verificando...' : 'Iniciar Sesión en el Panel'}
                </button>
              </form>
            </>
          )}

          {onBackToPlayer && (
            <button
              onClick={onBackToPlayer}
              style={{
                marginTop: '20px', width: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '6px',
                background: 'none', border: 'none', color: '#A1A1AA', fontSize: '13px', cursor: 'pointer',
              }}
            >
              <ArrowLeft size={14} /> Volver a Groovy Music Player
            </button>
          )}
        </div>
      </div>
    );
  }

  // Standalone Full-Screen Admin Dashboard
  return (
    <div style={{
      minHeight: '100vh', width: '100vw', background: '#09090B', color: '#fff',
      fontFamily: 'system-ui, -apple-system, sans-serif', display: 'flex', flexDirection: 'column',
    }}>
      {/* Standalone Top Bar */}
      <header style={{
        height: '64px', background: '#121215', borderBottom: '1px solid #27272A',
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        padding: '0 24px', position: 'sticky', top: 0, zIndex: 50,
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
          <div style={{
            width: '38px', height: '38px', borderRadius: '10px',
            background: 'linear-gradient(135deg, #FF9500, #FA243C)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            boxShadow: '0 4px 12px rgba(250,36,60,0.3)',
          }}>
            <ShieldCheck size={22} color="#fff" />
          </div>
          <div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <span style={{ fontSize: '17px', fontWeight: 800, letterSpacing: '-0.3px' }}>Groovy Admin Portal</span>
              <span style={{ fontSize: '10px', background: '#FF9500', color: '#000', padding: '1px 6px', borderRadius: '8px', fontWeight: 800 }}>
                CONSOLE
              </span>
            </div>
            <span style={{ fontSize: '11px', color: '#A1A1AA' }}>Servidor MySQL VPS 157.137.233.119</span>
          </div>
        </div>

        {/* Center Nav tabs */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
          <button
            onClick={() => setAdminTab('users')}
            style={{
              padding: '8px 16px', borderRadius: '10px', border: 'none',
              background: adminTab === 'users' ? '#27272A' : 'transparent',
              color: adminTab === 'users' ? '#fff' : '#A1A1AA',
              fontSize: '13px', fontWeight: 600, cursor: 'pointer',
            }}
          >
            👥 Usuarios ({users.length})
          </button>
          <button
            onClick={() => setAdminTab('sessions')}
            style={{
              padding: '8px 16px', borderRadius: '10px', border: 'none',
              background: adminTab === 'sessions' ? '#27272A' : 'transparent',
              color: adminTab === 'sessions' ? '#fff' : '#A1A1AA',
              fontSize: '13px', fontWeight: 600, cursor: 'pointer',
            }}
          >
            🌐 Dispositivos e IPs ({sessions.length})
          </button>
          <button
            onClick={() => setAdminTab('metrics')}
            style={{
              padding: '8px 16px', borderRadius: '10px', border: 'none',
              background: adminTab === 'metrics' ? '#27272A' : 'transparent',
              color: adminTab === 'metrics' ? '#fff' : '#A1A1AA',
              fontSize: '13px', fontWeight: 600, cursor: 'pointer',
            }}
          >
            📊 Estadísticas
          </button>
        </div>

        {/* Right Admin Controls */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
          <button
            onClick={fetchData}
            disabled={isLoading}
            title="Refrescar datos del servidor"
            style={{
              display: 'flex', alignItems: 'center', gap: '6px',
              padding: '7px 12px', borderRadius: '8px',
              background: '#1C1C20', border: '1px solid #2E2E33',
              color: '#D4D4D8', fontSize: '12px', fontWeight: 600, cursor: 'pointer',
            }}
          >
            <RefreshCw size={13} className={isLoading ? 'animate-spin' : ''} />
            <span>Refrescar</span>
          </button>

          {onBackToPlayer && (
            <button
              onClick={onBackToPlayer}
              style={{
                display: 'flex', alignItems: 'center', gap: '5px',
                padding: '7px 12px', borderRadius: '8px',
                background: '#1C1C20', border: '1px solid #2E2E33',
                color: '#D4D4D8', fontSize: '12px', fontWeight: 600, cursor: 'pointer',
              }}
            >
              <ExternalLink size={13} />
              <span>Ir a la App Web</span>
            </button>
          )}

          <div style={{ display: 'flex', alignItems: 'center', gap: '8px', paddingLeft: '8px', borderLeft: '1px solid #27272A' }}>
            <div style={{
              width: '32px', height: '32px', borderRadius: '50%', background: '#FA243C',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              fontSize: '13px', fontWeight: 700, color: '#fff',
            }}>
              {currentUser?.name?.charAt(0).toUpperCase() || 'A'}
            </div>
            <button
              onClick={logout}
              title="Cerrar sesión de administrador"
              style={{
                display: 'flex', alignItems: 'center', gap: '4px',
                padding: '6px 10px', borderRadius: '8px',
                background: 'rgba(255,59,48,0.12)', border: '1px solid rgba(255,59,48,0.2)',
                color: '#FF453A', fontSize: '12px', fontWeight: 600, cursor: 'pointer',
              }}
            >
              <LogOut size={13} />
              <span>Salir</span>
            </button>
          </div>
        </div>
      </header>

      {/* Main Content Area */}
      <main style={{ flex: 1, padding: '24px 32px', maxWidth: '1440px', width: '100%', margin: '0 auto', boxSizing: 'border-box' }}>
        {/* KPI Metrics Strip */}
        <div style={{
          display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(210px, 1fr))',
          gap: '14px', marginBottom: '24px',
        }}>
          <div style={{ background: '#121215', borderRadius: '16px', padding: '18px', border: '1px solid #27272A' }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '8px' }}>
              <span style={{ fontSize: '12px', color: '#A1A1AA', fontWeight: 600, textTransform: 'uppercase' }}>Usuarios Totales</span>
              <Users size={18} style={{ color: '#0A84FF' }} />
            </div>
            <div style={{ fontSize: '28px', fontWeight: 800, color: '#fff' }}>{metrics?.totalUsers ?? users.length}</div>
            <div style={{ fontSize: '12px', color: '#34C759', marginTop: '4px', display: 'flex', alignItems: 'center', gap: '4px' }}>
              <TrendingUp size={12} /> {metrics?.activeToday ?? 0} activos hoy
            </div>
          </div>

          <div style={{ background: '#121215', borderRadius: '16px', padding: '18px', border: '1px solid #27272A' }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '8px' }}>
              <span style={{ fontSize: '12px', color: '#A1A1AA', fontWeight: 600, textTransform: 'uppercase' }}>Sesiones & IPs</span>
              <Activity size={18} style={{ color: '#30D158' }} />
            </div>
            <div style={{ fontSize: '28px', fontWeight: 800, color: '#fff' }}>{metrics?.totalSessions ?? sessions.length}</div>
            <div style={{ fontSize: '12px', color: '#A1A1AA', marginTop: '4px' }}>Conexiones registradas</div>
          </div>

          <div style={{ background: '#121215', borderRadius: '16px', padding: '18px', border: '1px solid #27272A' }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '8px' }}>
              <span style={{ fontSize: '12px', color: '#A1A1AA', fontWeight: 600, textTransform: 'uppercase' }}>Favoritos en Nube</span>
              <Heart size={18} style={{ color: '#FF375F' }} />
            </div>
            <div style={{ fontSize: '28px', fontWeight: 800, color: '#fff' }}>{metrics?.totalFavorites ?? 0}</div>
            <div style={{ fontSize: '12px', color: '#A1A1AA', marginTop: '4px' }}>Canciones guardadas</div>
          </div>

          <div style={{ background: '#121215', borderRadius: '16px', padding: '18px', border: '1px solid #27272A' }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '8px' }}>
              <span style={{ fontSize: '12px', color: '#A1A1AA', fontWeight: 600, textTransform: 'uppercase' }}>Playlists Creadas</span>
              <ListMusic size={18} style={{ color: '#FA243C' }} />
            </div>
            <div style={{ fontSize: '28px', fontWeight: 800, color: '#fff' }}>{metrics?.totalPlaylists ?? 0}</div>
            <div style={{ fontSize: '12px', color: '#A1A1AA', marginTop: '4px' }}>Colecciones de usuario</div>
          </div>

          <div style={{ background: '#121215', borderRadius: '16px', padding: '18px', border: '1px solid #27272A' }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '8px' }}>
              <span style={{ fontSize: '12px', color: '#A1A1AA', fontWeight: 600, textTransform: 'uppercase' }}>Reproducciones</span>
              <Music size={18} style={{ color: '#BF5AF2' }} />
            </div>
            <div style={{ fontSize: '28px', fontWeight: 800, color: '#fff' }}>{metrics?.totalPlays ?? 0}</div>
            <div style={{ fontSize: '12px', color: '#A1A1AA', marginTop: '4px' }}>Historial en streaming</div>
          </div>
        </div>

        {/* Alert Notification if any */}
        {actionMessage && (
          <div style={{
            padding: '12px 18px', borderRadius: '12px', marginBottom: '20px',
            background: actionMessage.type === 'success' ? 'rgba(52,199,89,0.15)' : 'rgba(255,59,48,0.15)',
            border: `1px solid ${actionMessage.type === 'success' ? 'rgba(52,199,89,0.3)' : 'rgba(255,59,48,0.3)'}`,
            color: actionMessage.type === 'success' ? '#34C759' : '#FF453A',
            display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          }}>
            <span style={{ fontSize: '14px', fontWeight: 600 }}>{actionMessage.text}</span>
            <button onClick={() => setActionMessage(null)} style={{ background: 'none', border: 'none', color: 'inherit', cursor: 'pointer' }}>
              <X size={16} />
            </button>
          </div>
        )}

        {/* TAB 1: USERS MANAGEMENT TABLE */}
        {adminTab === 'users' && (
          <div>
            {/* Search & Filter bar */}
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: '12px', marginBottom: '16px' }}>
              <div style={{
                display: 'flex', alignItems: 'center', gap: '10px',
                background: '#121215', border: '1px solid #27272A', borderRadius: '12px',
                padding: '10px 16px', flex: 1, minWidth: '260px', maxWidth: '520px',
              }}>
                <Search size={16} color="#A1A1AA" />
                <input
                  type="text"
                  placeholder="Buscar usuario por nombre, email, IP o dispositivo..."
                  value={searchQuery}
                  onChange={e => setSearchQuery(e.target.value)}
                  style={{
                    background: 'none', border: 'none', color: '#fff', fontSize: '13px',
                    width: '100%', outline: 'none',
                  }}
                />
                {searchQuery && (
                  <button onClick={() => setSearchQuery('')} style={{ background: 'none', border: 'none', color: '#A1A1AA', cursor: 'pointer' }}>
                    <X size={14} />
                  </button>
                )}
              </div>

              <div style={{ display: 'flex', alignItems: 'center', gap: '10px', flexWrap: 'wrap' }}>
                <select
                  value={roleFilter}
                  onChange={e => setRoleFilter(e.target.value)}
                  style={{
                    background: '#121215', border: '1px solid #27272A', borderRadius: '10px',
                    color: '#fff', padding: '9px 14px', fontSize: '13px', outline: 'none', cursor: 'pointer',
                  }}
                >
                  <option value="all">Todos los roles</option>
                  <option value="admin">Administradores</option>
                  <option value="user">Usuarios regulares</option>
                </select>

                <select
                  value={statusFilter}
                  onChange={e => setStatusFilter(e.target.value)}
                  style={{
                    background: '#121215', border: '1px solid #27272A', borderRadius: '10px',
                    color: '#fff', padding: '9px 14px', fontSize: '13px', outline: 'none', cursor: 'pointer',
                  }}
                >
                  <option value="all">Todos los estados</option>
                  <option value="active">Activos</option>
                  <option value="banned">Suspendidos</option>
                </select>
              </div>
            </div>

            {/* Users Table */}
            <div style={{
              background: '#121215', borderRadius: '18px', border: '1px solid #27272A',
              overflow: 'hidden', boxShadow: '0 8px 30px rgba(0,0,0,0.5)',
            }}>
              <div style={{ overflowX: 'auto' }}>
                <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left', minWidth: '920px' }}>
                  <thead>
                    <tr style={{ background: '#18181C', borderBottom: '1px solid #27272A', color: '#A1A1AA', fontSize: '11px', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
                      <th style={{ padding: '14px 18px' }}>Usuario</th>
                      <th style={{ padding: '14px 18px' }}>Rol / Estado</th>
                      <th style={{ padding: '14px 18px' }}>Última IP</th>
                      <th style={{ padding: '14px 18px' }}>Dispositivo</th>
                      <th style={{ padding: '14px 18px' }}>Biblioteca</th>
                      <th style={{ padding: '14px 18px' }}>Fecha Registro</th>
                      <th style={{ padding: '14px 18px', textAlign: 'right' }}>Acciones</th>
                    </tr>
                  </thead>
                  <tbody>
                    {users.map((u) => (
                      <tr
                        key={u.id}
                        style={{
                          borderBottom: '1px solid #1E1E22',
                          background: u.isBanned ? 'rgba(255,69,58,0.06)' : 'transparent',
                          transition: 'background 0.15s',
                        }}
                        onMouseEnter={e => e.currentTarget.style.background = u.isBanned ? 'rgba(255,69,58,0.12)' : '#18181C'}
                        onMouseLeave={e => e.currentTarget.style.background = u.isBanned ? 'rgba(255,69,58,0.06)' : 'transparent'}
                      >
                        {/* User Profile */}
                        <td style={{ padding: '14px 18px' }}>
                          <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                            <div style={{
                              width: '40px', height: '40px', borderRadius: '50%',
                              background: u.role === 'admin' ? 'linear-gradient(135deg, #FF9500, #FA243C)' : '#27272A',
                              display: 'flex', alignItems: 'center', justifyContent: 'center',
                              fontSize: '15px', fontWeight: 800, color: '#fff', flexShrink: 0,
                            }}>
                              {u.name?.charAt(0).toUpperCase() || 'U'}
                            </div>
                            <div>
                              <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                                <span style={{ fontSize: '14px', fontWeight: 700, color: '#fff' }}>{u.name}</span>
                                {currentUser?.id === u.id && (
                                  <span style={{ fontSize: '10px', background: '#FA243C', color: '#fff', padding: '1px 6px', borderRadius: '10px', fontWeight: 800 }}>
                                    Tú
                                  </span>
                                )}
                              </div>
                              <div style={{ fontSize: '12px', color: '#A1A1AA', marginTop: '2px' }}>{u.email}</div>
                            </div>
                          </div>
                        </td>

                        {/* Role & Status */}
                        <td style={{ padding: '14px 18px' }}>
                          <div style={{ display: 'flex', flexDirection: 'column', gap: '4px', alignItems: 'flex-start' }}>
                            <span style={{
                              fontSize: '11px', fontWeight: 700, padding: '2px 8px', borderRadius: '12px',
                              background: u.role === 'admin' ? 'rgba(255,149,0,0.15)' : 'rgba(255,255,255,0.08)',
                              color: u.role === 'admin' ? '#FF9500' : '#A1A1AA',
                              border: `1px solid ${u.role === 'admin' ? 'rgba(255,149,0,0.3)' : 'transparent'}`,
                            }}>
                              {u.role === 'admin' ? '👑 Admin' : '👤 Usuario'}
                            </span>

                            <span style={{
                              fontSize: '11px', fontWeight: 600,
                              color: u.isBanned ? '#FF453A' : '#34C759',
                              display: 'flex', alignItems: 'center', gap: '4px',
                            }}>
                              {u.isBanned ? <XCircle size={11} /> : <CheckCircle2 size={11} />}
                              {u.isBanned ? 'Suspendido' : 'Activo'}
                            </span>
                          </div>
                        </td>

                        {/* IP Address */}
                        <td style={{ padding: '14px 18px' }}>
                          {u.lastLoginIp ? (
                            <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                              <code style={{ fontSize: '12px', background: '#1E1E22', padding: '4px 8px', borderRadius: '6px', color: '#34C759', fontFamily: 'monospace' }}>
                                {u.lastLoginIp}
                              </code>
                              <button
                                onClick={() => copyToClipboard(u.lastLoginIp)}
                                title="Copiar IP"
                                style={{ background: 'none', border: 'none', color: '#A1A1AA', cursor: 'pointer', padding: '2px' }}
                              >
                                {copiedIp === u.lastLoginIp ? <Check size={13} color="#34C759" /> : <Copy size={13} />}
                              </button>
                            </div>
                          ) : (
                            <span style={{ fontSize: '12px', color: '#52525B' }}>Sin IP registrada</span>
                          )}
                        </td>

                        {/* Device */}
                        <td style={{ padding: '14px 18px' }}>
                          {u.lastDevice ? (
                            <div style={{ display: 'flex', alignItems: 'center', gap: '7px', fontSize: '13px', color: '#E4E4E7' }}>
                              {getDeviceIcon(u.lastDevice)}
                              <span style={{ maxWidth: '170px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                                {u.lastDevice}
                              </span>
                            </div>
                          ) : (
                            <span style={{ fontSize: '12px', color: '#52525B' }}>Desconocido</span>
                          )}
                        </td>

                        {/* Stats */}
                        <td style={{ padding: '14px 18px' }}>
                          <div style={{ display: 'flex', alignItems: 'center', gap: '10px', fontSize: '12px', color: '#A1A1AA' }}>
                            <span title="Favoritos" style={{ display: 'flex', alignItems: 'center', gap: '3px' }}>
                              <Heart size={12} style={{ color: '#FF375F' }} /> {u.stats?.favorites || 0}
                            </span>
                            <span title="Playlists" style={{ display: 'flex', alignItems: 'center', gap: '3px' }}>
                              <ListMusic size={12} style={{ color: '#FA243C' }} /> {u.stats?.playlists || 0}
                            </span>
                            <span title="Reproducciones" style={{ display: 'flex', alignItems: 'center', gap: '3px' }}>
                              <Music size={12} style={{ color: '#BF5AF2' }} /> {u.stats?.plays || 0}
                            </span>
                          </div>
                        </td>

                        {/* Registered Date */}
                        <td style={{ padding: '14px 18px', fontSize: '12px', color: '#A1A1AA' }}>
                          {u.createdAt ? new Date(u.createdAt).toLocaleDateString() : 'N/A'}
                        </td>

                        {/* Actions */}
                        <td style={{ padding: '14px 18px', textAlign: 'right' }}>
                          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'flex-end', gap: '6px' }}>
                            <button
                              onClick={() => handleOpenUserDetail(u.id)}
                              title="Ver información completa (IPs, dispositivos, canciones)"
                              style={{
                                padding: '6px 12px', borderRadius: '8px',
                                background: '#1E1E24', border: '1px solid #2E2E36',
                                color: '#fff', fontSize: '12px', fontWeight: 600,
                                cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '4px',
                              }}
                            >
                              <Search size={13} color="#0A84FF" />
                              <span>Ver Todo</span>
                            </button>

                            <button
                              onClick={() => handleOpenEdit(u)}
                              title="Editar usuario"
                              style={{
                                padding: '6px 8px', borderRadius: '8px',
                                background: '#1E1E24', border: '1px solid #2E2E36',
                                color: '#FF9500', cursor: 'pointer',
                              }}
                            >
                              <Edit3 size={14} />
                            </button>

                            {currentUser?.id !== u.id && (
                              <button
                                onClick={() => handleToggleBan(u)}
                                title={u.isBanned ? 'Reactivar usuario' : 'Suspender usuario'}
                                style={{
                                  padding: '6px 8px', borderRadius: '8px',
                                  background: u.isBanned ? 'rgba(52,199,89,0.15)' : 'rgba(255,59,48,0.15)',
                                  border: `1px solid ${u.isBanned ? 'rgba(52,199,89,0.3)' : 'rgba(255,59,48,0.3)'}`,
                                  color: u.isBanned ? '#34C759' : '#FF453A',
                                  cursor: 'pointer',
                                }}
                              >
                                <Ban size={14} />
                              </button>
                            )}

                            {currentUser?.id !== u.id && (
                              <button
                                onClick={() => setUserToDelete(u)}
                                title="Eliminar usuario permanentemente"
                                style={{
                                  padding: '6px 8px', borderRadius: '8px',
                                  background: 'rgba(255,59,48,0.1)', border: '1px solid rgba(255,59,48,0.25)',
                                  color: '#FF453A', cursor: 'pointer',
                                }}
                              >
                                <Trash2 size={14} />
                              </button>
                            )}
                          </div>
                        </td>
                      </tr>
                    ))}

                    {users.length === 0 && !isLoading && (
                      <tr>
                        <td colSpan={7} style={{ padding: '40px', textAlign: 'center', color: '#A1A1AA' }}>
                          No se encontraron usuarios coincidentes con los filtros de búsqueda.
                        </td>
                      </tr>
                    )}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        )}

        {/* TAB 2: SESSIONS & IP AUDIT */}
        {adminTab === 'sessions' && (
          <div style={{
            background: '#121215', borderRadius: '18px', border: '1px solid #27272A',
            overflow: 'hidden', boxShadow: '0 8px 30px rgba(0,0,0,0.5)',
          }}>
            <div style={{ padding: '18px 24px', borderBottom: '1px solid #27272A' }}>
              <h3 style={{ fontSize: '17px', fontWeight: 700 }}>Registro Global de Conexiones y Dispositivos</h3>
              <p style={{ fontSize: '12px', color: '#A1A1AA', marginTop: '2px' }}>
                Historial cronológico en tiempo real de todos los accesos, IPs, navegadores y sistemas operativos
              </p>
            </div>

            <div style={{ overflowX: 'auto' }}>
              <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left', minWidth: '920px' }}>
                <thead>
                  <tr style={{ background: '#18181C', borderBottom: '1px solid #27272A', color: '#A1A1AA', fontSize: '11px', textTransform: 'uppercase' }}>
                    <th style={{ padding: '14px 18px' }}>Usuario</th>
                    <th style={{ padding: '14px 18px' }}>Dirección IP</th>
                    <th style={{ padding: '14px 18px' }}>Dispositivo / S.O.</th>
                    <th style={{ padding: '14px 18px' }}>Navegador / Cliente</th>
                    <th style={{ padding: '14px 18px' }}>Plataforma</th>
                    <th style={{ padding: '14px 18px' }}>Fecha y Hora</th>
                  </tr>
                </thead>
                <tbody>
                  {sessions.map((s) => (
                    <tr key={s.id} style={{ borderBottom: '1px solid #1E1E22' }}>
                      <td style={{ padding: '14px 18px' }}>
                        <div style={{ fontWeight: 700, color: '#fff', fontSize: '13px' }}>{s.user_name}</div>
                        <div style={{ fontSize: '11px', color: '#A1A1AA' }}>{s.user_email}</div>
                      </td>

                      <td style={{ padding: '14px 18px' }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                          <code style={{ fontSize: '12px', background: '#1E1E22', padding: '4px 8px', borderRadius: '6px', color: '#34C759', fontWeight: 600, fontFamily: 'monospace' }}>
                            {s.ip_address}
                          </code>
                          <button
                            onClick={() => copyToClipboard(s.ip_address)}
                            title="Copiar IP"
                            style={{ background: 'none', border: 'none', color: '#A1A1AA', cursor: 'pointer', padding: '2px' }}
                          >
                            {copiedIp === s.ip_address ? <Check size={12} color="#34C759" /> : <Copy size={12} />}
                          </button>
                        </div>
                      </td>

                      <td style={{ padding: '14px 18px' }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '13px' }}>
                          {getDeviceIcon(s.device_os, s.browser, s.device_type)}
                          <span>{s.device_os || 'Desconocido'}</span>
                        </div>
                      </td>

                      <td style={{ padding: '14px 18px', fontSize: '13px', color: '#E4E4E7' }}>
                        {s.browser || 'Web Browser'}
                      </td>

                      <td style={{ padding: '14px 18px' }}>
                        <span style={{ fontSize: '11px', background: '#1E1E22', padding: '2px 8px', borderRadius: '10px', color: '#A1A1AA' }}>
                          {s.client_platform || 'Web Client'}
                        </span>
                      </td>

                      <td style={{ padding: '14px 18px', fontSize: '12px', color: '#A1A1AA' }}>
                        {s.created_at ? new Date(s.created_at).toLocaleString() : 'N/A'}
                      </td>
                    </tr>
                  ))}

                  {sessions.length === 0 && (
                    <tr>
                      <td colSpan={6} style={{ padding: '32px', textAlign: 'center', color: '#A1A1AA' }}>
                        No hay registros de sesiones disponibles todavía.
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </div>
        )}

        {/* TAB 3: STATS & STREAMING TOP SONGS */}
        {adminTab === 'metrics' && (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(380px, 1fr))', gap: '20px' }}>
            <div style={{ background: '#121215', borderRadius: '18px', border: '1px solid #27272A', padding: '24px' }}>
              <h3 style={{ fontSize: '18px', fontWeight: 700, marginBottom: '16px', display: 'flex', alignItems: 'center', gap: '8px' }}>
                <TrendingUp size={20} color="#FA243C" /> Canciones más reproducidas en la nube
              </h3>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                {metrics?.topSongs?.map((song, i) => (
                  <div key={song.song_id || i} style={{ display: 'flex', alignItems: 'center', gap: '14px', background: '#18181C', padding: '12px 16px', borderRadius: '12px' }}>
                    <span style={{ fontSize: '15px', fontWeight: 800, color: i === 0 ? '#FFD700' : '#A1A1AA', width: '22px' }}>
                      #{i + 1}
                    </span>
                    {song.cover_art ? (
                      <img src={song.cover_art} alt={song.title} style={{ width: '44px', height: '44px', borderRadius: '8px', objectFit: 'cover' }} />
                    ) : (
                      <div style={{ width: '44px', height: '44px', borderRadius: '8px', background: '#27272A', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                        <Music size={20} color="#A1A1AA" />
                      </div>
                    )}
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <p style={{ fontSize: '14px', fontWeight: 700, color: '#fff', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                        {song.title}
                      </p>
                      <p style={{ fontSize: '12px', color: '#A1A1AA', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                        {song.artist}
                      </p>
                    </div>
                    <span style={{ fontSize: '13px', fontWeight: 800, color: '#34C759', background: 'rgba(52,199,89,0.12)', padding: '4px 10px', borderRadius: '12px' }}>
                      {song.play_count} plays
                    </span>
                  </div>
                ))}
                {(!metrics?.topSongs || metrics.topSongs.length === 0) && (
                  <p style={{ fontSize: '13px', color: '#A1A1AA', textAlign: 'center', padding: '24px' }}>
                    Sin datos de reproducción aún.
                  </p>
                )}
              </div>
            </div>
          </div>
        )}
      </main>

      {/* MODAL 1: FULL USER DEEP DIVE */}
      {selectedUserDetail && (
        <div style={{
          position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.85)', backdropFilter: 'blur(10px)',
          display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000, padding: '20px',
        }}>
          <div style={{
            background: '#141417', border: '1px solid #2E2E33', borderRadius: '24px',
            width: '100%', maxWidth: '880px', maxHeight: '90vh', overflowY: 'auto', padding: '28px',
            boxShadow: '0 25px 60px rgba(0,0,0,0.8)',
          }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '22px' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '14px' }}>
                <div style={{
                  width: '56px', height: '56px', borderRadius: '50%', background: '#FA243C',
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  fontSize: '24px', fontWeight: 800, color: '#fff',
                }}>
                  {selectedUserDetail.user.name?.charAt(0).toUpperCase() || 'U'}
                </div>
                <div>
                  <h2 style={{ fontSize: '22px', fontWeight: 800 }}>{selectedUserDetail.user.name}</h2>
                  <p style={{ fontSize: '13px', color: '#A1A1AA', display: 'flex', alignItems: 'center', gap: '6px' }}>
                    <Mail size={13} /> {selectedUserDetail.user.email}
                  </p>
                </div>
              </div>
              <button
                onClick={() => setSelectedUserDetail(null)}
                style={{ background: '#27272A', border: 'none', borderRadius: '50%', width: '36px', height: '36px', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff', cursor: 'pointer' }}
              >
                <X size={18} />
              </button>
            </div>

            {/* Profile Info Row */}
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '12px', marginBottom: '24px' }}>
              <div style={{ background: '#09090B', padding: '14px', borderRadius: '12px', border: '1px solid #27272A' }}>
                <span style={{ fontSize: '11px', color: '#71717A', textTransform: 'uppercase', fontWeight: 700 }}>Rol</span>
                <p style={{ fontSize: '14px', fontWeight: 700, color: '#FF9500', marginTop: '3px' }}>
                  {selectedUserDetail.user.role === 'admin' ? '👑 Administrador' : '👤 Usuario'}
                </p>
              </div>
              <div style={{ background: '#09090B', padding: '14px', borderRadius: '12px', border: '1px solid #27272A' }}>
                <span style={{ fontSize: '11px', color: '#71717A', textTransform: 'uppercase', fontWeight: 700 }}>Estado</span>
                <p style={{ fontSize: '14px', fontWeight: 700, color: selectedUserDetail.user.isBanned ? '#FF453A' : '#34C759', marginTop: '3px' }}>
                  {selectedUserDetail.user.isBanned ? 'Suspendido' : 'Activo'}
                </p>
              </div>
              <div style={{ background: '#09090B', padding: '14px', borderRadius: '12px', border: '1px solid #27272A' }}>
                <span style={{ fontSize: '11px', color: '#71717A', textTransform: 'uppercase', fontWeight: 700 }}>Última IP</span>
                <p style={{ fontSize: '13px', fontWeight: 700, color: '#34C759', marginTop: '3px', fontFamily: 'monospace' }}>
                  {selectedUserDetail.user.lastLoginIp || 'N/A'}
                </p>
              </div>
              <div style={{ background: '#09090B', padding: '14px', borderRadius: '12px', border: '1px solid #27272A' }}>
                <span style={{ fontSize: '11px', color: '#71717A', textTransform: 'uppercase', fontWeight: 700 }}>Fecha Registro</span>
                <p style={{ fontSize: '13px', fontWeight: 700, color: '#E4E4E7', marginTop: '3px' }}>
                  {new Date(selectedUserDetail.user.createdAt).toLocaleDateString()}
                </p>
              </div>
            </div>

            {/* Devices & Login Sessions */}
            <div style={{ marginBottom: '24px' }}>
              <h3 style={{ fontSize: '15px', fontWeight: 700, marginBottom: '12px', display: 'flex', alignItems: 'center', gap: '8px' }}>
                <Laptop size={17} color="#0A84FF" /> Historial de Dispositivos e IPs Utilizados ({selectedUserDetail.sessions?.length || 0})
              </h3>
              <div style={{ background: '#09090B', borderRadius: '14px', border: '1px solid #27272A', maxHeight: '200px', overflowY: 'auto' }}>
                <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left', fontSize: '12px' }}>
                  <thead>
                    <tr style={{ background: '#18181C', color: '#A1A1AA' }}>
                      <th style={{ padding: '10px 14px' }}>IP</th>
                      <th style={{ padding: '10px 14px' }}>Sistema Operativo</th>
                      <th style={{ padding: '10px 14px' }}>Navegador</th>
                      <th style={{ padding: '10px 14px' }}>Fecha y Hora</th>
                    </tr>
                  </thead>
                  <tbody>
                    {selectedUserDetail.sessions?.map((s) => (
                      <tr key={s.id} style={{ borderBottom: '1px solid #1E1E22' }}>
                        <td style={{ padding: '10px 14px', color: '#34C759', fontFamily: 'monospace', fontWeight: 600 }}>{s.ip_address}</td>
                        <td style={{ padding: '10px 14px', color: '#fff' }}>{s.device_os}</td>
                        <td style={{ padding: '10px 14px', color: '#A1A1AA' }}>{s.browser}</td>
                        <td style={{ padding: '10px 14px', color: '#71717A' }}>{new Date(s.created_at).toLocaleString()}</td>
                      </tr>
                    ))}
                    {(!selectedUserDetail.sessions || selectedUserDetail.sessions.length === 0) && (
                      <tr><td colSpan={4} style={{ padding: '16px', textAlign: 'center', color: '#A1A1AA' }}>Sin registros de sesiones</td></tr>
                    )}
                  </tbody>
                </table>
              </div>
            </div>

            {/* User Favorites & Playlists */}
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px', marginBottom: '20px' }}>
              <div>
                <h4 style={{ fontSize: '14px', fontWeight: 700, marginBottom: '10px', display: 'flex', alignItems: 'center', gap: '6px' }}>
                  <Heart size={15} color="#FF375F" /> Canciones Favoritas ({selectedUserDetail.favorites?.length || 0})
                </h4>
                <div style={{ background: '#09090B', borderRadius: '12px', padding: '10px', maxHeight: '150px', overflowY: 'auto' }}>
                  {selectedUserDetail.favorites?.map((fav) => (
                    <div key={fav.id} style={{ padding: '6px 8px', fontSize: '12px', borderBottom: '1px solid #1E1E22' }}>
                      <p style={{ fontWeight: 700, color: '#fff' }}>{fav.title}</p>
                      <p style={{ color: '#71717A', fontSize: '11px' }}>{fav.artist}</p>
                    </div>
                  ))}
                  {(!selectedUserDetail.favorites || selectedUserDetail.favorites.length === 0) && (
                    <p style={{ fontSize: '12px', color: '#52525B', textAlign: 'center', padding: '12px' }}>Sin favoritos guardados</p>
                  )}
                </div>
              </div>

              <div>
                <h4 style={{ fontSize: '14px', fontWeight: 700, marginBottom: '10px', display: 'flex', alignItems: 'center', gap: '6px' }}>
                  <ListMusic size={15} color="#FA243C" /> Playlists Creadas ({selectedUserDetail.playlists?.length || 0})
                </h4>
                <div style={{ background: '#09090B', borderRadius: '12px', padding: '10px', maxHeight: '150px', overflowY: 'auto' }}>
                  {selectedUserDetail.playlists?.map((pl) => (
                    <div key={pl.id} style={{ padding: '6px 8px', fontSize: '12px', borderBottom: '1px solid #1E1E22' }}>
                      <p style={{ fontWeight: 700, color: '#fff' }}>{pl.name}</p>
                      <p style={{ color: '#71717A', fontSize: '11px' }}>{new Date(pl.created_at).toLocaleDateString()}</p>
                    </div>
                  ))}
                  {(!selectedUserDetail.playlists || selectedUserDetail.playlists.length === 0) && (
                    <p style={{ fontSize: '12px', color: '#52525B', textAlign: 'center', padding: '12px' }}>Sin playlists creadas</p>
                  )}
                </div>
              </div>
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: '16px' }}>
              <button
                onClick={() => setSelectedUserDetail(null)}
                style={{ padding: '10px 22px', borderRadius: '10px', background: '#FA243C', color: '#fff', fontWeight: 700, border: 'none', cursor: 'pointer' }}
              >
                Cerrar
              </button>
            </div>
          </div>
        </div>
      )}

      {/* MODAL 2: EDIT USER */}
      {editingUser && (
        <div style={{
          position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.85)', backdropFilter: 'blur(8px)',
          display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000, padding: '20px',
        }}>
          <form onSubmit={handleSaveEdit} style={{
            background: '#141417', border: '1px solid #2E2E33', borderRadius: '22px',
            width: '100%', maxWidth: '480px', padding: '28px', boxShadow: '0 20px 50px rgba(0,0,0,0.8)',
          }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '20px' }}>
              <h3 style={{ fontSize: '18px', fontWeight: 800 }}>Editar Usuario</h3>
              <button type="button" onClick={() => setEditingUser(null)} style={{ background: 'none', border: 'none', color: '#A1A1AA', cursor: 'pointer' }}>
                <X size={18} />
              </button>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
              <div>
                <label style={{ display: 'block', fontSize: '12px', fontWeight: 600, color: '#A1A1AA', marginBottom: '6px' }}>Nombre</label>
                <input
                  type="text"
                  required
                  value={editFormData.name}
                  onChange={e => setEditFormData({ ...editFormData, name: e.target.value })}
                  style={{
                    width: '100%', background: '#09090B', border: '1px solid #27272A', borderRadius: '10px',
                    padding: '10px 14px', color: '#fff', fontSize: '14px', outline: 'none', boxSizing: 'border-box',
                  }}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '12px', fontWeight: 600, color: '#A1A1AA', marginBottom: '6px' }}>Correo Electrónico</label>
                <input
                  type="email"
                  required
                  value={editFormData.email}
                  onChange={e => setEditFormData({ ...editFormData, email: e.target.value })}
                  style={{
                    width: '100%', background: '#09090B', border: '1px solid #27272A', borderRadius: '10px',
                    padding: '10px 14px', color: '#fff', fontSize: '14px', outline: 'none', boxSizing: 'border-box',
                  }}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '12px', fontWeight: 600, color: '#A1A1AA', marginBottom: '6px' }}>Rol en el Sistema</label>
                <select
                  value={editFormData.role}
                  onChange={e => setEditFormData({ ...editFormData, role: e.target.value })}
                  style={{
                    width: '100%', background: '#09090B', border: '1px solid #27272A', borderRadius: '10px',
                    padding: '10px 14px', color: '#fff', fontSize: '14px', outline: 'none', cursor: 'pointer', boxSizing: 'border-box',
                  }}
                >
                  <option value="user">Usuario Regular</option>
                  <option value="admin">Administrador (Acceso Total)</option>
                </select>
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '12px', fontWeight: 600, color: '#A1A1AA', marginBottom: '6px' }}>
                  Nueva Contraseña (dejar en blanco para conservar la actual)
                </label>
                <input
                  type="password"
                  placeholder="Mínimo 6 caracteres"
                  value={editFormData.password}
                  onChange={e => setEditFormData({ ...editFormData, password: e.target.value })}
                  style={{
                    width: '100%', background: '#09090B', border: '1px solid #27272A', borderRadius: '10px',
                    padding: '10px 14px', color: '#fff', fontSize: '14px', outline: 'none', boxSizing: 'border-box',
                  }}
                />
              </div>
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '10px', marginTop: '24px' }}>
              <button
                type="button"
                onClick={() => setEditingUser(null)}
                style={{ padding: '10px 18px', borderRadius: '10px', background: '#27272A', color: '#A1A1AA', border: 'none', cursor: 'pointer', fontWeight: 600 }}
              >
                Cancelar
              </button>
              <button
                type="submit"
                disabled={isSubmitting}
                style={{ padding: '10px 22px', borderRadius: '10px', background: '#FA243C', color: '#fff', border: 'none', cursor: 'pointer', fontWeight: 700 }}
              >
                {isSubmitting ? 'Guardando...' : 'Guardar Cambios'}
              </button>
            </div>
          </form>
        </div>
      )}

      {/* MODAL 3: DELETE CONFIRMATION */}
      {userToDelete && (
        <div style={{
          position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.85)', backdropFilter: 'blur(8px)',
          display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000, padding: '20px',
        }}>
          <div style={{
            background: '#141417', border: '1px solid #FF453A', borderRadius: '22px',
            width: '100%', maxWidth: '440px', padding: '28px', textAlign: 'center',
          }}>
            <div style={{
              width: '56px', height: '56px', borderRadius: '50%', background: 'rgba(255,69,58,0.15)',
              display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 16px', color: '#FF453A',
            }}>
              <AlertTriangle size={28} />
            </div>

            <h3 style={{ fontSize: '20px', fontWeight: 800, marginBottom: '8px' }}>¿Eliminar usuario?</h3>
            <p style={{ fontSize: '14px', color: '#A1A1AA', marginBottom: '24px' }}>
              Esta acción eliminará de forma permanente a <strong style={{ color: '#fff' }}>{userToDelete.name}</strong> ({userToDelete.email}), junto con todas sus playlists, favoritos, reproducciones e historial de dispositivos.
            </p>

            <div style={{ display: 'flex', justifyContent: 'center', gap: '12px' }}>
              <button
                onClick={() => setUserToDelete(null)}
                disabled={isSubmitting}
                style={{ padding: '10px 18px', borderRadius: '10px', background: '#27272A', color: '#A1A1AA', border: 'none', cursor: 'pointer', fontWeight: 600 }}
              >
                Cancelar
              </button>
              <button
                onClick={handleConfirmDelete}
                disabled={isSubmitting}
                style={{ padding: '10px 22px', borderRadius: '10px', background: '#FF453A', color: '#fff', border: 'none', cursor: 'pointer', fontWeight: 700 }}
              >
                {isSubmitting ? 'Eliminando...' : 'Sí, Eliminar'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
