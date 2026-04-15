import Cocoa

struct ClipboardSnapshot {

    private let items: [[(NSPasteboard.PasteboardType, Data)]]

    @MainActor
    init(from pasteboard: NSPasteboard = .general) {
        items = pasteboard.pasteboardItems?.map { item in
            item.types.compactMap { type in
                guard let data = item.data(forType: type) else { return nil }
                return (type, data)
            }
        } ?? []
    }

    @MainActor
    func restore(to pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()
        for entries in items {
            let item = NSPasteboardItem()
            for (type, data) in entries {
                item.setData(data, forType: type)
            }
            pasteboard.writeObjects([item])
        }
    }
}
