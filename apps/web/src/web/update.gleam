//// State transitions: one pure function from (model, msg) to the new model
//// plus any effects to run, and the effect constructors it uses.

import api
import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import lustre/effect.{type Effect}
import web/model.{
  type Model, type Msg, ApiAuthenticated, ApiDeletedTodo, ApiLoggedOut,
  ApiReturnedTodos, ApiSavedTodo, ApiSignedUp, LoggedIn, LoggedOut,
  Login, Model, Signup, TodoItem, UserClickedDelete, UserClickedLogout,
  UserClickedRetry, UserSubmittedAuth, UserSubmittedTodo, UserSwitchedMode,
  UserToggledPassword, UserTypedPassword, UserTypedTitle, UserTypedUsername,
}

pub fn init(_flags) -> #(Model, Effect(Msg)) {
  #(model.initial(), fetch_todos())
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    ApiReturnedTodos(Ok(todos)) -> #(
      Model(..model, auth: LoggedIn, todos: todos, error: ""),
      effect.none(),
    )
    ApiReturnedTodos(Error(api.ApiError(status: 401, ..))) -> #(
      Model(..model, auth: LoggedOut, auth_busy: False),
      effect.none(),
    )
    ApiReturnedTodos(Error(e)) -> #(
      Model(..model, error: "Failed to load todos: " <> e.message, auth_busy: False),
      effect.none(),
    )

    UserTypedTitle(title) -> #(
      Model(..model, new_title: title, field_error: ""),
      effect.none(),
    )
    UserSubmittedTodo -> {
      let trimmed = string.trim(model.new_title)
      let is_duplicate =
        list.any(model.todos, fn(t) {
          string.lowercase(t.title) == string.lowercase(trimmed)
        })
      case trimmed, is_duplicate {
        "", _ -> #(
          Model(..model, field_error: "A todo cannot be empty."),
          effect.none(),
        )
        _, True -> #(
          Model(..model, field_error: "\"" <> trimmed <> "\" is already on your list."),
          effect.none(),
        )
        _, False -> #(
          Model(..model, busy: True),
          api.post(
            "/todos",
            Some(json.object([#("title", json.string(trimmed))])),
            fn(result) { ApiSavedTodo(discard_body(result)) },
          ),
        )
      }
    }
    ApiSavedTodo(Ok(_)) -> #(
      Model(..model, new_title: "", busy: False),
      fetch_todos(),
    )
    ApiSavedTodo(Error(e)) -> #(
      Model(..model, busy: False, error: "Failed to add todo: " <> e.message),
      effect.none(),
    )

    UserClickedDelete(id) -> #(
      model,
      api.delete("/todos/" <> int.to_string(id), fn(result) {
        ApiDeletedTodo(discard_body(result))
      }),
    )
    ApiDeletedTodo(Ok(_)) -> #(model, fetch_todos())
    ApiDeletedTodo(Error(e)) -> #(
      Model(..model, error: "Failed to delete todo: " <> e.message),
      effect.none(),
    )

    UserClickedLogout -> #(
      model,
      api.post("/logout", None, fn(result) { ApiLoggedOut(discard_body(result)) }),
    )
    // even if the server is unreachable, drop back to the login screen
    ApiLoggedOut(_) -> #(
      Model(..model, auth: LoggedOut, todos: [], username: "", password: ""),
      effect.none(),
    )

    UserClickedRetry -> #(Model(..model, error: ""), fetch_todos())

    UserTypedUsername(username) -> #(
      Model(..model, username: username),
      effect.none(),
    )
    UserTypedPassword(password) -> #(
      Model(..model, password: password),
      effect.none(),
    )
    UserToggledPassword -> #(
      Model(..model, show_password: !model.show_password),
      effect.none(),
    )
    UserSwitchedMode -> #(
      Model(
        ..model,
        mode: case model.mode {
          Login -> Signup
          Signup -> Login
        },
        auth_error: "",
      ),
      effect.none(),
    )
    UserSubmittedAuth -> {
      let path = case model.mode {
        Login -> "/login"
        Signup -> "/signup"
      }
      let to_msg = case model.mode {
        Login -> fn(result) { ApiAuthenticated(discard_body(result)) }
        Signup -> fn(result) { ApiSignedUp(discard_body(result)) }
      }
      #(
        Model(..model, auth_busy: True, auth_error: ""),
        api.post(path, Some(credentials(model)), to_msg),
      )
    }
    // signup succeeded — now log in with the same credentials
    ApiSignedUp(Ok(_)) -> #(
      model,
      api.post("/login", Some(credentials(model)), fn(result) {
        ApiAuthenticated(discard_body(result))
      }),
    )
    ApiSignedUp(Error(e)) -> #(
      Model(..model, auth_busy: False, auth_error: e.message),
      effect.none(),
    )
    ApiAuthenticated(Ok(_)) -> #(
      Model(..model, auth_busy: False, password: ""),
      fetch_todos(),
    )
    ApiAuthenticated(Error(e)) -> #(
      Model(..model, auth_busy: False, auth_error: e.message),
      effect.none(),
    )
  }
}

fn credentials(model: Model) -> json.Json {
  json.object([
    #("username", json.string(model.username)),
    #("password", json.string(model.password)),
  ])
}

fn discard_body(result: Result(String, api.ApiError)) -> Result(Nil, api.ApiError) {
  case result {
    Ok(_) -> Ok(Nil)
    Error(e) -> Error(e)
  }
}

fn fetch_todos() -> Effect(Msg) {
  api.get("/todos", fn(result) {
    ApiReturnedTodos(case result {
      Ok(text) -> {
        let todo_decoder = {
          use id <- decode.field("id", decode.int)
          use title <- decode.field("title", decode.string)
          decode.success(TodoItem(id:, title:))
        }
        case json.parse(text, decode.list(todo_decoder)) {
          Ok(todos) -> Ok(todos)
          Error(_) -> Error(api.ApiError(0, "Unexpected response from the server."))
        }
      }
      Error(e) -> Error(e)
    })
  })
}
