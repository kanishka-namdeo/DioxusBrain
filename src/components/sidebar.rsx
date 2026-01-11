use dioxus::prelude::*;
use crate::store::{use_store, Page};
use crate::utils::{get_today_title, get_week_dates};

/// Props for the Sidebar component
#[derive(Props, Clone, PartialEq)]
pub struct SidebarProps {
    on_close: EventHandler<()>,
}

/// Sidebar component with file explorer, favorites, and daily notes
#[component]
pub fn Sidebar(props: SidebarProps) -> Element {
    let store = use_store();
    
    let new_page_title = use_signal(|| String::new());
    let sidebar_section = use_signal(|| "pages".to_string());

    // Get pages sorted alphabetically
    let pages = store.read().get_pages_sorted();
    
    // Get recent pages
    let recent_pages = store.read().get_recent_pages(5);
    
    // Get favorite pages
    let favorite_pages = store.read().get_favorite_pages();
    
    // Get pages by tag
    let all_tags = {
        let tags: Vec<_> = store.read().pages.values()
            .flat_map(|p| p.tags.clone())
            .collect();
        let mut tags = tags.into_iter().collect::<std::collections::HashSet<_>>().into_iter().collect::<Vec<_>>();
        tags.sort();
        tags
    };

    let store_clone = store.clone();

    rsx! {
        div { class: "flex flex-col w-64 min-w-[250px] max-w-[400px] bg-white dark:bg-obsidian-900 border-r border-obsidian-200 dark:border-obsidian-800 transition-colors duration-200",
            
            // Header with close button
            div { class: "flex items-center justify-between px-4 py-3 border-b border-obsidian-200 dark:border-obsidian-800",
                span { class: "text-sm font-semibold text-obsidian-700 dark:text-obsidian-300", "Explorer" },
                button {
                    class: "p-1 rounded hover:bg-obsidian-100 dark:hover:bg-obsidian-800 transition-colors",
                    onclick: move |_| props.on_close.call(()),
                    svg { class: "w-4 h-4 text-obsidian-500", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24",
                        path { stroke_linecap: "round", stroke_linejoin: "round", stroke_width: "2", d: "M6 18L18 6M6 6l12 12" }
                    }
                }
            },

            // Quick actions
            div { class: "px-3 py-2",
                button {
                    class: "w-full flex items-center gap-2 px-3 py-2 text-sm bg-logseq-blue text-white rounded-lg hover:bg-blue-600 transition-colors",
                    onclick: move |_| {
                        let today = get_today_title();
                        let has_today = store.read().pages.values().any(|p| p.title == today);
                        if !has_today {
                            store_clone.write().create_page(&today);
                            if let Some(page) = store_clone.write().pages.get_mut(&today) {
                                page.icon = Some("📅".to_string());
                            }
                        }
                    },
                    svg { class: "w-4 h-4", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24",
                        path { stroke_linecap: "round", stroke_linejoin: "round", stroke_width: "2", d: "M12 4v16m8-8H4" }
                    },
                    span { "Today's Note" }
                }
            },

            // New page input
            div { class: "px-3 py-2",
                div { class: "flex gap-2",
                    input {
                        class: "flex-1 px-3 py-1.5 text-sm bg-obsidian-50 dark:bg-obsidian-800 border border-obsidian-200 dark:border-obsidian-700 rounded-lg focus:outline-none focus:ring-2 focus:ring-logseq-blue text-obsidian-900 dark:text-obsidian-100 placeholder-obsidian-400",
                        placeholder: "New page...",
                        value: "{new_page_title}",
                        oninput: move |e| new_page_title.set(e.value().clone()),
                        onkeydown: move |e| {
                            if e.key() == "Enter" && !new_page_title.read().trim().is_empty() {
                                let title = new_page_title.read().trim().to_string();
                                store_clone.write().create_page(&title);
                                new_page_title.set(String::new());
                            }
                        }
                    },
                    button {
                        class: "px-3 py-1.5 bg-obsidian-100 dark:bg-obsidian-800 rounded-lg hover:bg-obsidian-200 dark:hover:bg-obsidian-700 transition-colors",
                        onclick: move |_| {
                            if !new_page_title.read().trim().is_empty() {
                                let title = new_page_title.read().trim().to_string();
                                store_clone.write().create_page(&title);
                                new_page_title.set(String::new());
                            }
                        },
                        svg { class: "w-4 h-4 text-obsidian-600 dark:text-obsidian-400", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24",
                            path { stroke_linecap: "round", stroke_linejoin: "round", stroke_width: "2", d: "M12 4v16m8-8H4" }
                        }
                    }
                }
            },

            // Navigation tabs
            div { class: "flex px-3 py-2 gap-1 border-b border-obsidian-200 dark:border-obsidian-800",
                button {
                    class: format!("flex-1 px-2 py-1 text-xs font-medium rounded transition-colors {}",
                        if sidebar_section() == "pages" {
                            "bg-obsidian-100 dark:bg-obsidian-800 text-obsidian-900 dark:text-obsidian-100"
                        } else {
                            "text-obsidian-500 dark:text-obsidian-500 hover:bg-obsidian-50 dark:hover:bg-obsidian-900"
                        }
                    ),
                    onclick: move |_| sidebar_section.set("pages".to_string()),
                    "Pages"
                },
                button {
                    class: format!("flex-1 px-2 py-1 text-xs font-medium rounded transition-colors {}",
                        if sidebar_section() == "favorites" {
                            "bg-obsidian-100 dark:bg-obsidian-800 text-obsidian-900 dark:text-obsidian-100"
                        } else {
                            "text-obsidian-500 dark:text-obsidian-500 hover:bg-obsidian-50 dark:hover:bg-obsidian-900"
                        }
                    ),
                    onclick: move |_| sidebar_section.set("favorites".to_string()),
                    "Favorites"
                },
                button {
                    class: format!("flex-1 px-2 py-1 text-xs font-medium rounded transition-colors {}",
                        if sidebar_section() == "tags" {
                            "bg-obsidian-100 dark:bg-obsidian-800 text-obsidian-900 dark:text-obsidian-100"
                        } else {
                            "text-obsidian-500 dark:text-obsidian-500 hover:bg-obsidian-50 dark:hover:bg-obsidian-900"
                        }
                    ),
                    onclick: move |_| sidebar_section.set("tags".to_string()),
                    "Tags"
                }
            },

            // Content based on selected section
            div { class: "flex-1 overflow-y-auto",

                match sidebar_section().as_str() {
                    "pages" => rsx! {
                        // Recent pages
                        if !recent_pages.is_empty() {
                            div { class: "px-3 py-2",
                                div { class: "text-xs font-semibold text-obsidian-500 dark:text-obsidian-500 uppercase tracking-wider mb-1", "Recent" },
                                for page in recent_pages {
                                    PageItem { page: page.clone(), on_toggle_favorite: move |_| store_clone.write().toggle_favorite(&page.id) }
                                }
                            }
                        },

                        // All pages
                        div { class: "px-3 py-2",
                            div { class: "text-xs font-semibold text-obsidian-500 dark:text-obsidian-500 uppercase tracking-wider mb-1", "All Pages" },
                            if pages.is_empty() {
                                div { class: "text-sm text-obsidian-400 dark:text-obsidian-600 py-2", "No pages yet" }
                            } else {
                                for page in pages {
                                    PageItem { page: page.clone(), on_toggle_favorite: move |_| store_clone.write().toggle_favorite(&page.id) }
                                }
                            }
                        }
                    },
                    "favorites" => rsx! {
                        div { class: "px-3 py-2",
                            if favorite_pages.is_empty() {
                                div { class: "text-sm text-obsidian-400 dark:text-obsidian-600 py-2",
                                    "No favorites yet. Star a page to add it here."
                                }
                            } else {
                                for page in favorite_pages {
                                    PageItem { page: page.clone(), on_toggle_favorite: move |_| store_clone.write().toggle_favorite(&page.id) }
                                }
                            }
                        }
                    },
                    "tags" => rsx! {
                        div { class: "px-3 py-2",
                            if all_tags.is_empty() {
                                div { class: "text-sm text-obsidian-400 dark:text-obsidian-600 py-2",
                                    "No tags yet. Add #tags to your pages."
                                }
                            } else {
                                for tag in all_tags {
                                    TagItem { tag: tag.clone(), on_click: move |_| {} }
                                }
                            }
                        }
                    },
                    _ => rsx! {}
                }
            },

            // Week calendar (Daily notes)
            div { class: "px-3 py-2 border-t border-obsidian-200 dark:border-obsidian-800",
                div { class: "text-xs font-semibold text-obsidian-500 dark:text-obsidian-500 uppercase tracking-wider mb-2", "Daily Notes" },
                div { class: "grid grid-cols-7 gap-1",
                    for (date, label) in get_week_dates() {
                        let store_clone2 = store_clone.clone();
                        button {
                            class: format!("px-1 py-1 text-xs rounded transition-colors {}",
                                if date == get_today_title() {
                                    "bg-logseq-blue text-white"
                                } else {
                                    "hover:bg-obsidian-100 dark:hover:bg-obsidian-800 text-obsidian-600 dark:text-obsidian-400"
                                }
                            ),
                            onclick: move |_| {
                                let has_date = store_clone2.read().pages.values().any(|p| p.title == date);
                                if !has_date {
                                    store_clone2.write().create_page(&date);
                                }
                            },
                            span { class: "block text-[10px] opacity-70", "{label.split(' ').next().unwrap_or(\"\")}" }
                            span { class: "block font-medium", "{date.split('-').last().unwrap_or(\"\")}" }
                        }
                    }
                }
            }
        }
    }
}

/// Props for PageItem component
#[derive(Props, Clone, PartialEq)]
pub struct PageItemProps {
    page: Page,
    on_toggle_favorite: EventHandler<()>,
}

/// Individual page item component
#[component]
pub fn PageItem(props: PageItemProps) -> Element {
    let store = use_store();
    let is_active = store.read().current_page_id.as_ref() == Some(&props.page.id);
    let is_favorite = store.read().is_favorite(&props.page.id);

    rsx! {
        div {
            class: format!("flex items-center gap-2 px-2 py-1.5 rounded-lg cursor-pointer transition-colors {}",
                if is_active {
                    "bg-obsidian-100 dark:bg-obsidian-800"
                } else {
                    "hover:bg-obsidian-50 dark:hover:bg-obsidian-900"
                }
            ),
            onclick: move |_| {
                store.write().set_current_page(Some(props.page.id.clone()));
            },

            // Favorite button
            button {
                class: "p-0.5 rounded hover:bg-obsidian-200 dark:hover:bg-obsidian-700 transition-colors",
                onclick: move |e| {
                    e.stop_propagation();
                    props.on_toggle_favorite.call(());
                },
                svg {
                    class: format!("w-3.5 h-3.5 {}",
                        if is_favorite {
                            "text-logseq-orange fill-current"
                        } else {
                            "text-obsidian-300 dark:text-obsidian-700"
                        }
                    ),
                    viewBox: "0 0 24 24",
                    path { d: "M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z" }
                }
            },

            // Page icon
            if let Some(icon) = &props.page.icon {
                span { class: "text-sm", "{icon}" }
            },

            // Page title
            span {
                class: format!("flex-1 text-sm truncate {}",
                    if is_active {
                        "text-obsidian-900 dark:text-obsidian-100 font-medium"
                    } else {
                        "text-obsidian-700 dark:text-obsidian-300"
                    }
                ),
                "{props.page.title}"
            }
        }
    }
}

/// Props for TagItem component
#[derive(Props, Clone, PartialEq)]
pub struct TagItemProps {
    tag: String,
    on_click: EventHandler<()>,
}

/// Tag item component
#[component]
pub fn TagItem(props: TagItemProps) -> Element {
    rsx! {
        button {
            class: "flex items-center gap-2 px-2 py-1.5 rounded-lg hover:bg-obsidian-50 dark:hover:bg-obsidian-900 transition-colors w-full text-left",
            onclick: move |_| props.on_click.call(()),
            svg { class: "w-4 h-4 text-purple-500", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24",
                path { stroke_linecap: "round", stroke_linejoin: "round", stroke_width: "2", d: "M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z" }
            },
            span { class: "text-sm text-obsidian-700 dark:text-obsidian-300", "{props.tag}" }
        }
    }
}
