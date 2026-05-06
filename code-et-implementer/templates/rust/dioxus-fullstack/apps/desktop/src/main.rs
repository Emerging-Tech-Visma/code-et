//! Desktop renderer — Dioxus 0.7 desktop. The composition root for desktop is trivial:
//! the `interface::components::App` is rendered by the dioxus-desktop launcher.

use interface::components::App;

fn main() {
    dioxus::launch(App);
}
