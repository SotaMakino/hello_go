%%raw(`import "./App.css"`)

type todo = {id: int, title: string}

// celebration fireworks: staggered bursts of randomized particles
type particle = {
  dx: float,
  dy: float,
  size: float,
  rot: float,
  color: string,
  delay: int,
  duration: int,
  streak: bool, // confetti streak instead of a round spark
}

type burst = {x: int, y: int, key: int, particles: array<particle>}

let burstColors = [
  "#aa3bff",
  "#f59e0b",
  "#ef4444",
  "#22c55e",
  "#06b6d4",
  "#ec4899",
  "#facc15",
]

let makeBurst = (x, y, scale, key) => {
  let count = 24
  let particles = Belt.Array.makeBy(count, i => {
    let angle =
      2.0 *. Js.Math._PI *. Belt.Int.toFloat(i) /. Belt.Int.toFloat(count) +.
      (Js.Math.random() -. 0.5) *. 0.5
    let distance = (55.0 +. Js.Math.random() *. 65.0) *. scale
    {
      dx: Js.Math.cos(angle) *. distance,
      dy: Js.Math.sin(angle) *. distance,
      size: 4.0 +. Js.Math.random() *. 5.0,
      rot: Js.Math.random() *. 360.0,
      color: burstColors->Belt.Array.getExn(mod(i, Belt.Array.length(burstColors))),
      delay: Js.Math.random_int(0, 90),
      duration: 700 + Js.Math.random_int(0, 450),
      streak: mod(i, 3) == 0,
    }
  })
  {x, y, key, particles}
}

type rect = {left: float, top: float, width: float, height: float}
@send external getBoundingClientRect: Dom.element => rect = "getBoundingClientRect"

@react.component
let make = () => {
  let (authed, setAuthed) = React.useState(() => None) // None = still checking
  let (todos, setTodos) = React.useState(() => [])
  let (title, setTitle) = React.useState(() => "")
  let (error, setError) = React.useState(() => "")
  let (fieldError, setFieldError) = React.useState(() => "") // client-side validation
  let (busy, setBusy) = React.useState(() => false)
  let (bursts, setBursts) = React.useState(() => [])

  let loadTodos = async () => {
    setError(_ => "")
    switch await ApiClient.request("/todos") {
    | Ok(res) => {
        let fetched: array<todo> = await ApiClient.json(res)
        setTodos(_ => fetched)
        setAuthed(_ => Some(true))
      }
    | Error(err) if err.status == 401 => setAuthed(_ => Some(false))
    | Error(err) => setError(_ => `Failed to load todos: ${err.message}`)
    }
  }

  React.useEffect0(() => {
    loadTodos()->ignore
    None
  })

  let addTodo = async e => {
    ReactEvent.Form.preventDefault(e)
    let trimmed = title->Js.String2.trim
    let isDuplicate =
      todos->Belt.Array.some(t =>
        t.title->Js.String2.toLowerCase == trimmed->Js.String2.toLowerCase
      )
    if trimmed == "" {
      setFieldError(_ => "A todo cannot be empty.")
    } else if isDuplicate {
      setFieldError(_ => `"${trimmed}" is already on your list.`)
    } else {
      setBusy(_ => true)
      switch await ApiClient.request("/todos", ~method_="POST", ~body={"title": trimmed}) {
      | Ok(_) => {
          setTitle(_ => "")
          await loadTodos()
        }
      | Error(err) => setError(_ => `Failed to add todo: ${err.message}`)
      }
      setBusy(_ => false)
    }
  }

  let celebrate = (e: ReactEvent.Mouse.t) => {
    let x = e->ReactEvent.Mouse.clientX
    let y = e->ReactEvent.Mouse.clientY
    // keyboard activation fires a click at 0,0 — burst from the button instead
    let (x, y) = if x == 0 && y == 0 {
      let button: Dom.element = e->ReactEvent.Mouse.currentTarget->Obj.magic
      let r = button->getBoundingClientRect
      (
        Belt.Float.toInt(r.left +. r.width /. 2.0),
        Belt.Float.toInt(r.top +. r.height /. 2.0),
      )
    } else {
      (x, y)
    }
    let base = Js.Date.now()->Belt.Float.toInt
    // a small finale: main burst, then two smaller ones off to the sides
    let fire = (offsetX, offsetY, scale, afterMs, index) => {
      let key = base + index
      let _ = Js.Global.setTimeout(() => {
        setBursts(prev => prev->Belt.Array.concat([makeBurst(x + offsetX, y + offsetY, scale, key)]))
        let _ = Js.Global.setTimeout(
          () => setBursts(prev => prev->Belt.Array.keep(b => b.key != key)),
          1400,
        )
      }, afterMs)
    }
    fire(0, 0, 1.2, 0, 0)
    fire(-75, -50, 0.8, 170, 1)
    fire(70, -65, 0.9, 340, 2)
  }

  let deleteTodo = async (todo: todo) => {
    switch await ApiClient.request(`/todos/${todo.id->Belt.Int.toString}`, ~method_="DELETE") {
    | Ok(_) => await loadTodos()
    | Error(err) => setError(_ => `Failed to delete todo: ${err.message}`)
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
          <div className="loading-screen">
            <div className="spinner" />
            <p> {React.string("Connecting to server…")} </p>
          </div>
        </main>
      : <main className="app">
          <p className="error" role="alert"> {React.string(error)} </p>
          <button type_="button" className="primary" onClick={_ => loadTodos()->ignore}>
            {React.string("Retry")}
          </button>
        </main>
  | Some(false) =>
    <main className="app">
      <AuthForm onSuccess={() => loadTodos()->ignore} />
    </main>
  | Some(true) =>
    <main className="app">
      <header className="app-header">
        <h1> {React.string("My todos")} </h1>
        <button type_="button" className="ghost" onClick={_ => handleLogout()->ignore}>
          {React.string("Log out")}
        </button>
      </header>
      {error == "" ? React.null : <p className="error" role="alert"> {React.string(error)} </p>}
      <form className="add-form" onSubmit={e => addTodo(e)->ignore}>
        <input
          value=title
          onChange={e => {
            let value = ReactEvent.Form.target(e)["value"]
            setTitle(_ => value)
            setFieldError(_ => "")
          }}
          placeholder="What needs doing?"
          ariaLabel="New todo"
        />
        <button type_="submit" className="primary" disabled=busy>
          {React.string("Add")}
        </button>
      </form>
      {fieldError == ""
        ? React.null
        : <p className="field-error" role="alert"> {React.string(fieldError)} </p>}
      {todos->Belt.Array.length == 0
        ? <p className="empty"> {React.string("Nothing to do. Add your first todo above.")} </p>
        : <ul className="todo-list">
            {todos
            ->Belt.Array.map(t =>
              <li key={t.id->Belt.Int.toString} className="todo-row">
                <span className="todo-title"> {React.string(t.title)} </span>
                <button
                  type_="button"
                  className="ghost small"
                  onClick={e => {
                    celebrate(e)
                    deleteTodo(t)->ignore
                  }}>
                  {React.string("Done")}
                </button>
              </li>
            )
            ->React.array}
          </ul>}
      {bursts
      ->Belt.Array.map(b =>
        <div
          key={b.key->Belt.Int.toString}
          className="firework"
          ariaHidden=true
          style={
            {
              left: `${b.x->Belt.Int.toString}px`,
              top: `${b.y->Belt.Int.toString}px`,
            }
          }>
          {b.particles
          ->Belt.Array.mapWithIndex((i, p) => {
            let height = p.streak ? p.size *. 2.8 : p.size
            let base: ReactDOM.Style.t = {
              backgroundColor: p.color,
              width: `${p.size->Js.Float.toString}px`,
              height: `${height->Js.Float.toString}px`,
              boxShadow: `0 0 6px ${p.color}`,
              animationDelay: `${p.delay->Belt.Int.toString}ms`,
              animationDuration: `${p.duration->Belt.Int.toString}ms`,
            }
            let style =
              base
              ->ReactDOM.Style.unsafeAddProp("--dx", `${p.dx->Js.Float.toString}px`)
              ->ReactDOM.Style.unsafeAddProp("--dy", `${p.dy->Js.Float.toString}px`)
              ->ReactDOM.Style.unsafeAddProp("--rot", `${p.rot->Js.Float.toString}deg`)
            <span
              key={i->Belt.Int.toString} className={p.streak ? "streak" : "dot"} style
            />
          })
          ->React.array}
        </div>
      )
      ->React.array}
    </main>
  }
}
