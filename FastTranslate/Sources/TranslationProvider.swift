import Foundation

protocol TranslationProvider {
    func translate(text: String, from source: Language, to target: Language) -> AsyncThrowingStream<String, Error>
}
