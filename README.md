# GenSnippets

<div align="center">
  <img src="https://img.shields.io/badge/Platform-macOS%2011.5%2B-blue" alt="macOS 11.5+">
  <img src="https://img.shields.io/badge/Swift-5.5%2B-orange" alt="Swift 5.5+">
  <img src="https://img.shields.io/badge/License-MIT-green" alt="MIT License">
  <img src="https://img.shields.io/badge/Version-2.4.0-purple" alt="Version 2.4.0">
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

1. **Grant Accessibility Permissions**: 
   - GenSnippets requires accessibility permissions to monitor keyboard input
   - You'll be prompted to grant permissions in System Preferences
   - Navigate to: System Preferences → Security & Privacy → Privacy → Accessibility

2. **Create Your First Snippet**:
   - Click the "+" button in the snippet list
   - Enter a command trigger (e.g., `!email`)
   - Enter the replacement text (e.g., `john.doe@example.com`)
   - Click "Save"

3. **Test It Out**:
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
- **Storage**: UserDefaults (local only)

### Key Components

- **TextReplacementService** (~1,195 lines): Core engine with embedded TrieNode class for O(m) text matching
- **MetafieldService**: Handles dynamic field parsing, input dialog, and value substitution
- **BrowserCompatibleTextInsertion**: Special handling for web browsers with timing adjustments
- **CategoryViewModel**: Manages category state with alphabetical sorting
- **SnippetsViewModel**: Handles snippet CRUD operations with batch saving
- **AccessibilityPermissionManager**: Manages macOS permission requests and status
- **LocalStorageService**: Batch-optimized UserDefaults persistence with caching layer
- **GlobalHotkeyManager**: Carbon-based global hotkey registration
- **OptimizedSnippetMatcher**: High-performance snippet matching algorithms

## Contributing

Contributions are welcome! Whether you're fixing bugs, adding features, or improving documentation, we appreciate your help.

Please see our [CONTRIBUTING.md](CONTRIBUTING.md) for details on:
- Code of conduct
- Development setup
- Submitting pull requests
- Reporting issues

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