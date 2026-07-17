//// Shared API client: distinguishes network failures, timeouts, and HTTP
//// error statuses, mirroring the behaviour of the previous ReScript client.

import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/option.{type Option, None, Some}
import lustre/effect.{type Effect}

pub type ApiError {
  // status 0 = network failure or timeout (no response at all)
  ApiError(status: Int, message: String)
}

@external(javascript, "./api.ffi.mjs", "do_request")
fn do_request(
  method: String,
  path: String,
  body: String,
  has_body: Bool,
  on_response: fn(Int, String) -> Nil,
  on_network_error: fn(String) -> Nil,
) -> Nil

pub fn get(path: String, to_msg: fn(Result(String, ApiError)) -> msg) -> Effect(msg) {
  request("GET", path, None, to_msg)
}

pub fn post(
  path: String,
  body: Option(json.Json),
  to_msg: fn(Result(String, ApiError)) -> msg,
) -> Effect(msg) {
  request("POST", path, body, to_msg)
}

pub fn delete(path: String, to_msg: fn(Result(String, ApiError)) -> msg) -> Effect(msg) {
  request("DELETE", path, None, to_msg)
}

fn request(
  method: String,
  path: String,
  body: Option(json.Json),
  to_msg: fn(Result(String, ApiError)) -> msg,
) -> Effect(msg) {
  effect.from(fn(dispatch) {
    let #(body_string, has_body) = case body {
      Some(b) -> #(json.to_string(b), True)
      None -> #("", False)
    }
    do_request(
      method,
      path,
      body_string,
      has_body,
      fn(status, text) { dispatch(to_msg(handle_response(status, text))) },
      fn(message) { dispatch(to_msg(Error(ApiError(0, message)))) },
    )
  })
}

fn handle_response(status: Int, text: String) -> Result(String, ApiError) {
  case status >= 200 && status < 300 {
    True -> Ok(text)
    False -> {
      let error_decoder = {
        use message <- decode.field("error", decode.string)
        decode.success(message)
      }
      let hint = case json.parse(text, error_decoder) {
        Ok(message) -> message
        Error(_) -> status_hint(status)
      }
      Error(ApiError(status, "HTTP " <> int.to_string(status) <> ": " <> hint))
    }
  }
}

// The statuses this app can realistically hit, with human-readable hints.
fn status_hint(status: Int) -> String {
  case status {
    400 -> "Bad Request — the server rejected the input"
    401 -> "Unauthorized — you need to log in"
    403 -> "Forbidden — logged in, but not allowed to do this"
    404 -> "Not Found"
    409 -> "Conflict — it already exists"
    500 -> "Internal Server Error — something broke on the server"
    503 -> "Service Unavailable — server is down or restarting"
    _ -> "Unexpected error"
  }
}
