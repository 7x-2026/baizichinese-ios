import Foundation

/// 保存原稿逐行的文字和局部字色，不将重复出现的字词合并。
struct ThousandChineseDocument: Decodable {
    struct Run: Decodable {
        let text: String
        let color: String
    }

    struct Section: Decodable, Identifiable {
        let id: String
        let label: String
        let title: String
        let lines: [[Run]]
    }

    let sections: [Section]
    let legend: [String]

    static let bundled: Result<ThousandChineseDocument, Error> = Result {
        try load(bundle: .main)
    }

    static func load(bundle: Bundle) throws -> ThousandChineseDocument {
        guard let url = bundle.url(forResource: "thousand-chinese", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
    }
}
