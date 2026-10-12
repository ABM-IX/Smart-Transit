const DEFAULT_BACKEND_URL = 'https://smart-transit-uhyf.onrender.com';

export function getDefaultBackendUrl() {
  return import.meta.env.VITE_BACKEND_URL || DEFAULT_BACKEND_URL;
}

function normalizeBaseUrl(url) {
  return (url || '').trim().replace(/\/+$/, '');
}

export function isSafeBackendUrl(url) {
  try {
    const parsed = new URL(url);
    return parsed.protocol === 'https:' || parsed.protocol === 'http:';
  } catch {
    return false;
  }
}

async function fetchJson(baseUrl, path, options = {}) {
  const cleanBase = normalizeBaseUrl(baseUrl);
  if (!isSafeBackendUrl(cleanBase)) {
    throw new Error('Invalid backend URL');
  }

  const controller = new AbortController();
  const timeout = window.setTimeout(() => controller.abort(), options.timeoutMs || 9000);

  try {
    const response = await fetch(`${cleanBase}${path}`, {
      method: 'GET',
      headers: { Accept: 'application/json' },
      signal: controller.signal,
    });

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }

    return await response.json();
  } finally {
    window.clearTimeout(timeout);
  }
}

export async function fetchDashboardBaseline(baseUrl) {
  const results = await Promise.allSettled([
    fetchJson(baseUrl, '/health'),
    fetchJson(baseUrl, '/api/analytics'),
    fetchJson(baseUrl, '/api/transit/routes'),
    fetchJson(baseUrl, '/api/transit/stops'),
    fetchJson(baseUrl, '/api/transit/fleet/active'),
  ]);

  const [health, analytics, routes, stops, activeFleet] = results;

  return {
    health: toDataState(health),
    analytics: toDataState(analytics),
    routes: toDataState(routes, []),
    stops: toDataState(stops, []),
    activeFleet: toDataState(activeFleet, []),
    refreshedAt: new Date().toISOString(),
  };
}

function toDataState(result, fallback = null) {
  if (result.status === 'fulfilled') {
    return {
      status: 'ready',
      data: result.value ?? fallback,
      error: null,
    };
  }

  return {
    status: result.reason?.name === 'AbortError' ? 'timeout' : 'error',
    data: fallback,
    error: result.reason?.message || 'Request failed',
  };
}
