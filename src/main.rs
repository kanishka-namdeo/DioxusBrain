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
    
    dioxus::web::launch(
        move |cx| {
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
