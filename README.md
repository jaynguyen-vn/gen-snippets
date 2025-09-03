# Gen Snippets

<div align="center">
  <img src="https://img.shields.io/badge/Platform-macOS%2011.0%2B-blue" alt="macOS 11.0+">
  <img src="https://img.shields.io/badge/Swift-5.5%2B-orange" alt="Swift 5.5+">
  <img src="https://img.shields.io/badge/License-MIT-green" alt="MIT License">
</div>

## 📝 Overview

Gen Snippets is a powerful macOS text snippet management application that enables system-wide text replacement. Running seamlessly in both the menu bar and dock, it monitors your keyboard input to instantly replace trigger commands with pre-defined snippets, boosting your productivity across all applications.

## ✨ Features

### Core Functionality
- 🚀 **System-wide Text Replacement**: Works in any application across macOS
- 📁 **Category Management**: Organize snippets into custom categories for better organization
- 🔍 **Smart Command Matching**: Automatically detects and replaces text as you type
- 🎯 **Priority Matching**: Longer commands take precedence for accurate replacements
- 🔄 **Auto-cleanup**: Automatically removes typed commands after replacement

### User Interface
- 🖥️ **Three-Column Layout**: Intuitive category list, snippet list, and detail view
- 📊 **Menu Bar Integration**: Quick access from the system menu bar
- 🎨 **Native macOS Design**: Built with SwiftUI for a seamless Mac experience
- 👁️ **Show/Hide Options**: Toggle between dock and menu bar visibility

### Data Management
- 💾 **100% Offline**: All data stored locally with no server dependencies
- ☁️ **iCloud Sync**: Optional synchronization across your Mac devices
- 📤 **Export/Import**: Backup and share your snippet collections
- 🔒 **Privacy-First**: Your data never leaves your devices

### Advanced Features
- 📈 **Usage Insights**: Track your most-used snippets and productivity gains
- 🌍 **Multi-language Support**: Localization infrastructure ready for expansion
- 🚦 **Accessibility Integration**: Full macOS accessibility permission handling
- ⚡ **Performance Optimized**: Sorted snippet cache for efficient real-time matching

## 🚀 Installation

### Requirements
- macOS 11.0 (Big Sur) or later
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
   - Select the "Gen Snippets" scheme
   - Press `⌘R` to build and run

Or build from command line:
```bash
# Debug build
xcodebuild -project GenSnippets.xcodeproj -scheme "Gen Snippets" -configuration Debug build

# Release build
xcodebuild -project GenSnippets.xcodeproj -scheme "Gen Snippets" -configuration Release build

# Run the app
open "build/Debug/Gen Snippets.app"
```

## 🎯 Getting Started

### First Launch

1. **Grant Accessibility Permissions**: 
   - Gen Snippets requires accessibility permissions to monitor keyboard input
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

## ⚙️ Configuration

### Settings Options

- **Menu Bar Icon**: Show/hide the menu bar icon
- **Dock Icon**: Show/hide the dock icon
- **Launch at Login**: Automatically start Gen Snippets when you log in
- **iCloud Sync**: Enable synchronization across devices
- **Server Sync**: Connect to a backend server for team sharing (optional)

### Data Storage

Local data is stored in:
```
~/Library/Preferences/com.gensnippets.app.plist
```

## 🏗️ Architecture

### Technology Stack
- **Language**: Swift 5.5+
- **UI Framework**: SwiftUI
- **Platform**: macOS 11.0+
- **Storage**: UserDefaults + Optional iCloud

### Key Components

- **TextReplacementService**: Core engine for detecting and replacing text
- **CategoryViewModel**: Manages category state and operations
- **SnippetsViewModel**: Handles snippet CRUD operations
- **AccessibilityPermissionManager**: Manages macOS permission requests
- **LocalStorageService**: Handles data persistence
- **iCloudSyncService**: Optional cloud synchronization

## 🤝 Contributing

We welcome contributions! Please see our [CONTRIBUTING.md](CONTRIBUTING.md) for details on:
- Code of conduct
- Development setup
- Submitting pull requests
- Reporting issues

## 📄 License

Gen Snippets is released under the MIT License. See [LICENSE](LICENSE) for details.

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