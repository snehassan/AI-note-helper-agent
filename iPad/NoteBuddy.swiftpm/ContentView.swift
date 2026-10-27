import SwiftUI

/// Built to live in a narrow Split View or Slide Over column beside Notes or Notability.
struct ContentView: View {
    @StateObject private var model = NotesModel()
    @State private var showSettings = APIKeyStore.keychainKey() == nil
    @State private var dropTargeted = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                notesArea

                HStack {
                    PasteButton(supportedContentTypes: NotesModel.acceptedTypes) { providers in
                        model.add(providers)
                    }
                    .buttonBorderShape(.capsule)
                    Spacer()
                    if !model.items.isEmpty {
                        Text("\(model.items.count) attached")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let notice = model.notice {
                    Text(notice).font(.caption).foregroundStyle(.red)
                }

                HStack {
                    TextField("Ask about your notes…", text: $model.question)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.send)
                        .onSubmit { model.submit() }
                    Button {
                        model.submit()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill").font(.title2)
                    }
                    .disabled(!model.canSubmit)
                }

                ScrollView {
                    Text(model.renderedAnswer)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if model.isStreaming && model.answer.isEmpty {
                        ProgressView().frame(maxWidth: .infinity)
                    }
                }
            }
            .padding()
            .navigationTitle("NoteBuddy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Clear") { model.clear() }
                        .disabled(model.items.isEmpty && model.answer.isEmpty && model.question.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
        }
        // Drop anywhere in the NoteBuddy column.
        .onDrop(of: NotesModel.acceptedTypes, isTargeted: $dropTargeted) { providers in
            model.add(providers)
            return true
        }
    }

    @ViewBuilder
    private var notesArea: some View {
        let outline = RoundedRectangle(cornerRadius: 12)
            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6]))
            .foregroundStyle(dropTargeted ? Color.accentColor : Color.secondary.opacity(0.5))

        if model.items.isEmpty {
            VStack(spacing: 6) {
                Image(systemName: "hand.draw").font(.largeTitle)
                Text("Drag handwriting, text, a screenshot, or a PDF here")
                    .multilineTextAlignment(.center)
                Text("or copy it and tap Paste")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 140)
            .background(outline)
        } else {
            ScrollView(.horizontal) {
                HStack {
                    ForEach(model.items) { item in
                        ItemThumbnail(item: item) { model.remove(item) }
                    }
                }
                .padding(8)
            }
            .background(outline)
        }
    }
}

struct ItemThumbnail: View {
    let item: NoteItem
    let onRemove: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            preview
                .frame(width: 100, height: 100)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color.white, Color.black.opacity(0.6))
            }
            .padding(4)
        }
    }

    @ViewBuilder
    private var preview: some View {
        switch item.kind {
        case .image(_, let thumbnail):
            Image(uiImage: thumbnail).resizable().scaledToFit()
        case .text(let text):
            Text(text)
                .font(.caption2)
                .padding(6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        case .pdf:
            VStack {
                Image(systemName: "doc.richtext").font(.title)
                Text("PDF").font(.caption)
            }
        }
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var keyInput = ""
    @State private var hasKey = APIKeyStore.keychainKey() != nil

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("sk-ant-…", text: $keyInput)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Save to Keychain") {
                        APIKeyStore.save(keyInput.trimmingCharacters(in: .whitespacesAndNewlines))
                        keyInput = ""
                        hasKey = APIKeyStore.keychainKey() != nil
                    }
                    .disabled(keyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if hasKey {
                        Button("Remove key", role: .destructive) {
                            APIKeyStore.delete()
                            hasKey = false
                        }
                    }
                } header: {
                    Text("Anthropic API key")
                } footer: {
                    Text(hasKey ? "A key is stored in this iPad's Keychain." : "No key set.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
