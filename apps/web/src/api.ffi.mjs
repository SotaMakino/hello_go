// Fetch wrapper for the Gleam `api` module. Kept in JS for three things Gleam
// can't reach directly: import.meta.env, AbortSignal.timeout, and cookies via
// credentials: "include".
const API = import.meta.env.VITE_API_URL ?? 'http://localhost:8080'
const TIMEOUT_MS = 8000

export function do_request(method, path, body, hasBody, onResponse, onNetworkError) {
  const options = {
    method,
    credentials: 'include',
    // a paused/frozen server never answers — without this, fetch hangs for minutes
    signal: AbortSignal.timeout(TIMEOUT_MS),
  }
  if (hasBody) {
    options.headers = { 'Content-Type': 'application/json' }
    options.body = body
  }
  fetch(`${API}${path}`, options).then(
    (res) => res.text().then((text) => onResponse(res.status, text)),
    (err) =>
      onNetworkError(
        err.name === 'TimeoutError'
          ? `Server did not respond within ${TIMEOUT_MS / 1000}s.`
          : 'Cannot reach the server. Is it running?',
      ),
  )
}
