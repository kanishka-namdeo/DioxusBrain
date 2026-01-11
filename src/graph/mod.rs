use std::collections::{HashMap, HashSet, VecDeque};
use serde::{Deserialize, Serialize};
use crate::store::{Page, Block};

/// Represents a node in the knowledge graph
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GraphNode {
    pub id: String,
    pub title: String,
    pub icon: Option<String>,
    pub tags: Vec<String>,
    pub link_count: usize,
    pub is_active: bool,
}

impl GraphNode {
    pub fn from_page(page: &Page, is_active: bool) -> Self {
        Self {
            id: page.id.clone(),
            title: page.title.clone(),
            icon: page.icon.clone(),
            tags: page.tags.clone(),
            link_count: 0,
            is_active,
        }
    }
}

/// Represents an edge between nodes
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GraphEdge {
    pub source: String,
    pub target: String,
    pub weight: u32,
}

impl GraphEdge {
    pub fn new(source: &str, target: &str) -> Self {
        Self {
            source: source.to_string(),
            target: target.to_string(),
            weight: 1,
        }
    }
}

/// The knowledge graph structure
#[derive(Debug, Clone)]
pub struct KnowledgeGraph {
    pub nodes: HashMap<String, GraphNode>,
    pub edges: Vec<GraphEdge>,
    pub adjacency: HashMap<String, HashSet<String>>,
}

impl Default for KnowledgeGraph {
    fn default() -> Self {
        Self {
            nodes: HashMap::new(),
            edges: Vec::new(),
            adjacency: HashMap::new(),
        }
    }
}

impl KnowledgeGraph {
    /// Build the graph from app state
    pub fn build_from_state(&mut self, pages: &HashMap<String, Page>, blocks: &HashMap<String, Block>, active_page_id: Option<&str>) {
        self.nodes.clear();
        self.edges.clear();
        self.adjacency.clear();

        // Track link counts
        let mut link_counts: HashMap<String, usize> = HashMap::new();

        // First pass: collect all wikilinks and build nodes
        for (page_id, page) in pages {
            // Create node
            let node = GraphNode::from_page(page, Some(page_id) == active_page_id);
            self.nodes.insert(page_id.clone(), node);

            // Parse wikilinks in blocks
            for block_id in &page.blocks {
                if let Some(block) = blocks.get(block_id) {
                    let links = Self::extract_wikilinks(&block.content);
                    for link in links {
                        // Update link count for target
                        *link_counts.entry(link.clone()).or_insert(0) += 1;

                        // Add edge
                        if link != page_id {
                            self.edges.push(GraphEdge::new(page_id, &link));
                            self.adjacency.entry(page_id.clone())
                                .or_insert_with(HashSet::new)
                                .insert(link.clone());
                            self.adjacency.entry(link.clone())
                                .or_insert_with(HashSet::new)
                                .insert(page_id.clone());
                        }
                    }
                }
            }
        }

        // Second pass: update link counts on nodes
        for (node_id, link_count) in link_counts {
            if let Some(node) = self.nodes.get_mut(&node_id) {
                node.link_count = *link_count;
            }
        }
    }

    /// Extract wikilinks from content
    pub fn extract_wikilinks(content: &str) -> Vec<String> {
        let mut links = Vec::new();
        
        // Match [[link]] or [[link|text]]
        let re = regex::Regex::new(r"\[\[([^\]]+)\]\]").unwrap();
        for cap in re.captures_iter(content) {
            if let Some(link_part) = cap.get(1) {
                let link = link_part.as_str();
                // Handle alias: [[link|text]] -> link
                let clean_link = link.split('|').next().unwrap_or(link).trim();
                links.push(clean_link.to_string());
            }
        }

        links
    }

    /// Get all tags from pages and blocks
    pub fn extract_tags(pages: &HashMap<String, Page>, blocks: &HashMap<String, Block>) -> Vec<String> {
        let mut tags: HashSet<String> = HashSet::new();

        // From page properties
        for page in pages.values() {
            for tag in &page.tags {
                tags.insert(format!("#{}", tag));
            }
        }

        // From blocks
        let tag_re = regex::Regex::new(r"#([a-zA-Z0-9_-]+)").unwrap();
        for block in blocks.values() {
            for cap in tag_re.captures_iter(&block.content) {
                if let Some(tag) = cap.get(1) {
                    tags.insert(format!("#{}", tag.as_str()));
                }
            }
        }

        let mut tags_vec: Vec<String> = tags.into_iter().collect();
        tags_vec.sort();
        tags_vec
    }

    /// Get related pages for a given page
    pub fn get_related_pages(&self, page_id: &str) -> Vec<(String, usize)> {
        let mut related: Vec<(String, usize)> = Vec::new();

        if let Some(connected) = self.adjacency.get(page_id) {
            for neighbor_id in connected {
                let weight = self.calculate_relevance(page_id, neighbor_id);
                related.push((neighbor_id.clone(), weight));
            }
        }

        related.sort_by(|a, b| b.1.cmp(&a.1));
        related
    }

    /// Calculate relevance score between two pages
    fn calculate_relevance(&self, page1: &str, page2: &str) -> usize {
        let mut score = 0;

        // Direct connection
        if self.adjacency.get(page1).map(|s| s.contains(page2)).unwrap_or(false) {
            score += 1;
        }

        // Shared neighbors
        if let (Some(n1), Some(n2)) = (self.adjacency.get(page1), self.adjacency.get(page2)) {
            let shared: HashSet<_> = n1.intersection(n2).collect();
            score += shared.len();
        }

        // Tag similarity
        if let (Some(node1), Some(node2)) = (self.nodes.get(page1), self.nodes.get(page2)) {
            let tags1: HashSet<_> = node1.tags.iter().collect();
            let tags2: HashSet<_> = node2.tags.iter().collect();
            score += tags1.intersection(&tags2).count() * 2;
        }

        score
    }

    /// Get graph statistics
    pub fn get_stats(&self) -> GraphStats {
        let total_links = self.edges.len();
        let connected_nodes = self.nodes.values().filter(|n| n.link_count > 0).count();
        
        // Find isolated nodes
        let isolated_nodes = self.nodes.values()
            .filter(|n| n.link_count == 0 && self.nodes.len() > 1)
            .count();

        GraphStats {
            total_pages: self.nodes.len(),
            total_links,
            connected_pages: connected_nodes,
            isolated_pages: isolated_nodes,
        }
    }

    /// Get nodes with most connections
    pub fn get_hub_pages(&self, limit: usize) -> Vec<(&GraphNode, usize)> {
        let mut hubs: Vec<(&GraphNode, usize)> = self.nodes
            .values()
            .map(|n| (n, n.link_count))
            .filter(|(_, count)| *count > 0)
            .collect();

        hubs.sort_by(|a, b| b.1.cmp(&a.1));
        hubs.into_iter().take(limit).collect()
    }

    /// Perform BFS to find shortest path between two pages
    pub fn find_path(&self, start: &str, end: &str) -> Option<Vec<String>> {
        if !self.nodes.contains_key(start) || !self.nodes.contains_key(end) {
            return None;
        }

        let mut visited: HashSet<String> = HashSet::new();
        let mut queue: VecDeque<(String, Vec<String>)> = VecDeque::new();
        
        queue.push_back((start.to_string(), vec![start.to_string()]));
        visited.insert(start.to_string());

        while let Some((current, path)) = queue.pop_front() {
            if current == end {
                return Some(path);
            }

            if let Some(neighbors) = self.adjacency.get(&current) {
                for neighbor in neighbors {
                    if !visited.contains(neighbor) {
                        visited.insert(neighbor.clone());
                        let mut new_path = path.clone();
                        new_path.push(neighbor.clone());
                        queue.push_back((neighbor.clone(), new_path));
                    }
                }
            }
        }

        None
    }
}

/// Graph statistics
#[derive(Debug, Clone)]
pub struct GraphStats {
    pub total_pages: usize,
    pub total_links: usize,
    pub connected_pages: usize,
    pub isolated_pages: usize,
}

/// Node positions for visualization
#[derive(Debug, Clone)]
pub struct NodePosition {
    pub x: f64,
    pub y: f64,
    pub vx: f64,
    pub vy: f64,
}

/// Force-directed graph layout calculator
pub struct GraphLayout {
    pub nodes: HashMap<String, NodePosition>,
    forces: GraphForces,
}

impl GraphLayout {
    pub fn new() -> Self {
        Self {
            nodes: HashMap::new(),
            forces: GraphForces::default(),
        }
    }

    /// Calculate layout for the graph
    pub fn calculate_layout(&mut self, graph: &KnowledgeGraph, width: f64, height: f64) -> HashMap<String, (f64, f64)> {
        let center_x = width / 2.0;
        let center_y = height / 2.0;

        // Initialize positions in a circle
        let nodes: Vec<_> = graph.nodes.keys().collect();
        let radius = width.min(height) / 4.0;
        
        self.nodes.clear();
        for (i, node_id) in nodes.iter().enumerate() {
            let angle = 2.0 * std::f64::consts::PI * i as f64 / nodes.len() as f64;
            self.nodes.insert(
                node_id.clone(),
                NodePosition {
                    x: center_x + radius * angle.cos(),
                    y: center_y + radius * angle.sin(),
                    vx: 0.0,
                    vy: 0.0,
                }
            );
        }

        // Run force simulation
        for _ in 0..100 {
            self.apply_forces(graph, width, height);
        }

        // Return final positions
        self.nodes.iter()
            .map(|(id, pos)| (id.clone(), (pos.x, pos.y)))
            .collect()
    }

    fn apply_forces(&mut self, graph: &KnowledgeGraph, width: f64, height: f64) {
        let repulsion = 5000.0;
        let attraction = 0.01;
        let damping = 0.85;

        // Reset velocities
        for pos in self.nodes.values_mut() {
            pos.vx *= damping;
            pos.vy *= damping;
        }

        // Repulsion between all nodes
        let nodes: Vec<_> = self.nodes.keys().collect();
        for (i, a) in nodes.iter().enumerate() {
            for b in nodes.iter().skip(i + 1) {
                let pos_a = self.nodes.get(a).unwrap();
                let pos_b = self.nodes.get(b).unwrap();

                let dx = pos_b.x - pos_a.x;
                let dy = pos_b.y - pos_a.y;
                let dist_sq = dx * dx + dy * dy;
                let dist = dist_sq.sqrt().max(1.0);

                let force = repulsion / dist_sq;
                let fx = (dx / dist) * force;
                let fy = (dy / dist) * force;

                if let Some(pos) = self.nodes.get_mut(a) {
                    pos.vx -= fx;
                    pos.vy -= fy;
                }
                if let Some(pos) = self.nodes.get_mut(b) {
                    pos.vx += fx;
                    pos.vy += fy;
                }
            }
        }

        // Attraction along edges
        for edge in &graph.edges {
            if let (Some(pos_a), Some(pos_b)) = (
                self.nodes.get(&edge.source),
                self.nodes.get(&edge.target)
            ) {
                let dx = pos_b.x - pos_a.x;
                let dy = pos_b.y - pos_a.y;
                let dist = (dx * dx + dy * dy).sqrt().max(1.0);

                let force = dist * attraction;
                let fx = (dx / dist) * force;
                let fy = (dy / dist) * force;

                if let Some(pos) = self.nodes.get_mut(&edge.source) {
                    pos.vx += fx;
                    pos.vy += fy;
                }
                if let Some(pos) = self.nodes.get_mut(&edge.target) {
                    pos.vx -= fx;
                    pos.vy -= fy;
                }
            }
        }

        // Apply velocities and keep nodes in bounds
        for pos in self.nodes.values_mut() {
            pos.x += pos.vx;
            pos.y += pos.vy;

            // Keep in bounds
            pos.x = pos.x.clamp(50.0, width - 50.0);
            pos.y = pos.y.clamp(50.0, height - 50.0);
        }
    }
}

/// Graph forces configuration
#[derive(Debug, Clone)]
struct GraphForces {
    pub repulsion: f64,
    pub attraction: f64,
    pub center: f64,
    pub damping: f64,
}

impl Default for GraphForces {
    fn default() -> Self {
        Self {
            repulsion: 5000.0,
            attraction: 0.01,
            center: 0.001,
            damping: 0.85,
        }
    }
}
