use regex::Regex;
use std::collections::HashMap;
use chrono::{DateTime, Utc, TimeZone};

/// Extract wikilinks from text
/// Returns a vector of (link_text, alias) tuples
pub fn extract_wikilinks(text: &str) -> Vec<(String, Option<String>)> {
    let mut links = Vec::new();
    
    if let Ok(re) = Regex::new(r"\[\[([^\]]+)\]\]") {
        for cap in re.captures_iter(text) {
            if let Some(full_match) = cap.get(1) {
                let content = full_match.as_str();
                if let Some((link, alias)) = content.split_once('|') {
                    links.push((link.trim().to_string(), Some(alias.trim().to_string())));
                } else {
                    links.push((content.trim().to_string(), None));
                }
            }
        }
    }
    
    links
}

/// Extract tags from text
pub fn extract_tags(text: &str) -> Vec<String> {
    let mut tags = Vec::new();
    
    if let Ok(re) = Regex::new(r"#([a-zA-Z0-9_-]+)") {
        for cap in re.captures_iter(text) {
            if let Some(tag) = cap.get(1) {
                tags.push(format!("#{}", tag.as_str()));
            }
        }
    }
    
    tags
}

/// Parse properties from a block
/// Properties are in the format: key:: value
pub fn parse_properties(text: &str) -> HashMap<String, String> {
    let mut properties = HashMap::new();
    
    if let Ok(re) = Regex::new(r"(\w+)\s*::\s*(.+)") {
        for cap in re.captures_iter(text) {
            if let (Some(key), Some(value)) = (cap.get(1), cap.get(2)) {
                properties.insert(
                    key.as_str().to_string(),
                    value.as_str().trim().to_string()
                );
            }
        }
    }
    
    properties
}

/// Format a datetime relative to now
pub fn format_relative_time(dt: &DateTime<Utc>) -> String {
    let now = Utc::now();
    let diff = now.signed_duration_since(*dt);
    
    let secs = diff.num_seconds();
    
    if secs < 60 {
        "just now".to_string()
    } else if secs < 3600 {
        let mins = secs / 60;
        format!("{}m ago", mins)
    } else if secs < 86400 {
        let hours = secs / 3600;
        format!("{}h ago", hours)
    } else if secs < 604800 {
        let days = secs / 86400;
        format!("{}d ago", days)
    } else if secs < 2592000 {
        let weeks = secs / 604800;
        format!("{}w ago", weeks)
    } else {
        let months = secs / 2592000;
        format!("{}mo ago", months)
    }
}

/// Truncate text to a maximum length
pub fn truncate_text(text: &str, max_length: usize) -> String {
    if text.len() <= max_length {
        text.to_string()
    } else {
        let truncated = &text[..max_length.saturating_sub(3)];
        format!("{}...", truncated.trim_end())
    }
}

/// Generate a slug from a title
pub fn slugify(title: &str) -> String {
    title.to_lowercase()
        .replace(|c: char| !c.is_alphanumeric() && c != '-', "-")
        .replace("--", "-")
        .trim_matches('-')
        .to_string()
}

/// Parse markdown-style formatting
/// Returns HTML string
pub fn parse_markdown(text: &str) -> String {
    let mut result = escape_html(text);
    
    // Bold
    if let Ok(re) = Regex::new(r"\*\*(.+?)\*\*") {
        result = re.replace_all(&result, "<strong>$1</strong>").into_owned();
    }
    
    // Italic
    if let Ok(re) = Regex::new(r"\*(.+?)\*") {
        result = re.replace_all(&result, "<em>$1</em>").into_owned();
    }
    
    // Code inline
    if let Ok(re) = Regex::new(r"`(.+?)`") {
        result = re.replace_all(&result, "<code class=\"bg-obsidian-100 dark:bg-obsidian-800 px-1 rounded\">$1</code>").into_owned();
    }
    
    // Strikethrough
    if let Ok(re) = Regex::new(r"~~(.+?)~~") {
        result = re.replace_all(&result, "<del>$1</del>").into_owned();
    }
    
    // Highlight
    if let Ok(re) = Regex::new(r"==(.+?)==") {
        result = re.replace_all(&result, "<mark>$1</mark>").into_owned();
    }
    
    result
}

/// Escape HTML special characters
fn escape_html(text: &str) -> String {
    text.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace("\"", "&quot;")
        .replace("'", "&#39;")
}

/// Get daily note title for today
pub fn get_today_title() -> String {
    let now = chrono::Local::now();
    now.format("%Y-%m-%d").to_string()
}

/// Get daily note title for a specific date
pub fn get_date_title(date: &chrono::DateTime<chrono::FixedOffset>) -> String {
    date.format("%Y-%m-%d").to_string()
}

/// Generate week dates for calendar view
pub fn get_week_dates() -> Vec<(String, String)> {
    let now = chrono::Local::now();
    let today = now.date_naive();
    
    let mut dates = Vec::new();
    
    // Get start of week (Monday)
    let start = today - chrono::Duration::days(today.weekday().num_days_from_monday() as i64);
    
    for i in 0..7 {
        let date = start + chrono::Duration::days(i);
        dates.push((
            date.format("%Y-%m-%d").to_string(),
            date.format("%a %d").to_string(),
        ));
    }
    
    dates
}

/// Search pages by title and content
pub fn search_pages(
    query: &str,
    pages: &HashMap<String, crate::store::Page>,
    blocks: &HashMap<String, crate::store::Block>
) -> Vec<SearchResult> {
    let query_lower = query.to_lowercase();
    let mut results: Vec<SearchResult> = Vec::new();
    
    for page in pages.values() {
        let title_score = if page.title.to_lowercase().contains(&query_lower) {
            10
        } else {
            0
        };
        
        // Search in blocks
        let mut block_matches = Vec::new();
        for block_id in &page.blocks {
            if let Some(block) = blocks.get(block_id) {
                if block.content.to_lowercase().contains(&query_lower) {
                    block_matches.push(truncate_text(&block.content, 100));
                }
            }
        }
        
        if title_score > 0 || !block_matches.is_empty() {
            results.push(SearchResult {
                page_id: page.id.clone(),
                page_title: page.title.clone(),
                score: title_score + block_matches.len() * 2,
                block_matches,
            });
        }
    }
    
    // Sort by score
    results.sort_by(|a, b| b.score.cmp(&a.score));
    results
}

/// Search result item
#[derive(Debug, Clone)]
pub struct SearchResult {
    pub page_id: String,
    pub page_title: String,
    pub score: usize,
    pub block_matches: Vec<String>,
}

/// Calculate word count
pub fn word_count(text: &str) -> usize {
    text.split_whitespace().count()
}

/// Calculate reading time in minutes
pub fn reading_time(text: &str, words_per_minute: usize) -> usize {
    let words = word_count(text);
    (words as f64 / words_per_minute as f64).ceil() as usize
}

/// Debounce function helper
pub fn debounce<F: FnMut()>(ms: u64, mut f: F) -> impl FnMut() {
    let mut timer = Option::<web_sys::Window>::None;
    
    move || {
        if let Some(window) = web_sys::window() {
            if let Some(old_timer) = timer {
                window.clear_timeout_with_id(old_timer.timeout_id());
            }
            
            let window = window.clone();
            timer = Some(window.set_timeout_with_callback_and_timeout_and_arguments_0(
                Closure::wrap(Box::new(move || {
                    f();
                }) as Box<dyn FnMut()>),
                ms as i32,
            ).unwrap());
        }
    }
}

/// Generate unique ID
pub fn generate_id() -> String {
    uuid::Uuid::new_v4().to_string()
}

/// Copy text to clipboard
#[cfg(feature = "web")]
pub fn copy_to_clipboard(text: &str) -> Result<(), String> {
    if let Some(window) = web_sys::window() {
        if let Some(document) = window.document() {
            let navigator = window.navigator();
            let clipboard = navigator.clipboard().map_err(|_| "Clipboard API not available")?;
            
            let promise = clipboard.write_text(text);
            let future = wasm_bindgen_futures::future_to_promise(promise);
            
            wasm_bindgen_futures::spawn(async move {
                if let Err(e) = future.await {
                    web_sys::console::error_1(&format!("Copy failed: {:?}", e));
                }
            });
            
            return Ok(());
        }
    }
    Err("Window not available".to_string())
}

/// Format file size
pub fn format_file_size(bytes: usize) -> String {
    if bytes < 1024 {
        format!("{} B", bytes)
    } else if bytes < 1024 * 1024 {
        format!("{:.1} KB", bytes as f64 / 1024.0)
    } else {
        format!("{:.1} MB", bytes as f64 / (1024.0 * 1024.0))
    }
}
