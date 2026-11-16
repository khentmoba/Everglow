import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { App } from './App';
import { AgentMode } from './core/agent/agentMode';
import './styles.css';

AgentMode.init();

// Flutter disables the browser's right-click menu on web.
window.addEventListener('contextmenu', (e) => e.preventDefault());

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
);
