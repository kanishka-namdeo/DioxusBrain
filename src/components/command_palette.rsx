use dioxus::prelude::*;
use crate::store::{use_store, Theme};
use crate::utils::{get_today_title, slugify};

/// Command palette component (Ctrl/Cmd + K)
#[component]
pub fn CommandPalette(on_close: EventHandler<()>) -> Element {
    let store = use_store();
    let query = use_signal(|| String::new());
    let selected_index = use_signal(|| 0usize);
    let input_ref = use_signal(|| Option::<web_sys::HtmlInputElement>::None);

    // Focus input on mount
    use_effect(move || {
        if let Some(input) = input_ref.as_ref() {
            let _ = input.focus();
        }
    });

    // Filter commands and pages based on query
    let filtered_commands = use_memo(move || {
        let q = query.to_lowercase();
        
        // Available commands
        let commands: Vec<Command> = vec![
            Command {
                id: "new_page",
                title: "Create new page",
                shortcut: "⌘N",
                icon: "📄",
                action: move |_| {
                    let title = if q.is_empty() { "Untitled" } else { &q };
                    let page_id = store.create_page(title);
                }
            },
            Command {
                id: "today_note",
                title: "Open today's note",
                shortcut: "⌘T",
                icon: "📅",
                action: move |_| {
                    let today = get_today_title();
                    if !store.pages.values().any(|p| p.title == today) {
                        let page_id = store.create_page(&today);
                        if let Some(page) = store.pages.get_mut(&page_id) {
                            page.icon = Some("📅".to_string());
                        }
                    } else if let Some((page_id, _)) = store.pages.iter().find(|(_, p)| p.title == today) {
                        store.set_current_page(Some(page_id.clone()));
                    }
                }
            },
            Command {
                id: "toggle_theme",
                title: "Toggle dark/light mode",
                shortcut: "⌘D",
                icon: if store.theme == Theme::Dark { "☀️" } else { "🌙" },
                action: move |_| {
                    store.toggle_theme();
                }
            },
            Command {
                id: "toggle_sidebar",
                title: "Toggle sidebar",
                shortcut: "⌘\\",
                icon: "📑",
                action: move |_| {
                    store.set_left_sidebar_open(!store.left_sidebar_open);
                }
            },
            Command {
                id: "toggle_backlinks",
                title: "Toggle backlinks panel",
                shortcut: "⌘|",
                icon: "🔗",
                action: move |_| {
                    store.set_right_sidebar_open(!store.right_sidebar_open);
                }
            },
            Command {
                id: "export_data",
                title: "Export all data",
                shortcut: "",
                icon: "📤",
                action: move |_| {
                    // TODO: Export functionality
                    web_sys::console::log_1(&"Export data");
                }
            },
            Command {
                id: "search_pages",
                title: "Search pages...",
                shortcut: "⌘P",
                icon: "🔍",
                action: move |_| {
                    // Focus on command palette with search
                }
            },
        ];

        // Filter commands
        let filtered: Vec<Command> = commands.into_iter()
            .filter(|cmd| cmd.title.to_lowercase().contains(&q) || q.is_empty())
            .collect();

        // If query is not empty, also search pages
        let page_results: Vec<PageSearchResult> = if !q.is_empty() {
            store.pages.values()
                .filter(|page| {
                    page.title.to_lowercase().contains(&q) ||
                    page.tags.iter().any(|t| t.to_lowercase().contains(&q))
                })
                .map(|page| PageSearchResult {
                    id: page.id.clone(),
                    title: page.title.clone(),
                    icon: page.icon.clone(),
                    tags: page.tags.clone(),
                })
                .collect()
        } else {
            Vec::new()
        };

        (filtered, page_results)
    });

    // Handle keyboard navigation
    let handle_keydown = move |e: web_sys::KeyboardEvent| {
        let total = filtered_commands.read().0.len() + filtered_commands.read().1.len();
        
        match e.key().as_str() {
            "ArrowDown" => {
                e.prevent_default();
                let current = *selected_index.read();
                if current < total.saturating_sub(1) {
                    selected_index.set(current + 1);
                }
            }
            "ArrowUp" => {
                e.prevent_default();
                let current = *selected_index.read();
                if current > 0 {
                    selected_index.set(current.saturating_sub(1));
                }
            }
            "Enter" => {
                e.prevent_default();
                let current = *selected_index.read();
                let (commands, pages) = &*filtered_commands.read();
                
                if current < commands.len() {
                    // Execute command
                    let cmd = &commands[current];
                    cmd.action.clone()("");
                    on_close.emit(());
                } else if current >= commands.len() && current < commands.len() + pages.len() {
                    // Navigate to page
                    let page = &pages[current - commands.len()];
                    store.set_current_page(Some(page.id.clone()));
                    on_close.emit(());
                }
            }
            "Escape" => {
                on_close.emit(());
            }
            _ => {}
        }
    };

    rsx! {
        // Backdrop
        div {
            class: "fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-start justify-center pt-[20vh]",
            onclick: move |e| {
                if e.target == e.current_target {
                    on_close.emit(());
                }
            },

            // Palette container
            div {
                class: "w-full max-w-xl bg-white dark:bg-obsidian-900 rounded-xl shadow-2xl overflow-hidden animate-fade-in",
                onkeydown: handle_keydown,

                // Search input
                div { class: "flex items-center gap-3 px-4 py-3 border-b border-obsidian-200 dark:border-obsidian-800",
                    svg { class: "w-5 h-5 text-obsidian-400", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24",
                        path { stroke_linecap: "round", stroke_linejoin: "round", stroke_width: "2", d: "M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" }
                    },
                    input {
                        ref: move |el| input_ref.set(Some(el)),
                        class: "flex-1 bg-transparent text-lg text-obsidian-900 dark:text-obsidian-100 placeholder-obsidian-400 focus:outline-none",
                        placeholder: "Type a command or search pages...",
                        value: "{query}",
                        oninput: move |e| {
                            query.set(e.value().clone());
                            selected_index.set(0);
                        }
                    },
                    span { class: "px-2 py-1 text-xs bg-obsidian-100 dark:bg-obsidian-800 text-obsidian-500 dark:text-obsidian-500 rounded",
                        "ESC"
                    }
                },

                // Results
                div { class: "max-h-[60vh] overflow-y-auto py-2",
                    
                    // Commands section
                    let (commands, pages) = &*filtered_commands.read();
                    
                    if !commands.is_empty() {
                        div { class: "px-2 py-1",
                            div { class: "px-3 py-1 text-xs font-semibold text-obsidian-500 dark:text-obsidian-500 uppercase tracking-wider",
                                if query.trim().is_empty() { "Commands" } else { "Commands" }
                            },
                            for (i, cmd) in commands.iter().enumerate() {
                                CommandItem {
                                    command: cmd.clone(),
                                    is_selected: *selected_index.read() == i,
                                    query: query.clone()
                                }
                            }
                        }
                    },

                    // Pages section (only when searching)
                    if !pages.is_empty() {
                        div { class: "px-2 py-1",
                            div { class: "px-3 py-1 text-xs font-semibold text-obsidian-500 dark:text-obsidian-500 uppercase tracking-wider", "Pages" },
                            for (i, page) in pages.iter().enumerate() {
                                let index = commands.len() + i;
                                PageSearchItem {
                                    page: page.clone(),
                                    is_selected: *selected_index.read() == index
                                }
                            }
                        }
                    },

                    // Empty state
                    if commands.is_empty() && pages.is_empty() && !query.trim().is_empty() {
                        div { class: "px-4 py-8 text-center text-obsidian-500 dark:text-obsidian-500",
                            svg { class: "w-12 h-12 mx-auto mb-3 text-obsidian-300 dark:text-obsidian-700", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24",
                                path { stroke_linecap: "round", stroke_linejoin: "round", stroke_width: "1.5", d: "M9.172 16.172a4 4 0 015.656 0M9 10h.01M15 10h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" }
                            },
                            div { class: "text-sm", "No results found" },
                            div { class: "text-xs mt-1 text-obsidian-400",
                                "Press ⌘N to create a new page"
                            }
                        }
                    }
                },

                // Footer
                div { class: "flex items-center justify-between px-4 py-2 border-t border-obsidian-200 dark:border-obsidian-800 bg-obsidian-50 dark:bg-obsidian-900/50 text-xs text-obsidian-500 dark:text-obsidian-500",
                    div { class: "flex items-center gap-4",
                        span { "↑↓ to navigate" },
                        span { "↵ to select" }
                    },
                    div { class: "flex items-center gap-2",
                        svg { class: "w-4 h-4", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24",
                            path { stroke_linecap: "round", stroke_linejoin: "round", stroke_width: "2", d: "M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" }
                        },
                        span { "DioxusBrain" }
                    }
                }
            }
        }
    }
}

/// Command item component
#[component]
pub fn CommandItem(command: Command, is_selected: bool, query: String) -> Element {
    rsx! {
        button {
            class: format!("w-full flex items-center gap-3 px-3 py-2 rounded-lg text-left transition-colors {}",
                if is_selected {
                    "bg-logseq-blue/10 text-logseq-blue dark:bg-logseq-blue/20"
                } else {
                    "hover:bg-obsidian-50 dark:hover:bg-obsidian-800 text-obsidian-700 dark:text-obsidian-300"
                }
            ),
            
            // Icon
            span { class: "text-lg", "{command.icon}" },

            // Title with query highlight
            div { class: "flex-1 min-w-0",
                let title = command.title.clone();
                let q = query.to_lowercase();
                let highlighted = if q.is_empty() || !title.to_lowercase().contains(&q) {
                    rsx! { span { "{title}" } }
                } else {
                    // Simple highlight - split on query
                    let parts: Vec<&str> = title.split(&q).collect();
                    rsx! {
                        for (i, part) in parts.iter().enumerate() {
                            span { "{part}" }
                            if i < parts.len() - 1 {
                                span { class: "bg-yellow-200 dark:bg-yellow-900/50", "{q}" }
                            }
                        }
                    }
                },
                { highlighted }
            },

            // Shortcut
            if !command.shortcut.is_empty() {
                span { class: format!("text-xs px-1.5 py-0.5 rounded {}",
                    if is_selected {
                        "bg-logseq-blue/20"
                    } else {
                        "bg-obsidian-100 dark:bg-obsidian-800 text-obsidian-500 dark:text-obsidian-500"
                    }
                ), "{command.shortcut}" }
            }
        }
    }
}

/// Page search result item
#[component]
pub fn PageSearchItem(page: PageSearchResult, is_selected: bool) -> Element {
    let store = use_store();
    let is_active = store.current_page_id.as_ref() == Some(&page.id);

    rsx! {
        button {
            class: format!("w-full flex items-center gap-3 px-3 py-2 rounded-lg text-left transition-colors {}",
                if is_selected {
                    "bg-logseq-blue/10"
                } else if is_active {
                    "bg-obsidian-100 dark:bg-obsidian-800"
                } else {
                    "hover:bg-obsidian-50 dark:hover:bg-obsidian-800"
                }
            ),
            onclick: move |_| {
                store.set_current_page(Some(page.id.clone()));
            },

            // Icon
            span { class: "text-lg", page.icon.as_ref().unwrap_or(&"📄".to_string()) },

            // Title
            span { class: format!("flex-1 text-sm {}",
                if is_active {
                    "text-logseq-blue font-medium"
                } else {
                    "text-obsidian-700 dark:text-obsidian-300"
                }
            ), "{page.title}" },

            // Tags
            if !page.tags.is_empty() {
                div { class: "flex items-center gap-1",
                    for tag in &page.tags[..page.tags.len().min(2)] {
                        span { class: "text-xs px-1.5 py-0.5 bg-obsidian-100 dark:bg-obsidian-800 text-obsidian-500 dark:text-obsidian-500 rounded", "#{}", tag }
                    }
                    if page.tags.len() > 2 {
                        span { class: "text-xs text-obsidian-400", "+{} more", page.tags.len() - 2 }
                    }
                }
            }
        }
    }
}

/// Command type
#[derive(Clone, Debug)]
pub struct Command {
    pub id: &'static str,
    pub title: String,
    pub shortcut: String,
    pub icon: &'static str,
    pub action: Arc<dyn Fn(&str)>,
}

/// Page search result
#[derive(Clone, Debug)]
pub struct PageSearchResult {
    pub id: String,
    pub title: String,
    pub icon: Option<String>,
    pub tags: Vec<String>,
}
