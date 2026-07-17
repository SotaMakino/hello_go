//// The login / signup card shown when there is no valid session.

import lustre/attribute.{attribute, class, disabled, placeholder, type_, value}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import web/model.{
  type Model, type Msg, Login, Signup, UserSubmittedAuth, UserSwitchedMode,
  UserToggledPassword, UserTypedPassword, UserTypedUsername,
}

pub fn view(model: Model) -> Element(Msg) {
  let heading = case model.mode {
    Login -> "Log in"
    Signup -> "Sign up"
  }
  html.div([class("auth")], [
    html.h1([], [html.text(heading)]),
    case model.auth_error {
      "" -> element.none()
      message ->
        html.p([class("error"), attribute("role", "alert")], [html.text(message)])
    },
    html.form([event.on_submit(fn(_) { UserSubmittedAuth })], [
      html.input([
        value(model.username),
        event.on_input(UserTypedUsername),
        placeholder("Username"),
        attribute("autocomplete", "username"),
        attribute.required(True),
      ]),
      html.div([class("password-field")], [
        html.input([
          type_(case model.show_password {
            True -> "text"
            False -> "password"
          }),
          value(model.password),
          event.on_input(UserTypedPassword),
          placeholder("Password"),
          attribute("autocomplete", case model.mode {
            Login -> "current-password"
            Signup -> "new-password"
          }),
          attribute("minlength", "8"),
          attribute.required(True),
        ]),
        html.button(
          [type_("button"), class("toggle-password"), event.on_click(UserToggledPassword)],
          [
            html.text(case model.show_password {
              True -> "Hide"
              False -> "Show"
            }),
          ],
        ),
      ]),
      html.button([type_("submit"), class("primary"), disabled(model.auth_busy)], [
        html.text(case model.auth_busy, model.mode {
          True, _ -> "Please wait…"
          False, Login -> "Log in"
          False, Signup -> "Create account"
        }),
      ]),
    ]),
    html.p([], [
      html.text(case model.mode {
        Login -> "No account? "
        Signup -> "Already have an account? "
      }),
      html.button([type_("button"), class("link"), event.on_click(UserSwitchedMode)], [
        html.text(case model.mode {
          Login -> "Sign up"
          Signup -> "Log in"
        }),
      ]),
    ]),
  ])
}
