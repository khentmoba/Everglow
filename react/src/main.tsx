import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { App } from './App';
import { AgentMode } from './core/agent/agentMode';
import { ConnectivityService } from './core/network/connectivity';
import { NetworkQualityService } from './core/network/networkQuality';
import { prefetchRoute } from './core/router/routeChunks';
import './styles.css';

AgentMode.init();
ConnectivityService.init();
NetworkQualityService.init();

const params = new URLSearchParams(window.location.search);
if (params.get('screencheck') === '1') {
  const manifestLink = document.querySelector<HTMLLinkElement>('link[rel="manifest"]');
  if (manifestLink) manifestLink.href = '/manifest_screen.json';
  const appleTitle = document.querySelector<HTMLMetaElement>('meta[name="apple-mobile-web-app-title"]');
  if (appleTitle) appleTitle.content = 'Everglow screen test';
}
const agentTarget = params.get('agent') ?? params.get('demo');
const initialRoute =
  agentTarget && agentTarget.toLowerCase().trim() in AgentMode.routeAliases
    ? AgentMode.routeAliases[agentTarget.toLowerCase().trim()]
    : window.location.pathname;
if (!NetworkQualityService.shouldSkipPrefetch()) {
  prefetchRoute(initialRoute);
}

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
