use dioxus::prelude::*;
use crate::store::{use_store, Block};
use crate::utils::{extract_wikilinks, extract_tags, parse_markdown};

/// Individual block component for the outliner
#[component]
pub fn BlockComponent(block_id: String, page_id: String) -> Element {
    let store = use_store();
    let block = store.blocks.get(&block_id);
    let editing = use_signal(|| false);
    let content = use_signal(|| String::new());

    // Initialize content signal when block is available
    use_effect(move || {
        if let Some(b) = store.blocks.get(&block_id) {
            if content.read().is_empty() {
                content.set(b.content.clone());
            }
        }
    });

    let block = block.cloned();

    match block {
        Some(b) => {
            let is_active = store.current_block_id.as_ref() == Some(&block_id);
            let is_child = b.parent_id.is_some();

            // Get child blocks
            let children: Vec<_> = b.children
                .iter()
                .filter_map(|child_id| store.blocks.get(child_id).cloned())
                .collect();

            rsx! {
                div {
                    class: format!("block-wrapper group flex items-start gap-1 {}", if is_active { "active-block" } else { "" }),

                    // Block handle (bullet point)
                    div {
                        class: "block-handle flex-shrink-0 w-6 h-6 flex items-center justify-center cursor-grab active:cursor-grabbing mt-0.5",
                        onmousedown: move |e| {
                            // TODO: Implement drag and drop
                        },
                        if is_child {
                            div { class: "w-1 h-1 rounded-full bg-obsidian-300 dark:bg-obsidian-600" }
                        } else {
                            div { class: "w-1.5 h-1.5 rounded-full bg-obsidian-400 dark:bg-obsidian-500" }
                        }
                    },

                    // Block content
                    div { class: "flex-1 min-w-0",

                        // Editing mode
                        if editing() {
                            textarea {
                                class: "w-full min-h-[1.5em] px-2 py-1 bg-white dark:bg-obsidian-800 border border-logseq-blue rounded resize-none focus:outline-none text-obsidian-900 dark:text-obsidian-100",
                                value: "{content}",
                                oninput: move |e| {
                                    content.set(e.value().clone());
                                },
                                onkeydown: move |e| {
                                    match e.key().as_str() {
                                        "Enter" if !e.shift_key() => {
                                            e.prevent_default();
                                            // Save and create new sibling block
                                            store.update_block_content(&block_id, &content);
                                            if let Some(page) = store.pages.get_mut(&page_id) {
                                                let new_block_id = store.create_block(b.parent_id.clone());
                                                page.blocks.push(new_block_id);
                                            }
                                            editing.set(false);
                                        }
                                        "Escape" => {
                                            content.set(b.content.clone());
                                            editing.set(false);
                                        }
                                        "Tab" => {
                                            e.prevent_default();
                                            // Indent block
                                            store.update_block_content(&block_id, &content);
                                            // TODO: Implement indentation
                                            editing.set(false);
                                        }
                                        _ => {}
                                    }
                                },
                                onfocusout: move |_| {
                                    store.update_block_content(&block_id, &content);
                                    editing.set(false);
                                },
                                autofocus: true
                            }
                        } else {
                            // View mode with parsed content
                            div {
                                class: format!("block-editor px-2 py-1 min-h-[1.5em] cursor-text {}",
                                    if b.content.trim().is_empty() {
                                        "text-obsidian-300 dark:text-obsidian-600 italic"
                                    } else {
                                        "text-obsidian-800 dark:text-obsidian-200"
                                    }
                                ),
                                "data-placeholder": "Type / for commands or just start writing...",
                                onclick: move |_| {
                                    editing.set(true);
                                    store.set_current_block(Some(block_id.clone()));
                                },
                                ondblclick: move |_| {
                                    editing.set(true);
                                },

                                // Render parsed content
                                { render_content(&b.content) },

                                // Add child block button (visible on hover)
                                button {
                                    class: "inline-flex items-center justify-center w-4 h-4 ml-1 opacity-0 group-hover:opacity-100 transition-opacity text-obsidian-400 hover:text-obsidian-600",
                                    onclick: move |_| {
                                        let new_block_id = store.create_block(Some(block_id.clone()));
                                        store.blocks.get_mut(&block_id).unwrap().children.push(new_block_id);
                                        editing.set(true);
                                    },
                                    svg { class: "w-3 h-3", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24",
                                        path { stroke_linecap: "round", stroke_linejoin: "round", stroke_width: "2", d: "M12 4v16m8-8H4" }
                                    }
                                }
                            }
                        }
                    },

                    // Block actions (visible on hover)
                    div { class: "block-actions opacity-0 group-hover:opacity-100 flex items-center gap-1 transition-opacity",
                        // Toggle checkbox (if task)
                        button {
                            class: "p-1 rounded hover:bg-obsidian-100 dark:hover:bg-obsidian-800",
                            onclick: move |_| {
                                // TODO: Toggle task state
                            },
                            svg { class: "w-4 h-4 text-obsidian-400", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24",
                                path { stroke_linecap: "round", stroke_linejoin: "round", stroke_width: "2", d: "M5 13l4 4L19 7" }
                            }
                        },

                        // More options
                        button {
                            class: "p-1 rounded hover:bg-obsidian-100 dark:hover:bg-obsidian-800",
                            onclick: move |_| {
                                // TODO: Open context menu
                            },
                            svg { class: "w-4 h-4 text-obsidian-400", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24",
                                path { stroke_linecap: "round", stroke_linejoin: "round", stroke_width: "2", d: "M12 5v.01M12 12v.01M12 19v.01M12 6a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2z" }
                            }
                        }
                    }
                },

                // Child blocks (indented)
                if !children.is_empty() {
                    div { class: "ml-6 pl-4 border-l border-obsidian-200 dark:border-obsidian-700",
                        for child in children {
                            BlockComponent { block_id: child.id.clone(), page_id: page_id.clone() }
                        }
                    }
                }
            }
        }
        None => rsx! {
            // Block not found (deleted)
        }
    }
}

/// Render content with wikilinks and tags highlighted
fn render_content(content: &str) -> Element {
    let parsed = parse_markdown(content);
    let wikilinks = extract_wikilinks(content);
    let tags = extract_tags(content);

    // This is a simplified version - in a real app, you'd use a proper parser
    let parts: Vec<_> = content.split("[[").collect();
    let mut elements: Vec< dioxus::prelude::VNode> = Vec::new();

    for (i, part) in parts.iter().enumerate() {
        if i > 0 {
            if let Some(close_pos) = part.find("]]") {
                let link = &part[..close_pos];
                let rest = &part[close_pos + 2..];
                let (link_text, alias) = if let Some((l, a)) = link.split_once('|') {
                    (l.trim().to_string(), Some(a.trim().to_string()))
                } else {
                    (link.trim().to_string(), None)
                };

                elements.push(rsx! {
                    a {
                        class: "wikilink",
                        href: "#",
                        onclick: move |e| {
                            e.prevent_default();
                            // TODO: Navigate to linked page
                            web_sys::console::log_1(&format!("Navigate to: {}", link_text));
                        },
                        "{}",
                        alias.unwrap_or(link_text)
                    }
                });
                if !rest.is_empty() {
                    elements.push(rsx! {
                        span { class: "text-obsidian-800 dark:text-obsidian-200", "{rest}" }
                    });
                }
            } else {
                elements.push(rsx! {
                    span { class: "text-obsidian-800 dark:text-obsidian-200", "{}", format!("[[{}", part) }
                });
            }
        } else {
            elements.push(rsx! {
                span { class: "text-obsidian-800 dark:text-obsidian-200", "{part}" }
            });
        }
    }

    // Add tags
    for tag in tags {
        let tag_name = tag.clone();
        elements.push(rsx! {
            span {
                class: "tag ml-1",
                onclick: move |_| {
                    // TODO: Filter by tag
                    web_sys::console::log_1(&format!("Filter by tag: {}", tag_name));
                },
                "{tag}"
            }
        });
    }

    // Return rendered content
    rsx! {
        span { "{parsed}" }
    }
}
