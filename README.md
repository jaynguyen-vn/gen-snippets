# GenSnippets

<div align="center">
  <img src="https://img.shields.io/badge/Platform-macOS%2011.5%2B-blue" alt="macOS 11.5+">
  <img src="https://img.shields.io/badge/Swift-5.5%2B-orange" alt="Swift 5.5+">
  <img src="https://img.shields.io/badge/License-MIT-green" alt="MIT License">
  <img src="https://img.shields.io/badge/Version-2.8.2-purple" alt="Version 2.8.2">
</div>

## Overview

GenSnippets is a lightweight macOS application for system-wide text expansion. It runs quietly in your menu bar, monitoring keyboard input and instantly replacing custom trigger commands with pre-defined text snippets across all applications.

## Features

### Core Functionality
- **System-wide Text Replacement** - Works in any application across macOS using CGEvent monitoring
- **Category Management** - Organize snippets into custom categories with alphabetical sorting
- **Smart Command Matching** - Trie data structure provides O(m) lookup performance
- **Priority Matching** - Longer commands take precedence for accurate replacements
- **Auto-cleanup** - Automatically removes typed commands after replacement
- **Dynamic Content** - Insert clipboard content, current date, or position cursor with special keywords
- **Security Buffer** - 15-second timeout prevents accidental replacements of old inputs
- **Browser Compatibility** - Specialized timing adjustments for Discord, Chrome, and other web browsers

### User Interface
- **Three-Column Layout** - Intuitive category list, snippet list, and detail view
- **Menu Bar Integration** - Quick access from the system menu bar with snippet count
- **Native macOS Design** - Built with SwiftUI for a seamless experience
- **Flexible Visibility** - Toggle between dock and menu bar visibility
- **Quick Search** - Global hotkey (default: Cmd+Ctrl+S) opens instant snippet search
- **Customizable Shortcuts** - Configure your preferred keyboard shortcuts

### Data Management
- **100% Offline** - All data stored locally in UserDefaults with batch saving
- **Export/Import** - Backup and share your snippet collections as JSON
- **Privacy-First** - Your data never leaves your device
- **Optimized Storage** - Caching layer with batch operations for performance

### Advanced Features
- **Usage Tracking** - Command-based usage tracking for accurate statistics
- **Insights Dashboard** - Monitor snippet usage patterns and analytics
- **Multi-language Support** - Localization infrastructure ready for expansion
- **Accessibility Integration** - Full macOS accessibility permission handling
- **Performance Optimized** - Trie-based matching with memory-efficient caching
- **Smart Keywords** - Dynamic content insertion with multiple placeholders:
  - `{clipboard}` - Current clipboard content
  - `{cursor}` - Cursor positioning after insertion
  - `{timestamp}` - Unix timestamp
  - `{random-number}` - Random number (1-1000)
  - `{dd/mm}` - Current date (day/month format)
  - `{dd/mm/yyyy}` - Full date format
  - `{time}` - Current time (HH:mm:ss)
  - `{uuid}` - Unique identifier
- **Metafields (Dynamic Fields)** - Custom placeholders that prompt for input:
  - `{{field}}` - Prompts for a value before insertion
  - `{{field:default}}` - Prompts with a pre-filled default value
  - Live preview shows the result as you type
  - Perfect for templates with variable content
- **Batch Operations** - Efficient batch saving and loading for large snippet collections

## Installation

### Download

1. Download the latest DMG from [Releases](https://github.com/jaynguyen-vn/gen-snippets/releases)
2. Open the DMG and drag **GenSnippets** to your Applications folder
3. Since the app is not notarized with Apple, macOS Gatekeeper will block it on first launch. To allow it, use **one** of these methods:

   **Option A — GUI (recommended):**
   - Double-click GenSnippets — you'll see a warning dialog, click **Done** (or **Cancel**)
   - Open **System Settings → Privacy & Security**
   - Scroll down to the **Security** section — you'll see *"GenSnippets" was blocked from use because it is not from an identified developer*
   - Click **Open Anyway** and confirm

   **Option B — Terminal:**
   ```bash
   xattr -cr /Applications/GenSnippets.app
   ```

4. Open GenSnippets — it will ask for **Accessibility** permission
5. Grant permission in **System Settings → Privacy & Security → Accessibility**
6. **Quit and reopen** GenSnippets for the permission to take effect

### Requirements
- macOS 11.5 (Big Sur) or later
- Xcode 13.0+ (for building from source)

### Building from Source

1. Clone the repository:
```bash
git clone https://github.com/jaynguyen-vn/gen-snippets
cd gen-snippets/GenSnippets
```

2. Open in Xcode:
```bash
open GenSnippets.xcodeproj
```

3. Build and run:
   - Select the "GenSnippets" scheme
   - Press `⌘R` to build and run

Or build from command line:
```bash
# Debug build
xcodebuild -project GenSnippets.xcodeproj -scheme "GenSnippets" -configuration Debug build

# Release build
xcodebuild -project GenSnippets.xcodeproj -scheme "GenSnippets" -configuration Release build

# Run the app (path may vary based on build settings)
open ~/Library/Developer/Xcode/DerivedData/GenSnippets-*/Build/Products/Debug/GenSnippets.app
```

## Getting Started

### First Launch

1. **Create Your First Snippet**:
   - Click the "+" button in the snippet list
   - Enter a command trigger (e.g., `!email`)
   - Enter the replacement text (e.g., `john.doe@example.com`)
   - Click "Save"

2. **Test It Out**:
   - Open any application (TextEdit, Safari, etc.)
   - Type your command trigger
   - Watch it instantly replace with your snippet!

### Organizing Snippets

Categories help you organize related snippets:
- Create categories for different contexts (Work, Personal, Code, etc.)
- The "Uncategory" is always available for miscellaneous snippets
- Deleted categories automatically move their snippets to Uncategory

## Usage Examples

### Email Templates
- Command: `!sig` → Your full email signature
- Command: `!thanks` → "Thank you for your time and consideration."

### Code Snippets
- Command: `!lorem` → Lorem ipsum placeholder text
- Command: `!copyright` → Copyright notice with current year

### Frequent Phrases
- Command: `!addr` → Your full address
- Command: `!phone` → Your phone number

### Dynamic Content
- Command: `!timestamp` → "Log entry {timestamp}" (inserts Unix timestamp)
- Command: `!template` → "Dear {cursor}," (positions cursor after insertion)
- Command: `!paste` → "{clipboard}" (inserts current clipboard content)
- Command: `!log` → "[{time}] {uuid}: " (inserts time and unique ID)
- Command: `!today` → "Date: {dd/mm/yyyy}" (inserts today's date)

### Metafields (Dynamic Input)
- Command: `!hello` → "Hello {{name}}, welcome to {{company}}!"
  - Prompts for "name" and "company" values before insertion
- Command: `!email` → "Hi {{name:John}}, ..."
  - Prompts with "John" as the default value for "name"
- Command: `!meeting` → "Meeting with {{client}} on {{date}} at {{time:10:00 AM}}"
  - Mix of required and default-value fields

## Configuration

### Settings Options

- **Menu Bar Icon** - Show/hide the menu bar icon with snippet count
- **Dock Icon** - Show/hide the dock icon
- **Launch at Login** - Automatically start GenSnippets when you log in
- **Global Hotkey** - Customize the keyboard shortcut (default: Cmd+Ctrl+S)
- **Search View** - Quick access to snippet search with customizable shortcut

### Data Storage

Local data is stored in:
```
~/Library/Preferences/Jay8448.Gen-Snippets.plist
```

## Architecture

### Technology Stack
- **Language**: Swift 5.5+
- **UI Framework**: SwiftUI
- **Platform**: macOS 11.5+
- **Storage**: UserDefaults (local only, JSON format)
- **Dependencies**: Zero third-party (Apple frameworks only)

### MVVM + Service Layer Design

**Services** handle business logic (singletons, thread-safe):
- **TextReplacementService**: Core engine with Trie for O(m) matching
- **LocalStorageService**: Batch-optimized UserDefaults with caching
- **MetafieldService**: Dynamic placeholder parsing and input dialog
- **RichContentService**: Sequential image/file/URL insertion (file-based storage)
- **EdgeCaseHandler**: App-specific timing (Discord, browsers, IDEs, terminals, Ghostty)
- **ShareService**: Import/export with conflict resolution
- **SandboxMigrationService**: Handles transition from sandboxed to non-sandboxed environment

**ViewModels** manage UI state (@Published, reactive):
- **LocalSnippetsViewModel**: Snippet CRUD + batch operations
- **CategoryViewModel**: Category management with alphabetical sorting

**Views** use SwiftUI with Design System tokens (DS*):
- ThreeColumnView, SnippetDetailView, AddSnippetSheet, etc.

For detailed architecture: see [docs/system-architecture.md](docs/system-architecture.md)

## Documentation

Complete developer documentation in `docs/`:

- **[Project Overview & PDR](docs/project-overview-pdr.md)** - Vision, features, requirements, roadmap
- **[Codebase Summary](docs/codebase-summary.md)** - Directory structure, 48 Swift files, LOC breakdown
- **[Code Standards](docs/code-standards.md)** - Swift conventions, naming, patterns, design system usage
- **[System Architecture](docs/system-architecture.md)** - MVVM design, data flow, threading, event system
- **[Project Roadmap](docs/project-roadmap.md)** - Version history, upcoming plans, technical debt
- **[Deployment Guide](docs/deployment-guide.md)** - Build, code signing, DMG creation, release process

## Contributing

Contributions welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for:
- Code of conduct
- Development setup (see docs/)
- Pull request process
- Reporting issues

**Before Contributing:**
1. Read [Code Standards](docs/code-standards.md)
2. Read [System Architecture](docs/system-architecture.md)
3. Follow MVVM + Service Layer patterns
4. Keep files <400 LOC, views <300 LOC

## License

GenSnippets is released under the MIT License. See [LICENSE](LICENSE) for details.

## Acknowledgments

- Built for the macOS community
- Thanks to all contributors and users
- Special thanks to the SwiftUI team for the amazing framework

## Support

- **Issues**: [GitHub Issues](https://github.com/jaynguyen-vn/gen-snippets/issues)
- **Discussions**: [GitHub Discussions](https://github.com/jaynguyen-vn/gen-snippets/discussions)
- **Email**: truongnd0001@gmail.com

---

<div align="center">
  Made for productivity enthusiasts
</div>