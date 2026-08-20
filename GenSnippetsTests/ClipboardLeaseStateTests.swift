import CoreGraphics
import XCTest
@testable import GenSnippets

final class ClipboardLeaseStateTests: XCTestCase {
  func testSyntheticPasteMarkerRoundTripsOnCGEvent() throws {
    let event = try XCTUnwrap(
      CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: true)
    )

    XCTAssertFalse(ClipboardPasteCoordinator.isSynthetic(event))
    ClipboardPasteCoordinator.markAsSynthetic(event)
    XCTAssertTrue(ClipboardPasteCoordinator.isSynthetic(event))
  }

  func testPhysicalPasteWhenIdlePassesThrough() {
    var state = ClipboardLeaseState()

    XCTAssertFalse(state.deferUserPaste())
    XCTAssertEqual(state.deferredPasteCount, 0)
  }

  func testPhysicalPasteDuringLeaseIsDeferredAndReplayedAfterRestore() {
    var state = ClipboardLeaseState()
    let lease = state.begin()
    state.recordWrite(changeCount: 10, for: lease)

    XCTAssertTrue(state.deferUserPaste())
    let completion = state.complete(lease: lease, observedChangeCount: 10)

    XCTAssertEqual(
      completion,
      .init(shouldRestoreOriginal: true, deferredPasteCount: 1)
    )
  }

  func testPhysicalPasteDuringCapturePhaseIsPreservedUntilLeaseCompletes() {
    var state = ClipboardLeaseState()
    let lease = state.begin()

    // Capture happens after begin but before the coordinator records its pasteboard write.
    XCTAssertTrue(state.deferUserPaste())
    state.recordWrite(changeCount: 15, for: lease)

    XCTAssertEqual(
      state.complete(lease: lease, observedChangeCount: 15),
      .init(shouldRestoreOriginal: true, deferredPasteCount: 1)
    )
  }

  func testMultiplePhysicalPastesAreCounted() {
    var state = ClipboardLeaseState()
    let lease = state.begin()
    state.recordWrite(changeCount: 20, for: lease)

    XCTAssertTrue(state.deferUserPaste())
    XCTAssertTrue(state.deferUserPaste())

    XCTAssertEqual(
      state.complete(lease: lease, observedChangeCount: 20)?.deferredPasteCount,
      2
    )
  }

  func testLeaseMustCompleteBeforeNextLeaseCanBegin() {
    var state = ClipboardLeaseState()
    let first = state.begin()
    state.recordWrite(changeCount: 30, for: first)

    XCTAssertFalse(state.canBegin)
    XCTAssertEqual(
      state.complete(lease: first, observedChangeCount: 30),
      .init(shouldRestoreOriginal: true, deferredPasteCount: 0)
    )
    XCTAssertTrue(state.canBegin)

    let second = state.begin()
    XCTAssertNotEqual(first, second)
    XCTAssertFalse(state.canBegin)
  }

  func testExternalCopyPreventsOldClipboardRestore() {
    var state = ClipboardLeaseState()
    let first = state.begin()
    state.recordWrite(changeCount: 40, for: first)
    XCTAssertTrue(state.deferUserPaste())

    XCTAssertEqual(
      state.complete(lease: first, observedChangeCount: 41),
      .init(shouldRestoreOriginal: false, deferredPasteCount: 1)
    )

    // A following expansion is a fresh serialized lease, so its coordinator capture uses
    // the externally copied clipboard instead of reusing the first lease's old snapshot.
    XCTAssertTrue(state.canBegin)
    let second = state.begin()
    XCTAssertNotEqual(first, second)
  }

  func testCancelBeforeWriteEndsLeaseAndPreservesDeferredPaste() {
    var state = ClipboardLeaseState()
    let lease = state.begin()
    XCTAssertTrue(state.deferUserPaste())

    XCTAssertEqual(
      state.cancel(lease: lease),
      .init(shouldRestoreOriginal: false, deferredPasteCount: 1)
    )
    XCTAssertNil(state.activeLease)
    XCTAssertTrue(state.canBegin)
  }
}
