import XCTest
@testable import MiniTools

final class TextTransformsTests: XCTestCase {
    func testURLRoundTrip() throws {
        let input = "hello world/中文?x=1"
        let encoded = TextTransforms.urlEncode(input)
        XCTAssertEqual(encoded, "hello%20world%2F%E4%B8%AD%E6%96%87%3Fx%3D1")
        XCTAssertEqual(try TextTransforms.urlDecode(encoded), input)
        XCTAssertTrue(TextTransforms.isPercentEncoded(encoded))
    }

    func testBase64DetectionRequiresPrintableUTF8() throws {
        let encoded = TextTransforms.base64Encode("MiniTools 中文")
        XCTAssertTrue(TextTransforms.isDecodableBase64(encoded))
        XCTAssertEqual(try TextTransforms.base64Decode(encoded), "MiniTools 中文")
        XCTAssertFalse(TextTransforms.isDecodableBase64("plain text"))
    }

    func testJSONEscapeRoundTrip() throws {
        let input = "line 1\n\"line 2\""
        let escaped = try TextTransforms.jsonEscape(input)
        XCTAssertEqual(escaped, "line 1\\n\\\"line 2\\\"")
        XCTAssertTrue(TextTransforms.isJSONEscaped(escaped))
        XCTAssertEqual(try TextTransforms.jsonUnescape(escaped), input)
    }

    func testJSONUnescapePreservesUnquotedLeadingAndTrailingSpaces() throws {
        XCTAssertEqual(try TextTransforms.jsonUnescape("  hello  "), "  hello  ")
    }

    func testTimestampDetection() throws {
        XCTAssertNotNil(TextTransforms.detectedTimestampDate("1767225600"))
        XCTAssertNotNil(TextTransforms.detectedTimestampDate("1767225600000"))
        XCTAssertNil(TextTransforms.detectedTimestampDate("123"))
        XCTAssertNil(TextTransforms.detectedTimestampDate("9999999999"))
    }

    func testHashes() {
        XCTAssertEqual(TextTransforms.md5("hello"), "5d41402abc4b2a76b9719d911017c592")
        XCTAssertEqual(
            TextTransforms.sha256("hello"),
            "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
        )
    }

    func testJSONSortAndUniqueLines() throws {
        let sorted = try TextTransforms.sortJSON(#"{"z":1,"a":{"y":2,"b":3}}"#)
        XCTAssertLessThan(sorted.range(of: "\"a\"")!.lowerBound, sorted.range(of: "\"z\"")!.lowerBound)
        XCTAssertEqual(TextTransforms.sortUniqueLines("b\na\nb\n"), "a\nb")
    }

    func testJSONFormatAndMinifyPreserveKeyOrderAndValueSpelling() throws {
        let input = #"{"z":1e+2,"a":"x y","nested":[true,{"key":"value"}]}"#

        let formatted = try TextTransforms.formatJSON(input)

        XCTAssertLessThan(
            try XCTUnwrap(formatted.range(of: "\"z\"" )).lowerBound,
            try XCTUnwrap(formatted.range(of: "\"a\"" )).lowerBound
        )
        XCTAssertTrue(formatted.contains("1e+2"))
        XCTAssertTrue(formatted.contains("\"x y\""))
        XCTAssertEqual(try TextTransforms.minifyJSON(formatted), input)
        XCTAssertTrue(TextTransforms.isJSONObjectOrArray(input))
        XCTAssertFalse(TextTransforms.isJSONObjectOrArray(#""plain""#))
        XCTAssertThrowsError(try TextTransforms.formatJSON("{invalid}"))
        XCTAssertEqual(
            try TextTransforms.formatJSON(#"{"empty":{},"next":1}"#),
            "{\n  \"empty\": {},\n  \"next\": 1\n}"
        )
    }

    func testJWTDecodeParsesHeaderAndPayloadWithoutSignatureVerification() throws {
        let header = base64URL(#"{"alg":"HS256","typ":"JWT"}"#)
        let payload = base64URL(#"{"sub":"1234567890","admin":true}"#)
        let token = "\(header).\(payload).not-a-real-signature"

        XCTAssertTrue(JWTDecoder.isDecodable(token))
        let decoded = try JWTDecoder.decode(token)
        let data = try XCTUnwrap(decoded.data(using: .utf8))
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let decodedHeader = try XCTUnwrap(object["header"] as? [String: Any])
        let decodedPayload = try XCTUnwrap(object["payload"] as? [String: Any])
        XCTAssertEqual(decodedHeader["alg"] as? String, "HS256")
        XCTAssertEqual(decodedPayload["sub"] as? String, "1234567890")
        XCTAssertEqual(decodedPayload["admin"] as? Bool, true)
        XCTAssertFalse(JWTDecoder.isDecodable("not.a.jwt"))
    }

    func testRFC3339DateConvertsToSecondAndMillisecondTimestamps() throws {
        XCTAssertEqual(
            try TextTransforms.rfc3339TimestampSeconds("2026-01-01T00:00:00.123Z"),
            "1767225600"
        )
        XCTAssertEqual(
            try TextTransforms.rfc3339TimestampMilliseconds("2026-01-01T00:00:00.123Z"),
            "1767225600123"
        )
        XCTAssertEqual(
            try TextTransforms.rfc3339TimestampSeconds("2026-01-01T08:00:00+08:00"),
            "1767225600"
        )
        XCTAssertNil(TextTransforms.detectedRFC3339Date("2026-01-01 00:00:00"))
    }

    func testUniqueLinesCanPreserveFirstAppearanceOrder() {
        XCTAssertEqual(
            TextTransforms.uniqueLinesPreservingOrder("beta\r\nalpha\r\nbeta\r\n\r\nalpha\r\n"),
            "beta\nalpha\n"
        )
    }

    func testCatalogRecommendsStructuredTransformsWithoutDuplicatingThem() throws {
        let jsonSections = TextActionCatalog.sections(for: #"{"b":2,"a":1}"#)
        XCTAssertEqual(jsonSections.first?.id, "recommended")
        XCTAssertEqual(jsonSections.first?.actions.map(\.id), ["json.format"])
        XCTAssertEqual(
            jsonSections.flatMap(\.actions).filter { $0.id == "json.format" }.count,
            1
        )
        XCTAssertTrue(jsonSections.flatMap(\.actions).contains { $0.id == "json.minify" })

        let token = "\(base64URL(#"{"alg":"none"}"#)).\(base64URL(#"{"sub":"1"}"#)).signature"
        XCTAssertEqual(
            TextActionCatalog.sections(for: token).first?.actions.first?.id,
            "jwt.decode"
        )

        let dateRecommendations = try XCTUnwrap(
            TextActionCatalog.sections(for: "2026-01-01T00:00:00.123Z").first
        )
        XCTAssertEqual(
            dateRecommendations.actions.map(\.id),
            ["date.timestamp.seconds", "date.timestamp.milliseconds"]
        )
    }

    func testActionSearchMatchesMultipleTokensAndKeywords() {
        let action = ToolAction(
            id: "base64.decode",
            title: "Base64 Decode",
            subtitle: "检测到可解码的 UTF-8 Base64",
            systemImage: "text.badge.checkmark",
            isRecommended: true,
            searchKeywords: ["base64", "b64", "decode", "utf8"]
        ) { .text("result") }

        XCTAssertTrue(action.matches(searchQuery: "base64"))
        XCTAssertTrue(action.matches(searchQuery: "b64"))
        XCTAssertTrue(action.matches(searchQuery: "BASE64 decode"))
        XCTAssertTrue(action.matches(searchQuery: "UTF-8"))
        XCTAssertFalse(action.matches(searchQuery: "二维码"))
        XCTAssertTrue(action.matches(searchQuery: "   "))
    }

    func testActionSearchDoesNotMatchHiddenSymbolNames() {
        let action = ToolAction(
            id: "example",
            title: "Example",
            subtitle: "Visible description",
            systemImage: "qrcode",
            isRecommended: false
        ) { .text("result") }

        XCTAssertFalse(action.matches(searchQuery: "qrcode"))
    }

    private func base64URL(_ value: String) -> String {
        Data(value.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
