import Foundation
import Combine

struct TranslationRecord: Identifiable {
    let id: UUID
    let sourceText: String
    let translatedText: String
    let sourceLanguage: Language
    let targetLanguage: Language
    let date: Date
    var isFavorite: Bool

    init(sourceText: String, translatedText: String, sourceLanguage: Language, targetLanguage: Language, isFavorite: Bool = false) {
        self.id = UUID()
        self.sourceText = sourceText
        self.translatedText = translatedText
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.date = Date()
        self.isFavorite = isFavorite
    }
}

@MainActor
final class HistoryService: ObservableObject {

    @Published private(set) var records: [TranslationRecord] = []

    func save(sourceText: String, translatedText: String, from source: Language, to target: Language) {
        let record = TranslationRecord(
            sourceText: sourceText,
            translatedText: translatedText,
            sourceLanguage: source,
            targetLanguage: target
        )
        records.insert(record, at: 0)
    }

    func toggleFavorite(_ record: TranslationRecord) {
        guard let index = records.firstIndex(where: { $0.id == record.id }) else { return }
        records[index].isFavorite.toggle()
    }

    func delete(_ record: TranslationRecord) {
        records.removeAll { $0.id == record.id }
    }

    func clearAll() {
        records.removeAll()
    }
}
