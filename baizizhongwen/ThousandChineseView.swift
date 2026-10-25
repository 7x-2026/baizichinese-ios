import SwiftUI

struct ThousandChineseView: View {
    var body: some View {
        switch ThousandChineseDocument.bundled {
        case .success(let document):
            ThousandChineseReadingView(document: document)
        case .failure:
            ContentUnavailableView(
                "千字中文加载失败",
                systemImage: "doc.text",
                description: Text("请返回后重试")
            )
        }
    }
}

private struct ThousandChineseReadingView: View {
    let document: ThousandChineseDocument

    @State private var selectedSectionID = "overview"
    @State private var showsLegend = false
    @ScaledMetric(relativeTo: .title2) private var characterSize = 24
    @ScaledMetric(relativeTo: .title2) private var characterSpacing = 5

    private var selectedSection: ThousandChineseDocument.Section? {
        document.sections.first { $0.id == selectedSectionID }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("字图分类")
                        .font(.subheadline)
                    Spacer()
                    Picker("字图分类", selection: $selectedSectionID) {
                        ForEach(document.sections) { section in
                            Text(section.label).tag(section.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("thousandChinese.sectionPicker")
                }

                DisclosureGroup("颜色说明", isExpanded: $showsLegend) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(document.legend.enumerated()), id: \.offset) { index, explanation in
                            Text(explanation)
                                .foregroundStyle(legendColor(at: index))
                        }
                    }
                    .font(.footnote)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
                }
                .font(.subheadline)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            if let section = selectedSection {
                GeometryReader { geometry in
                    ScrollView([.horizontal, .vertical]) {
                        VStack(spacing: 16) {
                            Text(section.title)
                                .font(.headline)
                                .foregroundStyle(Color.black)
                                .padding(.bottom, 8)

                            ForEach(Array(section.lines.enumerated()), id: \.offset) { _, runs in
                                Text(attributedLine(runs))
                                    .font(.system(size: characterSize, design: .serif))
                                    .tracking(characterSpacing)
                                    .fixedSize()
                                    .textSelection(.enabled)
                                    .accessibilityLabel(runs.map(\.text).joined())
                            }
                        }
                        .padding(16)
                        .frame(minWidth: geometry.size.width)
                    }
                    .id(section.id)
                    .accessibilityIdentifier("thousandChinese.\(section.id)")
                }
            }
        }
        .background(Color.white)
        // 原稿的固定字色按白纸呈现，保持菜单与说明在深色模式下清晰可读。
        .environment(\.colorScheme, .light)
    }

    private func attributedLine(_ runs: [ThousandChineseDocument.Run]) -> AttributedString {
        runs.reduce(into: AttributedString()) { line, run in
            var text = AttributedString(run.text)
            text.foregroundColor = color(hex: run.color)
            line.append(text)
        }
    }

    private func legendColor(at index: Int) -> Color {
        let colors = ["#ff0000", "#000000", "#0070c0", "#00b050", "#948a54"]
        return color(hex: colors[min(index, colors.count - 1)])
    }

    private func color(hex: String) -> Color {
        let rgb = UInt32(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0
        return Color(
            .sRGB,
            red: Double((rgb >> 16) & 0xff) / 255,
            green: Double((rgb >> 8) & 0xff) / 255,
            blue: Double(rgb & 0xff) / 255,
            opacity: 1
        )
    }
}
