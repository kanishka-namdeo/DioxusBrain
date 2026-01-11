use dioxus::prelude::*;
use uuid::Uuid;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Represents a block in the outliner structure
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Block {
    pub id: String,
    pub content: String,
    pub parent_id: Option<String>,
    pub children: Vec<String>, // Child block IDs
    pub properties: HashMap<String, String>,
    pub created_at: chrono::DateTime<chrono::Utc>,
    pub updated_at: chrono::DateTime<chrono::Utc>,
}

impl Default for Block {
    fn default() -> Self {
        Self {
            id: Uuid::new_v4().to_string(),
            content: String::new(),
            parent_id: None,
            children: Vec::new(),
            properties: HashMap::new(),
            created_at: chrono::Utc::now(),
            updated_at: chrono::Utc::now(),
        }
    }
}

/// Represents a page/note
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Page {
    pub id: String,
    pub title: String,
    pub icon: Option<String>,
    pub blocks: Vec<String>, // Top-level block IDs
    pub properties: HashMap<String, String>,
    pub tags: Vec<String>,
    pub created_at: chrono::DateTime<chrono::Utc>,
    pub updated_at: chrono::DateTime<chrono::Utc>,
}

impl Default for Page {
    fn default() -> Self {
        let now = chrono::Utc::now();
        Self {
            id: Uuid::new_v4().to_string(),
            title: String::new(),
            icon: None,
            blocks: Vec::new(),
            properties: HashMap::new(),
            tags: Vec::new(),
            created_at: now,
            updated_at: now,
        }
    }
}

impl Page {
    pub fn new(title: &str) -> Self {
        let now = chrono::Utc::now();
        Self {
            id: Uuid::new_v4().to_string(),
            title: title.to_string(),
            icon: None,
            blocks: Vec::new(),
            properties: HashMap::new(),
            tags: Vec::new(),
            created_at: now,
            updated_at: now,
        }
    }
}

/// Theme preference
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum Theme {
    Light,
    Dark,
    System,
}

impl Default for Theme {
    fn default() -> Self {
        Theme::System
    }
}

/// Filter type for page list
#[derive(Debug, Clone, PartialEq)]
pub enum PageFilter {
    All,
    Favorites,
    Recent,
    Tags(String),
}

/// The main application state
#[derive(Debug, Clone, PartialEq)]
pub struct AppState {
    /// All pages in the graph
    pub pages: HashMap<String, Page>,
    /// All blocks in the system
    pub blocks: HashMap<String, Block>,
    /// Current active page ID
    pub current_page_id: Option<String>,
    /// Current active block ID (for editing)
    pub current_block_id: Option<String>,
    /// Theme preference
    pub theme: Theme,
    /// Left sidebar visibility
    pub left_sidebar_open: bool,
    /// Right sidebar visibility
    pub right_sidebar_open: bool,
    /// Favorite page IDs
    pub favorites: Vec<String>,
    /// Search query
    pub search_query: String,
    /// Page filter
    pub page_filter: PageFilter,
}

impl Default for AppState {
    fn default() -> Self {
        Self {
            pages: HashMap::new(),
            blocks: HashMap::new(),
            current_page_id: None,
            current_block_id: None,
            theme: Theme::Light,
            left_sidebar_open: true,
            right_sidebar_open: true,
            favorites: Vec::new(),
            search_query: String::new(),
            page_filter: PageFilter::All,
        }
    }
}

impl AppState {
    /// Get the currently active page
    pub fn get_current_page(&self) -> Option<&Page> {
        self.current_page_id.as_ref().and_then(|id| self.pages.get(id))
    }

    /// Get the currently active block
    pub fn get_current_block(&self) -> Option<&Block> {
        self.current_block_id.as_ref().and_then(|id| self.blocks.get(id))
    }

    /// Get pages sorted by title
    pub fn get_pages_sorted(&self) -> Vec<&Page> {
        let mut pages: Vec<&Page> = self.pages.values().collect();
        pages.sort_by(|a, b| a.title.to_lowercase().cmp(&b.title.to_lowercase()));
        pages
    }

    /// Get recent pages (sorted by updated_at)
    pub fn get_recent_pages(&self, limit: usize) -> Vec<&Page> {
        let mut pages: Vec<&Page> = self.pages.values().collect();
        pages.sort_by(|a, b| b.updated_at.cmp(&a.updated_at));
        pages.into_iter().take(limit).collect()
    }

    /// Get favorite pages
    pub fn get_favorite_pages(&self) -> Vec<&Page> {
        self.favorites
            .iter()
            .filter_map(|id| self.pages.get(id))
            .collect()
    }

    /// Get pages by tag
    pub fn get_pages_by_tag(&self, tag: &str) -> Vec<&Page> {
        self.pages
            .values()
            .filter(|page| page.tags.contains(&tag.to_string()))
            .collect()
    }

    /// Check if a page is favorited
    pub fn is_favorite(&self, page_id: &str) -> bool {
        self.favorites.contains(&page_id.to_string())
    }

    /// Create a new page
    pub fn create_page(&mut self, title: &str) -> String {
        let page = Page::new(title);
        let id = page.id.clone();
        self.pages.insert(id.clone(), page);
        self.current_page_id = Some(id.clone());
        self.current_block_id = None;
        id
    }

    /// Create a new block as a child of the given parent
    pub fn create_block(&mut self, parent_id: Option<String>) -> String {
        let block = Block {
            parent_id: parent_id.clone(),
            ..Default::default()
        };
        let id = block.id.clone();
        self.blocks.insert(id.clone(), block);

        // If parent exists, add this block to parent's children
        if let Some(pid) = parent_id {
            if let Some(parent) = self.blocks.get_mut(&pid) {
                parent.children.push(id.clone());
            }
        }

        id
    }

    /// Delete a block and all its descendants
    pub fn delete_block(&mut self, block_id: &str) {
        if let Some(block) = self.blocks.get(block_id) {
            // Recursively delete children first
            for child_id in &block.children {
                self.delete_block(child_id);
            }
            // Remove from parent's children list
            if let Some(parent_id) = &block.parent_id {
                if let Some(parent) = self.blocks.get_mut(parent_id) {
                    parent.children.retain(|id| id != block_id);
                }
            }
            // Remove the block
            self.blocks.remove(block_id);
        }
    }

    /// Get backlink references for a page
    pub fn get_backlinks(&self, page_id: &str) -> Vec<Backlink> {
        let page_title = self.pages.get(page_id)
            .map(|p| p.title.to_lowercase())
            .unwrap_or_else(|| page_id.to_string());

        let mut backlinks = Vec::new();

        for (source_id, page) in &self.pages {
            if source_id == page_id { continue; }

            // Search for wikilinks in page blocks
            for block_id in &page.blocks {
                if let Some(block) = self.blocks.get(block_id) {
                    if block.content.to_lowercase().contains(&format!("[[{}]]", page_title)) ||
                       block.content.to_lowercase().contains(&format!("[[{}|", page_title)) {
                        backlinks.push(Backlink {
                            page_id: source_id.clone(),
                            page_title: page.title.clone(),
                            block_id: block.id.clone(),
                            context: block.content.clone(),
                        });
                    }
                }
            }
        }

        backlinks
    }
}

/// Represents a backlink reference
#[derive(Debug, Clone)]
pub struct Backlink {
    pub page_id: String,
    pub page_title: String,
    pub block_id: String,
    pub context: String,
}

/// Hook for using the app store
#[must_use]
pub fn use_store() -> UseGlobalStore<AppState> {
    use_global_provider(|| Signal::new(AppState::default()))
}

/// Extension trait for convenient state mutations
pub trait AppStateExt {
    fn set_current_page(&mut self, id: Option<String>);
    fn set_current_block(&mut self, id: Option<String>);
    fn set_theme(&mut self, theme: Theme);
    fn toggle_theme(&mut self);
    fn set_left_sidebar_open(&mut self, open: bool);
    fn set_right_sidebar_open(&mut self, open: bool);
    fn add_favorite(&mut self, page_id: &str);
    fn remove_favorite(&mut self, page_id: &str);
    fn toggle_favorite(&mut self, page_id: &str);
    fn set_search_query(&mut self, query: &str);
    fn update_page_title(&mut self, page_id: &str, title: &str);
    fn update_block_content(&mut self, block_id: &str, content: &str);
    fn add_tag(&mut self, page_id: &str, tag: &str);
    fn remove_tag(&mut self, page_id: &str, tag: &str);
}

impl AppStateExt for AppState {
    fn set_current_page(&mut self, id: Option<String>) {
        self.current_page_id = id;
        self.current_block_id = None;
    }

    fn set_current_block(&mut self, id: Option<String>) {
        self.current_block_id = id;
    }

    fn set_theme(&mut self, theme: Theme) {
        self.theme = theme;
        // Persist to localStorage
        #[cfg(feature = "web")]
        {
            if let Some(window) = web_sys::window() {
                if let Some(document) = window.document() {
                    let theme_str = match theme {
                        Theme::Light => "light",
                        Theme::Dark => "dark",
                        Theme::System => "system",
                    };
                    let _ = document.document_element().unwrap().class_list().toggle("dark", theme == Theme::Dark);
                }
            }
        }
    }

    fn toggle_theme(&mut self) {
        self.set_theme(match self.theme {
            Theme::Light => Theme::Dark,
            Theme::Dark => Theme::Light,
            Theme::System => Theme::Light,
        });
    }

    fn set_left_sidebar_open(&mut self, open: bool) {
        self.left_sidebar_open = open;
    }

    fn set_right_sidebar_open(&mut self, open: bool) {
        self.right_sidebar_open = open;
    }

    fn add_favorite(&mut self, page_id: &str) {
        if !self.favorites.contains(&page_id.to_string()) {
            self.favorites.push(page_id.to_string());
        }
    }

    fn remove_favorite(&mut self, page_id: &str) {
        self.favorites.retain(|id| id != page_id);
    }

    fn toggle_favorite(&mut self, page_id: &str) {
        if self.is_favorite(page_id) {
            self.remove_favorite(page_id);
        } else {
            self.add_favorite(page_id);
        }
    }

    fn set_search_query(&mut self, query: &str) {
        self.search_query = query.to_string();
    }

    fn update_page_title(&mut self, page_id: &str, title: &str) {
        if let Some(page) = self.pages.get_mut(page_id) {
            page.title = title.to_string();
            page.updated_at = chrono::Utc::now();
        }
    }

    fn update_block_content(&mut self, block_id: &str, content: &str) {
        if let Some(block) = self.blocks.get_mut(block_id) {
            block.content = content.to_string();
            block.updated_at = chrono::Utc::now();
        }
    }

    fn add_tag(&mut self, page_id: &str, tag: &str) {
        if let Some(page) = self.pages.get_mut(page_id) {
            let tag = tag.trim_start_matches('#').to_string();
            if !page.tags.contains(&tag) {
                page.tags.push(tag);
                page.updated_at = chrono::Utc::now();
            }
        }
    }

    fn remove_tag(&mut self, page_id: &str, tag: &str) {
        if let Some(page) = self.pages.get_mut(page_id) {
            let tag = tag.trim_start_matches('#').to_string();
            page.tags.retain(|t| t != &tag);
            page.updated_at = chrono::Utc::now();
        }
    }
}
