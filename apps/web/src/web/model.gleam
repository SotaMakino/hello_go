//// Shared types: the application state (Model) and every event that can
//// happen (Msg). Other modules import from here, never the reverse.

import api

pub type TodoItem {
  TodoItem(id: Int, title: String)
}

pub type Auth {
  Checking
  LoggedOut
  LoggedIn
}

pub type AuthMode {
  Login
  Signup
}

pub type Model {
  Model(
    auth: Auth,
    todos: List(TodoItem),
    new_title: String,
    error: String,
    field_error: String,
    busy: Bool,
    mode: AuthMode,
    username: String,
    password: String,
    show_password: Bool,
    auth_error: String,
    auth_busy: Bool,
  )
}

pub fn initial() -> Model {
  Model(
    auth: Checking,
    todos: [],
    new_title: "",
    error: "",
    field_error: "",
    busy: False,
    mode: Login,
    username: "",
    password: "",
    show_password: False,
    auth_error: "",
    auth_busy: False,
  )
}

pub type Msg {
  ApiReturnedTodos(Result(List(TodoItem), api.ApiError))
  UserTypedTitle(String)
  UserSubmittedTodo
  ApiSavedTodo(Result(Nil, api.ApiError))
  UserClickedDelete(Int)
  ApiDeletedTodo(Result(Nil, api.ApiError))
  UserClickedLogout
  ApiLoggedOut(Result(Nil, api.ApiError))
  UserClickedRetry
  UserTypedUsername(String)
  UserTypedPassword(String)
  UserToggledPassword
  UserSwitchedMode
  UserSubmittedAuth
  ApiSignedUp(Result(Nil, api.ApiError))
  ApiAuthenticated(Result(Nil, api.ApiError))
}
