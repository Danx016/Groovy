import React, { useState, useEffect, useCallback } from 'react';
import {
  ShieldAlert,
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
  ShieldCheck,
  AlertTriangle,
  X,
  Play,
  History,
  Activity,
  ChevronRight,
  TrendingUp,
} from 'lucide-react';
import { adminApi } from '../../services/api';
import { useAuth } from '../../context/AuthContext';

export const AdminView = () => {
  const { user: currentUser, isAdmin, isAuthenticated, login } = useAuth();
  const [adminLoginForm, setAdminLoginForm] = useState({ email: '', password: '' });
  const [adminLoginError, setAdminLoginError] = useState(null);
  const [isLoggingIn, setIsLoggingIn] = useState(false);
  const [activeTab, setActiveTab] = useState('users');
  const [metrics, setMetrics] = useState(null);
  const [users, setUsers] = useState([]);
  const [sessions, setSessions] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [roleFilter, setRoleFilter] = useState('all');
  const [statusFilter, setStatusFilter] = useState('all');
  const [selectedUserDetail, setSelectedUserDetail] = useState(null);
  const [editingUser, setEditingUser] = useState(null);
  const [editFormData, setEditFormData] = useState({ name: '', email: '', role: 'user', password: '' });
  const [userToDelete, setUserToDelete] = useState(null);
  const [userToToggleBan, setUserToToggleBan] = useState(null);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [actionMessage, setActionMessage] = useState(null);
  const [copiedIp, setCopiedIp] = useState(null);

  const handleAdminLogin = async (e) => {
    e.preventDefault();
    setAdminLoginError(null);
    setIsLoggingIn(true);
    try {
      await login(adminLoginForm.email, adminLoginForm.password);
    } catch (err) {
      setAdminLoginError(err.message || 'Error al iniciar sesión.');
    } finally {
      setIsLoggingIn(false);
    }
  };

  const fetchData = useCallback(async () => {
    if (!isAuthenticated || !isAdmin) {
      setIsLoading(false);
      return;
    }
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
    } finally {
      setIsLoading(false);
    }
  }, [isAuthenticated, isAdmin, searchQuery, roleFilter, statusFilter]);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  if (!isAuthenticated) {
    return (
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', minHeight: '65vh', textAlign: 'center', padding: '24px' }}>
        <div style={{
          background: '#181818', border: '1px solid #282828', borderRadius: '20px',
          width: '100%', maxWidth: '420px', padding: '32px 28px',
          boxShadow: '0 12px 40px rgba(0,0,0,0.5)',
        }}>
          <div style={{
            width: '60px', height: '60px', borderRadius: '16px',
            background: 'linear-gradient(135deg, #FA243C, #FF375F)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            margin: '0 auto 16px', boxShadow: '0 4px 16px rgba(250,36,60,0.4)',
          }}>
            <ShieldCheck size={32} color="#fff" />
          </div>

          <h2 style={{ fontSize: '22px', fontWeight: 700 }}>Acceso de Administrador</h2>
          <p style={{ color: '#A1A1A6', fontSize: '13px', marginTop: '6px', marginBottom: '24px' }}>
            Inicia sesión con tu cuenta de administrador para gestionar usuarios, dispositivos e IPs.
          </p>

          {adminLoginError && (
            <div style={{ padding: '10px 14px', borderRadius: '8px', background: 'rgba(255,59,48,0.15)', border: '1px solid rgba(255,59,48,0.3)', color: '#FF453A', fontSize: '13px', marginBottom: '16px', textAlign: 'left' }}>
              {adminLoginError}
            </div>
          )}

          <form onSubmit={handleAdminLogin} style={{ display: 'flex', flexDirection: 'column', gap: '14px', textAlign: 'left' }}>
            <div>
              <label style={{ display: 'block', fontSize: '12px', color: '#A1A1A6', marginBottom: '6px' }}>Correo Electrónico</label>
              <input
                type="email"
                required
                placeholder="ej. admin@groovy.com"
                value={adminLoginForm.email}
                onChange={e => setAdminLoginForm({ ...adminLoginForm, email: e.target.value })}
                style={{
                  width: '100%', background: '#121212', border: '1px solid #333', borderRadius: '10px',
                  padding: '12px 14px', color: '#fff', fontSize: '14px', outline: 'none',
                }}
              />
            </div>

            <div>
              <label style={{ display: 'block', fontSize: '12px', color: '#A1A1A6', marginBottom: '6px' }}>Contraseña</label>
              <input
                type="password"
                required
                placeholder="••••••••"
                value={adminLoginForm.password}
                onChange={e => setAdminLoginForm({ ...adminLoginForm, password: e.target.value })}
                style={{
                  width: '100%', background: '#121212', border: '1px solid #333', borderRadius: '10px',
                  padding: '12px 14px', color: '#fff', fontSize: '14px', outline: 'none',
                }}
              />
            </div>

            <button
              type="submit"
              disabled={isLoggingIn}
              style={{
                marginTop: '10px', width: '100%', padding: '13px', borderRadius: '12px',
                background: '#FA243C', color: '#fff', fontWeight: 700, fontSize: '15px',
                border: 'none', cursor: 'pointer', transition: 'all 0.2s',
              }}
            >
              {isLoggingIn ? 'Verificando credenciales...' : 'Ingresar como Administrador'}
            </button>
          </form>
        </div>
      </div>
    );
  }

  if (!isAdmin) {
    return (
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', minHeight: '60vh', textAlign: 'center', padding: '32px' }}>
        <div style={{ width: '64px', height: '64px', borderRadius: '50%', background: 'rgba(255,69,58,0.15)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#FF453A', marginBottom: '16px' }}>
          <ShieldAlert size={32} />
        </div>
        <h2 style={{ fontSize: '22px', fontWeight: 700 }}>Permisos de Administrador Requeridos</h2>
        <p style={{ color: '#A1A1A6', marginTop: '8px', maxWidth: '460px', fontSize: '14px' }}>
          Has iniciado sesión como <strong style={{ color: '#fff' }}>{currentUser?.email}</strong>, pero esta cuenta tiene rol de usuario regular. Inicia sesión con la cuenta de administrador registrada en el sistema.
        </p>
      </div>
    );
  }

  // Copy IP Helper
  const copyToClipboard = (text) => {
    navigator.clipboard?.writeText(text);
    setCopiedIp(text);
    setTimeout(() => setCopiedIp(null), 2000);
  };

  // Load deep user detail
  const handleOpenUserDetail = async (userId) => {
    setIsLoadingDetail(true);
    try {
      const data = await adminApi.getUserDetails(userId);
      setSelectedUserDetail(data);
    } catch (err) {
      alert('Error al cargar detalle del usuario: ' + err.message);
    } finally {
      setIsLoadingDetail(false);
    }
  };

  // Open Edit modal
  const handleOpenEdit = (user) => {
    setEditingUser(user);
    setEditFormData({
      name: user.name || '',
      email: user.email || '',
      role: user.role || 'user',
      password: '',
    });
  };

  // Save Edit
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

  // Toggle Ban/Suspend
  const handleToggleBan = (user) => {
    setUserToToggleBan(user);
  };

  const handleConfirmToggleBan = async () => {
    if (!userToToggleBan) return;
    const nextStatus = !userToToggleBan.isBanned;
    setIsSubmitting(true);
    try {
      await adminApi.toggleBanUser(userToToggleBan.id, nextStatus);
      setActionMessage({
        type: 'success',
        text: nextStatus
          ? `Acceso de ${userToToggleBan.name} suspendido correctamente.`
          : `Acceso de ${userToToggleBan.name} reactivado correctamente.`,
      });
      setUserToToggleBan(null);
      fetchData();
      if (selectedUserDetail?.user?.id === userToToggleBan.id) {
        handleOpenUserDetail(userToToggleBan.id);
      }
    } catch (err) {
      alert('Error: ' + err.message);
    } finally {
      setIsSubmitting(false);
    }
  };

  // Delete user
  const handleConfirmDelete = async () => {
    if (!userToDelete) return;
    setIsSubmitting(true);
    try {
      await adminApi.deleteUser(userToDelete.id);
      setUserToDelete(null);
      if (selectedUserDetail?.user?.id === userToDelete.id) {
        setSelectedUserDetail(null);
      }
      setActionMessage({ type: 'success', text: `Usuario ${userToDelete.name} eliminado.` });
      fetchData();
    } catch (err) {
      alert('Error al eliminar usuario: ' + err.message);
    } finally {
      setIsSubmitting(false);
    }
  };

  // Device icon helper
  const getDeviceIcon = (os = '', browser = '', deviceType = '') => {
    const osLower = os.toLowerCase();
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

  if (!isAdmin) {
    return (
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', minHeight: '60vh', textAlign: 'center', padding: '32px' }}>
        <div style={{ width: '64px', height: '64px', borderRadius: '50%', background: 'rgba(255,69,58,0.15)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#FF453A', marginBottom: '16px' }}>
          <ShieldAlert size={32} />
        </div>
        <h2 style={{ fontSize: '22px', fontWeight: 700 }}>Acceso Restringido</h2>
        <p style={{ color: '#A1A1A6', marginTop: '8px', maxWidth: '420px' }}>
          Esta sección es exclusiva para administradores de Groovy. Si crees que se trata de un error, contacta al administrador del sistema.
        </p>
      </div>
    );
  }

  return (
    <div style={{ maxWidth: '1280px', margin: '0 auto', paddingBottom: '160px' }}>
      {/* Header Banner */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: '16px', marginBottom: '24px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '14px' }}>
          <div style={{
            width: '46px', height: '46px', borderRadius: '12px',
            background: 'linear-gradient(135deg, #FA243C, #FF375F)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            boxShadow: '0 4px 16px rgba(250,36,60,0.3)',
          }}>
            <ShieldCheck size={26} color="#fff" />
          </div>
          <div>
            <h1 style={{ fontSize: '26px', fontWeight: 700, letterSpacing: '-0.5px' }}>Panel de Administración</h1>
            <p style={{ fontSize: '13px', color: '#A1A1A6', marginTop: '2px' }}>
              Control total de usuarios, dispositivos, direcciones IP y auditoría de la plataforma
            </p>
          </div>
        </div>

        <button
          onClick={fetchData}
          disabled={isLoading}
          style={{
            display: 'flex', alignItems: 'center', gap: '8px',
            padding: '10px 18px', borderRadius: '10px',
            background: '#1C1C1E', border: '1px solid #2C2C2E',
            color: '#fff', fontSize: '13px', fontWeight: 600,
            cursor: 'pointer', transition: 'all 0.2s',
          }}
          onMouseEnter={e => e.currentTarget.style.borderColor = '#FA243C'}
          onMouseLeave={e => e.currentTarget.style.borderColor = '#2C2C2E'}
        >
          <RefreshCw size={15} className={isLoading ? 'animate-spin' : ''} />
          <span>Actualizar Datos</span>
        </button>
      </div>

      {/* Alert banner if any */}
      {actionMessage && (
        <div style={{
          padding: '12px 16px', borderRadius: '10px', marginBottom: '20px',
          background: actionMessage.type === 'success' ? 'rgba(52,199,89,0.15)' : 'rgba(255,59,48,0.15)',
          border: `1px solid ${actionMessage.type === 'success' ? 'rgba(52,199,89,0.3)' : 'rgba(255,59,48,0.3)'}`,
          color: actionMessage.type === 'success' ? '#34C759' : '#FF453A',
          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        }}>
          <span style={{ fontSize: '14px', fontWeight: 500 }}>{actionMessage.text}</span>
          <button onClick={() => setActionMessage(null)} style={{ background: 'none', border: 'none', color: 'inherit', cursor: 'pointer' }}>
            <X size={16} />
          </button>
        </div>
      )}

      {/* KPI Metric Cards */}
      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
        gap: '14px', marginBottom: '28px',
      }}>
        <div style={{ background: '#181818', borderRadius: '14px', padding: '18px', border: '1px solid #282828' }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '10px' }}>
            <span style={{ fontSize: '13px', color: '#A1A1A6', fontWeight: 500 }}>Usuarios Registrados</span>
            <Users size={20} style={{ color: '#0A84FF' }} />
          </div>
          <div style={{ fontSize: '28px', fontWeight: 800, color: '#fff' }}>{metrics?.totalUsers ?? users.length}</div>
          <div style={{ fontSize: '12px', color: '#34C759', marginTop: '4px', display: 'flex', alignItems: 'center', gap: '4px' }}>
            <TrendingUp size={12} /> {metrics?.activeToday ?? 0} activos hoy
          </div>
        </div>

        <div style={{ background: '#181818', borderRadius: '14px', padding: '18px', border: '1px solid #282828' }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '10px' }}>
            <span style={{ fontSize: '13px', color: '#A1A1A6', fontWeight: 500 }}>Sesiones e IPs</span>
            <Activity size={20} style={{ color: '#30D158' }} />
          </div>
          <div style={{ fontSize: '28px', fontWeight: 800, color: '#fff' }}>{metrics?.totalSessions ?? sessions.length}</div>
          <div style={{ fontSize: '12px', color: '#A1A1A6', marginTop: '4px' }}>Inicios de sesión registrados</div>
        </div>

        <div style={{ background: '#181818', borderRadius: '14px', padding: '18px', border: '1px solid #282828' }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '10px' }}>
            <span style={{ fontSize: '13px', color: '#A1A1A6', fontWeight: 500 }}>Canciones Favoritas</span>
            <Heart size={20} style={{ color: '#FF375F' }} />
          </div>
          <div style={{ fontSize: '28px', fontWeight: 800, color: '#fff' }}>{metrics?.totalFavorites ?? 0}</div>
          <div style={{ fontSize: '12px', color: '#A1A1A6', marginTop: '4px' }}>Guardadas por usuarios</div>
        </div>

        <div style={{ background: '#181818', borderRadius: '14px', padding: '18px', border: '1px solid #282828' }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '10px' }}>
            <span style={{ fontSize: '13px', color: '#A1A1A6', fontWeight: 500 }}>Playlists Creadas</span>
            <ListMusic size={20} style={{ color: '#FA243C' }} />
          </div>
          <div style={{ fontSize: '28px', fontWeight: 800, color: '#fff' }}>{metrics?.totalPlaylists ?? 0}</div>
          <div style={{ fontSize: '12px', color: '#A1A1A6', marginTop: '4px' }}>Colecciones en la nube</div>
        </div>

        <div style={{ background: '#181818', borderRadius: '14px', padding: '18px', border: '1px solid #282828' }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '10px' }}>
            <span style={{ fontSize: '13px', color: '#A1A1A6', fontWeight: 500 }}>Reproducciones Totales</span>
            <Music size={20} style={{ color: '#BF5AF2' }} />
          </div>
          <div style={{ fontSize: '28px', fontWeight: 800, color: '#fff' }}>{metrics?.totalPlays ?? 0}</div>
          <div style={{ fontSize: '12px', color: '#A1A1A6', marginTop: '4px' }}>Historial en streaming</div>
        </div>
      </div>

      {/* Main Tabs Navigation */}
      <div style={{
        display: 'flex', alignItems: 'center', gap: '8px',
        borderBottom: '1px solid #282828', paddingBottom: '12px', marginBottom: '20px',
      }}>
        <button
          onClick={() => setActiveTab('users')}
          style={{
            padding: '8px 18px', borderRadius: '20px',
            fontSize: '14px', fontWeight: 600, cursor: 'pointer',
            background: activeTab === 'users' ? '#FA243C' : '#1C1C1E',
            color: activeTab === 'users' ? '#fff' : '#A1A1A6',
            border: 'none', transition: 'all 0.15s',
          }}
        >
          👥 Usuarios ({users.length})
        </button>

        <button
          onClick={() => setActiveTab('sessions')}
          style={{
            padding: '8px 18px', borderRadius: '20px',
            fontSize: '14px', fontWeight: 600, cursor: 'pointer',
            background: activeTab === 'sessions' ? '#FA243C' : '#1C1C1E',
            color: activeTab === 'sessions' ? '#fff' : '#A1A1A6',
            border: 'none', transition: 'all 0.15s',
          }}
        >
          🌐 Auditoría de Dispositivos e IPs ({sessions.length})
        </button>

        <button
          onClick={() => setActiveTab('metrics')}
          style={{
            padding: '8px 18px', borderRadius: '20px',
            fontSize: '14px', fontWeight: 600, cursor: 'pointer',
            background: activeTab === 'metrics' ? '#FA243C' : '#1C1C1E',
            color: activeTab === 'metrics' ? '#fff' : '#A1A1A6',
            border: 'none', transition: 'all 0.15s',
          }}
        >
          📊 Canciones Populares
        </button>
      </div>

      {/* TAB 1: USERS LIST */}
      {activeTab === 'users' && (
        <div>
          {/* Filter Bar */}
          <div style={{
            display: 'flex', alignItems: 'center', justifyContent: 'space-between',
            flexWrap: 'wrap', gap: '12px', marginBottom: '16px',
          }}>
            {/* Search Input */}
            <div style={{
              display: 'flex', alignItems: 'center', gap: '10px',
              background: '#181818', border: '1px solid #282828', borderRadius: '10px',
              padding: '8px 14px', flex: 1, minWidth: '240px', maxWidth: '480px',
            }}>
              <Search size={16} color="#A1A1A6" />
              <input
                type="text"
                placeholder="Buscar por nombre, correo, IP o dispositivo..."
                value={searchQuery}
                onChange={e => setSearchQuery(e.target.value)}
                style={{
                  background: 'none', border: 'none', color: '#fff',
                  fontSize: '13px', width: '100%', outline: 'none',
                }}
              />
              {searchQuery && (
                <button onClick={() => setSearchQuery('')} style={{ background: 'none', border: 'none', color: '#A1A1A6', cursor: 'pointer' }}>
                  <X size={14} />
                </button>
              )}
            </div>

            {/* Role & Status Filters */}
            <div style={{ display: 'flex', alignItems: 'center', gap: '10px', flexWrap: 'wrap' }}>
              <select
                value={roleFilter}
                onChange={e => setRoleFilter(e.target.value)}
                style={{
                  background: '#181818', border: '1px solid #282828', borderRadius: '8px',
                  color: '#fff', padding: '8px 12px', fontSize: '13px', outline: 'none', cursor: 'pointer',
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
                  background: '#181818', border: '1px solid #282828', borderRadius: '8px',
                  color: '#fff', padding: '8px 12px', fontSize: '13px', outline: 'none', cursor: 'pointer',
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
            background: '#141414', borderRadius: '16px', border: '1px solid #282828',
            overflow: 'hidden', boxShadow: '0 8px 30px rgba(0,0,0,0.4)',
          }}>
            <div style={{ overflowX: 'auto' }}>
              <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left', minWidth: '850px' }}>
                <thead>
                  <tr style={{ background: '#1C1C1E', borderBottom: '1px solid #282828', color: '#A1A1A6', fontSize: '12px', textTransform: 'uppercase', letterSpacing: '0.04em' }}>
                    <th style={{ padding: '14px 16px' }}>Usuario</th>
                    <th style={{ padding: '14px 16px' }}>Rol / Estado</th>
                    <th style={{ padding: '14px 16px' }}>Última IP</th>
                    <th style={{ padding: '14px 16px' }}>Último Dispositivo</th>
                    <th style={{ padding: '14px 16px' }}>Biblioteca</th>
                    <th style={{ padding: '14px 16px' }}>Registrado</th>
                    <th style={{ padding: '14px 16px', textAlign: 'right' }}>Acciones</th>
                  </tr>
                </thead>
                <tbody>
                  {users.map((u) => (
                    <tr
                      key={u.id}
                      style={{
                        borderBottom: '1px solid #202020',
                        transition: 'background 0.15s',
                        background: u.isBanned ? 'rgba(255,69,58,0.05)' : 'transparent',
                      }}
                      onMouseEnter={e => e.currentTarget.style.background = u.isBanned ? 'rgba(255,69,58,0.1)' : '#1C1C1E'}
                      onMouseLeave={e => e.currentTarget.style.background = u.isBanned ? 'rgba(255,69,58,0.05)' : 'transparent'}
                    >
                      {/* User Avatar + Name + Email */}
                      <td style={{ padding: '14px 16px' }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                          <div style={{
                            width: '38px', height: '38px', borderRadius: '50%',
                            background: u.role === 'admin' ? 'linear-gradient(135deg, #FF9500, #FA243C)' : '#282828',
                            display: 'flex', alignItems: 'center', justifyContent: 'center',
                            fontSize: '15px', fontWeight: 700, color: '#fff', flexShrink: 0,
                          }}>
                            {u.name?.charAt(0).toUpperCase() || 'U'}
                          </div>
                          <div>
                            <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                              <span style={{ fontSize: '14px', fontWeight: 600, color: '#fff' }}>{u.name}</span>
                              {currentUser?.id === u.id && (
                                <span style={{ fontSize: '10px', background: '#FA243C', color: '#fff', padding: '1px 6px', borderRadius: '10px', fontWeight: 700 }}>
                                  Tú
                                </span>
                              )}
                            </div>
                            <div style={{ fontSize: '12px', color: '#A1A1A6', marginTop: '2px' }}>{u.email}</div>
                          </div>
                        </div>
                      </td>

                      {/* Role & Status */}
                      <td style={{ padding: '14px 16px' }}>
                        <div style={{ display: 'flex', flexDirection: 'column', gap: '4px', alignItems: 'flex-start' }}>
                          <span style={{
                            fontSize: '11px', fontWeight: 700, padding: '2px 8px', borderRadius: '12px',
                            background: u.role === 'admin' ? 'rgba(255,149,0,0.15)' : 'rgba(255,255,255,0.08)',
                            color: u.role === 'admin' ? '#FF9500' : '#A1A1A6',
                            border: `1px solid ${u.role === 'admin' ? 'rgba(255,149,0,0.3)' : 'transparent'}`,
                          }}>
                            {u.role === 'admin' ? '👑 Administrador' : '👤 Usuario'}
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

                      {/* Last IP */}
                      <td style={{ padding: '14px 16px' }}>
                        {u.lastLoginIp ? (
                          <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                            <code style={{ fontSize: '12px', background: '#242426', padding: '3px 7px', borderRadius: '6px', color: '#34C759' }}>
                              {u.lastLoginIp}
                            </code>
                            <button
                              onClick={() => copyToClipboard(u.lastLoginIp)}
                              title="Copiar IP"
                              style={{ background: 'none', border: 'none', color: '#A1A1A6', cursor: 'pointer', padding: '2px' }}
                            >
                              {copiedIp === u.lastLoginIp ? <Check size={13} color="#34C759" /> : <Copy size={13} />}
                            </button>
                          </div>
                        ) : (
                          <span style={{ fontSize: '12px', color: '#6B6B6B' }}>Sin IP registrada</span>
                        )}
                      </td>

                      {/* Last Device */}
                      <td style={{ padding: '14px 16px' }}>
                        {u.lastDevice ? (
                          <div style={{ display: 'flex', alignItems: 'center', gap: '7px', fontSize: '13px', color: '#E0E0E0' }}>
                            {getDeviceIcon(u.lastDevice)}
                            <span style={{ maxWidth: '160px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                              {u.lastDevice}
                            </span>
                          </div>
                        ) : (
                          <span style={{ fontSize: '12px', color: '#6B6B6B' }}>Desconocido</span>
                        )}
                      </td>

                      {/* Stats / Library */}
                      <td style={{ padding: '14px 16px' }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '10px', fontSize: '12px', color: '#A1A1A6' }}>
                          <span title="Canciones favoritas" style={{ display: 'flex', alignItems: 'center', gap: '3px' }}>
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
                      <td style={{ padding: '14px 16px', fontSize: '12px', color: '#A1A1A6' }}>
                        {u.createdAt ? new Date(u.createdAt).toLocaleDateString() : 'N/A'}
                      </td>

                      {/* Actions */}
                      <td style={{ padding: '14px 16px', textAlign: 'right' }}>
                        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'flex-end', gap: '6px' }}>
                          {/* Deep Dive Button */}
                          <button
                            onClick={() => handleOpenUserDetail(u.id)}
                            title="Ver información completa (IPs, dispositivos, canciones)"
                            style={{
                              padding: '6px 10px', borderRadius: '8px',
                              background: '#282828', border: '1px solid #383838',
                              color: '#fff', fontSize: '12px', fontWeight: 600,
                              cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '4px',
                            }}
                            onMouseEnter={e => e.currentTarget.style.borderColor = '#0A84FF'}
                            onMouseLeave={e => e.currentTarget.style.borderColor = '#383838'}
                          >
                            <Search size={13} color="#0A84FF" />
                            <span>Ver Todo</span>
                          </button>

                          {/* Edit Button */}
                          <button
                            onClick={() => handleOpenEdit(u)}
                            title="Editar usuario"
                            style={{
                              padding: '6px', borderRadius: '8px',
                              background: '#282828', border: '1px solid #383838',
                              color: '#fff', cursor: 'pointer',
                            }}
                            onMouseEnter={e => e.currentTarget.style.borderColor = '#FF9500'}
                            onMouseLeave={e => e.currentTarget.style.borderColor = '#383838'}
                          >
                            <Edit3 size={14} color="#FF9500" />
                          </button>

                          {/* Ban / Suspend Button */}
                          {currentUser?.id !== u.id && (
                            <button
                              onClick={() => handleToggleBan(u)}
                              title={u.isBanned ? 'Reactivar usuario' : 'Suspender usuario'}
                              style={{
                                padding: '6px', borderRadius: '8px',
                                background: u.isBanned ? 'rgba(52,199,89,0.15)' : 'rgba(255,59,48,0.15)',
                                border: `1px solid ${u.isBanned ? 'rgba(52,199,89,0.3)' : 'rgba(255,59,48,0.3)'}`,
                                color: u.isBanned ? '#34C759' : '#FF453A',
                                cursor: 'pointer',
                              }}
                            >
                              <Ban size={14} />
                            </button>
                          )}

                          {/* Delete Button */}
                          {currentUser?.id !== u.id && (
                            <button
                              onClick={() => setUserToDelete(u)}
                              title="Eliminar usuario permanentemente"
                              style={{
                                padding: '6px', borderRadius: '8px',
                                background: 'rgba(255,59,48,0.1)', border: '1px solid rgba(255,59,48,0.2)',
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
                      <td colSpan={7} style={{ padding: '40px', textAlign: 'center', color: '#A1A1A6' }}>
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

      {/* TAB 2: GLOBAL SESSIONS & IP AUDIT */}
      {activeTab === 'sessions' && (
        <div style={{
          background: '#141414', borderRadius: '16px', border: '1px solid #282828',
          overflow: 'hidden', boxShadow: '0 8px 30px rgba(0,0,0,0.4)',
        }}>
          <div style={{ padding: '16px 20px', borderBottom: '1px solid #282828', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
            <div>
              <h3 style={{ fontSize: '16px', fontWeight: 700 }}>Registro Global de Conexiones y Dispositivos</h3>
              <p style={{ fontSize: '12px', color: '#A1A1A6', marginTop: '2px' }}>
                Historial cronológico de todos los accesos con dirección IP, navegador y sistema operativo
              </p>
            </div>
          </div>

          <div style={{ overflowX: 'auto' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left', minWidth: '850px' }}>
              <thead>
                <tr style={{ background: '#1C1C1E', borderBottom: '1px solid #282828', color: '#A1A1A6', fontSize: '12px', textTransform: 'uppercase' }}>
                  <th style={{ padding: '12px 16px' }}>Usuario</th>
                  <th style={{ padding: '12px 16px' }}>Dirección IP</th>
                  <th style={{ padding: '12px 16px' }}>Dispositivo / S.O.</th>
                  <th style={{ padding: '12px 16px' }}>Navegador / Cliente</th>
                  <th style={{ padding: '12px 16px' }}>Plataforma</th>
                  <th style={{ padding: '12px 16px' }}>Fecha y Hora</th>
                </tr>
              </thead>
              <tbody>
                {sessions.map((s) => (
                  <tr key={s.id} style={{ borderBottom: '1px solid #202020' }}>
                    <td style={{ padding: '12px 16px' }}>
                      <div style={{ fontWeight: 600, color: '#fff', fontSize: '13px' }}>{s.user_name}</div>
                      <div style={{ fontSize: '11px', color: '#A1A1A6' }}>{s.user_email}</div>
                    </td>

                    <td style={{ padding: '12px 16px' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                        <code style={{ fontSize: '12px', background: '#242426', padding: '3px 7px', borderRadius: '6px', color: '#34C759', fontWeight: 600 }}>
                          {s.ip_address}
                        </code>
                        <button
                          onClick={() => copyToClipboard(s.ip_address)}
                          title="Copiar IP"
                          style={{ background: 'none', border: 'none', color: '#A1A1A6', cursor: 'pointer', padding: '2px' }}
                        >
                          {copiedIp === s.ip_address ? <Check size={12} color="#34C759" /> : <Copy size={12} />}
                        </button>
                      </div>
                    </td>

                    <td style={{ padding: '12px 16px' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '13px' }}>
                        {getDeviceIcon(s.device_os, s.browser, s.device_type)}
                        <span>{s.device_os || 'Desconocido'}</span>
                      </div>
                    </td>

                    <td style={{ padding: '12px 16px', fontSize: '13px', color: '#E0E0E0' }}>
                      {s.browser || 'Web Browser'}
                    </td>

                    <td style={{ padding: '12px 16px' }}>
                      <span style={{ fontSize: '11px', background: '#282828', padding: '2px 8px', borderRadius: '10px', color: '#A1A1A6' }}>
                        {s.client_platform || 'Web Client'}
                      </span>
                    </td>

                    <td style={{ padding: '12px 16px', fontSize: '12px', color: '#A1A1A6' }}>
                      {s.created_at ? new Date(s.created_at).toLocaleString() : 'N/A'}
                    </td>
                  </tr>
                ))}

                {sessions.length === 0 && (
                  <tr>
                    <td colSpan={6} style={{ padding: '32px', textAlign: 'center', color: '#A1A1A6' }}>
                      No hay registros de sesiones disponibles todavía.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* TAB 3: POPULAR SONGS METRICS */}
      {activeTab === 'metrics' && (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(360px, 1fr))', gap: '20px' }}>
          {/* Top Played */}
          <div style={{ background: '#141414', borderRadius: '16px', border: '1px solid #282828', padding: '20px' }}>
            <h3 style={{ fontSize: '17px', fontWeight: 700, marginBottom: '14px', display: 'flex', alignItems: 'center', gap: '8px' }}>
              <TrendingUp size={18} color="#FA243C" /> Canciones más reproducidas
            </h3>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
              {metrics?.topSongs?.map((song, i) => (
                <div key={song.song_id || i} style={{ display: 'flex', alignItems: 'center', gap: '12px', background: '#1C1C1E', padding: '10px 14px', borderRadius: '10px' }}>
                  <span style={{ fontSize: '14px', fontWeight: 800, color: i === 0 ? '#FFD700' : '#A1A1A6', width: '20px' }}>
                    #{i + 1}
                  </span>
                  {song.cover_art ? (
                    <img src={song.cover_art} alt={song.title} style={{ width: '40px', height: '40px', borderRadius: '6px', objectFit: 'cover' }} />
                  ) : (
                    <div style={{ width: '40px', height: '40px', borderRadius: '6px', background: '#282828', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                      <Music size={18} color="#A1A1A6" />
                    </div>
                  )}
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <p style={{ fontSize: '14px', fontWeight: 600, color: '#fff', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                      {song.title}
                    </p>
                    <p style={{ fontSize: '12px', color: '#A1A1A6', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                      {song.artist}
                    </p>
                  </div>
                  <span style={{ fontSize: '13px', fontWeight: 700, color: '#34C759', background: 'rgba(52,199,89,0.1)', padding: '3px 8px', borderRadius: '12px' }}>
                    {song.play_count} plays
                  </span>
                </div>
              ))}
              {(!metrics?.topSongs || metrics.topSongs.length === 0) && (
                <p style={{ fontSize: '13px', color: '#A1A1A6', textAlign: 'center', padding: '20px' }}>
                  No hay reproducciones registradas aún.
                </p>
              )}
            </div>
          </div>
        </div>
      )}

      {/* MODAL 1: FULL USER DETAILS & TELEMETRY */}
      {selectedUserDetail && (
        <div style={{
          position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.8)', backdropFilter: 'blur(10px)',
          display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000, padding: '20px',
        }}>
          <div style={{
            background: '#181818', border: '1px solid #2C2C2E', borderRadius: '20px',
            width: '100%', maxWidth: '850px', maxHeight: '90vh', overflowY: 'auto', padding: '24px',
            boxShadow: '0 20px 50px rgba(0,0,0,0.6)',
          }}>
            {/* Modal Header */}
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '20px' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '14px' }}>
                <div style={{
                  width: '52px', height: '52px', borderRadius: '50%', background: '#FA243C',
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  fontSize: '22px', fontWeight: 800, color: '#fff',
                }}>
                  {selectedUserDetail.user.name?.charAt(0).toUpperCase() || 'U'}
                </div>
                <div>
                  <h2 style={{ fontSize: '20px', fontWeight: 700 }}>{selectedUserDetail.user.name}</h2>
                  <p style={{ fontSize: '13px', color: '#A1A1A6', display: 'flex', alignItems: 'center', gap: '6px' }}>
                    <Mail size={13} /> {selectedUserDetail.user.email}
                  </p>
                </div>
              </div>
              <button
                onClick={() => setSelectedUserDetail(null)}
                style={{ background: '#282828', border: 'none', borderRadius: '50%', width: '36px', height: '36px', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff', cursor: 'pointer' }}
              >
                <X size={18} />
              </button>
            </div>

            {/* Profile info cards */}
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '10px', marginBottom: '20px' }}>
              <div style={{ background: '#121212', padding: '12px', borderRadius: '10px', border: '1px solid #242424' }}>
                <span style={{ fontSize: '11px', color: '#8E8E93', textTransform: 'uppercase' }}>Rol</span>
                <p style={{ fontSize: '14px', fontWeight: 600, color: '#FF9500', marginTop: '2px' }}>
                  {selectedUserDetail.user.role === 'admin' ? '👑 Administrador' : '👤 Usuario'}
                </p>
              </div>
              <div style={{ background: '#121212', padding: '12px', borderRadius: '10px', border: '1px solid #242424' }}>
                <span style={{ fontSize: '11px', color: '#8E8E93', textTransform: 'uppercase' }}>Estado</span>
                <p style={{ fontSize: '14px', fontWeight: 600, color: selectedUserDetail.user.isBanned ? '#FF453A' : '#34C759', marginTop: '2px' }}>
                  {selectedUserDetail.user.isBanned ? 'Suspendido' : 'Activo'}
                </p>
              </div>
              <div style={{ background: '#121212', padding: '12px', borderRadius: '10px', border: '1px solid #242424' }}>
                <span style={{ fontSize: '11px', color: '#8E8E93', textTransform: 'uppercase' }}>Última IP</span>
                <p style={{ fontSize: '13px', fontWeight: 600, color: '#34C759', marginTop: '2px', fontFamily: 'monospace' }}>
                  {selectedUserDetail.user.lastLoginIp || 'N/A'}
                </p>
              </div>
              <div style={{ background: '#121212', padding: '12px', borderRadius: '10px', border: '1px solid #242424' }}>
                <span style={{ fontSize: '11px', color: '#8E8E93', textTransform: 'uppercase' }}>Fecha de Registro</span>
                <p style={{ fontSize: '13px', fontWeight: 600, color: '#E0E0E0', marginTop: '2px' }}>
                  {new Date(selectedUserDetail.user.createdAt).toLocaleDateString()}
                </p>
              </div>
            </div>

            {/* Devices & Login Sessions Section */}
            <div style={{ marginBottom: '24px' }}>
              <h3 style={{ fontSize: '15px', fontWeight: 700, marginBottom: '10px', display: 'flex', alignItems: 'center', gap: '6px' }}>
                <Laptop size={16} color="#0A84FF" /> Historial de Dispositivos e IPs ({selectedUserDetail.sessions?.length || 0})
              </h3>
              <div style={{ background: '#121212', borderRadius: '12px', border: '1px solid #242424', maxHeight: '180px', overflowY: 'auto' }}>
                <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left', fontSize: '12px' }}>
                  <thead>
                    <tr style={{ background: '#1C1C1E', color: '#A1A1A6' }}>
                      <th style={{ padding: '8px 12px' }}>IP</th>
                      <th style={{ padding: '8px 12px' }}>S.O.</th>
                      <th style={{ padding: '8px 12px' }}>Navegador</th>
                      <th style={{ padding: '8px 12px' }}>Fecha</th>
                    </tr>
                  </thead>
                  <tbody>
                    {selectedUserDetail.sessions?.map((s) => (
                      <tr key={s.id} style={{ borderBottom: '1px solid #1C1C1E' }}>
                        <td style={{ padding: '8px 12px', color: '#34C759', fontFamily: 'monospace' }}>{s.ip_address}</td>
                        <td style={{ padding: '8px 12px', color: '#fff' }}>{s.device_os}</td>
                        <td style={{ padding: '8px 12px', color: '#A1A1A6' }}>{s.browser}</td>
                        <td style={{ padding: '8px 12px', color: '#8E8E93' }}>{new Date(s.created_at).toLocaleString()}</td>
                      </tr>
                    ))}
                    {(!selectedUserDetail.sessions || selectedUserDetail.sessions.length === 0) && (
                      <tr><td colSpan={4} style={{ padding: '16px', textAlign: 'center', color: '#A1A1A6' }}>Sin registros de sesiones</td></tr>
                    )}
                  </tbody>
                </table>
              </div>
            </div>

            {/* Favorites & Playlists preview */}
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px', marginBottom: '20px' }}>
              <div>
                <h4 style={{ fontSize: '14px', fontWeight: 700, marginBottom: '8px', display: 'flex', alignItems: 'center', gap: '6px' }}>
                  <Heart size={14} color="#FF375F" /> Favoritos ({selectedUserDetail.favorites?.length || 0})
                </h4>
                <div style={{ background: '#121212', borderRadius: '10px', padding: '8px', maxHeight: '140px', overflowY: 'auto' }}>
                  {selectedUserDetail.favorites?.map((fav) => (
                    <div key={fav.id} style={{ padding: '6px 8px', fontSize: '12px', borderBottom: '1px solid #1C1C1E', color: '#E0E0E0' }}>
                      <p style={{ fontWeight: 600 }}>{fav.title}</p>
                      <p style={{ color: '#8E8E93', fontSize: '11px' }}>{fav.artist}</p>
                    </div>
                  ))}
                  {(!selectedUserDetail.favorites || selectedUserDetail.favorites.length === 0) && (
                    <p style={{ fontSize: '12px', color: '#6B6B6B', textAlign: 'center', padding: '12px' }}>Sin favoritos</p>
                  )}
                </div>
              </div>

              <div>
                <h4 style={{ fontSize: '14px', fontWeight: 700, marginBottom: '8px', display: 'flex', alignItems: 'center', gap: '6px' }}>
                  <ListMusic size={14} color="#FA243C" /> Playlists ({selectedUserDetail.playlists?.length || 0})
                </h4>
                <div style={{ background: '#121212', borderRadius: '10px', padding: '8px', maxHeight: '140px', overflowY: 'auto' }}>
                  {selectedUserDetail.playlists?.map((pl) => (
                    <div key={pl.id} style={{ padding: '6px 8px', fontSize: '12px', borderBottom: '1px solid #1C1C1E', color: '#E0E0E0' }}>
                      <p style={{ fontWeight: 600 }}>{pl.name}</p>
                      <p style={{ color: '#8E8E93', fontSize: '11px' }}>{new Date(pl.created_at).toLocaleDateString()}</p>
                    </div>
                  ))}
                  {(!selectedUserDetail.playlists || selectedUserDetail.playlists.length === 0) && (
                    <p style={{ fontSize: '12px', color: '#6B6B6B', textAlign: 'center', padding: '12px' }}>Sin playlists</p>
                  )}
                </div>
              </div>
            </div>

            {/* Close button */}
            <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: '16px' }}>
              <button
                onClick={() => setSelectedUserDetail(null)}
                style={{ padding: '10px 20px', borderRadius: '10px', background: '#FA243C', color: '#fff', fontWeight: 600, border: 'none', cursor: 'pointer' }}
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
          position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.8)', backdropFilter: 'blur(8px)',
          display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000, padding: '20px',
        }}>
          <form onSubmit={handleSaveEdit} style={{
            background: '#181818', border: '1px solid #2C2C2E', borderRadius: '20px',
            width: '100%', maxWidth: '480px', padding: '24px', boxShadow: '0 20px 50px rgba(0,0,0,0.6)',
          }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '20px' }}>
              <h3 style={{ fontSize: '18px', fontWeight: 700 }}>Editar Usuario</h3>
              <button type="button" onClick={() => setEditingUser(null)} style={{ background: 'none', border: 'none', color: '#A1A1A6', cursor: 'pointer' }}>
                <X size={18} />
              </button>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
              <div>
                <label style={{ display: 'block', fontSize: '12px', color: '#A1A1A6', marginBottom: '6px' }}>Nombre</label>
                <input
                  type="text"
                  required
                  value={editFormData.name}
                  onChange={e => setEditFormData({ ...editFormData, name: e.target.value })}
                  style={{
                    width: '100%', background: '#121212', border: '1px solid #282828', borderRadius: '8px',
                    padding: '10px 12px', color: '#fff', fontSize: '14px', outline: 'none',
                  }}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '12px', color: '#A1A1A6', marginBottom: '6px' }}>Correo Electrónico</label>
                <input
                  type="email"
                  required
                  value={editFormData.email}
                  onChange={e => setEditFormData({ ...editFormData, email: e.target.value })}
                  style={{
                    width: '100%', background: '#121212', border: '1px solid #282828', borderRadius: '8px',
                    padding: '10px 12px', color: '#fff', fontSize: '14px', outline: 'none',
                  }}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '12px', color: '#A1A1A6', marginBottom: '6px' }}>Rol en el Sistema</label>
                <select
                  value={editFormData.role}
                  onChange={e => setEditFormData({ ...editFormData, role: e.target.value })}
                  style={{
                    width: '100%', background: '#121212', border: '1px solid #282828', borderRadius: '8px',
                    padding: '10px 12px', color: '#fff', fontSize: '14px', outline: 'none', cursor: 'pointer',
                  }}
                >
                  <option value="user">Usuario Regular</option>
                  <option value="admin">Administrador (Acceso Total)</option>
                </select>
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '12px', color: '#A1A1A6', marginBottom: '6px' }}>
                  Nueva Contraseña (dejar en blanco para no cambiar)
                </label>
                <input
                  type="password"
                  placeholder="Mínimo 6 caracteres"
                  value={editFormData.password}
                  onChange={e => setEditFormData({ ...editFormData, password: e.target.value })}
                  style={{
                    width: '100%', background: '#121212', border: '1px solid #282828', borderRadius: '8px',
                    padding: '10px 12px', color: '#fff', fontSize: '14px', outline: 'none',
                  }}
                />
              </div>
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '10px', marginTop: '24px' }}>
              <button
                type="button"
                onClick={() => setEditingUser(null)}
                style={{ padding: '10px 16px', borderRadius: '8px', background: '#282828', color: '#A1A1A6', border: 'none', cursor: 'pointer', fontWeight: 600 }}
              >
                Cancelar
              </button>
              <button
                type="submit"
                disabled={isSubmitting}
                style={{ padding: '10px 20px', borderRadius: '8px', background: '#FA243C', color: '#fff', border: 'none', cursor: 'pointer', fontWeight: 700 }}
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
            background: '#181818', border: '1px solid #FF453A', borderRadius: '20px',
            width: '100%', maxWidth: '440px', padding: '24px', textAlign: 'center',
          }}>
            <div style={{
              width: '56px', height: '56px', borderRadius: '50%', background: 'rgba(255,69,58,0.15)',
              display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 16px', color: '#FF453A',
            }}>
              <AlertTriangle size={28} />
            </div>

            <h3 style={{ fontSize: '20px', fontWeight: 700, marginBottom: '8px' }}>¿Eliminar usuario?</h3>
            <p style={{ fontSize: '14px', color: '#A1A1A6', marginBottom: '20px' }}>
              Esta acción eliminará de forma permanente a <strong style={{ color: '#fff' }}>{userToDelete.name}</strong> ({userToDelete.email}), junto con todas sus playlists, favoritos, reproducciones e historial de dispositivos.
            </p>

            <div style={{ display: 'flex', justifyContent: 'center', gap: '12px' }}>
              <button
                type="button"
                onClick={() => setUserToDelete(null)}
                disabled={isSubmitting}
                style={{ padding: '10px 18px', borderRadius: '10px', background: '#282828', color: '#A1A1A6', border: 'none', cursor: 'pointer', fontWeight: 600 }}
              >
                Cancelar
              </button>
              <button
                type="button"
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

      {/* MODAL 4: BAN / SUSPENSION CONFIRMATION */}
      {userToToggleBan && (
        <div style={{
          position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.85)', backdropFilter: 'blur(12px)',
          display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000, padding: '20px',
        }}>
          <div style={{
            background: '#181818',
            border: `1px solid ${userToToggleBan.isBanned ? '#34C759' : '#FF9500'}`,
            borderRadius: '20px',
            width: '100%', maxWidth: '440px', padding: '24px', textAlign: 'center',
          }}>
            <div style={{
              width: '56px', height: '56px', borderRadius: '50%',
              background: userToToggleBan.isBanned ? 'rgba(52,199,89,0.15)' : 'rgba(255,149,0,0.15)',
              display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 16px',
              color: userToToggleBan.isBanned ? '#34C759' : '#FF9500',
            }}>
              {userToToggleBan.isBanned ? <CheckCircle2 size={28} /> : <Ban size={28} />}
            </div>

            <h3 style={{ fontSize: '20px', fontWeight: 700, marginBottom: '8px' }}>
              {userToToggleBan.isBanned ? '¿Reactivar cuenta?' : '¿Suspender cuenta?'}
            </h3>
            <p style={{ fontSize: '14px', color: '#A1A1A6', marginBottom: '20px', lineHeight: 1.5 }}>
              {userToToggleBan.isBanned ? (
                <>
                  Se restaurará el acceso para <strong style={{ color: '#fff' }}>{userToToggleBan.name}</strong> ({userToToggleBan.email}) y podrá volver a iniciar sesión y sincronizar su música.
                </>
              ) : (
                <>
                  ¿Estás seguro de suspender el acceso a <strong style={{ color: '#fff' }}>{userToToggleBan.name}</strong> ({userToToggleBan.email})? No podrá iniciar sesión ni usar la app.
                </>
              )}
            </p>

            <div style={{ display: 'flex', justifyContent: 'center', gap: '12px' }}>
              <button
                type="button"
                onClick={() => setUserToToggleBan(null)}
                disabled={isSubmitting}
                style={{ padding: '10px 18px', borderRadius: '10px', background: '#282828', color: '#A1A1A6', border: 'none', cursor: 'pointer', fontWeight: 600 }}
              >
                Cancelar
              </button>
              <button
                type="button"
                onClick={handleConfirmToggleBan}
                disabled={isSubmitting}
                style={{
                  padding: '10px 22px', borderRadius: '10px',
                  background: userToToggleBan.isBanned ? '#34C759' : '#FF9500',
                  color: '#fff', border: 'none', cursor: 'pointer', fontWeight: 700,
                }}
              >
                {isSubmitting ? 'Procesando...' : (userToToggleBan.isBanned ? 'Reactivar Acceso' : 'Suspender Acceso')}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
