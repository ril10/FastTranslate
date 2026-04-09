import SwiftUI

private enum Constants {
    // swiftlint:disable:next force_unwrapping
    static let ollamaURL = URL(string: "https://ollama.com")!
}

struct SettingsView: View {

    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @StateObject private var settingsVM = SettingsViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title bar
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            .padding()

            Divider()

            Form {
                // MARK: Ollama
                Section("Ollama") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Server URL")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        TextField("http://localhost:11434", text: $settings.ollamaURL)
                            .textFieldStyle(.roundedBorder)
                    }

                    HStack {
                        Text("Model")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Spacer()
                        if settingsVM.isLoadingModels {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 16, height: 16)
                        } else if settingsVM.models.isEmpty {
                            Text("No models found")
                                .foregroundStyle(.secondary)
                                .font(.system(size: 12))
                        } else {
                            Picker("", selection: $settings.selectedModel) {
                                ForEach(settingsVM.models, id: \.name) { model in
                                    Text(model.name).tag(model.name)
                                }
                            }
                            .labelsHidden()
                            .frame(maxWidth: 200)
                        }

                        Button {
                            settingsVM.refreshModels(url: settings.ollamaURL, settings: settings)
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.plain)
                        .help("Refresh models list")
                    }

                    if !settingsVM.connectionError.isEmpty {
                        Text(settingsVM.connectionError)
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                    }
                }

                // MARK: Default Languages
                Section("Default Languages") {
                    HStack {
                        Text("Source")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Picker("", selection: $settings.sourceLanguage) {
                            ForEach(Language.all) { lang in
                                Text("\(lang.flag) \(lang.name)").tag(lang)
                            }
                        }
                        .labelsHidden()
                        .fixedSize()
                    }

                    HStack {
                        Text("Target")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Picker("", selection: $settings.targetLanguage) {
                            ForEach(Language.targets) { lang in
                                Text("\(lang.flag) \(lang.name)").tag(lang)
                            }
                        }
                        .labelsHidden()
                        .fixedSize()
                    }
                }

                // MARK: General
                Section("General") {
                    Toggle("Launch at login", isOn: $settings.launchAtLogin)
                    Toggle("Inline translation (⌘⇧T)", isOn: $settings.inlineTranslation)
                }

                // MARK: About
                Section("About") {
                    LabeledContent("Version", value: "1.0.0 (MVP)")
                    LabeledContent("Requires", value: "Ollama running locally")

                    Link("Get Ollama →", destination: Constants.ollamaURL)
                        .font(.system(size: 12))
                }
            }
            .formStyle(.grouped)
            .padding(.horizontal, 4)
        }
        .frame(width: 420, height: 480)
        .onAppear {
            settingsVM.refreshModels(url: settings.ollamaURL, settings: settings)
        }
    }
}
