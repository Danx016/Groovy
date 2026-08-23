import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { X, Mail, Lock, User, AlertCircle, ArrowRight } from 'lucide-react';
import { useAuth } from '../../context/AuthContext';

export const AuthModal = () => {
  const { isAuthModalOpen, closeAuthModal, login, register, authError, setAuthError } = useAuth();
  const [isRegisterMode, setIsRegisterMode] = useState(false);
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);

  if (!isAuthModalOpen) return null;

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    try {
      if (isRegisterMode) {
        await register(name, email, password);
      } else {
        await login(email, password);
      }
    } catch (err) {
      // handled in context
    } finally {
      setLoading(false);
    }
  };

  const switchMode = (mode) => {
    setIsRegisterMode(mode);
    setAuthError(null);
  };

  return (
    <AnimatePresence>
      <div
        style={{ position: 'fixed', inset: 0, zIndex: 50, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '16px' }}
      >
        {/* Backdrop */}
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          onClick={closeAuthModal}
          style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.85)', backdropFilter: 'blur(10px)' }}
        />

        {/* Modal */}
        <motion.div
          initial={{ scale: 0.92, opacity: 0, y: 16 }}
          animate={{ scale: 1, opacity: 1, y: 0 }}
          exit={{ scale: 0.92, opacity: 0, y: 16 }}
          transition={{ duration: 0.22, ease: [0.4, 0, 0.2, 1] }}
          style={{
            position: 'relative',
            width: '100%',
            maxWidth: '400px',
            background: '#121212',
            borderRadius: '16px',
            border: '0.5px solid #404040',
            padding: '28px 24px',
            boxShadow: '0 24px 64px rgba(0,0,0,0.8)',
          }}
        >
          {/* Close */}
          <button
            onClick={closeAuthModal}
            style={{ position: 'absolute', right: '16px', top: '16px', padding: '8px', borderRadius: '50%', color: '#B3B3B3' }}
            onMouseEnter={e => e.currentTarget.style.background = '#282828'}
            onMouseLeave={e => e.currentTarget.style.background = 'transparent'}
          >
            <X size={18} />
          </button>

          {/* Logo & Title */}
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', marginBottom: '24px', gap: '12px' }}>
            <div style={{
              width: '60px', height: '60px', borderRadius: '14px', overflow: 'hidden',
              boxShadow: '0 4px 16px rgba(0,0,0,0.5)'
            }}>
              <img src="./logo.png" alt="Groovy" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
            </div>
            <div style={{ textAlign: 'center' }}>
              <h2 style={{ fontSize: '22px', fontWeight: 700, letterSpacing: '-0.3px', color: '#fff' }}>Groovy</h2>
              <p style={{ fontSize: '14px', color: '#B3B3B3', marginTop: '2px' }}>
                {isRegisterMode ? 'Crea tu cuenta de usuario' : 'Inicia sesión con tu cuenta'}
              </p>
            </div>
          </div>

          {/* Segmented Control (iOS style) */}
          <div style={{ display: 'flex', background: '#1E1E1E', borderRadius: '10px', padding: '3px', marginBottom: '20px' }}>
            <button
              onClick={() => switchMode(false)}
              style={{
                flex: 1, padding: '9px 0', borderRadius: '8px', fontSize: '14px', fontWeight: !isRegisterMode ? 700 : 500,
                color: '#fff', background: !isRegisterMode ? '#333333' : 'transparent',
                transition: 'all 0.2s ease',
              }}
            >
              Iniciar Sesión
            </button>
            <button
              onClick={() => switchMode(true)}
              style={{
                flex: 1, padding: '9px 0', borderRadius: '8px', fontSize: '14px', fontWeight: isRegisterMode ? 700 : 500,
                color: '#fff', background: isRegisterMode ? '#333333' : 'transparent',
                transition: 'all 0.2s ease',
              }}
            >
              Crear Cuenta
            </button>
          </div>

          {/* Error */}
          {authError && (
            <div style={{
              display: 'flex', alignItems: 'center', gap: '8px', padding: '10px 12px',
              background: 'rgba(255,59,48,0.12)', borderRadius: '10px', border: '0.8px solid rgba(255,59,48,0.3)',
              marginBottom: '14px',
            }}>
              <AlertCircle size={16} style={{ color: '#FF3B30', flexShrink: 0 }} />
              <span style={{ fontSize: '13px', color: '#FF3B30', fontWeight: 500 }}>{authError}</span>
            </div>
          )}

          {/* Form – grouped iOS card style */}
          <form onSubmit={handleSubmit}>
            <div style={{
              background: '#181818', borderRadius: '12px',
              border: '0.5px solid rgba(255,255,255,0.08)', overflow: 'hidden',
              marginBottom: '20px',
            }}>
              {isRegisterMode && (
                <>
                  <InputRow icon={<User size={18} />} type="text" placeholder="Nombre completo" value={name} onChange={e => setName(e.target.value)} required />
                  <div style={{ height: '0.5px', background: '#404040', margin: '0 14px' }} />
                </>
              )}
              <InputRow icon={<Mail size={18} />} type="email" placeholder="Correo electrónico" value={email} onChange={e => setEmail(e.target.value)} required />
              <div style={{ height: '0.5px', background: '#404040', margin: '0 14px' }} />
              <InputRow icon={<Lock size={18} />} type="password" placeholder="Contraseña" value={password} onChange={e => setPassword(e.target.value)} required />
            </div>

            {/* Submit button */}
            <button
              type="submit"
              disabled={loading}
              style={{
                width: '100%', padding: '14px', borderRadius: '12px',
                background: '#FA243C', color: '#fff', fontWeight: 700, fontSize: '15px',
                display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px',
                opacity: loading ? 0.6 : 1, transition: 'all 0.2s ease',
              }}
              onMouseEnter={e => { if (!loading) e.currentTarget.style.background = '#c41c2e'; }}
              onMouseLeave={e => { if (!loading) e.currentTarget.style.background = '#FA243C'; }}
            >
              {loading
                ? <div style={{ width: '20px', height: '20px', border: '2px solid #fff', borderTopColor: 'transparent', borderRadius: '50%' }} className="animate-spin" />
                : <>{isRegisterMode ? 'Crear Cuenta' : 'Iniciar Sesión'}<ArrowRight size={16} /></>
              }
            </button>
          </form>

          {/* Cloud status */}
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '6px', marginTop: '16px' }}>
            <div style={{ width: '8px', height: '8px', borderRadius: '50%', background: '#34C759' }} />
            <span style={{ fontSize: '12px', color: '#B3B3B3' }}>Groovy Cloud • MySQL DB en línea</span>
          </div>
        </motion.div>
      </div>
    </AnimatePresence>
  );
};

function InputRow({ icon, type, placeholder, value, onChange, required }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', padding: '2px 14px', gap: '12px' }}>
      <span style={{ color: '#B3B3B3', flexShrink: 0 }}>{icon}</span>
      <input
        type={type}
        placeholder={placeholder}
        value={value}
        onChange={onChange}
        required={required}
        style={{
          flex: 1, background: 'transparent', border: 'none', padding: '14px 0',
          fontSize: '15px', color: '#fff', outline: 'none',
        }}
        onFocus={e => e.currentTarget.style.color = '#fff'}
      />
    </div>
  );
}
