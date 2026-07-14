import { useState } from 'react'
import { login, signup } from './api/auth'

function AuthForm({ onSuccess }) {
  const [mode, setMode] = useState('login')
  const [username, setUsername] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [busy, setBusy] = useState(false)

  async function submit(e) {
    e.preventDefault()
    setBusy(true)
    setError('')
    try {
      if (mode === 'login') {
        await login(username, password)
      } else {
        await signup(username, password)
      }
      onSuccess()
    } catch (err) {
      setError(err.message)
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="auth">
      <h1>{mode === 'login' ? 'Log in' : 'Sign up'}</h1>

      {error && <p className="error">{error}</p>}

      <form onSubmit={submit}>
        <input
          value={username}
          onChange={(e) => setUsername(e.target.value)}
          placeholder="Username"
          autoComplete="username"
          required
        />
        <input
          type="password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          placeholder="Password"
          autoComplete={mode === 'login' ? 'current-password' : 'new-password'}
          minLength={8}
          required
        />
        <button type="submit" disabled={busy}>
          {mode === 'login' ? 'Log in' : 'Create account'}
        </button>
      </form>

      <p>
        {mode === 'login' ? 'No account?' : 'Already have an account?'}{' '}
        <button
          type="button"
          className="link"
          onClick={() => {
            setMode(mode === 'login' ? 'signup' : 'login')
            setError('')
          }}
        >
          {mode === 'login' ? 'Sign up' : 'Log in'}
        </button>
      </p>
    </div>
  )
}

export default AuthForm
