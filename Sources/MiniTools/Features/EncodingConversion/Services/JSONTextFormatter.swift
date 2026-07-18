import Foundation

enum JSONTextFormatter {
    static func format(_ text: String) throws -> String {
        try validate(text)
        return render(text, prettyPrinted: true)
    }

    static func minify(_ text: String) throws -> String {
        try validate(text)
        return render(text, prettyPrinted: false)
    }

    static func isJSONObjectOrArray(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.first == "{" || trimmed.first == "[" else { return false }
        return (try? validate(trimmed)) != nil
    }

    private static func validate(_ text: String) throws {
        guard let data = text.data(using: .utf8) else {
            throw MiniToolsError.invalidInput("文本无法转换为 UTF-8")
        }
        do {
            _ = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        } catch {
            throw MiniToolsError.invalidInput("当前文本不是有效的 JSON")
        }
    }

    private static func render(_ text: String, prettyPrinted: Bool) -> String {
        let characters = Array(text)
        var output = ""
        output.reserveCapacity(characters.count + (prettyPrinted ? characters.count / 4 : 0))
        var indentation = 0
        var isInsideString = false
        var isEscaped = false
        var previousSignificantCharacter: Character?

        for index in characters.indices {
            let character = characters[index]

            if isInsideString {
                output.append(character)
                if isEscaped {
                    isEscaped = false
                } else if character == "\\" {
                    isEscaped = true
                } else if character == "\"" {
                    isInsideString = false
                }
                continue
            }

            if character == "\"" {
                isInsideString = true
                output.append(character)
                previousSignificantCharacter = character
                continue
            }

            if character.isWhitespace {
                continue
            }

            switch character {
            case "{", "[":
                output.append(character)
                let matchingClose: Character = character == "{" ? "}" : "]"
                indentation += 1
                if prettyPrinted, nextSignificantCharacter(after: index, in: characters) != matchingClose {
                    appendNewline(to: &output, indentation: indentation)
                }

            case "}", "]":
                indentation = max(0, indentation - 1)
                if prettyPrinted,
                   previousSignificantCharacter != "{",
                   previousSignificantCharacter != "[" {
                    appendNewline(to: &output, indentation: indentation)
                }
                output.append(character)

            case ",":
                output.append(character)
                if prettyPrinted {
                    appendNewline(to: &output, indentation: indentation)
                }

            case ":":
                output.append(prettyPrinted ? ": " : ":")

            default:
                output.append(character)
            }
            previousSignificantCharacter = character
        }
        return output
    }

    private static func nextSignificantCharacter(
        after index: Int,
        in characters: [Character]
    ) -> Character? {
        guard index < characters.index(before: characters.endIndex) else { return nil }
        var nextIndex = characters.index(after: index)
        while nextIndex < characters.endIndex {
            let character = characters[nextIndex]
            if !character.isWhitespace { return character }
            nextIndex = characters.index(after: nextIndex)
        }
        return nil
    }

    private static func appendNewline(to output: inout String, indentation: Int) {
        output.append("\n")
        output.append(String(repeating: "  ", count: indentation))
    }
}
