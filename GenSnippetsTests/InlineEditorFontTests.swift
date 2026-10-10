import AppKit
import XCTest
@testable import GenSnippets

final class InlineEditorFontTests: XCTestCase {
  private func font(of attr: NSAttributedString, at index: Int = 0) -> NSFont? {
    attr.attribute(.font, at: index, effectiveRange: nil) as? NSFont
  }

  private func body(_ text: String) -> NSAttributedString {
    NSAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: InlineEditorFont.storedSize)])
  }

  func testStoredBodyTextIsShownLarger() {
    XCTAssertGreaterThan(InlineEditorFont.displaySize, InlineEditorFont.storedSize)
    XCTAssertEqual(font(of: InlineEditorFont.forDisplay(body("hello")))?.pointSize, InlineEditorFont.displaySize)
  }

  func testTextWithNoFontIsShownAsBodyText() {
    // Left alone, AppKit draws a font-less run in 12pt Helvetica — smaller than typed text.
    let shown = InlineEditorFont.forDisplay(NSAttributedString(string: "plain snippet"))
    XCTAssertEqual(font(of: shown)?.pointSize, InlineEditorFont.displaySize)
  }

  func testTypedTextIsStoredAtStoredSize() {
    let typed = NSAttributedString(string: "typed", attributes: [.font: InlineEditorFont.display])
    XCTAssertEqual(font(of: InlineEditorFont.forStorage(typed))?.pointSize, InlineEditorFont.storedSize)
  }

  func testBodyTextRoundTripsAtStoredSize() {
    let stored = InlineEditorFont.forStorage(InlineEditorFont.forDisplay(body("signature")))
    XCTAssertEqual(font(of: stored)?.pointSize, InlineEditorFont.storedSize)
    XCTAssertEqual(stored.string, "signature")
  }

  func testBoldBodyTextKeepsItsWeight() {
    let bold = NSAttributedString(string: "bold", attributes: [
      .font: NSFont.boldSystemFont(ofSize: InlineEditorFont.storedSize)
    ])
    let shown = font(of: InlineEditorFont.forDisplay(bold))
    XCTAssertEqual(shown?.pointSize, InlineEditorFont.displaySize)
    XCTAssertTrue(shown?.fontDescriptor.symbolicTraits.contains(.bold) ?? false)
  }

  func testStyledTextInAnotherFontOrSizeIsUntouched() throws {
    // Pasted styled text must expand exactly as it was pasted.
    let foreign: [NSFont] = [
      try XCTUnwrap(NSFont(name: "Helvetica", size: 18)),
      try XCTUnwrap(NSFont(name: "Georgia", size: InlineEditorFont.storedSize)),
      try XCTUnwrap(NSFont(name: "HelveticaNeue", size: 20)),
      NSFont.systemFont(ofSize: 20),
    ]
    for original in foreign {
      let pasted = NSAttributedString(string: "pasted", attributes: [.font: original])
      XCTAssertEqual(font(of: InlineEditorFont.forDisplay(pasted)), original, original.fontName)
      XCTAssertEqual(font(of: InlineEditorFont.forStorage(pasted)), original, original.fontName)
    }
  }

  func testOnlyBodyRunsOfAMixedDocumentChange() throws {
    let heading = try XCTUnwrap(NSFont(name: "Helvetica", size: 24))
    let doc = NSMutableAttributedString(attributedString: body("body "))
    doc.append(NSAttributedString(string: "heading", attributes: [.font: heading]))

    let shown = InlineEditorFont.forDisplay(doc)
    XCTAssertEqual(font(of: shown, at: 0)?.pointSize, InlineEditorFont.displaySize)
    XCTAssertEqual(font(of: shown, at: 5), heading)
  }

  func testBodyTextReadBackFromRTFDIsRecognised() throws {
    // Saved rich snippets are RTFD files, and RTF writes the system font as Helvetica Neue.
    // If that were not recognised, every saved snippet would still load at the old small size.
    let original = body("from disk")
    let data = try original.data(
      from: NSRange(location: 0, length: original.length),
      documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd])
    let loaded = try NSAttributedString(
      data: data,
      options: [.documentType: NSAttributedString.DocumentType.rtfd],
      documentAttributes: nil)

    let shown = InlineEditorFont.forDisplay(loaded)
    XCTAssertEqual(font(of: shown)?.pointSize, InlineEditorFont.displaySize)
    // And it goes back to disk as the same font it came from, so the expansion is unchanged.
    XCTAssertEqual(font(of: InlineEditorFont.forStorage(shown)), font(of: loaded))
  }
}
