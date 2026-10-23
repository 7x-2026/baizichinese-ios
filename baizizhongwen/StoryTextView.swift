import SwiftUI

/// 二级菜单中的故事名进入此三级阅读页。
struct StoryTextView: View {
    let story: LineStory

    @State private var selectedLanguage: StoryAudioLanguage

    init(story: LineStory) {
        self.story = story
        _selectedLanguage = State(initialValue: story.texts.first?.language ?? .chinese)
    }

    var body: some View {
        VStack(spacing: 0) {
            if story.texts.count > 1 {
                Picker("故事语言", selection: $selectedLanguage) {
                    ForEach(story.texts) { document in
                        Text(document.language.title)
                            .tag(document.language)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
            }

            if let document = story.texts.first(where: { $0.language == selectedLanguage }) {
                StoryDocumentView(document: document)
                    // 切换语言时从新文本的开头阅读。
                    .id(document.id)
            } else {
                ContentUnavailableView(
                    "暂无故事文本",
                    systemImage: "doc.text",
                    description: Text("该故事的文本暂未收录")
                )
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle(story.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct StoryDocumentView: View {
    let document: StoryTextDocument

    @State private var text: String?
    @State private var loadFailed = false

    var body: some View {
        Group {
            if let text {
                ScrollView {
                    Text(text)
                        .font(.system(.title3, design: .serif))
                        .lineSpacing(8)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                }
            } else if loadFailed {
                ContentUnavailableView(
                    "故事文本加载失败",
                    systemImage: "doc.text",
                    description: Text("请返回后重试")
                )
            } else {
                ProgressView("正在加载故事…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            do {
                let content = try String(contentsOf: document.url, encoding: .utf8)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if content.isEmpty {
                    loadFailed = true
                } else {
                    text = content
                }
            } catch {
                loadFailed = true
            }
        }
    }
}
