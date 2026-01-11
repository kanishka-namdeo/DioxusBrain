use dioxus::prelude::*;
use crate::store::{use_store, Backlink};

/// Backlinks panel component showing incoming links to the current page
#[component]
pub fn BacklinksPanel(on_close: EventHandler<()>) -> Element {
    let store = use_store();
    
    // Get backlinks for current page
    let backlinks = {
        let page_id = store.current_page_id.clone();
        page_id.and_then(|id| {
            let links = store.get_backlinks(&id);
            Some(links)
        }).unwrap_or_default()
    };

    // Get current page for display
    let current_page = store.get_current_page();

    rsx! {
        div { class: "flex flex-col w-72 min-w-[280px] max-w-[400px] bg-white dark:bg-obsidian-900 border-l border-obsidian-200 dark:border-obsidian-800 transition-colors duration-200",

            // Header
            div { class: "flex items-center justify-between px-4 py-3 border-b border-obsidian-200 dark:border-obsidian-800",
                div { class: "flex items-center gap-2",
                    svg { class: "w-4 h-4 text-obsidian-500", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24",
                        path { stroke_linecap: "round", stroke_linejoin: "round", stroke_width: "2", d: "M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1" }
                    },
                    span { class: "text-sm font-semibold text-obsidian-700 dark:text-obsidian-300", "Backlinks" }
                },
                button {
                    class: "p-1 rounded hover:bg-obsidian-100 dark:hover:bg-obsidian-800 transition-colors",
                    onclick: move |_| on_close.emit(()),
                    svg { class: "w-4 h-4 text-obsidian-500", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24",
                        path { stroke_linecap: "round", stroke_linejoin: "round", stroke_width: "2", d: "M6 18L18 6M6 6l12 12" }
                    }
                }
            },

            // Page info
            if let Some(page) = current_page {
                div { class: "px-4 py-2 border-b border-obsidian-200 dark:border-obsidian-800 bg-obsidian-50 dark:bg-obsidian-900/50",
                    div { class: "text-xs text-obsidian-500 dark:text-obsidian-500 mb-1", "Links to this page" },
                    div { class: "flex items-center gap-2",
                        if let Some(icon) = &page.icon {
                            span { class: "text-sm", "{icon}" }
                        }
                        span { class: "text-sm font-medium text-obsidian-800 dark:text-obsidian-200", "{page.title}" }
                    }
                }
            },

            // Backlinks list
            div { class: "flex-1 overflow-y-auto",
                if backlinks.is_empty() {
                    div { class: "px-4 py-8 text-center",
                        svg { class: "w-12 h-12 mx-auto mb-3 text-obsidian-300 dark:text-obsidian-700", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24",
                            path { stroke_linecap: "round", stroke_linejoin: "round", stroke_width: "1.5", d: "M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1" }
                        },
                        div { class: "text-sm text-obsidian-500 dark:text-obsidian-500 mb-2", "No backlinks yet" },
                        div { class: "text-xs text-obsidian-400 dark:text-obsidian-600",
                            "Link to this page using [[{page_title}]] to see it here",
                            page_title: current_page.as_ref().map(|p| &p.title).unwrap_or("page")
                        }
                    }
                } else {
                    div { class: "py-2",
                        // Group by page
                        let mut grouped: std::collections::HashMap<String, Vec<Backlink>> = std::collections::HashMap::new();
                        for link in &backlinks {
                            grouped.entry(link.page_title.clone())
                                .or_insert_with(Vec::new)
                                .push(link.clone());
                        }

                        for (page_title, links) in grouped {
                            div { class: "mb-3",
                                // Page header
                                button {
                                    class: "w-full px-4 py-2 text-left hover:bg-obsidian-50 dark:hover:bg-obsidian-800/50 transition-colors",
                                    onclick: move |_| {
                                        // Find and navigate to the page
                                        if let Some((page_id, _)) = store.pages.iter()
                                            .find(|(_, p)| p.title == page_title) {
                                            store.set_current_page(Some(page_id.clone()));
                                        }
                                    },
                                    div { class: "flex items-center gap-2",
                                        svg { class: "w-3 h-3 text-obsidian-400", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24",
                                            path { stroke_linecap: "round", stroke_linejoin: "round", stroke_width: "2", d: "M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" }
                                        },
                                        span { class: "text-sm font-medium text-obsidian-700 dark:text-obsidian-300", "{page_title}" }
                                    }
                                },

                                // Context snippets
                                div { class: "ml-4 mr-4 space-y-1",
                                    for link in links {
                                        div {
                                            class: "text-xs text-obsidian-500 dark:text-obsidian-500 p-2 bg-obsidian-50 dark:bg-obsidian-900/50 rounded border-l-2 border-logseq-blue",
                                            "{crate::utils::truncate_text(&link.context, 100)}"
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            },

            // Footer with stats
            div { class: "px-4 py-3 border-t border-obsidian-200 dark:border-obsidian-800 bg-obsidian-50 dark:bg-obsidian-900/50",
                div { class: "flex items-center justify-between text-xs text-obsidian-500 dark:text-obsidian-500",
                    span { format!("{} link{}", backlinks.len(), if backlinks.len() != 1 { "s" } else { "" }) },
                    span { "Updated just now" }
                }
            }
        }
    }
}

/// Outlinks panel (optional, shows outgoing links from current page)
#[component]
pub fn OutlinksPanel(on_close: EventHandler<()>) -> Element {
    let store = use_store();
    
    let current_page = store.get_current_page();
    let outlinks: Vec<String> = current_page
        .and_then(|page| {
            Some(
                page.blocks.iter()
                    .filter_map(|block_id| store.blocks.get(block_id))
                    .flat_map(|block| crate::graph::KnowledgeGraph::extract_wikilinks(&block.content))
                    .collect()
            )
        })
        .unwrap_or_default();

    rsx! {
        div { class: "flex flex-col w-72 bg-white dark:bg-obsidian-900 border-l border-obsidian-200 dark:border-obsidian-800",

            // Header
            div { class: "flex items-center justify-between px-4 py-3 border-b border-obsidian-200 dark:border-obsidian-800",
                span { class: "text-sm font-semibold text-obsidian-700 dark:text-obsidian-300", "Outlinks" },
                button {
                    class: "p-1 rounded hover:bg-obsidian-100 dark:hover:bg-obsidian-800",
                    onclick: move |_| on_close.emit(()),
                    svg { class: "w-4 h-4 text-obsidian-500", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24",
                        path { stroke_linecap: "round", stroke_linejoin: "round", stroke_width: "2", d: "M6 18L18 6M6 6l12 12" }
                    }
                }
            },

            // Outlinks list
            div { class: "flex-1 overflow-y-auto py-2",
                if outlinks.is_empty() {
                    div { class: "px-4 py-8 text-center text-sm text-obsidian-500 dark:text-obsidian-500",
                        "No outlinks"
                    }
                } else {
                    div { class: "space-y-1 px-2",
                        for link in outlinks {
                            button {
                                class: "w-full flex items-center gap-2 px-3 py-2 rounded-lg hover:bg-obsidian-50 dark:hover:bg-obsidian-800 transition-colors text-left",
                                onclick: move |_| {
                                    // Find and navigate to the linked page
                                    if let Some((page_id, _)) = store.pages.iter()
                                        .find(|(_, p)| p.title.to_lowercase() == link.to_lowercase()) {
                                        store.set_current_page(Some(page_id.clone()));
                                    } else {
                                        // Create new page if it doesn't exist
                                        let new_id = store.create_page(&link);
                                        store.set_current_page(Some(new_id));
                                    }
                                },
                                svg { class: "w-4 h-4 text-obsidian-400", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24",
                                    path { stroke_linecap: "round", stroke_linejoin: "round", stroke_width: "2", d: "M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1" }
                                },
                                span { class: "text-sm text-obsidian-700 dark:text-obsidian-300", "{link}" }
                            }
                        }
                    }
                }
            }
        }
    }
}
