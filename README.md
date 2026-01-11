# DioxusBrain

A modern knowledge management tool inspired by Logseq and Obsidian, built with Rust and Dioxus. DioxusBrain combines the best features of block-based outliners with a powerful knowledge graph visualization, all running natively in the browser.

## Features

### Core Functionality
- **Block-Based Editing**: Every paragraph is a discrete block that can be nested, reordered, and organized hierarchically
- **Wikilinks**: Connect pages using `[[Page Name]]` syntax with optional aliases `[[Page Name|alias]]`
- **Tags**: Organize content with `#tag` syntax
- **Properties**: Add metadata to pages with `key:: value` syntax
- **Daily Notes**: Quick access to daily notes with a built-in calendar

### Knowledge Graph
- **Visual Graph**: See all your pages and their connections at a glance
- **Force-Directed Layout**: Automatic layout with physics simulation
- **Interactive Navigation**: Click nodes to navigate between pages
- **Filtering**: Show/hide isolated nodes, filter by connection count

### Obsidian-Inspired Features
- **Command Palette**: Press `Cmd+K` (or `Ctrl+K`) to open the command palette
- **Quick Navigation**: Search pages and execute commands instantly
- **Dark Mode**: Full dark mode support with system preference detection
- **Local Storage**: All data is stored locally in your browser

### Logseq-Inspired Features
- **Outliner Structure**: Nested bullet points with indentation
- **Block Properties**: Rich metadata for each block
- **Backlinks Panel**: See all pages linking to the current page
- **Page Properties**: Frontmatter-style properties for pages

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd/Ctrl + K` | Open command palette |
| `Cmd/Ctrl + P` | Quick page search |
| `Cmd/Ctrl + N` | Create new block |
| `Cmd/Ctrl + \` | Toggle sidebar |
| `Cmd/Ctrl + \|` | Toggle backlinks panel |
| `Cmd/Ctrl + D` | Toggle dark/light mode |
| `Enter` | Create new block |
| `Tab` | Indent block |
| `Shift+Tab` | Outdent block |
| `Escape` | Close modal/command palette |

## Getting Started

### Prerequisites

- Rust 1.70 or higher
- Cargo package manager
- A modern web browser (Chrome, Firefox, Safari, Edge)

### Installation

1. **Clone the repository**:
```bash
git clone https://github.com/yourusername/dioxus-brain.git
cd dioxus-brain
```

2. **Install Dioxus CLI**:
```bash
cargo install dioxus-cli
```

3. **Run the development server**:
```bash
dx serve
```

4. **Open your browser**:
Navigate to `http://localhost:8080`

### Building for Production

```bash
# Build for web
dx build --release

# The output will be in the `dist` folder
```

## Project Structure

```
dioxus-brain/
├── Cargo.toml              # Rust dependencies
├── index.html              # Entry HTML file
├── src/
│   ├── main.rs             # Application entry point
│   ├── lib.rs              # Library module exports
│   ├── app.rsx             # Main App component
│   ├── store/
│   │   └── mod.rs          # State management (Pages, Blocks, Theme)
│   ├── storage/
│   │   └── mod.rs          # LocalStorage persistence layer
│   ├── graph/
│   │   └── mod.rs          # Knowledge graph logic and layout
│   ├── utils/
│   │   └── mod.rs          # Utility functions (wikilinks, tags, etc.)
│   └── components/
│       ├── mod.rs          # Component exports
│       ├── sidebar.rsx     # Sidebar navigation component
│       ├── editor.rsx      # Main editor component
│       ├── block.rsx       # Individual block component
│       ├── backlinks.rsx   # Backlinks panel component
│       ├── graph.rsx       # Graph visualization component
│       └── command_palette.rsx  # Command palette component
```

## Architecture

### State Management

DioxusBrain uses a centralized state store (`AppState`) managed through Dioxus signals:

- **Pages**: HashMap of all pages by ID
- **Blocks**: HashMap of all blocks by ID with parent-child relationships
- **Theme**: Current theme preference (Light/Dark/System)
- **UI State**: Sidebar visibility, current page, current block

### Data Model

```
Page
├── id: String
├── title: String
├── icon: Option<String>
├── blocks: Vec<String>           // Top-level block IDs
├── properties: HashMap<String, String>
├── tags: Vec<String>
├── created_at: DateTime<Utc>
└── updated_at: DateTime<Utc>

Block
├── id: String
├── content: String
├── parent_id: Option<String>
├── children: Vec<String>
├── properties: HashMap<String, String>
├── created_at: DateTime<Utc>
└── updated_at: DateTime<Utc>
```

### Knowledge Graph

The knowledge graph is built by parsing wikilinks (`[[Page]]`) in all blocks:

1. **Extraction**: Parse all wikilinks from block content
2. **Node Creation**: Each page becomes a node
3. **Edge Creation**: Each wikilink creates a directed edge
4. **Layout**: Force-directed algorithm positions nodes
5. **Visualization**: SVG-based rendering with Dioxus

### Persistence

All data is persisted to the browser's LocalStorage:

- Individual pages and blocks are stored with unique keys
- Application state (theme, favorites) is stored separately
- Full data export/import as JSON is supported

## Extending DioxusBrain

### Adding New Commands

Add to the `commands` array in `CommandPalette`:

```rust
Command {
    id: "my_command",
    title: "My custom command",
    shortcut: "⌘M",
    icon: "✨",
    action: Arc::new(|_| {
        // Your action here
    })
}
```

### Custom Block Types

Extend the `BlockComponent` to support new block types:

```rust
match block.block_type {
    BlockType::Code => CodeBlock { ... },
    BlockType::Quote => QuoteBlock { ... },
    BlockType::Todo => TodoBlock { ... },
    _ => DefaultBlock { ... }
}
```

### Theme Customization

Modify the Tailwind config in `index.html`:

```javascript
theme: {
    extend: {
        colors: {
            obsidian: {
                // Your custom colors
            }
        }
    }
}
```

## Browser Support

- Chrome 90+
- Firefox 88+
- Safari 14+
- Edge 90+

## Performance

- **Virtual DOM**: Dioxus efficiently updates only changed components
- **Memoization**: Expensive computations are memoized
- **Lazy Loading**: Components load on demand
- **IndexedDB Ready**: Can be extended for larger datasets

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [Dioxus](https://dioxus.org/) - Excellent Rust-based UI framework
- [Logseq](https://logseq.com/) - Inspiration for block-based outliner
- [Obsidian](https://obsidian.md/) - Inspiration for knowledge graph and command palette
- [Tailwind CSS](https://tailwindcss.com/) - Utility-first CSS framework
- [Heroicons](https://heroicons.com/) - Beautiful hand-crafted SVG icons
