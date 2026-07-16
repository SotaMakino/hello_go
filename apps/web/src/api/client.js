const API = import.meta.env.VITE_API_URL ?? 'http://localhost:8080'

export class ApiError extends Error {
  constructor(status, message) {
    super(message)
    this.name = 'ApiError'
    this.status = status // 0 = network failure (no response at all)
  }
}

// The statuses this app can realistically hit, with human-readable hints.
const STATUS_HINTS = {
  400: 'Bad Request — the server rejected the input',
  401: 'Unauthorized — you need to log in',
  403: 'Forbidden — logged in, but not allowed to do this',
  404: 'Not Found',
  409: 'Conflict — it already exists',
  500: 'Internal Server Error — something broke on the server',
  503: 'Service Unavailable — server is down or restarting',
}

const TIMEOUT_MS = 8000

export async function request(path, { method = 'GET', body } = {}) {
  let res
  try {
    res = await fetch(`${API}${path}`, {
      method,
      credentials: 'include',
      headers: body ? { 'Content-Type': 'application/json' } : undefined,
      body: body ? JSON.stringify(body) : undefined,
      // a paused/frozen server never answers — without this, fetch hangs for minutes
      signal: AbortSignal.timeout(TIMEOUT_MS),
    })
  } catch (err) {
    if (err.name === 'TimeoutError') {
      throw new ApiError(0, `Server did not respond within ${TIMEOUT_MS / 1000}s.`)
    }
    // fetch only throws when no response arrived: server down, DNS, CORS, offline
    throw new ApiError(0, 'Cannot reach the server. Is it running?')
  }

  if (!res.ok) {
    const data = await res.json().catch(() => ({}))
    const hint = data.error ?? STATUS_HINTS[res.status] ?? res.statusText
    throw new ApiError(res.status, `HTTP ${res.status}: ${hint}`)
  }

  return res
}
