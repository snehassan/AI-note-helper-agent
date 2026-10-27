import SwiftUI
import UniformTypeIdentifiers

/// One piece of your notes, handed over by drag and drop or Paste.
struct NoteItem: Identifiable {
    enum Kind {
        case text(String)
        case image(jpeg: Data, thumbnail: UIImage)
        case pdf(Data)
    }

    let id = UUID()
    let kind: Kind
}

/// State for the session. Nothing is saved; Clear (or quitting) drops everything.
@MainActor
final class NotesModel: ObservableObject {
    /// PDF first, then image, then text: dragged handwriting often carries both an
    /// image and recognized text, and the image is what Claude should read.
    static let acceptedTypes: [UTType] = [.pdf, .image, .plainText, .text]

    @Published private(set) var items: [NoteItem] = []
    @Published var question = ""
    @Published private(set) var answer = ""
    @Published private(set) var isStreaming = false
    @Published private(set) var notice: String?

    private var task: Task<Void, Never>?

    var canSubmit: Bool {
        !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var renderedAnswer: AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: answer, options: options)) ?? AttributedString(answer)
    }

    // MARK: Adding notes

    func add(_ providers: [NSItemProvider]) {
        notice = nil
        for provider in providers {
            Self.load(provider) { [weak self] kind in
                guard let self else { return }
                if let kind {
                    self.items.append(NoteItem(kind: kind))
                } else {
                    self.notice = "Couldn't use one of those items."
                }
            }
        }
    }

    func remove(_ item: NoteItem) {
        items.removeAll { $0.id == item.id }
    }

    nonisolated private static func load(_ provider: NSItemProvider, completion: @escaping @MainActor (NoteItem.Kind?) -> Void) {
        let deliver: (NoteItem.Kind?) -> Void = { kind in
            Task { @MainActor in completion(kind) }
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
            _ = provider.loadDataRepresentation(forTypeIdentifier: UTType.pdf.identifier) { data, _ in
                deliver(data.map { .pdf($0) })
            }
        } else if provider.canLoadObject(ofClass: UIImage.self) {
            _ = provider.loadObject(ofClass: UIImage.self) { object, _ in
                deliver((object as? UIImage).flatMap(ImagePrep.prepare))
            }
        } else if provider.canLoadObject(ofClass: String.self) {
            _ = provider.loadObject(ofClass: String.self) { string, _ in
                guard let string, !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    return deliver(nil)
                }
                deliver(.text(string))
            }
        } else {
            deliver(nil)
        }
    }

    // MARK: Asking

    func submit() {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        task?.cancel()
        answer = ""
        notice = nil
        isStreaming = true

        let items = self.items
        task = Task { [weak self] in
            do {
                try await ClaudeClient.streamAnswer(question: trimmed, items: items) { chunk in
                    self?.answer += chunk
                }
            } catch {
                if !Task.isCancelled, let self {
                    self.answer += (self.answer.isEmpty ? "" : "\n\n") + "⚠️ " + error.localizedDescription
                }
            }
            if !Task.isCancelled { self?.isStreaming = false }
        }
    }

    func clear() {
        task?.cancel()
        task = nil
        items = []
        question = ""
        answer = ""
        notice = nil
        isStreaming = false
    }
}

/// Shrinks images to what Claude reads best and flattens them onto white,
/// since dragged handwriting is often transparent ink.
enum ImagePrep {
    static let maxSide: CGFloat = 1568

    static func prepare(_ image: UIImage) -> NoteItem.Kind? {
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        guard pixelWidth > 0, pixelHeight > 0 else { return nil }

        let scale = min(1, maxSide / max(pixelWidth, pixelHeight))
        let size = CGSize(width: (pixelWidth * scale).rounded(), height: (pixelHeight * scale).rounded())

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let flattened = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            image.draw(in: CGRect(origin: .zero, size: size))
        }

        guard let jpeg = flattened.jpegData(compressionQuality: 0.85) else { return nil }
        return .image(jpeg: jpeg, thumbnail: flattened)
    }
}
