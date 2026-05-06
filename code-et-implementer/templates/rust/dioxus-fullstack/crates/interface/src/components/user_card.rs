use dioxus::prelude::*;

#[component]
pub fn UserCard(email: String) -> Element {
    rsx! {
        article { class: "user-card",
            span { class: "user-card__email", "{email}" }
        }
    }
}
