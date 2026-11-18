import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { App } from './App';
import { AgentMode } from './core/agent/agentMode';
import './styles.css';

AgentMode.init();

// Flutter disables the browser's right-click menu on web.
window.addEventListener('contextmenu', (e) => e.preventDefault());

if (!import.meta.env.DEV && 'serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    void navigator.serviceWorker.register('/sw.js').catch(() => {});
  });
}

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
);
