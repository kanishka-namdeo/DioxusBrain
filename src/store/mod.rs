use dioxus::prelude::*;
use uuid::Uuid;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::RwLock;
use std::rc::Rc;

/// Represents a block in the outliner structure
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Block {
    pub id: String,
    pub content: String,
    pub parent_id: Option<String>,
    pub children: Vec<String>,
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
    pub blocks: Vec<String>,
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

/// The main application state (wrapped in Rc<RwLock> for shared mutability)
#[derive(Debug, Clone, Default)]
pub struct AppState {
    pub pages: HashMap<String, Page>,
    pub blocks: HashMap<String, Block>,
    pub current_page_id: Option<String>,
    pub current_block_id: Option<String>,
    pub theme: Theme,
    pub left_sidebar_open: bool,
    pub right_sidebar_open: bool,
    pub favorites: Vec<String>,
    pub search_query: String,
    pub page_filter: PageFilter,
}

impl AppState {
    pub fn get_current_page(&self) -> Option<&Page> {
        self.current_page_id.as_ref().and_then(|id| self.pages.get(id))
    }

    pub fn get_current_block(&self) -> Option<&Block> {
        self.current_block_id.as_ref().and_then(|id| self.blocks.get(id))
    }

    pub fn get_pages_sorted(&self) -> Vec<&Page> {
        let mut pages: Vec<&Page> = self.pages.values().collect();
        pages.sort_by(|a, b| a.title.to_lowercase().cmp(&b.title.to_lowercase()));
        pages
    }

    pub fn get_recent_pages(&self, limit: usize) -> Vec<&Page> {
        let mut pages: Vec<&Page> = self.pages.values().collect();
        pages.sort_by(|a, b| b.updated_at.cmp(&a.updated_at));
        pages.into_iter().take(limit).collect()
    }

    pub fn get_favorite_pages(&self) -> Vec<&Page> {
        self.favorites
            .iter()
            .filter_map(|id| self.pages.get(id))
            .collect()
    }

    pub fn get_pages_by_tag(&self, tag: &str) -> Vec<&Page> {
        self.pages
            .values()
            .filter(|page| page.tags.contains(&tag.to_string()))
            .collect()
    }

    pub fn is_favorite(&self, page_id: &str) -> bool {
        self.favorites.contains(&page_id.to_string())
    }

    pub fn create_page(&mut self, title: &str) -> String {
        let page = Page::new(title);
        let id = page.id.clone();
        self.pages.insert(id.clone(), page);
        self.current_page_id = Some(id.clone());
        self.current_block_id = None;
        id
    }

    pub fn create_block(&mut self, parent_id: Option<String>) -> String {
        let block = Block {
            parent_id: parent_id.clone(),
            ..Default::default()
        };
        let id = block.id.clone();
        self.blocks.insert(id.clone(), block);

        if let Some(pid) = parent_id {
            if let Some(parent) = self.blocks.get_mut(&pid) {
                parent.children.push(id.clone());
            }
        }

        id
    }

    pub fn delete_block(&mut self, block_id: &str) {
        if let Some(block) = self.blocks.get(block_id) {
            for child_id in &block.children {
                self.delete_block(child_id);
            }
            if let Some(parent_id) = &block.parent_id {
                if let Some(parent) = self.blocks.get_mut(parent_id) {
                    parent.children.retain(|id| id != block_id);
                }
            }
            self.blocks.remove(block_id);
        }
    }

    pub fn get_backlinks(&self, page_id: &str) -> Vec<Backlink> {
        let page_title = self.pages.get(page_id)
            .map(|p| p.title.to_lowercase())
            .unwrap_or_else(|| page_id.to_string());

        let mut backlinks = Vec::new();

        for (source_id, page) in &self.pages {
            if source_id == page_id { continue; }

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

/// Global state wrapper for Dioxus 0.7
#[derive(Clone, Default)]
pub struct GlobalStore(pub Rc<RwLock<AppState>>);

impl GlobalStore {
    pub fn new() -> Self {
        Self(Rc::new(RwLock::new(AppState::default())))
    }

    pub fn read(&self) -> std::sync::RwLockReadGuard<AppState> {
        self.0.read().unwrap()
    }

    pub fn write(&self) -> std::sync::RwLockWriteGuard<AppState> {
        self.0.write().unwrap()
    }
}

/// Hook for using the app store with signals
#[component]
pub fn AppStoreProvider(children: Element) -> Element {
    let store = use_hook(|| GlobalStore::new());
    provide_context(store.clone());

    rsx! { children }
}

/// Hook to get the app store
#[must_use]
pub fn use_store() -> GlobalStore {
    use_context::<GlobalStore>().unwrap_or_else(|| GlobalStore::new())
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

impl AppStateExt for GlobalStore {
    fn set_current_page(&mut self, id: Option<String>) {
        self.write().current_page_id = id;
        self.write().current_block_id = None;
    }

    fn set_current_block(&mut self, id: Option<String>) {
        self.write().current_block_id = id;
    }

    fn set_theme(&mut self, theme: Theme) {
        self.write().theme = theme;
        #[cfg(feature = "web")]
        {
            if let Some(window) = web_sys::window() {
                if let Some(document) = window.document() {
                    let is_dark = matches!(theme, Theme::Dark);
                    let _ = document.document_element().unwrap().class_list().toggle("dark", is_dark);
                }
            }
        }
    }

    fn toggle_theme(&mut self) {
        let new_theme = match self.read().theme {
            Theme::Light => Theme::Dark,
            Theme::Dark => Theme::Light,
            Theme::System => Theme::Light,
        };
        self.set_theme(new_theme);
    }

    fn set_left_sidebar_open(&mut self, open: bool) {
        self.write().left_sidebar_open = open;
    }

    fn set_right_sidebar_open(&mut self, open: bool) {
        self.write().right_sidebar_open = open;
    }

    fn add_favorite(&mut self, page_id: &str) {
        let favorites = &mut self.write().favorites;
        if !favorites.contains(&page_id.to_string()) {
            favorites.push(page_id.to_string());
        }
    }

    fn remove_favorite(&mut self, page_id: &str) {
        self.write().favorites.retain(|id| id != page_id);
    }

    fn toggle_favorite(&mut self, page_id: &str) {
        if self.read().is_favorite(page_id) {
            self.remove_favorite(page_id);
        } else {
            self.add_favorite(page_id);
        }
    }

    fn set_search_query(&mut self, query: &str) {
        self.write().search_query = query.to_string();
    }

    fn update_page_title(&mut self, page_id: &str, title: &str) {
        if let Some(page) = self.write().pages.get_mut(page_id) {
            page.title = title.to_string();
            page.updated_at = chrono::Utc::now();
        }
    }

    fn update_block_content(&mut self, block_id: &str, content: &str) {
        if let Some(block) = self.write().blocks.get_mut(block_id) {
            block.content = content.to_string();
            block.updated_at = chrono::Utc::now();
        }
    }

    fn add_tag(&mut self, page_id: &str, tag: &str) {
        if let Some(page) = self.write().pages.get_mut(page_id) {
            let tag = tag.trim_start_matches('#').to_string();
            if !page.tags.contains(&tag) {
                page.tags.push(tag);
                page.updated_at = chrono::Utc::now();
            }
        }
    }

    fn remove_tag(&mut self, page_id: &str, tag: &str) {
        if let Some(page) = self.write().pages.get_mut(page_id) {
            let tag = tag.trim_start_matches('#').to_string();
            page.tags.retain(|t| t != &tag);
            page.updated_at = chrono::Utc::now();
        }
    }
}
