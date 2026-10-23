import SwiftUI

/// 百字诗的两种文字版本共用一个展示页。
struct PoemView: View {
    private enum Version: String, CaseIterable, Identifiable {
        case regular = "楷书"
        case oracleBone = "甲骨文"

        var id: Self { self }
    }

    @State private var version: Version = .regular

    var body: some View {
        VStack(spacing: 0) {
            Picker("诗文版本", selection: $version) {
                ForEach(Version.allCases) { version in
                    Text(version.rawValue).tag(version)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            switch version {
            case .regular:
                RegularScriptPoemView()
            case .oracleBone:
                ContentUnavailableView("甲骨文版本待补充", systemImage: "text.book.closed")
            }
        }
        .background(Color(.systemBackground))
    }
}
