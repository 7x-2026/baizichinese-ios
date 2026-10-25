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

struct StoryTextDocument: Identifiable {
    let language: StoryAudioLanguage
    let url: URL

    var id: String { language.rawValue }
}

struct LineStory: Identifiable {
    let lineNumber: Int
    let title: String
    let tracks: [StoryAudioTrack]
    let texts: [StoryTextDocument]

    var id: String { "\(lineNumber)-\(title)" }
}

/// 从 line1-故事名(zh/en).m4a 自动生成故事列表。
/// 源文件统一放在 Resources/Stories/Line编号，音频与对应语言文本放在一起。
/// Xcode 可以平铺或保留资源目录，因此按文件名识别，不依赖打包后的目录层级。
struct StoryAudioLibrary {
    static let shared = StoryAudioLibrary(bundle: .main)

    /// 童谣在前，动物故事按照十二生肖顺序展示。
    private static let zodiacStoryTitles = [
        "十二生肖童谣", "老鼠的故事", "公牛的故事", "老虎的故事",
        "兔子的故事", "一条蓝龙", "蛇的故事", "马和老鼠的故事",
        "狼和小羊的故事", "猴子的故事", "公鸡的故事", "狗的故事",
        "白头神猪的故事"
    ]

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
        self.init(resourceURLs: urls)
    }

    init(resourceURLs: [URL]) {
        var tracksByLine: [Int: [String: [StoryAudioTrack]]] = [:]
        var textsByLine: [Int: [String: [StoryTextDocument]]] = [:]

        for url in resourceURLs.sorted(by: { $0.path < $1.path }) {
            let fileExtension = url.pathExtension.lowercased()
            guard fileExtension == "m4a" || fileExtension == "txt" else { continue }

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

            if fileExtension == "txt" {
                let existingTexts = textsByLine[lineNumber]?[title] ?? []
                guard !existingTexts.contains(where: { $0.language == language }) else { continue }

                textsByLine[lineNumber, default: [:]][title, default: []].append(
                    StoryTextDocument(language: language, url: url)
                )
            } else {
                // 同名资源即使重复出现，也只展示一条对应语言的播放器。
                let existingTracks = tracksByLine[lineNumber]?[title] ?? []
                guard !existingTracks.contains(where: { $0.language == language }) else { continue }

                tracksByLine[lineNumber, default: [:]][title, default: []].append(
                    StoryAudioTrack(language: language, url: url)
                )
            }
        }

        storiesByLine = Dictionary(uniqueKeysWithValues: tracksByLine.map { lineNumber, stories in
            let lineStories = stories.map { title, tracks in
                LineStory(
                    lineNumber: lineNumber,
                    title: title,
                    tracks: tracks.sorted { $0.language.sortOrder < $1.language.sortOrder },
                    texts: (textsByLine[lineNumber]?[title] ?? [])
                        .sorted { $0.language.sortOrder < $1.language.sortOrder }
                )
            }
            .sorted {
                if lineNumber == 23 || lineNumber == 24 {
                    let firstOrder = Self.zodiacStoryTitles.firstIndex(of: $0.title) ?? Int.max
                    let secondOrder = Self.zodiacStoryTitles.firstIndex(of: $1.title) ?? Int.max
                    if firstOrder != secondOrder {
                        return firstOrder < secondOrder
                    }
                }
                return $0.title.compare(
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
        // 生肖与地支两行共用 Line23 的文本和音频，避免重复打包。
        let resourceLine = lineIndex == 23 ? 23 : lineIndex + 1
        return storiesByLine[resourceLine] ?? []
    }
}
