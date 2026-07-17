//// Entry point: wires init, update, and view into a Lustre application.

import lustre
import web/update
import web/view

pub fn main() {
  let app = lustre.application(update.init, update.update, view.view)
  let assert Ok(_) = lustre.start(app, "#root", Nil)
}
