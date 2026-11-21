import { AgentMode } from '../agent/agentMode';
import { ConnectivityService } from '../network/connectivity';

export interface SystemStatus {
  status: 'ok' | 'degraded' | 'unreachable' | 'offline';
  version?: string;
  timestamp?: string;
  checks?: Record<string, unknown>;
  error?: string;
  raw?: Record<string, unknown>;
}

function defaultHealthEndpoints(): string[] {
  const host = typeof window !== 'undefined' ? window.location.hostname : '';
  const isLocal = host === 'localhost' || host === '127.0.0.1' || host === '0.0.0.0';
  if (isLocal) {
    return [
      'https://everglow-1c6db.web.app/api/health',
      'https://us-central1-everglow-1c6db.cloudfunctions.net/health',
    ];
  }
  return [
    '/api/health',
    'https://us-central1-everglow-1c6db.cloudfunctions.net/health',
  ];
}

export async function probeSystemHealth(timeoutMs = 6000): Promise<SystemStatus> {
  if (AgentMode.demo) {
    return {
      status: 'ok',
      version: 'demo',
      timestamp: new Date().toISOString(),
      checks: { firestore: 'ok', proxies: 'ok', motchi: 'ok' },
    };
  }
  if (!ConnectivityService.isOnline) {
    return { status: 'offline', error: 'Client is offline' };
  }

  let lastError = 'Backend health endpoint unreachable';
  for (const endpoint of defaultHealthEndpoints()) {
    try {
      const resp = await fetch(endpoint, { signal: AbortSignal.timeout(timeoutMs) });
      if (resp.status === 200 || resp.status === 503) {
        const decoded = (await resp.json()) as unknown;
        if (decoded && typeof decoded === 'object') {
          const map = decoded as Record<string, unknown>;
          const rawStatus = typeof map.status === 'string' ? map.status.toLowerCase() : 'ok';
          const status: SystemStatus['status'] =
            rawStatus === 'ok' || rawStatus === 'healthy'
              ? 'ok'
              : resp.status === 503 || rawStatus === 'degraded'
                ? 'degraded'
                : 'unreachable';
          return {
            status,
            version: typeof map.version === 'string' ? map.version : undefined,
            timestamp: typeof map.timestamp === 'string' ? map.timestamp : undefined,
            checks: map.checks && typeof map.checks === 'object' ? (map.checks as Record<string, unknown>) : undefined,
            raw: map,
          };
        }
      }
      lastError = `Backend health returned HTTP ${resp.status}`;
    } catch (e) {
      lastError = e instanceof Error ? e.message : String(e);
    }
  }
  return { status: 'unreachable', error: lastError };
}
