//! Web (WASM) renderer — Dioxus 0.7 web. Build with `dx build --platform web`.

use interface::components::App;

fn main() {
    dioxus::launch(App);
}
