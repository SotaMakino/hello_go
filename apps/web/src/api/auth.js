import { request } from './client'

export async function signup(username, password) {
  await request('/signup', { method: 'POST', body: { username, password } })
  await request('/login', { method: 'POST', body: { username, password } })
}

export async function login(username, password) {
  await request('/login', { method: 'POST', body: { username, password } })
}

export async function logout() {
  await request('/logout', { method: 'POST' })
}
