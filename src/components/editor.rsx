use dioxus::prelude::*;
use crate::store::{use_store, Theme};
use crate::components::block::BlockComponent;

/// Main editor component for editing pages
#[component]
pub fn Editor() -> Element {
    let store = use_store();
    let editing_title = use_signal(|| false);
    let title_input = use_signal(|| String::new());

    // Get current page
    let current_page = store.read().get_current_page().cloned();

    let store_clone = store.clone();

    // Handle page title editing
    let start_editing_title = move || {
        if let Some(page) = current_page.as_ref() {
            title_input.set(page.title.clone());
            editing_title.set(true);
        }
    };

    let save_title = move || {
        let title = title_input.read().clone();
        if !title.trim().is_empty() {
            if let Some(page_id) = store.read().current_page_id.clone() {
                store_clone.write().update_page_title(&page_id, &title.trim());
            }
        }
        editing_title.set(false);
    };

    // Create new block
    let create_block = move || {
        let mut store = store_clone.write();
        if let Some(page_id) = store.current_page_id.clone() {
            if let Some(page) = store.pages.get_mut(&page_id) {
                let new_block_id = store.create_block(None);
                page.blocks.push(new_block_id.clone());
            }
        }
    };

    // Keyboard shortcuts for editor
    use_effect(move || {
        let create_block = create_block.clone();
        let closure = move |event: web_sys::KeyboardEvent| {
            if !editing_title() {
                match event.key().as_str() {
                    "n" if event.ctrl_key() => {
                        event.prevent_default();
                        create_block();
                    }
                    _ => {}
                }
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

    let is_dark = store.read().theme == Theme::Dark;

    match current_page {
        Some(page) => rsx! {
            // Page header
            div { class: "px-8 py-6 border-b border-obsidian-200 dark:border-obsidian-800 bg-white dark:bg-obsidian-900 transition-colors duration-200",

                // Page controls
                div { class: "flex items-center gap-2 mb-3",
                    // Page icon
                    button {
                        class: "p-1 rounded hover:bg-obsidian-100 dark:hover:bg-obsidian-800 transition-colors",
                        onclick: move |_| {},
                        span { class: "text-xl", page.icon.as_ref().unwrap_or(&"📄".to_string()) }
                    },

                    // Theme toggle
                    button {
                        class: "p-1 rounded hover:bg-obsidian-100 dark:hover:bg-obsidian-800 transition-colors",
                        onclick: move |_| store.write().toggle_theme(),
                        svg { class: "w-4 h-4 text-obsidian-500", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24",
                            if is_dark {
                                path { stroke_linecap: "round", stroke_linejoin: "round", stroke_width: "2", d: "M12 3v1m0 16v1m9-9h-1M4 12H3m15.364 6.364l-.707-.707M6.343 6.343l-.707-.707m12.728 0l-.707.707M6.343 17.657l-.707.707M16 12a4 4 0 11-8 0 4 4 0 018 0z" }
                            } else {
                                path { stroke_linecap: "round", stroke_linejoin: "round", stroke_width: "2", d: "M20.354 15.354A9 9 0 018.646 3.646 9.003 9.003 0 0012 21a9.003 9.003 0 008.354-5.646z" }
                            }
                        }
                    }
                },

                // Page title
                if editing_title() {
                    input {
                        class: "w-full text-3xl font-bold bg-transparent border-none focus:outline-none text-obsidian-900 dark:text-obsidian-100 placeholder-obsidian-300 dark:placeholder-obsidian-600",
                        value: "{title_input}",
                        oninput: move |e| title_input.set(e.value().clone()),
                        onkeydown: move |e| {
                            if e.key() == "Enter" {
                                save_title();
                            } else if e.key() == "Escape" {
                                editing_title.set(false);
                            }
                        },
                        autofocus: true,
                        onfocusout: move |_| save_title()
                    }
                } else {
                    div {
                        class: "flex items-center gap-3 group",
                        onclick: move |_| start_editing_title(),
                        h1 { class: "text-3xl font-bold text-obsidian-900 dark:text-obsidian-100 cursor-text", "{page.title}" },
                        svg { class: "w-4 h-4 text-obsidian-400 opacity-0 group-hover:opacity-100 transition-opacity", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24",
                            path { stroke_linecap: "round", stroke_linejoin: "round", stroke_width: "2", d: "M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" }
                        }
                    }
                },

                // Page metadata
                div { class: "flex items-center gap-4 mt-3 text-sm text-obsidian-500 dark:text-obsidian-500",
                    span { "Created {crate::utils::format_relative_time(&page.created_at)}" },
                    if page.updated_at != page.created_at {
                        span { "Updated {crate::utils::format_relative_time(&page.updated_at)}" }
                    },
                    // Tags
                    if !page.tags.is_empty() {
                        div { class: "flex items-center gap-1 ml-auto",
                            for tag in &page.tags {
                                span { class: "tag", "#{}", tag }
                            }
                        }
                    }
                }
            },

            // Properties section (if any)
            if !page.properties.is_empty() {
                div { class: "px-8 py-4 border-b border-obsidian-200 dark:border-obsidian-800 bg-obsidian-50 dark:bg-obsidian-900/50",
                    div { class: "text-xs font-semibold text-obsidian-500 dark:text-obsidian-500 uppercase tracking-wider mb-2", "Properties" },
                    div { class: "grid grid-cols-2 gap-x-8 gap-y-2",
                        for (key, value) in &page.properties {
                            div { class: "flex items-baseline gap-2",
                                span { class: "text-sm font-medium text-obsidian-700 dark:text-obsidian-300", "{key}" },
                                span { class: "text-sm text-obsidian-600 dark:text-obsidian-400", "{value}" }
                            }
                        }
                    }
                }
            },

            // Blocks editor
            div { class: "flex-1 overflow-y-auto px-8 py-4",
                div { class: "space-y-1",
                    // Render top-level blocks
                    for block_id in &page.blocks {
                        BlockComponent { block_id: block_id.clone(), page_id: page.id.clone() }
                    },

                    // Add block button
                    button {
                        class: "flex items-center gap-2 w-full py-2 text-sm text-obsidian-400 dark:text-obsidian-600 hover:text-obsidian-600 dark:hover:text-obsidian-400 transition-colors",
                        onclick: move |_| create_block(),
                        svg { class: "w-4 h-4", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24",
                            path { stroke_linecap: "round", stroke_linejoin: "round", stroke_width: "2", d: "M12 4v16m8-8H4" }
                        },
                        span { "Click to add a block" }
                    }
                }
            }
        },
        None => rsx! {
            // Empty state
            div { class: "flex-1 flex items-center justify-center",
                div { class: "text-center",
                    div { class: "text-6xl mb-4", "🧠" },
                    h2 { class: "text-xl font-semibold text-obsidian-700 dark:text-obsidian-300 mb-2", "Welcome to DioxusBrain" },
                    p { class: "text-obsidian-500 dark:text-obsidian-500 mb-4", "Your knowledge awaits. Select or create a page to get started." },
                    div { class: "flex items-center justify-center gap-4",
                        button {
                            class: "px-4 py-2 bg-logseq-blue text-white rounded-lg hover:bg-blue-600 transition-colors",
                            onclick: move |_| {
                                let page_id = store.write().create_page("Welcome");
                                if let Some(page) = store.write().pages.get_mut(&page_id) {
                                    page.icon = Some("👋".to_string());
                                    store.write().create_block(None);
                                }
                            },
                            "Create Welcome Page"
                        },
                        button {
                            class: "px-4 py-2 bg-obsidian-100 dark:bg-obsidian-800 text-obsidian-700 dark:text-obsidian-300 rounded-lg hover:bg-obsidian-200 dark:hover:bg-obsidian-700 transition-colors",
                            onclick: move |_| {
                                let today = crate::utils::get_today_title();
                                let has_today = store.read().pages.values().any(|p| p.title == today);
                                if !has_today {
                                    let page_id = store.write().create_page(&today);
                                    if let Some(page) = store.write().pages.get_mut(&page_id) {
                                        page.icon = Some("📅".to_string());
                                    }
                                }
                            },
                            "Today's Note"
                        }
                    },
                    // Keyboard shortcuts help
                    div { class: "mt-8 text-sm text-obsidian-400 dark:text-obsidian-600",
                        div { class: "mb-1", "⌘K - Open command palette" },
                        div { class: "mb-1", "Ctrl+N - New block" },
                        div { class: "mb-1", "Enter - New block" },
                        div { class: "mb-1", "Tab - Indent block" },
                        div { "Shift+Tab - Outdent block" }
                    }
                }
            }
        }
    }
}
