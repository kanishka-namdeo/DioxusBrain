use dioxus::prelude::*;
use crate::store::{use_store, AppState, Theme};
use crate::components::{Sidebar, Editor, BacklinksPanel, GraphView, CommandPalette};
use crate::storage::{StorageManager, use_storage};

/// Main App component with three-panel layout
#[component]
pub fn App() -> Element {
    // Global state management
    let store = use_store();
    let _storage = use_storage();

    // Command palette state
    let show_command_palette = use_signal(|| false);
    let current_view = use_signal(|| "editor".to_string());

    // Keyboard shortcuts
    use_effect(move || {
        let closure = |event: web_sys::KeyboardEvent| {
            if event.ctrl_key() || event.meta_key() {
                match event.key().as_str() {
                    "k" => {
                        event.prevent_default();
                        show_command_palette.set(true);
                    }
                    "p" => {
                        event.prevent_default();
                        show_command_palette.set(true);
                    }
                    "\\" => {
                        event.prevent_default();
                        store.set_left_sidebar_open(!store.left_sidebar_open);
                    }
                    "|" => {
                        event.prevent_default();
                        store.set_right_sidebar_open(!store.right_sidebar_open);
                    }
                    _ => {}
                }
            }
            if event.key() == "Escape" {
                show_command_palette.set(false);
            }
        };

        let window = web_sys::window().unwrap();
        let document = window.document().unwrap();
        let listener = document.add_event_listener_with_callback("keydown", closure.as_ref().unchecked_ref());
        
        move || {
            if let Ok(listener) = listener {
                let _ = document.remove_event_listener_with_callback("keydown", closure.as_ref().unchecked_ref());
            }
        }
    });

    let is_dark = store.theme == Theme::Dark;

    rsx! {
        div {
            class: "h-screen w-screen flex flex-col bg-obsidian-50 dark:bg-obsidian-950 text-obsidian-900 dark:text-obsidian-100 transition-colors duration-200",
            class: if is_dark { "dark" } else { "" },

            // Header / Top bar
            header {
                class: "flex items-center justify-between px-4 py-2 border-b border-obsidian-200 dark:border-obsidian-800 bg-white dark:bg-obsidian-900 transition-colors duration-200",

                // Left section
                div { class: "flex items-center gap-3",

                    // Menu button
                    button {
                        class: "p-2 rounded-lg hover:bg-obsidian-100 dark:hover:bg-obsidian-800 transition-colors",
                        onclick: move |_| store.set_left_sidebar_open(!store.left_sidebar_open),
                        svg {
                            class: "w-5 h-5 text-obsidian-600 dark:text-obsidian-400",
                            fill: "none",
                            stroke: "currentColor",
                            viewBox: "0 0 24 24",
                            path { stroke_linecap: "round", stroke_linejoin: "round", stroke_width: "2", d: "M4 6h16M4 12h16M4 18h16" }
                        }
                    },

                    // App title
                    h1 {
                        class: "text-lg font-semibold text-obsidian-700 dark:text-obsidian-200",
                        "DioxusBrain"
                    }
                },

                // Center section - Breadcrumb/Page title
                div { class: "flex items-center gap-2 text-sm text-obsidian-600 dark:text-obsidian-400",

                    if let Some(page) = store.get_current_page() {
                        span { "📄" }
                        span { class: "font-medium", "{page.title}" }
                    } else {
                        span { "No page selected" }
                    }
                },

                // Right section
                div { class: "flex items-center gap-2",

                    // View switcher
                    div { class: "flex rounded-lg border border-obsidian-200 dark:border-obsidian-700 overflow-hidden",

                        button {
                            class: format!("px-3 py-1 text-sm transition-colors {}",
                                if current_view() == "editor" {
                                    "bg-obsidian-100 dark:bg-obsidian-800 text-obsidian-900 dark:text-obsidian-100"
                                } else {
                                    "hover:bg-obsidian-50 dark:hover:bg-obsidian-900 text-obsidian-600 dark:text-obsidian-400"
                                }
                            ),
                            onclick: move |_| current_view.set("editor".to_string()),
                            "Editor"
                        },
                        button {
                            class: format!("px-3 py-1 text-sm transition-colors {}",
                                if current_view() == "graph" {
                                    "bg-obsidian-100 dark:bg-obsidian-800 text-obsidian-900 dark:text-obsidian-100"
                                } else {
                                    "hover:bg-obsidian-50 dark:hover:bg-obsidian-900 text-obsidian-600 dark:text-obsidian-400"
                                }
                            ),
                            onclick: move |_| current_view.set("graph".to_string()),
                            "Graph"
                        }
                    },

                    // Command palette trigger
                    button {
                        class: "flex items-center gap-2 px-3 py-1.5 text-sm bg-obsidian-100 dark:bg-obsidian-800 rounded-lg hover:bg-obsidian-200 dark:hover:bg-obsidian-700 transition-colors",
                        onclick: move |_| show_command_palette.set(true),
                        svg {
                            class: "w-4 h-4 text-obsidian-600 dark:text-obsidian-400",
                            fill: "none",
                            stroke: "currentColor",
                            viewBox: "0 0 24 24",
                            path { stroke_linecap: "round", stroke_linejoin: "round", stroke_width: "2", d: "M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" }
                        },
                        span { class: "text-obsidian-600 dark:text-obsidian-400", "Search" }
                        span { class: "px-1.5 py-0.5 text-xs bg-white dark:bg-obsidian-700 rounded border border-obsidian-200 dark:border-obsidian-600", "⌘K" }
                    },

                    // Theme toggle
                    button {
                        class: "p-2 rounded-lg hover:bg-obsidian-100 dark:hover:bg-obsidian-800 transition-colors",
                        onclick: move |_| store.toggle_theme(),
                        svg {
                            class: "w-5 h-5 text-obsidian-600 dark:text-obsidian-400",
                            fill: "none",
                            stroke: "currentColor",
                            viewBox: "0 0 24 24",
                            if is_dark {
                                path { stroke_linecap: "round", stroke_linejoin: "round", stroke_width: "2", d: "M12 3v1m0 16v1m9-9h-1M4 12H3m15.364 6.364l-.707-.707M6.343 6.343l-.707-.707m12.728 0l-.707.707M6.343 17.657l-.707.707M16 12a4 4 0 11-8 0 4 4 0 018 0z" }
                            } else {
                                path { stroke_linecap: "round", stroke_linejoin: "round", stroke_width: "2", d: "M20.354 15.354A9 9 0 018.646 3.646 9.003 9.003 0 0012 21a9.003 9.003 0 008.354-5.646z" }
                            }
                        }
                    },

                    // Right sidebar toggle
                    button {
                        class: "p-2 rounded-lg hover:bg-obsidian-100 dark:hover:bg-obsidian-800 transition-colors",
                        onclick: move |_| store.set_right_sidebar_open(!store.right_sidebar_open),
                        svg {
                            class: "w-5 h-5 text-obsidian-600 dark:text-obsidian-400",
                            fill: "none",
                            stroke: "currentColor",
                            viewBox: "0 0 24 24",
                            path { stroke_linecap: "round", stroke_linejoin: "round", stroke_width: "2", d: "M9 17V7m0 10a2 2 0 01-2 2H5a2 2 0 01-2-2V7a2 2 0 012-2h2a2 2 0 012 2m0 10a2 2 0 002 2h2a2 2 0 002-2M9 7a2 2 0 012-2h2a2 2 0 012 2m0 10V7m0 10a2 2 0 002 2h2a2 2 0 002-2V7a2 2 0 00-2-2h-2a2 2 0 00-2 2" }
                        }
                    }
                }
            },

            // Main content area with sidebars
            div { class: "flex-1 flex overflow-hidden",

                // Left Sidebar
                if store.left_sidebar_open {
                    Sidebar {
                        on_close: move |_| store.set_left_sidebar_open(false)
                    }
                },

                // Main content
                div { class: "flex-1 flex flex-col overflow-hidden bg-obsidian-50 dark:bg-obsidian-950 transition-colors duration-200",

                    match current_view().as_str() {
                        "editor" => Editor {},
                        "graph" => GraphView {},
                        _ => Editor {}
                    }
                },

                // Right Sidebar (Backlinks)
                if store.right_sidebar_open {
                    BacklinksPanel {
                        on_close: move |_| store.set_right_sidebar_open(false)
                    }
                }
            },

            // Command Palette Overlay
            if show_command_palette() {
                CommandPalette {
                    on_close: move |_| show_command_palette.set(false)
                }
            }
        }
    }
}
