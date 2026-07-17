//// The todo page: header, add form with validation message, and the list.

import gleam/int
import gleam/list
import lustre/attribute.{attribute, class, disabled, placeholder, type_, value}
import lustre/element.{type Element}
import lustre/element/html
import lustre/element/keyed
import lustre/event
import web/model.{
  type Model, type Msg, UserClickedDelete, UserClickedLogout, UserSubmittedTodo,
  UserTypedTitle,
}

pub fn view(model: Model) -> List(Element(Msg)) {
  [
    html.header([class("app-header")], [
      html.h1([], [html.text("My todos")]),
      html.button(
        [type_("button"), class("ghost"), event.on_click(UserClickedLogout)],
        [html.text("Log out")],
      ),
    ]),
    case model.error {
      "" -> element.none()
      message ->
        html.p([class("error"), attribute("role", "alert")], [html.text(message)])
    },
    html.form([class("add-form"), event.on_submit(fn(_) { UserSubmittedTodo })], [
      html.input([
        value(model.new_title),
        event.on_input(UserTypedTitle),
        placeholder("What needs doing?"),
        attribute("aria-label", "New todo"),
      ]),
      html.button([type_("submit"), class("primary"), disabled(model.busy)], [
        html.text("Add"),
      ]),
    ]),
    case model.field_error {
      "" -> element.none()
      message ->
        html.p([class("field-error"), attribute("role", "alert")], [
          html.text(message),
        ])
    },
    case model.todos {
      [] ->
        html.p([class("empty")], [
          html.text("Nothing to do. Add your first todo above."),
        ])
      todos ->
        keyed.ul(
          [class("todo-list")],
          list.map(todos, fn(t) {
            #(
              int.to_string(t.id),
              html.li([class("todo-row")], [
                html.span([class("todo-title")], [html.text(t.title)]),
                html.button(
                  [
                    type_("button"),
                    class("ghost small danger"),
                    event.on_click(UserClickedDelete(t.id)),
                  ],
                  [html.text("Delete")],
                ),
              ]),
            )
          }),
        )
    },
  ]
}
