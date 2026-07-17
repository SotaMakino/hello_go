%%raw(`import "./App.css"`)

type user = {id: string, name: string}

@scope("window") @val
external prompt: (string, string) => Js.Nullable.t<string> = "prompt"

@react.component
let make = () => {
  let (authed, setAuthed) = React.useState(() => None) // None = still checking
  let (users, setUsers) = React.useState(() => [])
  let (id, setId) = React.useState(() => "")
  let (name, setName) = React.useState(() => "")
  let (error, setError) = React.useState(() => "")

  let loadUsers = async () => {
    setError(_ => "")
    switch await ApiClient.request("/users") {
    | Ok(res) => {
        let fetched: array<user> = await ApiClient.json(res)
        setUsers(_ => fetched)
        setAuthed(_ => Some(true))
      }
    | Error(err) if err.status == 401 => setAuthed(_ => Some(false))
    | Error(err) => setError(_ => `Failed to load users: ${err.message}`)
    }
  }

  React.useEffect0(() => {
    loadUsers()->ignore
    None
  })

  let createUser = async e => {
    ReactEvent.Form.preventDefault(e)
    switch await ApiClient.request("/users", ~method_="POST", ~body={"id": id, "name": name}) {
    | Ok(_) => {
        setId(_ => "")
        setName(_ => "")
        await loadUsers()
      }
    | Error(err) => setError(_ => `Failed to create user: ${err.message}`)
    }
  }

  let renameUser = async (user: user) => {
    let newName =
      prompt(`New name for ${user.name}:`, user.name)
      ->Js.Nullable.toOption
      ->Belt.Option.getWithDefault("")
    if newName != "" && newName != user.name {
      switch await ApiClient.request(`/users/${user.id}`, ~method_="PUT", ~body={"name": newName}) {
      | Ok(_) => await loadUsers()
      | Error(err) => setError(_ => `Failed to update user: ${err.message}`)
      }
    }
  }

  let handleLogout = async () => {
    // even if the server is unreachable, drop back to the login screen
    let _ = await AuthApi.logout()
    setAuthed(_ => Some(false))
  }

  switch authed {
  | None =>
    // still checking the session; if the check itself failed, say so
    error == ""
      ? <main className="app">
          <p> {React.string("Connecting to server…")} </p>
        </main>
      : <main className="app">
          <p className="error"> {React.string(error)} </p>
          <button type_="button" onClick={_ => loadUsers()->ignore}>
            {React.string("Retry")}
          </button>
        </main>
  | Some(false) =>
    <main className="app">
      <AuthForm onSuccess={() => loadUsers()->ignore} />
    </main>
  | Some(true) =>
    <main className="app">
      <h1> {React.string("Users")} </h1>
      <button type_="button" className="link" onClick={_ => handleLogout()->ignore}>
        {React.string("Log out")}
      </button>
      {error == "" ? React.null : <p className="error"> {React.string(error)} </p>}
      <form onSubmit={e => createUser(e)->ignore}>
        <input
          value=id
          onChange={e => {
            let value = ReactEvent.Form.target(e)["value"]
            setId(_ => value)
          }}
          placeholder="ID"
          required=true
        />
        <input
          value=name
          onChange={e => {
            let value = ReactEvent.Form.target(e)["value"]
            setName(_ => value)
          }}
          placeholder="Name"
          required=true
        />
        <button type_="submit"> {React.string("Add")} </button>
      </form>
      {users->Belt.Array.length == 0
        ? <p> {React.string("No users yet.")} </p>
        : <ul>
            {users
            ->Belt.Array.map(u =>
              <li key=u.id>
                <span>
                  <code> {React.string(u.id)} </code>
                  {React.string(" " ++ u.name)}
                </span>
                <button type_="button" onClick={_ => renameUser(u)->ignore}>
                  {React.string("Rename")}
                </button>
              </li>
            )
            ->React.array}
          </ul>}
    </main>
  }
}
