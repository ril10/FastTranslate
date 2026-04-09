import Foundation

struct Language: Identifiable, Hashable {
    let id: String
    let code: String
    let name: String
    let flag: String

    static let auto = Language(id: "auto", code: "auto", name: "Auto-detect", flag: "🌐")
    static let english = Language(id: "en", code: "en", name: "English", flag: "🇬🇧")
    static let russian = Language(id: "ru", code: "ru", name: "Russian", flag: "🇷🇺")
    static let german = Language(id: "de", code: "de", name: "German", flag: "🇩🇪")
    static let french = Language(id: "fr", code: "fr", name: "French", flag: "🇫🇷")
    static let spanish = Language(id: "es", code: "es", name: "Spanish", flag: "🇪🇸")
    static let italian = Language(id: "it", code: "it", name: "Italian", flag: "🇮🇹")
    static let portuguese = Language(id: "pt", code: "pt", name: "Portuguese", flag: "🇵🇹")
    static let chinese = Language(id: "zh", code: "zh", name: "Chinese", flag: "🇨🇳")
    static let japanese = Language(id: "ja", code: "ja", name: "Japanese", flag: "🇯🇵")
    static let polish = Language(id: "pl", code: "pl", name: "Polish", flag: "🇵🇱")
    static let ukrainian = Language(id: "uk", code: "uk", name: "Ukrainian", flag: "🇺🇦")

    static let all: [Language] = [
        .auto, .english, .russian, .german, .french,
        .spanish, .italian, .portuguese, .chinese, .japanese,
        .polish, .ukrainian
    ]

    static let targets: [Language] = all.filter { $0.code != "auto" }
}
