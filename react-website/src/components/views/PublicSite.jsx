import React, { useState } from 'react';
import {
  ArrowRight, Check, Download, Globe2, Heart, ImagePlus, LogIn, LogOut,
  Menu, ShieldCheck, Sparkles, UserRound, X, Zap,
} from 'lucide-react';
import { useAuth } from '../../context/AuthContext';
import { authApi } from '../../services/api';

const featureGroups = [
  { icon: Zap, title: 'Rápido y multiplataforma', text: 'Una experiencia ligera para Windows, Android, macOS, Linux, iOS y web.' },
  { icon: Globe2, title: 'Groovy Connect', text: 'Mantén tu cuenta, preferencias y biblioteca sincronizadas entre tus dispositivos.' },
  { icon: Heart, title: 'Tu música, tus reglas', text: 'Organiza favoritos, playlists, historial y configuraciones desde un solo lugar.' },
  { icon: ShieldCheck, title: 'Cuenta protegida', text: 'Autenticación segura, control de sesiones y herramientas para administradores.' },
];

export function PublicSite({ onOpenDownloads, onOpenAdmin }) {
  const { user, isAuthenticated, isAdmin, login, register, logout, setUser } = useAuth();
  const [mobileMenu, setMobileMenu] = useState(false);
  const [authMode, setAuthMode] = useState('login');
  const [showAuth, setShowAuth] = useState(false);
  const [showAccount, setShowAccount] = useState(false);
  const [showEditProfile, setShowEditProfile] = useState(false);
  const [form, setForm] = useState({ name: '', email: '', password: '' });
  const [profileName, setProfileName] = useState('');
  const [profileAvatar, setProfileAvatar] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  const openAuth = (mode = 'login') => {
    setAuthMode(mode);
    setError('');
    setShowAuth(true);
    setMobileMenu(false);
  };

  const submitAuth = async (event) => {
    event.preventDefault();
    setBusy(true);
    setError('');
    try {
      if (authMode === 'register') await register(form.name, form.email, form.password);
      else await login(form.email, form.password);
      setShowAuth(false);
      setForm({ name: '', email: '', password: '' });
    } catch (err) {
      setError(err.message || 'No se pudo completar la operación.');
    } finally {
      setBusy(false);
    }
  };

  const openAccount = () => {
    setProfileName(user?.name || '');
    setProfileAvatar(user?.avatarUrl || '');
    setError('');
    setShowAccount(true);
    setShowEditProfile(false);
    setMobileMenu(false);
  };

  const saveProfile = async (event) => {
    event.preventDefault();
    setBusy(true);
    setError('');
    try {
      const cleanName = profileName.trim();
      if (!cleanName) {
        throw new Error('El nombre no puede estar vacío.');
      }
      const data = await authApi.updateProfile({ name: cleanName, avatarUrl: profileAvatar.trim() });
      setUser(data.user);
      setShowEditProfile(false);
    } catch (err) {
      setError(err.message || 'No se pudo actualizar el perfil.');
    } finally {
      setBusy(false);
    }
  };

  const selectAvatar = (event) => {
    const file = event.target.files?.[0];
    if (!file) return;
    if (!file.type.startsWith('image/')) {
      setError('Selecciona un archivo de imagen válido.');
      return;
    }
    if (file.size > 2 * 1024 * 1024) {
      setError('La imagen debe pesar menos de 2 MB.');
      return;
    }
    const reader = new FileReader();
    reader.onload = () => {
      if (typeof reader.result === 'string') {
        setProfileAvatar(reader.result);
        setError('');
      }
    };
    reader.onerror = () => setError('No se pudo leer la imagen seleccionada.');
    reader.readAsDataURL(file);
  };

  return (
    <div className="public-site">
      <header className="public-header">
        <a className="brand" href="#inicio" onClick={() => setMobileMenu(false)}>
          <img className="brand-mark" src="/logo.png" alt="Groovy" /><span>Groovy</span>
        </a>
        <button className="mobile-menu-button" onClick={() => setMobileMenu(!mobileMenu)} aria-label="Abrir menú">
          {mobileMenu ? <X size={22} /> : <Menu size={22} />}
        </button>
        <nav className={`public-nav ${mobileMenu ? 'open' : ''}`}>
          <a href="#caracteristicas" onClick={() => setMobileMenu(false)}>Características</a>
          <a href="#como-funciona" onClick={() => setMobileMenu(false)}>Cómo funciona</a>
          <a href="#seguridad" onClick={() => setMobileMenu(false)}>Seguridad</a>
          <button className="nav-download" onClick={onOpenDownloads}><Download size={16} /> Descargas</button>
          {isAuthenticated ? (
            <>
              {isAdmin && <button className="nav-admin" onClick={onOpenAdmin}><ShieldCheck size={16} /> Panel admin</button>}
              <button className="account-button" onClick={openAccount}><UserRound size={16} /> {user.name}</button>
            </>
          ) : <button className="nav-login" onClick={() => openAuth('login')}><LogIn size={16} /> Iniciar sesión</button>}
        </nav>
      </header>

      <main>
        <section className="hero-section" id="inicio">
          <div className="hero-copy">
            <p className="eyebrow"><Sparkles size={15} /> Música y comunidad, sin complicaciones</p>
            <h1>Todo Groovy.<br /><span>En un solo lugar.</span></h1>
            <p className="hero-text">Descubre una plataforma pensada para disfrutar, organizar y sincronizar tu experiencia musical en todos tus dispositivos.</p>
            <div className="hero-actions">
              <button className="primary-action" onClick={onOpenDownloads}>Descargar Groovy <ArrowRight size={18} /></button>
              <button className="secondary-action" onClick={() => document.getElementById('caracteristicas')?.scrollIntoView({ behavior: 'smooth' })}>Conocer características</button>
            </div>
            <div className="trust-row"><Check size={16} /> Gratis para empezar <Check size={16} /> Sin anuncios invasivos <Check size={16} /> Multiplataforma</div>
          </div>
          <div className="hero-panel">
            <div className="panel-glow" />
            <div className="hero-card">
              <div className="hero-card-top"><span className="status-dot" /> Groovy Cloud <span>En línea</span></div>
              <div className="hero-card-icon"><Sparkles size={38} /></div>
              <h3>Tu experiencia,<br /><strong>siempre sincronizada.</strong></h3>
              <p>Inicia sesión para administrar tu cuenta y mantener todo bajo control.</p>
              <button onClick={() => isAuthenticated ? openAccount() : openAuth('register')}>{isAuthenticated ? 'Ver mi cuenta' : 'Crear una cuenta'} <ArrowRight size={16} /></button>
            </div>
          </div>
        </section>

        <section className="feature-section" id="caracteristicas">
          <div className="section-heading"><p className="eyebrow">Una plataforma completa</p><h2>Hecha para acompañarte.</h2><p>Groovy reúne las herramientas que necesitas sin obligarte a usar un reproductor web que no necesitas.</p></div>
          <div className="feature-grid">{featureGroups.map(({ icon, title, text }) => <article className="feature-card" key={title}><div className="feature-icon">{React.createElement(icon, { size: 22 })}</div><h3>{title}</h3><p>{text}</p></article>)}</div>
        </section>

        <section className="split-section" id="como-funciona">
          <div><p className="eyebrow">Una cuenta, más control</p><h2>Administra tus datos cuando quieras.</h2><p>Consulta y actualiza tu nombre, avatar y preferencias desde tu cuenta. Si tienes permisos de administrador, tendrás acceso a métricas, usuarios, sesiones y actividad de la plataforma.</p><button className="text-action" onClick={() => isAuthenticated ? openAccount() : openAuth('register')}>{isAuthenticated ? 'Abrir mi cuenta' : 'Crear mi cuenta'} <ArrowRight size={17} /></button></div>
          <div className="info-list"><div><span>01</span><strong>Crea tu cuenta</strong><p>Regístrate en segundos y protege tu acceso.</p></div><div><span>02</span><strong>Personaliza tus datos</strong><p>Actualiza tu información desde cualquier dispositivo.</p></div><div><span>03</span><strong>Gestiona Groovy</strong><p>Los administradores pueden supervisar toda la plataforma.</p></div></div>
        </section>

        <section className="security-section" id="seguridad"><ShieldCheck size={28} /><div><h2>Diseñado pensando en tu privacidad.</h2><p>Tus credenciales se procesan mediante el backend seguro de Groovy y las funciones administrativas están protegidas por permisos.</p></div></section>
      </main>

      <footer className="public-footer"><div className="brand"><img className="brand-mark" src="/logo.png" alt="Groovy" /><span>Groovy</span></div><p>Tu música. Tu cuenta. Tu experiencia.</p><button onClick={onOpenDownloads}>Descargas</button></footer>

      {showAuth && <Modal onClose={() => setShowAuth(false)} title={authMode === 'login' ? 'Bienvenido de nuevo' : 'Crea tu cuenta'} subtitle={authMode === 'login' ? 'Accede a tu cuenta Groovy.' : 'Empieza a gestionar tu experiencia Groovy.'}><form className="site-form" onSubmit={submitAuth}>{authMode === 'register' && <label>Nombre<input required value={form.name} onChange={e => setForm({ ...form, name: e.target.value })} placeholder="Tu nombre" /></label>}<label>Correo electrónico<input required type="email" value={form.email} onChange={e => setForm({ ...form, email: e.target.value })} placeholder="tu@correo.com" /></label><label>Contraseña<input required minLength={6} type="password" value={form.password} onChange={e => setForm({ ...form, password: e.target.value })} placeholder="Mínimo 6 caracteres" /></label>{error && <p className="form-error">{error}</p>}<button className="primary-action full" disabled={busy}>{busy ? 'Procesando...' : authMode === 'login' ? 'Iniciar sesión' : 'Crear cuenta'} <ArrowRight size={17} /></button><button type="button" className="form-switch" onClick={() => { setAuthMode(authMode === 'login' ? 'register' : 'login'); setError(''); }}>{authMode === 'login' ? '¿No tienes cuenta? Regístrate' : 'Ya tengo una cuenta'}</button></form></Modal>}
      {showAccount && <div className="account-backdrop"><section className="account-page">{showEditProfile ? <EditProfilePage profileName={profileName} setProfileName={setProfileName} profileAvatar={profileAvatar} selectAvatar={selectAvatar} error={error} busy={busy} saveProfile={saveProfile} onBack={() => setShowEditProfile(false)} /> : <><button className="account-back" onClick={() => setShowAccount(false)}><ArrowRight size={24} /> <span>Cuenta</span></button><div className="account-profile-row"><div className="avatar-preview account-avatar-large">{profileAvatar ? <img src={profileAvatar} alt="Foto de perfil" /> : <UserRound size={34} />}</div><div><h2>{profileName}</h2><p>Tu nombre y foto serán visibles para los colaboradores de las playlists y de las sesiones de escucha conjunta.</p></div><button type="button" className="account-edit" onClick={() => setShowEditProfile(true)}>Editar</button></div><button type="button" className="account-config-row" onClick={() => setShowEditProfile(true)}><span><strong>Configura tu perfil</strong><small>Configura tu perfil para compartir tu música y ver lo que están escuchando tus amigos.</small></span><ArrowRight size={19} /></button><div className="account-logout"><button type="button" className="account-link accent" onClick={() => { logout(); setShowAccount(false); }}><LogOut size={16} /> Cerrar sesión</button><p>{user.email}</p></div></>}</section></div>}
    </div>
  );
}

function Modal({ onClose, title, subtitle, children }) {
  return <div className="modal-backdrop" onMouseDown={e => e.target === e.currentTarget && onClose()}><div className="site-modal"><button className="modal-close" onClick={onClose}><X size={19} /></button><div className="modal-heading"><img className="brand-mark" src="/logo.png" alt="Groovy" /><h2>{title}</h2><p>{subtitle}</p></div>{children}</div></div>;
}

function EditProfilePage({ profileName, setProfileName, profileAvatar, selectAvatar, error, busy, saveProfile, onBack }) {
  return <form className="edit-profile-page" onSubmit={saveProfile}><button type="button" className="account-back" onClick={onBack}><ArrowRight size={24} /> <span>Editar perfil</span></button><h1>Ayuda a otros a<br />encontrarte</h1><label className="edit-avatar-picker"><div className="avatar-preview edit-avatar-large">{profileAvatar ? <img src={profileAvatar} alt="Foto de perfil" /> : <ImagePlus size={34} />}</div><span>{profileAvatar ? 'Cambiar foto' : 'Agregar foto'}</span><input type="file" accept="image/png,image/jpeg,image/webp" onChange={selectAvatar} /></label><label>Nombre<input required value={profileName} onChange={e => setProfileName(e.target.value)} /></label><label>Nombre de usuario<input value={profileName.toLowerCase().trim().replace(/\s+/g, '_')} readOnly /></label>{error && <p className="form-error">{error}</p>}<button className="primary-action edit-profile-save" disabled={busy}>{busy ? 'Guardando...' : 'Continuar'} <Check size={17} /></button></form>;
}
