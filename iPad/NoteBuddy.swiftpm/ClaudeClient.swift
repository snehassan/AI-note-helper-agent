import Foundation
import Security

/// Streams answers from the Anthropic Messages API. Never logs notes, questions, or the key.
enum ClaudeClient {
    static let model = "claude-sonnet-5-5"
    static let systemPrompt = """
        You are a helper beside the user's notes. Answer using their notes when relevant. \
        If the answer comes from general knowledge rather than their notes, say so. Be concise.
        """
    /// The API rejects requests over 32 MB; base64 adds about a third.
    static let maxPDFBytes = 20_000_000

    static func streamAnswer(
        question: String,
        items: [NoteItem],
        onText: @MainActor (String) -> Void
    ) async throws {
        guard let apiKey = APIKeyStore.keychainKey() else { throw ClaudeError.missingKey }

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2026-10-21", forHTTPHeaderField: "anthropic-version")
        // If a safety classifier declines, the API retries on its recommended fallback model.
        request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": model,
            "max_tokens": 16000,
            "stream": true,
            "system": systemPrompt,
            "output_config": ["effort": "low"],
            "fallbacks": "default",
            "messages": [
                ["role": "user", "content": try content(question: question, items: items)]
            ],
        ] as [String: Any])

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            var body = ""
            for try await line in bytes.lines { body += line }
            throw ClaudeError.http(status, errorMessage(in: body))
        }

        // Server-sent events: we only need the `data:` lines.
        for try await line in bytes.lines {
            guard line.hasPrefix("data:"),
                  let event = try? JSONSerialization.jsonObject(with: Data(line.dropFirst(5).utf8)) as? [String: Any]
            else { continue }

            switch event["type"] as? String {
            case "content_block_delta":
                if let delta = event["delta"] as? [String: Any],
                   delta["type"] as? String == "text_delta",
                   let text = delta["text"] as? String {
                    await onText(text)
                }
            case "message_delta":
                if (event["delta"] as? [String: Any])?["stop_reason"] as? String == "refusal" {
                    throw ClaudeError.refusal
                }
            case "error":
                let message = (event["error"] as? [String: Any])?["message"] as? String
                throw ClaudeError.api(message ?? "Unknown error")
            default:
                continue
            }
        }
    }

    /// Images and PDFs first, then one text block with any typed notes and the question.
    private static func content(question: String, items: [NoteItem]) throws -> [[String: Any]] {
        var blocks: [[String: Any]] = []
        var typedNotes: [String] = []

        for item in items {
            switch item.kind {
            case .image(let jpeg, _):
                blocks.append([
                    "type": "image",
                    "source": ["type": "base64", "media_type": "image/jpeg", "data": jpeg.base64EncodedString()],
                ])
            case .pdf(let data):
                guard data.count <= maxPDFBytes else { throw ClaudeError.pdfTooLarge }
                blocks.append([
                    "type": "document",
                    "source": ["type": "base64", "media_type": "application/pdf", "data": data.base64EncodedString()],
                ])
            case .text(let text):
                typedNotes.append(text)
            }
        }

        var prompt = ""
        if !blocks.isEmpty {
            prompt += "The attachments above are from my notes. They are often handwritten.\n\n"
        }
        if !typedNotes.isEmpty {
            prompt += "<note>\n\(typedNotes.joined(separator: "\n\n"))\n</note>\n\n"
        }
        prompt += question
        blocks.append(["type": "text", "text": prompt])
        return blocks
    }

    private static func errorMessage(in body: String) -> String {
        guard let json = try? JSONSerialization.jsonObject(with: Data(body.utf8)) as? [String: Any],
              let message = (json["error"] as? [String: Any])?["message"] as? String
        else { return "Request failed" }
        return message
    }
}

enum ClaudeError: LocalizedError {
    case missingKey
    case pdfTooLarge
    case http(Int, String)
    case api(String)
    case refusal

    var errorDescription: String? {
        switch self {
        case .missingKey: return "No API key. Add one in Settings (gear icon)."
        case .pdfTooLarge: return "That PDF is too large. Try a screenshot of the page instead."
        case .http(let code, let message): return "API error \(code): \(message)"
        case .api(let message): return "API error: \(message)"
        case .refusal: return "Claude declined to answer this request."
        }
    }
}

/// The API key lives only in the Keychain on this device.
enum APIKeyStore {
    private static let baseQuery: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "NoteBuddy",
        kSecAttrAccount as String: "anthropic-api-key",
    ]

    static func keychainKey() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func save(_ key: String) -> Bool {
        delete()
        var query = baseQuery
        query[kSecValueData as String] = Data(key.utf8)
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    @discardableResult
    static func delete() -> Bool {
        let status = SecItemDelete(baseQuery as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
