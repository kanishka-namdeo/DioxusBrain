use dioxus::prelude::*;
use dioxus_web::Config;

mod app;
mod components;
mod store;
mod storage;
mod graph;
mod utils;

use crate::app::App;
use crate::storage::StorageProvider;

fn main() {
    // Set up better panic messages for debugging
    console_error_panic_hook::set_once();
    
    // Launch the app with Dioxus 0.7
    dioxus_web::launch(
        move |_| {
            rsx! {
                StorageProvider {
                    App {}
                }
            }
        },
        Config::new()
            .root_id("main")
            .hydrate(true)
    );
}
