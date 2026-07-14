const API = 'http://localhost:8080'

async function post(path, body) {
  const res = await fetch(`${API}${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  })
  if (!res.ok) {
    const data = await res.json().catch(() => ({}))
    throw new Error(data.error ?? `server returned ${res.status}`)
  }
  return res.json()
}

export async function signup(email, password) {
  const { token } = await post('/auth/signup', { email, password })
  localStorage.setItem('token', token)
  return token
}

export async function login(email, password) {
  const { token } = await post('/auth/login', { email, password })
  localStorage.setItem('token', token)
  return token
}

export function logout() {
  localStorage.removeItem('token')
}

export function getToken() {
  return localStorage.getItem('token')
}
