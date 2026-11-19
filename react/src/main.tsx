import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { App } from './App';
import { AgentMode } from './core/agent/agentMode';
import { prefetchRoute } from './core/router/routeChunks';
import './styles.css';

AgentMode.init();

const params = new URLSearchParams(window.location.search);
const agentTarget = params.get('agent') ?? params.get('demo');
const initialRoute =
  agentTarget && agentTarget.toLowerCase().trim() in AgentMode.routeAliases
    ? AgentMode.routeAliases[agentTarget.toLowerCase().trim()]
    : window.location.pathname;
prefetchRoute(initialRoute);

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
