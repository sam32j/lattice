import AppKit

enum MediaHUDPayload {
    static func urls(from board: NSPasteboard) -> [URL]? {
        guard !board.canReadObject(forClasses: [NSFilePromiseReceiver.self], options: nil),
              let urls = board.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
              !urls.isEmpty, urls.count >= (board.pasteboardItems?.count ?? 0),
              !MediaOutputFormat.choices(for: urls).isEmpty else { return nil }
        return urls
    }
}
