//// Top-level view: picks a screen from the auth state and delegates to the
//// page modules.

import lustre/attribute.{attribute, class, type_}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import web/auth_form
import web/model.{
  type Model, type Msg, Checking, LoggedIn, LoggedOut, UserClickedRetry,
}
import web/todo_list

pub fn view(model: Model) -> Element(Msg) {
  case model.auth {
    Checking ->
      case model.error {
        // still checking the session; if the check itself failed, say so
        "" ->
          html.main([class("app")], [
            html.div([class("loading-screen")], [
              html.div([class("spinner")], []),
              html.p([], [html.text("Connecting to server…")]),
            ]),
          ])
        _ ->
          html.main([class("app")], [
            html.p([class("error"), attribute("role", "alert")], [
              html.text(model.error),
            ]),
            html.button(
              [type_("button"), class("primary"), event.on_click(UserClickedRetry)],
              [html.text("Retry")],
            ),
          ])
      }
    LoggedOut -> html.main([class("app")], [auth_form.view(model)])
    LoggedIn -> html.main([class("app")], todo_list.view(model))
  }
}
