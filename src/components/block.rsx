use dioxus::prelude::*;
use crate::store::{use_store, Block};
use crate::utils::{parse_markdown};

/// Props for BlockComponent
#[derive(Props, Clone, PartialEq)]
pub struct BlockComponentProps {
    block_id: String,
    page_id: String,
}

/// Individual block component for the outliner
#[component]
pub fn BlockComponent(props: BlockComponentProps) -> Element {
    let store = use_store();
    let editing = use_signal(|| false);
    let content = use_signal(|| String::new());

    let block = store.read().blocks.get(&props.block_id).cloned();
    let store_clone = store.clone();

    // Initialize content signal when block is available
    use_effect(move || {
        if let Some(b) = store.read().blocks.get(&props.block_id) {
            if content.read().is_empty() {
                content.set(b.content.clone());
            }
        }
    });

    match block {
        Some(b) => {
            let is_active = store.read().current_block_id.as_ref() == Some(&props.block_id);
            let is_child = b.parent_id.is_some();
            let block_id_clone = props.block_id.clone();
            let page_id_clone = props.page_id.clone();

            // Get child blocks
            let children: Vec<_> = b.children
                .iter()
                .filter_map(|child_id| store.read().blocks.get(child_id).cloned())
                .collect();

            let content_clone = content.clone();

            rsx! {
                div {
                    class: format!("block-wrapper group flex items-start gap-1 {}", if is_active { "active-block" } else { "" }),

                    // Block handle (bullet point)
                    div {
                        class: "block-handle flex-shrink-0 w-6 h-6 flex items-center justify-center cursor-grab active:cursor-grabbing mt-0.5",
                        onmousedown: move |_| {},
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
                            let content_value = content.read().clone();
                            textarea {
                                class: "w-full min-h-[1.5em] px-2 py-1 bg-white dark:bg-obsidian-800 border border-logseq-blue rounded resize-none focus:outline-none text-obsidian-900 dark:text-obsidian-100",
                                value: "{content_value}",
                                oninput: move |e| {
                                    content.set(e.value().clone());
                                },
                                onkeydown: move |e| {
                                    match e.key().as_str() {
                                        "Enter" if !e.shift_key() => {
                                            e.prevent_default();
                                            store_clone.write().update_block_content(&block_id_clone, &content.read());
                                            let parent_id = store_clone.read().blocks.get(&block_id_clone).and_then(|b| b.parent_id.clone());
                                            let new_block_id = store_clone.write().create_block(parent_id);
                                            store_clone.write().pages.get_mut(&page_id_clone).map(|page| {
                                                if !page.blocks.contains(&new_block_id) {
                                                    page.blocks.push(new_block_id);
                                                }
                                            });
                                            editing.set(false);
                                        }
                                        "Escape" => {
                                            if let Some(b) = store_clone.read().blocks.get(&block_id_clone) {
                                                content.set(b.content.clone());
                                            }
                                            editing.set(false);
                                        }
                                        "Tab" => {
                                            e.prevent_default();
                                            store_clone.write().update_block_content(&block_id_clone, &content.read());
                                            editing.set(false);
                                        }
                                        _ => {}
                                    }
                                },
                                onfocusout: move |_| {
                                    store_clone.write().update_block_content(&block_id_clone, &content.read());
                                    editing.set(false);
                                },
                                autofocus: true
                            }
                        } else {
                            // View mode with parsed content
                            let content_text = b.content.clone();
                            let parsed = parse_markdown(&content_text);
                            
                            div {
                                class: format!("block-editor px-2 py-1 min-h-[1.5em] cursor-text {}",
                                    if content_text.trim().is_empty() {
                                        "text-obsidian-300 dark:text-obsidian-600 italic"
                                    } else {
                                        "text-obsidian-800 dark:text-obsidian-200"
                                    }
                                ),
                                "data-placeholder": "Type / for commands or just start writing...",
                                onclick: move |_| {
                                    editing.set(true);
                                    store_clone.write().set_current_block(Some(block_id_clone.clone()));
                                },
                                ondblclick: move |_| {
                                    editing.set(true);
                                },

                                // Render parsed content
                                span { class: "text-obsidian-800 dark:text-obsidian-200", "{parsed}" },

                                // Add child block button (visible on hover)
                                button {
                                    class: "inline-flex items-center justify-center w-4 h-4 ml-1 opacity-0 group-hover:opacity-100 transition-opacity text-obsidian-400 hover:text-obsidian-600",
                                    onclick: move |_| {
                                        let new_block_id = store_clone.write().create_block(Some(block_id_clone.clone()));
                                        store_clone.write().blocks.get_mut(&block_id_clone).map(|block| {
                                            if !block.children.contains(&new_block_id) {
                                                block.children.push(new_block_id);
                                            }
                                        });
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
                            onclick: move |_| {},
                            svg { class: "w-4 h-4 text-obsidian-400", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24",
                                path { stroke_linecap: "round", stroke_linejoin: "round", stroke_width: "2", d: "M5 13l4 4L19 7" }
                            }
                        },

                        // More options
                        button {
                            class: "p-1 rounded hover:bg-obsidian-100 dark:hover:bg-obsidian-800",
                            onclick: move |_| {},
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
                            BlockComponent { block_id: child.id.clone(), page_id: props.page_id.clone() }
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
