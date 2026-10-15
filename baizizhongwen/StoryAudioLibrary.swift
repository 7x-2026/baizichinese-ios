import Foundation

enum StoryAudioLanguage: String {
    case chinese = "zh"
    case english = "en"

    var title: String {
        switch self {
        case .chinese: return "中文"
        case .english: return "English"
        }
    }

    var sortOrder: Int {
        self == .chinese ? 0 : 1
    }
}

struct StoryAudioTrack: Identifiable {
    let language: StoryAudioLanguage
    let url: URL

    var id: String { url.lastPathComponent }
}

struct LineStory: Identifiable {
    let lineNumber: Int
    let title: String
    let tracks: [StoryAudioTrack]

    var id: String { "\(lineNumber)-\(title)" }
}

/// 从 line1-故事名(zh/en).m4a 自动生成故事列表。
/// Xcode 可以平铺或保留资源目录，因此按文件名识别，不依赖打包后的目录层级。
struct StoryAudioLibrary {
    static let shared = StoryAudioLibrary(bundle: .main)

    private let storiesByLine: [Int: [LineStory]]

    init(bundle: Bundle) {
        let enumerator = bundle.resourceURL.flatMap {
            FileManager.default.enumerator(
                at: $0,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
        }
        let urls = enumerator?.allObjects.compactMap { $0 as? URL } ?? []
        self.init(audioURLs: urls)
    }

    init(audioURLs: [URL]) {
        var tracksByLine: [Int: [String: [StoryAudioTrack]]] = [:]

        for url in audioURLs.sorted(by: { $0.path < $1.path }) {
            guard url.pathExtension.lowercased() == "m4a" else { continue }

            let name = url.deletingPathExtension().lastPathComponent
            guard name.hasPrefix("line"),
                  let separator = name.firstIndex(of: "-"),
                  let lineNumber = Int(name[name.index(name.startIndex, offsetBy: 4)..<separator]),
                  lineNumber > 0,
                  let language = StoryAudioLanguage(rawValue: String(name.suffix(4).dropFirst().dropLast())),
                  name.hasSuffix("(\(language.rawValue))")
            else { continue }

            let title = String(name[name.index(after: separator)...].dropLast(4))
            guard !title.isEmpty else { continue }

            // 同名资源即使重复出现，也只展示一条对应语言的播放器。
            let existingTracks = tracksByLine[lineNumber]?[title] ?? []
            guard !existingTracks.contains(where: { $0.language == language }) else { continue }

            tracksByLine[lineNumber, default: [:]][title, default: []].append(
                StoryAudioTrack(language: language, url: url)
            )
        }

        storiesByLine = Dictionary(uniqueKeysWithValues: tracksByLine.map { lineNumber, stories in
            let lineStories = stories.map { title, tracks in
                LineStory(
                    lineNumber: lineNumber,
                    title: title,
                    tracks: tracks.sorted { $0.language.sortOrder < $1.language.sortOrder }
                )
            }
            .sorted {
                $0.title.compare(
                    $1.title,
                    options: [.numeric],
                    locale: Locale(identifier: "zh_Hans_CN")
                ) == .orderedAscending
            }
            return (lineNumber, lineStories)
        })
    }

    /// 导航使用零基行号，素材文件夹和文件名使用一基行号。
    func stories(forLineIndex lineIndex: Int) -> [LineStory] {
        storiesByLine[lineIndex + 1] ?? []
    }
}
