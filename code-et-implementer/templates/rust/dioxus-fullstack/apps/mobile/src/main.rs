//! Mobile (iOS + Android) renderer — Dioxus 0.7 mobile. Build with `dx build --platform mobile`.
//! Mobile is best-effort: requires xcode (iOS) or android-ndk locally; CI builds web + desktop only.

use interface::components::App;

fn main() {
    dioxus::launch(App);
}
