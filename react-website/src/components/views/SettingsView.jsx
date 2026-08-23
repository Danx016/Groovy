import React, { useState } from 'react';
import { Volume2, Info, Heart, Check, Settings } from 'lucide-react';

const QUALITIES = [
  { id: 'normal', label: 'Normal', rate: '128 kbps' },
  { id: 'high', label: 'Alta', rate: '256 kbps' },
  { id: 'ultra', label: 'Ultra HD', rate: '320 kbps' },
];

const Section = ({ title, children }) => (
  <div style={{ background: '#181818', borderRadius: '12px', border: '0.5px solid #282828', padding: '16px', marginBottom: '12px' }}>
    <h3 style={{ fontSize: '13px', fontWeight: 700, color: '#B3B3B3', letterSpacing: '0.06em', textTransform: 'uppercase', marginBottom: '12px' }}>{title}</h3>
    <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
      {children}
    </div>
  </div>
);

const Row = ({ label, value }) => (
  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '10px 0', borderBottom: '0.5px solid #282828' }}>
    <span style={{ fontSize: '15px', color: '#fff' }}>{label}</span>
    <span style={{ fontSize: '14px', color: '#B3B3B3' }}>{value}</span>
  </div>
);

export const SettingsView = () => {
  const [quality, setQuality] = useState('high');

  return (
    <div style={{ maxWidth: '580px', paddingBottom: '148px' }}>
      <h1 style={{ fontSize: '28px', fontWeight: 700, letterSpacing: '-0.5px', marginBottom: '24px' }}>Preferencias</h1>

      {/* Audio Quality */}
      <Section title="Calidad de Audio">
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '8px' }}>
          {QUALITIES.map(q => (
            <button
              key={q.id}
              onClick={() => setQuality(q.id)}
              style={{
                display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
                padding: '12px 8px', borderRadius: '10px',
                background: quality === q.id ? 'rgba(250,36,60,0.15)' : '#282828',
                border: `1px solid ${quality === q.id ? '#FA243C' : '#404040'}`,
                color: quality === q.id ? '#FA243C' : '#B3B3B3',
                gap: '4px', transition: 'all 0.15s',
              }}
            >
              <span style={{ fontWeight: 700, fontSize: '14px' }}>{q.label}</span>
              <span style={{ fontSize: '11px' }}>{q.rate}</span>
              {quality === q.id && <Check size={14} style={{ marginTop: '2px' }} />}
            </button>
          ))}
        </div>
      </Section>

      {/* Acerca de */}
      <Section title="Acerca de Groovy">
        <Row label="Aplicación" value="Groovy Cloud Music" />
        <Row label="Versión" value="1.0.0" />
        <Row label="Desarrollador" value="Danx016 ❤️" />
        <Row label="Plataformas" value="Android & Web" />
        <Row label="Base de Datos" value="MySQL 8.0" />
        <Row label="Servidor" value="157.137.233.119" />
      </Section>
    </div>
  );
};
