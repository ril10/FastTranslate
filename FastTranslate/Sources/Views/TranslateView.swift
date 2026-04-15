import SwiftUI

struct TranslateView: View {

    @State private var viewModel: TranslationViewModel
    @Bindable var settings: AppSettings
    @State private var showSettings = false
    @State private var copied = false

    init(settings: AppSettings) {
        self.settings = settings
        let provider = OllamaProvider(baseURL: settings.ollamaURL, model: settings.selectedModel)
        _viewModel = State(initialValue: TranslationViewModel(provider: provider, settings: settings))
    }

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

            // MARK: Translation
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
            SettingsView(settings: settings)
                .onDisappear {
                    viewModel.send(.updateProvider(OllamaProvider(baseURL: settings.ollamaURL, model: settings.selectedModel)))
                }
        }
        .onAppear {
            viewModel.send(.checkOllamaStatus)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "translate")
                .foregroundStyle(.secondary)
            Text("FastTranslate")
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

            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Quit FastTranslate")
            .keyboardShortcut("q", modifiers: .command)
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

            // Status indicator
            translationStatus
        }
    }

    // MARK: - Translation Area

    private var translationArea: some View {
        VStack(spacing: 8) {
            // Input
            TextField("Enter text to translate...", text: $viewModel.inputText, axis: .vertical)
                .font(.system(size: 13))
                .lineLimit(5...10)
                .textFieldStyle(.plain)
                .padding(6)
                .frame(height: 100, alignment: .topLeading)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                )

            // Output
            ZStack(alignment: .topLeading) {
                ScrollView {
                    Text(viewModel.outputText.isEmpty && viewModel.errorMessage == nil
                         ? ""
                         : (viewModel.errorMessage ?? viewModel.outputText))
                        .font(.system(size: 13))
                        .foregroundStyle(viewModel.errorMessage != nil ? .red : .primary)
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

                if viewModel.outputText.isEmpty && viewModel.errorMessage == nil && !viewModel.isTranslating {
                    Text("Translation will appear here...")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                        .padding(.leading, 9)
                        .allowsHitTesting(false)
                }

                if viewModel.isTranslating && viewModel.outputText.isEmpty {
                    ProgressView()
                        .scaleEffect(0.8)
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
                    .fill(viewModel.isOllamaReachable ? Color.green : Color.red)
                    .frame(width: 6, height: 6)
                Text(viewModel.isOllamaReachable
                     ? settings.selectedModel
                     : "Ollama not running")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Clear button
            if !viewModel.inputText.isEmpty || !viewModel.outputText.isEmpty {
                Button {
                    viewModel.send(.clearAll)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .help("Clear")
            }

            // Copy button
            if !viewModel.outputText.isEmpty {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(viewModel.outputText, forType: .string)
                    copied = true
                    Task {
                        try? await Task.sleep(for: .seconds(1.5))
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

    // MARK: - Translation Status

    @ViewBuilder
    private var translationStatus: some View {
        switch viewModel.translationState {
        case .idle:
            EmptyView()
        case .translating:
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 12, height: 12)
                Text("Translating...")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        case .done:
            HStack(spacing: 3) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.green)
                Text("Done")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        case .error:
            HStack(spacing: 3) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                Text("Error")
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
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
        if !viewModel.outputText.isEmpty {
            viewModel.send(.swapTexts(newInput: viewModel.outputText, newOutput: viewModel.inputText))
        }
    }
}
