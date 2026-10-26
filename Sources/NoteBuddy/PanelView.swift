import SwiftUI

/// State for one panel session. Everything is cleared when the panel closes.
@MainActor
final class PanelModel: ObservableObject {
    @Published var question = ""
    @Published private(set) var answer = ""
    @Published private(set) var status = ""
    @Published private(set) var openCount = 0

    var onClose: (() -> Void)?

    private var noteText: String?
    private var appName: String?
    private var task: Task<Void, Never>?

    func open(with capture: NoteCapture) {
        task?.cancel()
        question = ""
        answer = ""
        switch capture {
        case .notes(let text, let app):
            noteText = text
            appName = app
            status = "Using \(text.count.formatted()) characters from \(app)"
        case .unreadable:
            noteText = nil
            appName = nil
            status = "Can't read this app"
        case .paused:
            noteText = nil
            appName = nil
            status = "Reading paused: only your question is sent"
        }
        openCount += 1
    }

    func close() {
        task?.cancel()
        task = nil
        noteText = nil
        appName = nil
        question = ""
        answer = ""
    }

    func submit() {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        task?.cancel()
        answer = ""

        let notes = noteText
        let app = appName
        task = Task { [weak self] in
            do {
                try await ClaudeClient.streamAnswer(question: trimmed, notes: notes, appName: app) { chunk in
                    self?.answer += chunk
                }
            } catch {
                guard !Task.isCancelled, let self else { return }
                self.answer += (self.answer.isEmpty ? "" : "\n\n") + "⚠️ " + error.localizedDescription
            }
        }
    }
}

struct PanelView: View {
    @ObservedObject var model: PanelModel
    @FocusState private var questionFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.status)
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Ask about your note…", text: $model.question)
                .textFieldStyle(.roundedBorder)
                .focused($questionFocused)
                .onSubmit { model.submit() }

            ScrollView {
                Text(renderedAnswer)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .padding(.top, 8)
        .frame(width: 420, height: 280)
        .onAppear { questionFocused = true }
        .onChange(of: model.openCount) { _ in questionFocused = true }
        .onExitCommand { model.onClose?() }
    }

    private var renderedAnswer: AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: model.answer, options: options)) ?? AttributedString(model.answer)
    }
}

// MARK: - Settings

struct SettingsView: View {
    @State private var keyInput = ""
    @State private var status = SettingsView.currentStatus()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Anthropic API key").font(.headline)
            SecureField("sk-ant-…", text: $keyInput)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("Save to Keychain") {
                    APIKeyStore.save(keyInput.trimmingCharacters(in: .whitespacesAndNewlines))
                    keyInput = ""
                    status = Self.currentStatus()
                }
                .disabled(keyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Remove") {
                    APIKeyStore.delete()
                    status = Self.currentStatus()
                }
            }
            Text(status)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 380)
    }

    private static func currentStatus() -> String {
        if APIKeyStore.keychainKey() != nil { return "Using the key stored in Keychain." }
        if APIKeyStore.environmentKey() != nil { return "Using ANTHROPIC_API_KEY from the environment." }
        return "No key set."
    }
}
