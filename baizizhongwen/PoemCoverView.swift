import SwiftUI

/// 先展示书法全图，点击后进入带拼音的百字诗长文。
struct PoemCoverView: View {
    var body: some View {
        NavigationLink {
            PoemView()
                .navigationTitle("中文百字诗")
                .navigationBarTitleDisplayMode(.inline)
        } label: {
            VStack(spacing: 16) {
                Image("PoemCalligraphy")
                    .resizable()
                    .scaledToFit()
                    .layoutPriority(1)
                    .accessibilityHidden(true)

                Text("点击书法，阅读长文")
                    .font(.footnote)
                    .foregroundStyle(Color.gray)
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color.white.ignoresSafeArea())
        .accessibilityLabel("百字中文书法")
        .accessibilityHint("查看中文百字诗长文")
        .accessibilityIdentifier("poemCover.openText")
    }
}
