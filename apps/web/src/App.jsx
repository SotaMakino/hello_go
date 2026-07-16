import { useEffect, useState } from 'react'
import AuthForm from './AuthForm'
import { logout } from './api/auth'
import { request } from './api/client'
import './App.css'

function App() {
  const [authed, setAuthed] = useState(null) // null = still checking
  const [users, setUsers] = useState([])
  const [id, setId] = useState('')
  const [name, setName] = useState('')
  const [error, setError] = useState('')

  async function loadUsers() {
    setError('')
    try {
      const res = await request('/users')
      setUsers(await res.json())
      setAuthed(true)
    } catch (err) {
      if (err.status === 401) {
        setAuthed(false)
        return
      }
      setError(`Failed to load users: ${err.message}`)
    }
  }

  useEffect(() => {
    loadUsers()
  }, [])

  async function createUser(e) {
    e.preventDefault()
    try {
      await request('/users', { method: 'POST', body: { id, name } })
      setId('')
      setName('')
      await loadUsers()
    } catch (err) {
      setError(`Failed to create user: ${err.message}`)
    }
  }

  async function renameUser(user) {
    const newName = window.prompt(`New name for ${user.name}:`, user.name)
    if (!newName || newName === user.name) return
    try {
      await request(`/users/${user.id}`, { method: 'PUT', body: { name: newName } })
      await loadUsers()
    } catch (err) {
      setError(`Failed to update user: ${err.message}`)
    }
  }

  async function handleLogout() {
    try {
      await logout()
    } catch {
      // even if the server is unreachable, drop back to the login screen
    }
    setAuthed(false)
  }

  if (authed === null) {
    // still checking the session; if the check itself failed, say so
    if (!error) {
      return (
        <main className="app">
          <p>Connecting to server…</p>
        </main>
      )
    }
    return (
      <main className="app">
        <p className="error">{error}</p>
        <button type="button" onClick={loadUsers}>
          Retry
        </button>
      </main>
    )
  }

  if (!authed) {
    return (
      <main className="app">
        <AuthForm onSuccess={loadUsers} />
      </main>
    )
  }

  return (
    <main className="app">
      <h1>Users</h1>
      <button type="button" className="link" onClick={handleLogout}>
        Log out
      </button>

      {error && <p className="error">{error}</p>}

      <form onSubmit={createUser}>
        <input
          value={id}
          onChange={(e) => setId(e.target.value)}
          placeholder="ID"
          required
        />
        <input
          value={name}
          onChange={(e) => setName(e.target.value)}
          placeholder="Name"
          required
        />
        <button type="submit">Add</button>
      </form>

      {users.length === 0 ? (
        <p>No users yet.</p>
      ) : (
        <ul>
          {users.map((u) => (
            <li key={u.id}>
              <span>
                <code>{u.id}</code> {u.name}
              </span>
              <button type="button" onClick={() => renameUser(u)}>
                Rename
              </button>
            </li>
          ))}
        </ul>
      )}
    </main>
  )
}

export default App
