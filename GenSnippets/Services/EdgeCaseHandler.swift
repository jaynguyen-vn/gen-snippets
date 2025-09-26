import Foundation
import AppKit
import Carbon

// MARK: - Edge Case Detection and Handling
final class EdgeCaseHandler {

    // MARK: - App Categories

    static func detectAppCategory() -> AppCategory {
        guard let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else {
            return .unknown
        }

        // Check each category
        if isPasswordField() { return .passwordField }
        if isVMApp(bundleID) { return .virtualMachine }
        if isRemoteDesktop(bundleID) { return .remoteDesktop }
        if isElectronApp(bundleID) { return .electronApp }
        if isIDE(bundleID) { return .ide }
        if isGame(bundleID) { return .game }
        if isSSHSession() { return .sshSession }
        if isTerminal(bundleID) { return .terminal }
        if isBrowser(bundleID) { return .browser }

        return .standard
    }

    enum AppCategory {
        case standard
        case browser
        case terminal
        case passwordField
        case virtualMachine
        case remoteDesktop
        case electronApp
        case ide
        case game
        case sshSession
        case unknown

        var shouldDisableExpansion: Bool {
            switch self {
            case .passwordField, .game:
                return true
            default:
                return false
            }
        }

        var deletionDelay: TimeInterval {
            switch self {
            case .terminal, .sshSession:
                return 0.001  // 1ms - simple deletion
            case .browser, .electronApp:
                return 0.002  // 2ms - slower for web
            case .virtualMachine, .remoteDesktop:
                return 0.003  // 3ms - account for latency
            case .ide:
                return 0.0015 // 1.5ms - medium speed
            default:
                return 0.0005 // 0.5ms - standard
            }
        }

        var pasteDelay: TimeInterval {
            switch self {
            case .browser, .electronApp:
                return 0.002  // 2ms
            case .virtualMachine, .remoteDesktop:
                return 0.004  // 4ms - extra time for VM
            case .sshSession:
                return 0.003  // 3ms - network latency
            default:
                return 0.0008 // 0.8ms - standard
            }
        }

        var useSimpleDeletion: Bool {
            switch self {
            case .terminal, .sshSession, .virtualMachine, .remoteDesktop:
                return true  // No Shift+Arrow selection
            default:
                return false
            }
        }
    }

    // MARK: - Detection Methods

    private static func isPasswordField() -> Bool {
        // Check if secure text input is active
        return IsSecureEventInputEnabled()
    }

    private static func isVMApp(_ bundleID: String) -> Bool {
        let vmApps = [
            "com.parallels.desktop.console",
            "com.vmware.fusion",
            "org.virtualbox.app.VirtualBox",
            "com.utmapp.UTM",
            "com.qemu.QEMU"
        ]
        return vmApps.contains(bundleID)
    }

    private static func isRemoteDesktop(_ bundleID: String) -> Bool {
        let remoteApps = [
            "com.microsoft.rdc.macos",
            "com.teamviewer.TeamViewer",
            "com.anydesk.anydesk",
            "com.realvnc.VNCViewer",
            "net.nomachine.nxplayer",
            "com.parsec.parsec"
        ]
        return remoteApps.contains(bundleID)
    }

    private static func isElectronApp(_ bundleID: String) -> Bool {
        let electronApps = [
            "com.tinyspeck.slackmacgap",  // Slack
            "com.hnc.Discord",             // Discord
            "com.microsoft.VSCode",        // VS Code (also in IDE)
            "com.github.atom",             // Atom
            "com.spotify.client",          // Spotify
            "com.tdesktop.Telegram",       // Telegram
            "net.whatsapp.WhatsApp",       // WhatsApp
            "com.microsoft.teams2",        // Teams
            "notion.id",                   // Notion
            "md.obsidian",                 // Obsidian
            "com.figma.desktop",           // Figma
            "com.electron.postman"         // Postman
        ]
        return electronApps.contains(bundleID)
    }

    private static func isIDE(_ bundleID: String) -> Bool {
        let ideApps = [
            "com.microsoft.VSCode",
            "com.apple.dt.Xcode",
            "com.jetbrains.intellij",
            "com.jetbrains.PhpStorm",
            "com.jetbrains.WebStorm",
            "com.jetbrains.pycharm",
            "com.jetbrains.rider",
            "com.jetbrains.CLion",
            "com.jetbrains.GoLand",
            "com.sublimetext.4",
            "com.github.atom",
            "com.barebones.bbedit",
            "org.vim.MacVim"
        ]
        return ideApps.contains(bundleID)
    }

    private static func isGame(_ bundleID: String) -> Bool {
        // Check if app is fullscreen
        if let app = NSWorkspace.shared.frontmostApplication {
            if let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] {
                for window in windows {
                    if let ownerPID = window[kCGWindowOwnerPID as String] as? Int,
                       ownerPID == app.processIdentifier,
                       let bounds = window[kCGWindowBounds as String] as? [String: CGFloat] {
                        // Check if window is fullscreen
                        let screenFrame = NSScreen.main?.frame ?? .zero
                        if bounds["Width"] == screenFrame.width &&
                           bounds["Height"] == screenFrame.height {
                            return true  // Likely a fullscreen game
                        }
                    }
                }
            }
        }

        // Known game launchers/apps
        let gameApps = [
            "com.riotgames.LeagueofLegends",
            "com.blizzard.worldofwarcraft",
            "com.valvesoftware.steam",
            "com.epicgames.launcher"
        ]
        return gameApps.contains(bundleID)
    }

    private static func isSSHSession() -> Bool {
        // Check if Terminal is running SSH
        if isTerminal(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "") {
            // Check process list for SSH
            let task = Process()
            task.launchPath = "/bin/ps"
            task.arguments = ["aux"]

            let pipe = Pipe()
            task.standardOutput = pipe

            do {
                try task.run()
                task.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    return output.contains("ssh ") && !output.contains("ssh-agent")
                }
            } catch {
                return false
            }
        }
        return false
    }

    private static func isTerminal(_ bundleID: String) -> Bool {
        let terminalApps = [
            "com.apple.Terminal",
            "com.googlecode.iterm2",
            "net.kovidgoyal.kitty",
            "com.github.wez.wezterm",
            "io.alacritty"
        ]
        return terminalApps.contains(bundleID)
    }

    private static func isBrowser(_ bundleID: String) -> Bool {
        let browserApps = [
            "com.google.Chrome",
            "com.apple.Safari",
            "org.mozilla.firefox",
            "com.microsoft.edgemac",
            "com.brave.Browser"
        ]
        return browserApps.contains(bundleID)
    }

    // MARK: - IME State Check

    static func isIMEComposing() -> Bool {
        // Check if IME is in composition mode
        if let inputSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() {
            if let sourceID = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID) {
                let id = Unmanaged<CFString>.fromOpaque(sourceID).takeUnretainedValue() as String

                // Vietnamese IME IDs and other IMEs that use composition
                let composingIMEs = [
                    "com.apple.inputmethod.VietnameseIM",
                    "org.tuyenmai.openkey",
                    "com.trankynam.GoTiengViet",
                    "com.apple.inputmethod.TCIM",     // Chinese Traditional
                    "com.apple.inputmethod.SCIM",     // Chinese Simplified
                    "com.apple.inputmethod.Kotoeri",  // Japanese
                    "com.apple.inputmethod.Korean"    // Korean
                ]

                for imeID in composingIMEs {
                    if id.contains(imeID) {
                        // For IMEs that use composition, we can check if marked text exists
                        // This is a simple heuristic - return true when these IMEs are active
                        // to be safe and avoid interfering with composition
                        return true
                    }
                }
            }
        }
        return false
    }
}

// MARK: - Integration Extension
extension TextReplacementService {

    func shouldPerformExpansion() -> Bool {
        let category = EdgeCaseHandler.detectAppCategory()

        // Don't expand in password fields or games
        if category.shouldDisableExpansion {
            #if DEBUG
            print("[EdgeCase] Expansion disabled for: \(category)")
            #endif
            return false
        }

        // Don't expand if IME is composing
        if EdgeCaseHandler.isIMEComposing() {
            #if DEBUG
            print("[EdgeCase] IME is composing - skip expansion")
            #endif
            return false
        }

        return true
    }

    func getTimingForCurrentApp() -> (deletion: TimeInterval, paste: TimeInterval, useSimple: Bool) {
        let category = EdgeCaseHandler.detectAppCategory()

        #if DEBUG
        print("[EdgeCase] App category: \(category)")
        #endif

        return (
            deletion: category.deletionDelay,
            paste: category.pasteDelay,
            useSimple: category.useSimpleDeletion
        )
    }
}