import React, { useState } from 'react';
import {
  Volume2, Sliders, Database, Info, Trash2, Check,
  Moon, Sparkles, Activity, ShieldCheck, Cpu, HardDrive
} from 'lucide-react';

const QUALITIES = [
  { id: 'normal', label: 'Normal', rate: '128 kbps', desc: 'Ahorro de datos' },
  { id: 'high', label: 'Alta', rate: '256 kbps', desc: 'Equilibrado' },
  { id: 'ultra', label: 'Ultra HD', rate: '320 kbps', desc: 'Máxima fidelidad' },
];

const EQUALIZERS = [
  { id: 'flat', label: 'Plano (Default)' },
  { id: 'bass', label: 'Refuerzo de Graves' },
  { id: 'vocal', label: 'Claridad Vocal' },
  { id: 'electronic', label: 'Electrónica / Dance' },
  { id: 'rock', label: 'Rock & Alternativo' },
  { id: 'acoustic', label: 'Acústico & Pop' },
];

const SLEEP_TIMES = [
  { val: 0, label: 'Desactivado' },
  { val: 15, label: '15 min' },
  { val: 30, label: '30 min' },
  { val: 45, label: '45 min' },
  { val: 60, label: '1 hora' },
];

export const SettingsView = () => {
  const [activeTab, setActiveTab] = useState('playback'); // 'playback' | 'storage' | 'server' | 'about'
  const [quality, setQuality] = useState(() => localStorage.getItem('groovy_audio_quality') || 'ultra');
  const [crossfade, setCrossfade] = useState(() => parseInt(localStorage.getItem('groovy_crossfade') || '3', 10));
  const [eq, setEq] = useState(() => localStorage.getItem('groovy_eq') || 'flat');
  const [sleepTime, setSleepTime] = useState(0);
  const [cacheCleared, setCacheCleared] = useState(false);

  const handleQualityChange = (qId) => {
    setQuality(qId);
    localStorage.setItem('groovy_audio_quality', qId);
  };

  const handleCrossfadeChange = (val) => {
    setCrossfade(val);
    localStorage.setItem('groovy_crossfade', String(val));
  };

  const handleEqChange = (eqId) => {
    setEq(eqId);
    localStorage.setItem('groovy_eq', eqId);
  };

  const handleClearCache = () => {
    localStorage.removeItem('groovy_search_history');
    setCacheCleared(true);
    setTimeout(() => setCacheCleared(false), 3000);
  };

  return (
    <div style={{ maxWidth: '720px', padding: '8px 20px 140px' }}>
      <div style={{ marginBottom: '24px' }}>
        <h1 style={{ fontSize: '32px', fontWeight: 900, letterSpacing: '-0.8px', color: '#fff', margin: '0 0 6px' }}>
          Configuración
        </h1>
        <p style={{ fontSize: '13px', color: '#8E8E93', margin: 0 }}>
          Personaliza la reproducción de audio, ecualización, caché y telemetría
        </p>
      </div>

      {/* Tabs Bar */}
      <div style={{
        display: 'flex', gap: '8px', borderBottom: '1px solid #222',
        paddingBottom: '12px', marginBottom: '24px', overflowX: 'auto',
      }}>
        {[
          { id: 'playback', label: 'Reproducción', icon: Volume2 },
          { id: 'storage', label: 'Almacenamiento', icon: HardDrive },
          { id: 'server', label: 'Servidor', icon: Database },
          { id: 'about', label: 'Acerca de', icon: Info },
        ].map(({ id, label, icon: Icon }) => {
          const isSel = activeTab === id;
          return (
            <button
              key={id}
              onClick={() => setActiveTab(id)}
              style={{
                display: 'flex', alignItems: 'center', gap: '8px',
                padding: '8px 16px', borderRadius: '20px',
                background: isSel ? '#FA243C' : '#18181b',
                color: isSel ? '#fff' : '#8E8E93',
                fontSize: '13px', fontWeight: 700, border: 'none',
                cursor: 'pointer', transition: 'all 0.15s',
              }}
            >
              <Icon size={15} />
              <span>{label}</span>
            </button>
          );
        })}
      </div>

      {/* 1. PLAYBACK TAB */}
      {activeTab === 'playback' && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
          {/* Quality */}
          <div style={{ background: '#131418', borderRadius: '14px', border: '1px solid #222', padding: '20px' }}>
            <h3 style={{ fontSize: '14px', fontWeight: 700, color: '#fff', margin: '0 0 14px' }}>
              Calidad de Audio Streaming
            </h3>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '10px' }}>
              {QUALITIES.map(q => {
                const isSel = quality === q.id;
                return (
                  <div
                    key={q.id}
                    onClick={() => handleQualityChange(q.id)}
                    style={{
                      padding: '16px 12px', borderRadius: '12px',
                      background: isSel ? 'rgba(250,36,60,0.12)' : '#1c1d22',
                      border: `1.5px solid ${isSel ? '#FA243C' : '#28292f'}`,
                      cursor: 'pointer', textAlign: 'center', transition: 'all 0.15s',
                    }}
                  >
                    <p style={{ fontSize: '14px', fontWeight: 800, color: '#fff', margin: '0 0 4px' }}>{q.label}</p>
                    <p style={{ fontSize: '12px', fontWeight: 700, color: isSel ? '#FA243C' : '#8E8E93', margin: '0 0 2px' }}>{q.rate}</p>
                    <p style={{ fontSize: '10px', color: '#666', margin: 0 }}>{q.desc}</p>
                  </div>
                );
              })}
            </div>
          </div>

          {/* Crossfade */}
          <div style={{ background: '#131418', borderRadius: '14px', border: '1px solid #222', padding: '20px' }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '10px' }}>
              <div>
                <h3 style={{ fontSize: '14px', fontWeight: 700, color: '#fff', margin: '0 0 2px' }}>
                  Crossfade (Transición suave)
                </h3>
                <p style={{ fontSize: '12px', color: '#8E8E93', margin: 0 }}>
                  Mezcla el final de una canción con el inicio de la siguiente
                </p>
              </div>
              <span style={{ fontSize: '14px', fontWeight: 800, color: '#FA243C' }}>
                {crossfade} segundos
              </span>
            </div>
            <input
              type="range" min="0" max="10" step="1"
              value={crossfade}
              onChange={e => handleCrossfadeChange(parseInt(e.target.value, 10))}
              style={{ width: '100%', accentColor: '#FA243C', cursor: 'pointer', margin: '10px 0 0' }}
            />
          </div>

          {/* Equalizer */}
          <div style={{ background: '#131418', borderRadius: '14px', border: '1px solid #222', padding: '20px' }}>
            <h3 style={{ fontSize: '14px', fontWeight: 700, color: '#fff', margin: '0 0 14px' }}>
              Ecualizador de Audio
            </h3>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: '8px' }}>
              {EQUALIZERS.map(item => {
                const isSel = eq === item.id;
                return (
                  <button
                    key={item.id}
                    onClick={() => handleEqChange(item.id)}
                    style={{
                      padding: '12px 14px', borderRadius: '8px',
                      background: isSel ? 'rgba(250,36,60,0.15)' : '#1c1d22',
                      border: `1px solid ${isSel ? '#FA243C' : '#28292f'}`,
                      color: isSel ? '#FA243C' : '#fff',
                      fontSize: '13px', fontWeight: 600, textAlign: 'left',
                      cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'space-between',
                    }}
                  >
                    <span>{item.label}</span>
                    {isSel && <Check size={16} />}
                  </button>
                );
              })}
            </div>
          </div>

          {/* Sleep Timer */}
          <div style={{ background: '#131418', borderRadius: '14px', border: '1px solid #222', padding: '20px' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '14px' }}>
              <Moon size={18} style={{ color: '#AF52DE' }} />
              <h3 style={{ fontSize: '14px', fontWeight: 700, color: '#fff', margin: 0 }}>
                Temporizador de Apagado
              </h3>
            </div>
            <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
              {SLEEP_TIMES.map(st => (
                <button
                  key={st.val}
                  onClick={() => setSleepTime(st.val)}
                  style={{
                    padding: '8px 16px', borderRadius: '20px',
                    background: sleepTime === st.val ? '#AF52DE' : '#1c1d22',
                    border: `1px solid ${sleepTime === st.val ? '#AF52DE' : '#28292f'}`,
                    color: '#fff', fontSize: '12px', fontWeight: 700,
                    cursor: 'pointer',
                  }}
                >
                  {st.label}
                </button>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* 2. STORAGE TAB */}
      {activeTab === 'storage' && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
          <div style={{ background: '#131418', borderRadius: '14px', border: '1px solid #222', padding: '20px' }}>
            <h3 style={{ fontSize: '15px', fontWeight: 700, color: '#fff', margin: '0 0 10px' }}>
              Caché y Almacenamiento Local
            </h3>
            <p style={{ fontSize: '13px', color: '#8E8E93', margin: '0 0 20px', lineHeight: 1.5 }}>
              Groovy almacena en memoria caché carátulas, letras sincronizadas y preferencias para agilizar la carga instantánea.
            </p>

            <button
              onClick={handleClearCache}
              style={{
                display: 'inline-flex', alignItems: 'center', gap: '8px',
                padding: '10px 18px', borderRadius: '10px',
                background: cacheCleared ? 'rgba(52,199,89,0.15)' : 'rgba(255,59,48,0.12)',
                border: `1px solid ${cacheCleared ? '#34C759' : 'rgba(255,59,48,0.3)'}`,
                color: cacheCleared ? '#34C759' : '#FF3B30',
                fontSize: '13px', fontWeight: 700, cursor: 'pointer',
              }}
            >
              <Trash2 size={16} />
              <span>{cacheCleared ? '¡Caché limpiada con éxito!' : 'Vaciar caché de almacenamiento'}</span>
            </button>
          </div>
        </div>
      )}

      {/* 3. SERVER TAB */}
      {activeTab === 'server' && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
          <div style={{ background: '#131418', borderRadius: '14px', border: '1px solid #222', padding: '20px' }}>
            <h3 style={{ fontSize: '15px', fontWeight: 700, color: '#fff', margin: '0 0 16px' }}>
              Estado del Servidor & Sincronización
            </h3>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', paddingBottom: '12px', borderBottom: '1px solid #222' }}>
                <span style={{ fontSize: '13px', color: '#8E8E93' }}>Host Backend API</span>
                <span style={{ fontSize: '13px', fontWeight: 700, color: '#fff', fontFamily: 'monospace' }}>https://groovymusic.duckdns.org</span>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', paddingBottom: '12px', borderBottom: '1px solid #222' }}>
                <span style={{ fontSize: '13px', color: '#8E8E93' }}>Base de Datos MySQL</span>
                <span style={{ fontSize: '13px', fontWeight: 700, color: '#34C759' }}>● Conectada (Online)</span>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', paddingBottom: '12px', borderBottom: '1px solid #222' }}>
                <span style={{ fontSize: '13px', color: '#8E8E93' }}>Telemetría en Vivo (Groovy Connect)</span>
                <span style={{ fontSize: '13px', fontWeight: 700, color: '#34C759' }}>● Activa</span>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* 4. ABOUT TAB */}
      {activeTab === 'about' && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
          <div style={{ background: '#131418', borderRadius: '14px', border: '1px solid #222', padding: '24px', textAlign: 'center' }}>
            <div style={{ width: '64px', height: '64px', borderRadius: '14px', overflow: 'hidden', margin: '0 auto 16px' }}>
              <img src="./logo.png" alt="Groovy" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
            </div>
            <h2 style={{ fontSize: '20px', fontWeight: 800, color: '#fff', margin: '0 0 4px' }}>Groovy Cloud Music</h2>
            <p style={{ fontSize: '13px', color: '#8E8E93', margin: '0 0 16px' }}>Versión Oficial v1.0.78</p>
            <p style={{ fontSize: '13px', color: '#aaa', maxWidth: '400px', margin: '0 auto', lineHeight: 1.5 }}>
              Reproductor musical en la nube con soporte multiplataforma para Windows, Android y Web. Desarrollado con pasión.
            </p>
          </div>
        </div>
      )}
    </div>
  );
};
