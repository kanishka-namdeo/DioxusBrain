use dioxus::prelude::*;
use crate::store::{use_store};
use crate::graph::{KnowledgeGraph, GraphLayout, GraphStats};

/// Graph view component showing the knowledge graph visualization
#[component]
pub fn GraphView() -> Element {
    let store = use_store();
    
    // Build graph from current state
    let graph = use_memo(move || {
        let mut kg = KnowledgeGraph::default();
        kg.build_from_state(&store.pages, &store.blocks, store.current_page_id.as_ref());
        kg
    });

    // Calculate layout
    let layout = use_memo(move || {
        let mut layout = GraphLayout::new();
        layout.calculate_layout(&graph, 800.0, 600.0)
    });

    // Graph statistics
    let stats = use_memo(move || {
        graph.get_stats()
    });

    // Selected node
    let selected_node = use_signal(|| Option::<String>::None);

    // Filter options
    let show_isolated = use_signal(|| true);
    let min_links = use_signal(|| 0);

    rsx! {
        div { class: "flex-1 flex flex-col overflow-hidden bg-obsidian-50 dark:bg-obsidian-950 transition-colors duration-200",

            // Header
            div { class: "flex items-center justify-between px-6 py-4 border-b border-obsidian-200 dark:border-obsidian-800 bg-white dark:bg-obsidian-900 transition-colors duration-200",

                // Title and stats
                div { class: "flex items-center gap-4",
                    div { class: "flex items-center gap-2",
                        svg { class: "w-5 h-5 text-logseq-blue", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24",
                            path { stroke_linecap: "round", stroke_linejoin: "round", stroke_width: "2", d: "M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1" }
                        },
                        h1 { class: "text-lg font-semibold text-obsidian-800 dark:text-obsidian-200", "Knowledge Graph" }
                    },

                    // Stats
                    div { class: "flex items-center gap-4 text-sm text-obsidian-600 dark:text-obsidian-400",
                        span { class: "flex items-center gap-1",
                            svg { class: "w-4 h-4", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24",
                                path { stroke_linecap: "round", stroke_linejoin: "round", stroke_width: "2", d: "M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" }
                            },
                            format!("{} pages", stats.total_pages)
                        },
                        span { class: "flex items-center gap-1",
                            svg { class: "w-4 h-4", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24",
                                path { stroke_linecap: "round", stroke_linejoin: "round", stroke_width: "2", d: "M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1" }
                            },
                            format!("{} links", stats.total_links)
                        },
                        if stats.isolated_pages > 0 {
                            span { class: "flex items-center gap-1 text-obsidian-400",
                                svg { class: "w-4 h-4", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24",
                                    path { stroke_linecap: "round", stroke_linejoin: "round", stroke_width: "2", d: "M18.364 18.364A9 9 0 005.636 5.636m12.728 12.728A9 9 0 015.636 5.636m12.728 12.728L5.636 5.636" }
                                },
                                format!("{} isolated", stats.isolated_pages)
                            }
                        }
                    }
                },

                // Controls
                div { class: "flex items-center gap-3",
                    // Show isolated toggle
                    label { class: "flex items-center gap-2 text-sm text-obsidian-600 dark:text-obsidian-400 cursor-pointer",
                        input {
                            type: "checkbox",
                            checked: show_isolated(),
                            onchange: move |_| show_isolated.toggle(),
                        },
                        "Show isolated"
                    },

                    // Min links filter
                    div { class: "flex items-center gap-2",
                        span { class: "text-sm text-obsidian-600 dark:text-obsidian-400", "Min links:" },
                        input {
                            type: "number",
                            class: "w-16 px-2 py-1 text-sm bg-obsidian-100 dark:bg-obsidian-800 border border-obsidian-200 dark:border-obsidian-700 rounded focus:outline-none focus:ring-2 focus:ring-logseq-blue text-obsidian-900 dark:text-obsidian-100",
                            value: "{min_links}",
                            min: "0",
                            oninput: move |e| {
                                if let Ok(val) = e.value().parse() {
                                    min_links.set(val);
                                }
                            }
                        }
                    }
                }
            },

            // Graph visualization area
            div { class: "flex-1 flex overflow-hidden",

                // Main graph canvas
                div { class: "flex-1 relative overflow-hidden",

                    // SVG Graph
                    svg {
                        class: "w-full h-full",
                        viewBox: "0 0 800 600",
                        preserveAspectRatio: "xMidYMid meet",

                        // Definitions for gradients and filters
                        defs {
                            // Gradient for links
                            linearGradient {
                                id: "link-gradient",
                                x1: "0%",
                                y1: "0%",
                                x2: "100%",
                                y2: "0%",
                                stop { offset: "0%", stop_color: "#9fa3b0", stop_opacity: "0.4" }
                                stop { offset: "100%", stop_color: "#5c5f72", stop_opacity: "0.4" }
                            },

                            // Glow filter
                            filter {
                                id: "glow",
                                x: "-50%",
                                y: "-50%",
                                width: "200%",
                                height: "200%",
                                feGaussianBlur { std_deviation: "2", result: "coloredBlur" }
                                feMerge {
                                    feMergeNode { in: "coloredBlur" }
                                    feMergeNode { in: "SourceGraphic" }
                                }
                            }
                        },

                        // Edges
                        for edge in &graph.edges {
                            if let (Some(source_pos), Some(target_pos)) = (
                                layout.get(&edge.source),
                                layout.get(&edge.target)
                            ) {
                                line {
                                    x1: "{source_pos.0}",
                                    y1: "{source_pos.1}",
                                    x2: "{target_pos.0}",
                                    y2: "{target_pos.1}",
                                    stroke: "#9fa3b0",
                                    stroke_width: "1",
                                    stroke_opacity: "0.4",
                                    class: "graph-link"
                                }
                            }
                        },

                        // Nodes
                        for (node_id, node) in &graph.nodes {
                            // Skip isolated nodes if filter is off
                            if !show_isolated() && node.link_count == 0 && graph.nodes.len() > 1 {
                                continue;
                            }

                            // Skip nodes with too few links
                            if node.link_count < min_links() {
                                continue;
                            }

                            if let Some(pos) = layout.get(node_id) {
                                let is_selected = selected_node.as_ref().map(|s| s == node_id).unwrap_or(false);
                                let is_active = store.current_page_id.as_ref() == Some(node_id);

                                g {
                                    class: "graph-node",
                                    onclick: move |_| {
                                        selected_node.set(Some(node_id.clone()));
                                        store.set_current_page(Some(node_id.clone()));
                                    },

                                    // Node circle
                                    circle {
                                        cx: "{pos.0}",
                                        cy: "{pos.1}",
                                        r: if is_active { 20.0 } else if node.link_count > 5 { 16.0 } else if node.link_count > 0 { 12.0 } else { 8.0 },
                                        fill: if is_active {
                                            "#2962ff"
                                        } else if is_selected {
                                            "#6200ea"
                                        } else if node.link_count > 5 {
                                            "#00c853"
                                        } else if node.link_count > 0 {
                                            "#2962ff"
                                        } else {
                                            "#9fa3b0"
                                        },
                                        stroke: if is_active {
                                            "#fff"
                                        } else {
                                            "transparent"
                                        },
                                        stroke_width: "3",
                                        filter: if is_active || is_selected { "url(#glow)" } else { "" },
                                        class: "transition-all duration-200"
                                    },

                                    // Node icon (if available)
                                    if let Some(icon) = &node.icon {
                                        text {
                                            x: "{pos.0}",
                                            y: "{pos.1 + 5}",
                                            text_anchor: "middle",
                                            font_size: "14",
                                            class: "pointer-events-none select-none",
                                            "{icon}"
                                        }
                                    },

                                    // Node label
                                    text {
                                        x: "{pos.0}",
                                        y: if node.icon.is_some() { pos.1 + 28.0 } else { pos.1 + 20.0 },
                                        text_anchor: "middle",
                                        font_size: "11",
                                        fill: "#5c5f72",
                                        class: "pointer-events-none select-none dark:fill-9fa3b0",
                                        "{crate::utils::truncate_text(&node.title, 15)}"
                                    }
                                }
                            }
                        }
                    }
                },

                // Side panel with selected node info
                if let Some(node_id) = selected_node.as_ref() {
                    div { class: "w-64 bg-white dark:bg-obsidian-900 border-l border-obsidian-200 dark:border-obsidian-800 p-4 overflow-y-auto",
                        if let Some(node) = graph.nodes.get(node_id) {
                            div { class: "space-y-4",

                                // Node title
                                div { class: "flex items-center gap-2",
                                    if let Some(icon) = &node.icon {
                                        span { class: "text-2xl", "{icon}" }
                                    }
                                    h2 { class: "text-lg font-semibold text-obsidian-900 dark:text-obsidian-100", "{node.title}" }
                                },

                                // Stats
                                div { class: "flex items-center gap-4 text-sm text-obsidian-600 dark:text-obsidian-400",
                                    span { class: "flex items-center gap-1",
                                        svg { class: "w-4 h-4", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24",
                                            path { stroke_linecap: "round", stroke_linejoin: "round", stroke_width: "2", d: "M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1" }
                                        },
                                        format!("{} connections", node.link_count)
                                    }
                                },

                                // Tags
                                if !node.tags.is_empty() {
                                    div { class: "flex flex-wrap gap-1",
                                        for tag in &node.tags {
                                            span { class: "tag", "#{}", tag }
                                        }
                                    }
                                },

                                // Actions
                                div { class: "flex gap-2 mt-4",
                                    button {
                                        class: "flex-1 px-3 py-2 bg-logseq-blue text-white text-sm rounded-lg hover:bg-blue-600 transition-colors",
                                        onclick: move |_| {
                                            store.set_current_page(Some(node_id.clone()));
                                        },
                                        "Open Page"
                                    },
                                    button {
                                        class: "px-3 py-2 bg-obsidian-100 dark:bg-obsidian-800 text-obsidian-700 dark:text-obsidian-300 text-sm rounded-lg hover:bg-obsidian-200 dark:hover:bg-obsidian-700 transition-colors",
                                        onclick: move |_| {
                                            // TODO: Add to favorites
                                        },
                                        "Favorite"
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
