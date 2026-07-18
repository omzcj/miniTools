import AppKit
import XCTest
@testable import MiniTools

final class ClipboardAndImageTests: XCTestCase {
    func testReadsOnlyFirstPasteboardItem() throws {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("MiniToolsTests.\(UUID().uuidString)"))
        pasteboard.clearContents()
        let first = NSPasteboardItem()
        first.setString("first", forType: .string)
        let second = NSPasteboardItem()
        second.setString("second", forType: .string)
        XCTAssertTrue(pasteboard.writeObjects([first, second]))

        guard case let .text(value) = try ClipboardService.readFirstItem(from: pasteboard) else {
            return XCTFail("Expected text")
        }
        XCTAssertEqual(value, "first")
    }

    func testQRCodeCanBeRecognized() throws {
        let value = "https://example.com/mini-tools"
        let data = try QRCodeService.generatePNGData(for: value)
        let analysis = try ImageRecognitionService.recognizeContents(in: data)
        XCTAssertEqual(analysis.qrPayload, value)
    }

    func testReadsImagePixelDimensionsFromClipboardData() throws {
        let data = try QRCodeService.generatePNGData(for: "dimensions")
        let dimensions = try ImageCodec.pixelDimensions(from: data)
        XCTAssertGreaterThan(dimensions.width, 0)
        XCTAssertEqual(dimensions.width, dimensions.height)
    }

    func testBuildsStructuredTextClipboardPreview() {
        let content = ClipboardContent.text("first\nsecond\tvalue")

        XCTAssertEqual(content.summary, "文本 · 18 字符 · 2 行")
        XCTAssertEqual(content.preview, "first ↵ second ⇥ value")
        XCTAssertNil(content.thumbnailData)
    }

    func testBuildsStructuredImageClipboardPreview() throws {
        let data = try QRCodeService.generatePNGData(for: "preview")
        let dimensions = try ImageCodec.pixelDimensions(from: data)
        let content = ClipboardContent.image(ClipboardImagePayload(
            data: data,
            sourceTypeIdentifier: "public.png",
            pixelWidth: dimensions.width,
            pixelHeight: dimensions.height
        ))

        XCTAssertTrue(content.summary.hasPrefix("PNG · \(dimensions.width) × \(dimensions.height) · "))
        XCTAssertEqual(content.preview, "")
        XCTAssertEqual(content.thumbnailData, data)
    }

    func testImageDataURLRoundTrip() throws {
        let imageData = try QRCodeService.generatePNGData(for: "data-url-round-trip")

        let encoded = try DataURLCodec.encodeImage(
            data: imageData,
            typeIdentifier: ImageCodec.pngTypeIdentifier
        )
        let decoded = try DataURLCodec.decodeImage(encoded)

        XCTAssertTrue(encoded.hasPrefix("data:image/png;base64,"))
        XCTAssertEqual(decoded.data, imageData)
        XCTAssertEqual(decoded.typeIdentifier, ImageCodec.pngTypeIdentifier)
        XCTAssertEqual(decoded.mimeType, "image/png")
        XCTAssertTrue(DataURLCodec.isDecodableImage(encoded))
        XCTAssertFalse(DataURLCodec.isDecodableImage("data:text/plain;base64,aGVsbG8="))
    }

    func testDataURLActionsConvertBetweenClipboardTypes() throws {
        let imageData = try QRCodeService.generatePNGData(for: "data-url-action")
        let dimensions = try ImageCodec.pixelDimensions(from: imageData)
        let payload = ClipboardImagePayload(
            data: imageData,
            sourceTypeIdentifier: ImageCodec.pngTypeIdentifier,
            pixelWidth: dimensions.width,
            pixelHeight: dimensions.height
        )
        let imageAction = try XCTUnwrap(
            ImageActionCatalog.sections(for: payload, compressionQuality: 0.7)
                .flatMap(\.actions)
                .first { $0.id == "image.data-url" }
        )
        guard case let .text(dataURL) = try imageAction.execute() else {
            return XCTFail("Expected Data URL text output")
        }

        let textSections = TextActionCatalog.sections(for: dataURL)
        XCTAssertEqual(textSections.first?.actions.first?.id, "data-url.image")
        let textAction = try XCTUnwrap(textSections.first?.actions.first)
        guard case let .image(decodedData, typeIdentifier) = try textAction.execute() else {
            return XCTFail("Expected image output")
        }
        XCTAssertEqual(decodedData, imageData)
        XCTAssertEqual(typeIdentifier, ImageCodec.pngTypeIdentifier)
    }

    @MainActor
    func testWritesTextToPasteboard() throws {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("MiniToolsTests.\(UUID().uuidString)"))
        try ClipboardService.write(.text("result"), to: pasteboard)
        XCTAssertEqual(pasteboard.string(forType: .string), "result")
    }
}
