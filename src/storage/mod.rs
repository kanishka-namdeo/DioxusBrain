use dioxus::prelude::*;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::rc::Rc;
use std::cell::RefCell;
use crate::store::{Page, Block, Theme};

/// Storage key prefixes
const PREFIX_PAGES: &str = "dioxus_brain_pages_";
const PREFIX_BLOCKS: &str = "dioxus_brain_blocks_";
const PREFIX_STATE: &str = "dioxus_brain_state_";
const PREFIX_FAVORITES: &str = "dioxus_brain_favorites_";

/// JSON-serializable page representation for storage
#[derive(Debug, Clone, Serialize, Deserialize)]
struct StoredPage {
    id: String,
    title: String,
    icon: Option<String>,
    blocks: Vec<String>,
    properties: HashMap<String, String>,
    tags: Vec<String>,
    created_at: String,
    updated_at: String,
}

impl From<Page> for StoredPage {
    fn from(page: Page) -> Self {
        Self {
            id: page.id,
            title: page.title,
            icon: page.icon,
            blocks: page.blocks,
            properties: page.properties,
            tags: page.tags,
            created_at: page.created_at.to_rfc3339(),
            updated_at: page.updated_at.to_rfc3339(),
        }
    }
}

impl Into<Page> for StoredPage {
    fn into(self) -> Page {
        Page {
            id: self.id,
            title: self.title,
            icon: self.icon,
            blocks: self.blocks,
            properties: self.properties,
            tags: self.tags,
            created_at: self.created_at.parse().unwrap_or_default(),
            updated_at: self.updated_at.parse().unwrap_or_default(),
        }
    }
}

/// JSON-serializable block representation for storage
#[derive(Debug, Clone, Serialize, Deserialize)]
struct StoredBlock {
    id: String,
    content: String,
    parent_id: Option<String>,
    children: Vec<String>,
    properties: HashMap<String, String>,
    created_at: String,
    updated_at: String,
}

impl From<Block> for StoredBlock {
    fn from(block: Block) -> Self {
        Self {
            id: block.id,
            content: block.content,
            parent_id: block.parent_id,
            children: block.children,
            properties: block.properties,
            created_at: block.created_at.to_rfc3339(),
            updated_at: block.updated_at.to_rfc3339(),
        }
    }
}

impl Into<Block> for StoredBlock {
    fn into(self) -> Block {
        Block {
            id: self.id,
            content: self.content,
            parent_id: self.parent_id,
            children: self.children,
            properties: self.properties,
            created_at: self.created_at.parse().unwrap_or_default(),
            updated_at: self.updated_at.parse().unwrap_or_default(),
        }
    }
}

/// Storage manager using Rc<RefCell> for shared mutable state
#[derive(Debug, Clone)]
pub struct StorageManager {
    pages: Rc<RefCell<HashMap<String, Page>>>,
    blocks: Rc<RefCell<HashMap<String, Block>>>,
    favorites: Rc<RefCell<Vec<String>>>,
    theme: Rc<RefCell<Theme>>,
    loaded: Rc<RefCell<bool>>,
}

impl StorageManager {
    /// Create a new storage manager
    pub fn new() -> Self {
        Self {
            pages: Rc::new(RefCell::new(HashMap::new())),
            blocks: Rc::new(RefCell::new(HashMap::new())),
            favorites: Rc::new(RefCell::new(Vec::new())),
            theme: Rc::new(RefCell::new(Theme::Light)),
            loaded: Rc::new(RefCell::new(false)),
        }
    }

    /// Get pages reference
    pub fn pages(&self) -> std::cell::Ref<'_, HashMap<String, Page>> {
        self.pages.borrow()
    }

    /// Get pages mutable reference
    pub fn pages_mut(&self) -> std::cell::RefMut<'_, HashMap<String, Page>> {
        self.pages.borrow_mut()
    }

    /// Get blocks reference
    pub fn blocks(&self) -> std::cell::Ref<'_, HashMap<String, Block>> {
        self.blocks.borrow()
    }

    /// Get blocks mutable reference
    pub fn blocks_mut(&self) -> std::cell::RefMut<'_, HashMap<String, Block>> {
        self.blocks.borrow_mut()
    }

    /// Get favorites reference
    pub fn favorites(&self) -> std::cell::Ref<'_, Vec<String>> {
        self.favorites.borrow()
    }

    /// Get theme reference
    pub fn theme(&self) -> std::cell::Ref<'_, Theme> {
        self.theme.borrow()
    }

    /// Get loaded flag
    pub fn is_loaded(&self) -> bool {
        *self.loaded.borrow()
    }

    /// Save a page to storage
    pub fn save_page(&self, page: &Page) {
        let stored: StoredPage = page.clone().into();
        if let Ok(json) = serde_json::to_string(&stored) {
            self.set_storage(&format!("{}{}", PREFIX_PAGES, page.id), &json);
        }
    }

    /// Load a page from storage
    pub fn load_page(&self, page_id: &str) -> Option<Page> {
        let key = format!("{}{}", PREFIX_PAGES, page_id);
        self.get_storage(&key).and_then(|json| {
            serde_json::from_str::<StoredPage>(&json).ok()
        }).map(|sp| sp.into())
    }

    /// Delete a page from storage
    pub fn delete_page(&self, page_id: &str) {
        self.remove_storage(&format!("{}{}", PREFIX_PAGES, page_id));
    }

    /// Save a block to storage
    pub fn save_block(&self, block: &Block) {
        let stored: StoredBlock = block.clone().into();
        if let Ok(json) = serde_json::to_string(&stored) {
            self.set_storage(&format!("{}{}", PREFIX_BLOCKS, block.id), &json);
        }
    }

    /// Load a block from storage
    pub fn load_block(&self, block_id: &str) -> Option<Block> {
        let key = format!("{}{}", PREFIX_BLOCKS, block_id);
        self.get_storage(&key).and_then(|json| {
            serde_json::from_str::<StoredBlock>(&json).ok()
        }).map(|sb| sb.into())
    }

    /// Delete a block from storage
    pub fn delete_block(&self, block_id: &str) {
        self.remove_storage(&format!("{}{}", PREFIX_BLOCKS, block_id));
    }

    /// Save all state
    pub fn save_state(&self, favorites: &[String], theme: &Theme) {
        // Save favorites
        if let Ok(json) = serde_json::to_string(favorites) {
            self.set_storage(PREFIX_FAVORITES, &json);
        }

        // Save theme
        let theme_str = match theme {
            Theme::Light => "light",
            Theme::Dark => "dark",
            Theme::System => "system",
        };
        self.set_storage(PREFIX_STATE, theme_str);
    }

    /// Load all state
    pub fn load_state(&self) -> (Vec<String>, Theme) {
        let favorites: Vec<String> = self.get_storage(PREFIX_FAVORITES)
            .and_then(|json| serde_json::from_str(&json).ok())
            .unwrap_or_default();

        let theme: Theme = self.get_storage(PREFIX_STATE)
            .and_then(|theme_str| match theme_str.as_str() {
                "light" => Some(Theme::Light),
                "dark" => Some(Theme::Dark),
                "system" => Some(Theme::System),
                _ => Some(Theme::System),
            })
            .unwrap_or(Theme::Light);

        (favorites, theme)
    }

    /// Export all data as JSON
    pub fn export_all(&self) -> String {
        let pages: Vec<StoredPage> = self.pages.borrow()
            .values()
            .cloned()
            .map(|p| p.into())
            .collect();

        let blocks: Vec<StoredBlock> = self.blocks.borrow()
            .values()
            .cloned()
            .map(|b| b.into())
            .collect();

        serde_json::to_string_pretty(&serde_json::json!({
            "pages": pages,
            "blocks": blocks,
        })).unwrap_or_default()
    }

    /// Import data from JSON
    pub fn import_all(&self, json: &str) -> Result<(), String> {
        let data: serde_json::Value = serde_json::from_str(json)
            .map_err(|e| format!("Invalid JSON: {}", e))?;

        // Import pages
        if let Some(pages_array) = data.get("pages").and_then(|p| p.as_array()) {
            for page_value in pages_array {
                if let Ok(stored) = serde_json::from_value::<StoredPage>(page_value.clone()) {
                    let page: Page = stored.into();
                    self.pages.borrow_mut().insert(page.id.clone(), page.clone());
                    self.save_page(&page);
                }
            }
        }

        // Import blocks
        if let Some(blocks_array) = data.get("blocks").and_then(|b| b.as_array()) {
            for block_value in blocks_array {
                if let Ok(stored) = serde_json::from_value::<StoredBlock>(block_value.clone()) {
                    let block: Block = stored.into();
                    self.blocks.borrow_mut().insert(block.id.clone(), block.clone());
                    self.save_block(&block);
                }
            }
        }

        Ok(())
    }

    /// Web storage helpers
    #[cfg(feature = "web")]
    fn set_storage(&self, key: &str, value: &str) {
        if let Some(window) = web_sys::window() {
            if let Some(local_storage) = window.local_storage().ok().flatten() {
                let _ = local_storage.set_item(key, value);
            }
        }
    }

    #[cfg(feature = "web")]
    fn get_storage(&self, key: &str) -> Option<String> {
        if let Some(window) = web_sys::window() {
            if let Some(local_storage) = window.local_storage().ok().flatten() {
                return local_storage.get_item(key).ok().flatten();
            }
        }
        None
    }

    #[cfg(feature = "web")]
    fn remove_storage(&self, key: &str) {
        if let Some(window) = web_sys::window() {
            if let Some(local_storage) = window.local_storage().ok().flatten() {
                let _ = local_storage.remove_item(key);
            }
        }
    }

    /// File download helper
    #[cfg(feature = "web")]
    pub fn download_file(&self, filename: &str, content: &str) {
        if let Some(window) = web_sys::window() {
            let document = window.document().unwrap();
            let body = document.body().unwrap();

            let blob = web_sys::Blob::new_with_str_sequence_and_options(
                &js_sys::Array::from(&js_sys::JsString::from(content)),
                web_sys::BlobPropertyBag::new().type_("application/json"),
            ).unwrap();

            let url = web_sys::Url::create_object_url_with_blob(&blob).unwrap();

            let a = document.create_element("a").unwrap();
            a.set_attribute("href", &url).unwrap();
            a.set_attribute("download", filename).unwrap();
            a.set_attribute("display", "none").unwrap();

            body.append_child(&a).unwrap();
            let click_event = document.create_event("MouseEvents").unwrap();
            click_event.init_event("click", true, true);
            let _ = a.dispatch_event(&click_event);

            body.remove_child(&a).unwrap();
            web_sys::Url::revoke_object_url(&url).unwrap();
        }
    }
}

/// Hook for using the storage manager
#[must_use]
pub fn use_storage() -> StorageManager {
    use_context::<StorageManager>().unwrap_or_else(|| {
        let manager = StorageManager::new();
        provide_context(manager.clone());
        manager
    })
}

/// Provider component for storage manager
#[component]
pub fn StorageProvider(children: Element) -> Element {
    let storage = use_hook(|| StorageManager::new());

    // Load initial state
    use_effect(move || {
        let (favorites, theme) = storage.load_state();
        *storage.favorites.borrow_mut() = favorites;
        *storage.theme.borrow_mut() = theme;
        *storage.loaded.borrow_mut() = true;

        // Apply theme
        if let Some(window) = web_sys::window() {
            if let Some(document) = window.document() {
                let is_dark = matches!(theme, Theme::Dark);
                let _ = document.document_element().unwrap().class_list().toggle("dark", is_dark);
            }
        }
    });

    provide_context(storage);

    rsx! {
        { children }
    }
}
