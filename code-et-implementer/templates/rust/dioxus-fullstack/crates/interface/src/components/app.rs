use dioxus::prelude::*;

use crate::components::UserCard;

#[component]
pub fn App() -> Element {
    rsx! {
        div { class: "app",
            h1 { "{{name}}" }
            p { "Pure-Rust full-stack — Dioxus 0.7+ on web, desktop, mobile." }
            UserCard { email: "alice@example.com".to_string() }
        }
    }
}
