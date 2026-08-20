import AppKit
import Foundation

/// Pure state machine behind `ClipboardPasteCoordinator`. Keeping ownership decisions separate from
/// NSPasteboard makes lease serialization and deferred-paste rules deterministic and unit-testable.
struct ClipboardLeaseState {
  struct Lease: Equatable {
    let generation: UInt64
  }

  struct Completion: Equatable {
    let shouldRestoreOriginal: Bool
    let deferredPasteCount: Int
  }

  private(set) var activeLease: Lease?
  private(set) var expectedChangeCount: Int?
  private(set) var deferredPasteCount = 0
  private var nextGeneration: UInt64 = 0

  var canBegin: Bool { activeLease == nil }

  mutating func begin() -> Lease {
    precondition(activeLease == nil, "Clipboard leases must be serialized")
    nextGeneration &+= 1
    let lease = Lease(generation: nextGeneration)
    activeLease = lease
    expectedChangeCount = nil
    return lease
  }

  @discardableResult
  mutating func recordWrite(changeCount: Int, for lease: Lease) -> Bool {
    guard activeLease == lease else { return false }
    expectedChangeCount = changeCount
    return true
  }

  mutating func deferUserPaste() -> Bool {
    guard activeLease != nil else { return false }
    deferredPasteCount += 1
    return true
  }

  mutating func complete(lease: Lease, observedChangeCount: Int) -> Completion? {
    guard activeLease == lease, let expectedChangeCount else { return nil }
    let completion = Completion(
      shouldRestoreOriginal: observedChangeCount == expectedChangeCount,
      deferredPasteCount: deferredPasteCount
    )
    activeLease = nil
    self.expectedChangeCount = nil
    deferredPasteCount = 0
    return completion
  }

  mutating func cancel(lease: Lease) -> Completion? {
    guard activeLease == lease else { return nil }
    let completion = Completion(
      shouldRestoreOriginal: false,
      deferredPasteCount: deferredPasteCount
    )
    activeLease = nil
    expectedChangeCount = nil
    deferredPasteCount = 0
    return completion
  }
}

/// Owns the temporary use of `NSPasteboard.general` while GenSnippets posts synthetic paste events.
/// Expansions are serialized so each one snapshots the latest user-owned clipboard, and physical Cmd+V
/// presses are replayed only after that snapshot has been restored (or a newer user Copy wins the guard).
final class ClipboardPasteCoordinator {
  struct Lease {
    fileprivate let stateLease: ClipboardLeaseState.Lease
    let originalClipboardString: String?
  }

  static let shared = ClipboardPasteCoordinator()

  /// Marks paste events created by GenSnippets so the event tap never mistakes them for a real Cmd+V.
  private static let syntheticEventMarker: Int64 = 0x47454E53 // "GENS"

  private let condition = NSCondition()
  private var state = ClipboardLeaseState()
  private var originalBackup: RichContentService.PasteboardBackup?
  private var originalClipboardString: String?
  private var isCapturing = false
  private var isRestoring = false

  private init() {}

  func beginLease() -> Lease {
    condition.lock()
    while !state.canBegin || isCapturing || isRestoring {
      condition.wait()
    }
    isCapturing = true
    let stateLease = state.begin()
    condition.unlock()

    // Full pasteboard reads can synchronously ask another app to provide lazy/promised data. Keep
    // that I/O outside the condition used by the event tap. The lease is already active, so a
    // physical Cmd+V during capture is deferred: target apps consume posted paste events
    // asynchronously and could otherwise read the snippet after capture finishes and overwrites it.
    let snapshot = captureStablePasteboardSnapshot()

    condition.lock()
    originalClipboardString = snapshot.string
    originalBackup = snapshot.backup
    isCapturing = false
    condition.broadcast()
    let lease = Lease(
      stateLease: stateLease,
      originalClipboardString: originalClipboardString
    )
    condition.unlock()
    return lease
  }

  private func captureStablePasteboardSnapshot() -> (
    string: String?,
    backup: RichContentService.PasteboardBackup
  ) {
    let pasteboard = NSPasteboard.general
    var latestString: String?
    var latestBackup = RichContentService.PasteboardBackup()

    // Clipboard managers can write while a snapshot is being materialized. Retry a bounded number
    // of times so the string used by {clipboard} and the full-item backup describe one generation.
    for _ in 0..<3 {
      let before = pasteboard.changeCount
      latestString = pasteboard.string(forType: .string)
      latestBackup = RichContentService.shared.backupPasteboard()
      if pasteboard.changeCount == before {
        break
      }
    }
    return (latestString, latestBackup)
  }

  func recordWrite(changeCount: Int, for lease: Lease) {
    condition.lock()
    state.recordWrite(changeCount: changeCount, for: lease.stateLease)
    condition.unlock()
  }

  /// Called on the event-tap thread. This only mutates in-memory state; pasteboard I/O and replay happen
  /// later, so the tap remains comfortably below macOS's timeout threshold.
  func deferPhysicalPasteIfNeeded() -> Bool {
    condition.lock()
    let shouldDefer = state.deferUserPaste()
    condition.unlock()
    return shouldDefer
  }

  func restoreIfCurrent(_ lease: Lease, completion: (() -> Void)? = nil) {
    finish(lease, completion: completion)
  }

  func restoreNow(_ lease: Lease, completion: (() -> Void)? = nil) {
    finish(lease, completion: completion)
  }

  private func finish(_ lease: Lease, completion: (() -> Void)?) {
    condition.lock()
    guard state.activeLease == lease.stateLease else {
      condition.unlock()
      DispatchQueue.main.async { completion?() }
      return
    }

    guard state.expectedChangeCount != nil else {
      let result = state.cancel(lease: lease.stateLease)
      originalBackup = nil
      originalClipboardString = nil
      isRestoring = (result?.deferredPasteCount ?? 0) > 0
      if !isRestoring {
        condition.broadcast()
      }
      condition.unlock()
      DispatchQueue.main.async {
        self.replayDeferredPastes(count: result?.deferredPasteCount ?? 0)
        completion?()
      }
      scheduleReplayProtectionRelease(deferredPasteCount: result?.deferredPasteCount ?? 0)
      return
    }

    isRestoring = true
    let backup = originalBackup
    let originalString = originalClipboardString
    let expectedChangeCount = state.expectedChangeCount!
    condition.unlock()

    let observedChangeCount = NSPasteboard.general.changeCount
    if observedChangeCount == expectedChangeCount, let backup {
      RichContentService.shared.restorePasteboardIfUnchanged(
        backup,
        expectedChangeCount: expectedChangeCount,
        previousClipboardString: originalString
      )
    }

    condition.lock()
    guard let result = state.complete(
      lease: lease.stateLease,
      observedChangeCount: observedChangeCount
    ) else {
      isRestoring = false
      condition.broadcast()
      condition.unlock()
      DispatchQueue.main.async { completion?() }
      return
    }
    originalBackup = nil
    originalClipboardString = nil
    if result.deferredPasteCount == 0 {
      isRestoring = false
      condition.broadcast()
    }
    condition.unlock()

    DispatchQueue.main.async {
      self.replayDeferredPastes(count: result.deferredPasteCount)
      completion?()
    }
    scheduleReplayProtectionRelease(deferredPasteCount: result.deferredPasteCount)
  }

  private func scheduleReplayProtectionRelease(deferredPasteCount: Int) {
    guard deferredPasteCount > 0 else { return }
    let delay = 0.6 + (Double(deferredPasteCount - 1) * 0.03)
    DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + delay) {
      self.condition.lock()
      self.isRestoring = false
      self.condition.broadcast()
      self.condition.unlock()
    }
  }

  static func markAsSynthetic(_ event: CGEvent) {
    event.setIntegerValueField(.eventSourceUserData, value: syntheticEventMarker)
  }

  static func isSynthetic(_ event: CGEvent) -> Bool {
    event.getIntegerValueField(.eventSourceUserData) == syntheticEventMarker
  }

  private func replayDeferredPastes(count: Int) {
    guard count > 0 else { return }
    for index in 0..<count {
      DispatchQueue.main.asyncAfter(deadline: .now() + (Double(index) * 0.03)) {
        Self.postSyntheticPaste()
      }
    }
  }

  static func postSyntheticPaste(interEventDelay: TimeInterval = 0.002) {
    guard let source = CGEventSource(stateID: .hidSystemState),
          let commandDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true),
          let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true),
          let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false),
          let commandUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false) else {
      return
    }

    let events = [commandDown, vDown, vUp, commandUp]
    events.forEach(markAsSynthetic)
    commandDown.flags = [.maskCommand, .maskNonCoalesced]
    vDown.flags = [.maskCommand, .maskNonCoalesced]
    vUp.flags = [.maskCommand, .maskNonCoalesced]
    commandUp.flags = .maskNonCoalesced

    for event in events {
      event.post(tap: .cghidEventTap)
      Thread.sleep(forTimeInterval: interEventDelay)
    }
  }
}
