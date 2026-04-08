import SwiftUI

struct TranslateView: View {

    @StateObject private var service = TranslationService()
    @StateObject private var settings = AppSettings.shared
    @State private var showSettings = false
    @State private var copied = false

    var body: some View {
        VStack(spacing: 0) {
            // MARK: Header
            header

            Divider()

            // MARK: Language picker
            languagePicker
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            Divider()

            // MARK: Input / Output
            translationArea
                .padding(12)

            Divider()

            // MARK: Footer
            footer
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
        }
        .frame(width: 380)
        .background(Color(NSColor.windowBackgroundColor))
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(settings)
                .onDisappear { service.updateClient() }
        }
        .onAppear {
            service.checkOllamaStatus()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "translate")
                .foregroundStyle(.secondary)
            Text("MenuTranslate")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gear")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Language Picker

    private var languagePicker: some View {
        HStack(spacing: 8) {
            // Source language
            Menu {
                ForEach(Language.all) { lang in
                    Button {
                        settings.sourceLanguage = lang
                    } label: {
                        Text("\(lang.flag) \(lang.name)")
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(settings.sourceLanguage.flag)
                    Text(settings.sourceLanguage.name)
                        .font(.system(size: 12))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            // Swap button
            Button {
                swapLanguages()
            } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .disabled(settings.sourceLanguage.code == "auto")
            .help("Swap languages")

            // Target language
            Menu {
                ForEach(Language.targets) { lang in
                    Button {
                        settings.targetLanguage = lang
                    } label: {
                        Text("\(lang.flag) \(lang.name)")
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(settings.targetLanguage.flag)
                    Text(settings.targetLanguage.name)
                        .font(.system(size: 12))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Spacer()

            // Translate button
            Button {
                service.translate()
            } label: {
                if service.isTranslating {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 12, height: 12)
                        Text("Stop")
                            .font(.system(size: 12, weight: .medium))
                    }
                } else {
                    Text("Translate")
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .onTapGesture {
                if service.isTranslating {
                    service.cancelTranslation()
                }
            }
            .keyboardShortcut(.return, modifiers: .command)
            .help("Translate (⌘↵)")
        }
    }

    // MARK: - Translation Area

    private var translationArea: some View {
        VStack(spacing: 8) {
            // Input
            ZStack(alignment: .topLeading) {
                TextEditor(text: $service.inputText)
                    .font(.system(size: 13))
                    .frame(height: 100)
                    .scrollContentBackground(.hidden)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                    )

                if service.inputText.isEmpty {
                    Text("Enter text to translate...")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
            }

            // Output
            ZStack(alignment: .topLeading) {
                ScrollView {
                    Text(service.outputText.isEmpty && service.errorMessage == nil
                         ? ""
                         : (service.errorMessage ?? service.outputText))
                        .font(.system(size: 13))
                        .foregroundStyle(service.errorMessage != nil ? .red : .primary)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .textSelection(.enabled)
                        .padding(4)
                }
                .frame(height: 100)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                )

                if service.outputText.isEmpty && service.errorMessage == nil && !service.isTranslating {
                    Text("Translation will appear here...")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                        .padding(.leading, 9)
                        .allowsHitTesting(false)
                }

                if service.isTranslating && service.outputText.isEmpty {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Translating...")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .allowsHitTesting(false)
                }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            // Status indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(service.isOllamaReachable ? Color.green : Color.red)
                    .frame(width: 6, height: 6)
                Text(service.isOllamaReachable
                     ? settings.selectedModel
                     : "Ollama not running")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Clear button
            if !service.inputText.isEmpty || !service.outputText.isEmpty {
                Button {
                    service.clearAll()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .help("Clear")
            }

            // Copy button
            if !service.outputText.isEmpty {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(service.outputText, forType: .string)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        copied = false
                    }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .foregroundStyle(copied ? .green : .secondary)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .help("Copy translation")
            }
        }
    }

    // MARK: - Helpers

    private func swapLanguages() {
        guard settings.sourceLanguage.code != "auto" else { return }
        let temp = settings.sourceLanguage
        settings.sourceLanguage = settings.targetLanguage
        settings.targetLanguage = temp
        // Swap text too if translation exists
        if !service.outputText.isEmpty {
            let tempText = service.inputText
            service.inputText = service.outputText
            service.outputText = tempText
        }
    }
}
