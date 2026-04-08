import SwiftUI
import Combine

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
                    LabeledContent("Server URL") {
                        TextField("http://localhost:11434", text: $settings.ollamaURL)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 220)
                    }

                    LabeledContent("Model") {
                        HStack {
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
                                .frame(width: 220)
                            }

                            Button {
                                settingsVM.refreshModels(url: settings.ollamaURL)
                            } label: {
                                Image(systemName: "arrow.clockwise")
                            }
                            .buttonStyle(.plain)
                            .help("Refresh models list")
                        }
                    }

                    if !settingsVM.connectionError.isEmpty {
                        Text(settingsVM.connectionError)
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                    }
                }

                // MARK: Default Languages
                Section("Default Languages") {
                    LabeledContent("Source") {
                        Picker("", selection: $settings.sourceLanguage) {
                            ForEach(Language.all) { lang in
                                Text("\(lang.flag) \(lang.name)").tag(lang)
                            }
                        }
                        .frame(width: 180)
                    }

                    LabeledContent("Target") {
                        Picker("", selection: $settings.targetLanguage) {
                            ForEach(Language.targets) { lang in
                                Text("\(lang.flag) \(lang.name)").tag(lang)
                            }
                        }
                        .frame(width: 180)
                    }
                }

                // MARK: About
                Section("About") {
                    LabeledContent("Version", value: "1.0.0 (MVP)")
                    LabeledContent("Requires", value: "Ollama running locally")

                    Link("Get Ollama →", destination: URL(string: "https://ollama.com")!)
                        .font(.system(size: 12))
                }
            }
            .formStyle(.grouped)
            .padding(.horizontal, 4)
        }
        .frame(width: 420, height: 420)
        .onAppear {
            settingsVM.refreshModels(url: settings.ollamaURL)
        }
    }
}

// MARK: - ViewModel

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var models: [OllamaModel] = []
    @Published var isLoadingModels = false
    @Published var connectionError = ""

    func refreshModels(url: String) {
        isLoadingModels = true
        connectionError = ""

        Task {
            let client = OllamaClient(baseURL: url)
            do {
                let fetched = try await client.fetchModels()
                models = fetched
            } catch let error as OllamaError {
                connectionError = error.localizedDescription
                models = []
            } catch {
                connectionError = "Cannot connect to Ollama"
                models = []
            }
            isLoadingModels = false
        }
    }
}
