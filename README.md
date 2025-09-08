# GenSnippets

<div align="center">
  <img src="https://img.shields.io/badge/Platform-macOS%2011.0%2B-blue" alt="macOS 11.0+">
  <img src="https://img.shields.io/badge/Swift-5.5%2B-orange" alt="Swift 5.5+">
  <img src="https://img.shields.io/badge/License-MIT-green" alt="MIT License">
</div>

## 📝 Overview

GenSnippets is a powerful macOS text snippet management application that enables system-wide text replacement. Running seamlessly in both the menu bar and dock, it monitors your keyboard input to instantly replace trigger commands with pre-defined snippets, boosting your productivity across all applications.

## ✨ Features

### Core Functionality
- 🚀 **System-wide Text Replacement**: Works in any application across macOS using CGEvent monitoring
- 📁 **Category Management**: Organize snippets into custom categories for better organization
- 🔍 **Smart Command Matching**: Uses Trie data structure for O(m) lookup performance
- 🎯 **Priority Matching**: Longer commands take precedence for accurate replacements
- 🔄 **Auto-cleanup**: Automatically removes typed commands after replacement
- ⚡ **Dynamic Content**: Insert clipboard content, current date, or position cursor with special keywords
- ⏱️ **Security Buffer**: 15-second timeout prevents accidental replacements of old inputs

### User Interface
- 🖥️ **Three-Column Layout**: Intuitive category list, snippet list, and detail view
- 📊 **Menu Bar Integration**: Quick access from the system menu bar with snippet count
- 🎨 **Native macOS Design**: Built with SwiftUI for a seamless Mac experience
- 👁️ **Show/Hide Options**: Toggle between dock and menu bar visibility
- 🔎 **Quick Search**: Global hotkey (default: Cmd+Ctrl+S) opens instant snippet search
- ⌨️ **Customizable Shortcuts**: Configure your preferred keyboard shortcuts

### Data Management
- 💾 **100% Offline**: All data stored locally in UserDefaults with batch saving
- 📤 **Export/Import**: Backup and share your snippet collections as JSON
- 🔒 **Privacy-First**: Your data never leaves your devices
- 💨 **Optimized Storage**: Caching layer with batch operations for performance

### Advanced Features
- 📈 **Usage Tracking**: Monitor snippet usage with automatic counting
- 🌍 **Multi-language Support**: Localization infrastructure ready for expansion
- 🚦 **Accessibility Integration**: Full macOS accessibility permission handling
- ⚡ **Performance Optimized**: Trie-based matching with memory-efficient caching
- 📋 **Smart Keywords**: Dynamic content insertion with multiple placeholders:
  - `{clipboard}` - Current clipboard content
  - `{cursor}` - Cursor positioning after insertion
  - `{timestamp}` - Unix timestamp
  - `{random-number}` - Random number (1-1000)
  - `{dd/mm}` - Current date (day/month format)
  - `{dd/mm/yyyy}` - Full date format
  - `{time}` - Current time (HH:mm:ss)
  - `{uuid}` - Unique identifier
- 🔄 **Batch Operations**: Efficient batch saving and loading for large snippet collections

## 🚀 Installation

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

# Run the app
open "build/Debug/GenSnippets.app"
```

## 🎯 Getting Started

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

## 💡 Usage Examples

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

## ⚙️ Configuration

### Settings Options

- **Menu Bar Icon**: Show/hide the menu bar icon with snippet count
- **Dock Icon**: Show/hide the dock icon
- **Launch at Login**: Automatically start GenSnippets when you log in
- **Global Hotkey**: Customize the keyboard shortcut (default: Cmd+Ctrl+S)
- **Search View**: Quick access to snippet search with customizable shortcut

### Data Storage

Local data is stored in:
```
~/Library/Preferences/Jay8448.Gen-Snippets.plist
```

## 🏗️ Architecture

### Technology Stack
- **Language**: Swift 5.0+
- **UI Framework**: SwiftUI
- **Platform**: macOS 11.5+
- **Storage**: UserDefaults (local only)

### Key Components

- **TextReplacementService** (906 lines): Core engine using Trie data structure for O(m) text matching
- **CategoryViewModel**: Manages category state with real-time updates
- **SnippetsViewModel**: Handles snippet CRUD operations with usage tracking
- **AccessibilityPermissionManager**: Manages macOS permission requests and status
- **LocalStorageService**: Batch-optimized UserDefaults persistence with caching
- **SearchViewModel**: Powers the global quick search functionality
- **KeyboardShortcutManager**: Handles customizable global hotkeys

## 🤝 Contributing

We welcome contributions! Please see our [CONTRIBUTING.md](CONTRIBUTING.md) for details on:
- Code of conduct
- Development setup
- Submitting pull requests
- Reporting issues

## 📄 License

GenSnippets is released under the MIT License. See [LICENSE](LICENSE) for details.

## 🙏 Acknowledgments

- Built with ❤️ for the macOS community
- Thanks to all contributors and users
- Special thanks to the SwiftUI team for the amazing framework

## 📮 Support

- **Issues**: [GitHub Issues](https://github.com/jaynguyen-vn/gen-snippets/issues)
- **Discussions**: [GitHub Discussions](https://github.com/jaynguyen-vn/gen-snippets/discussions)
- **Email**: truongnd0001@gmail.com

---

<div align="center">
  Made with ⚡ for productivity enthusiasts
</div>