import SwiftUI

/// 文字构成逐层展开的树冠，下接分叉树干与向两侧伸展的树根。
struct TreeDiagramView: View {
    let poemLines: [PoemLine]
    let levelColors: [Color]
    var showsTrunk = true

    @ScaledMetric(relativeTo: .title3) private var textScale = 1

    var body: some View {
        GeometryReader { geometry in
            let layout = TreeDiagramLayout(
                viewport: geometry.size,
                poemLines: poemLines,
                textScale: textScale,
                showsTrunk: showsTrunk
            )

            ScrollView(.vertical) {
                TreeDiagramCanvas(poemLines: poemLines, levelColors: levelColors, layout: layout)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height, alignment: .center)
            }
            .accessibilityIdentifier(showsTrunk ? "treeDiagram" : "hundredChineseDiagram")
        }
        .background(Color.white.ignoresSafeArea())
    }
}

struct TreeDiagramLayout {
    let width: CGFloat
    let trunkHeight: CGFloat
    let rowHeight: CGFloat
    let fontSize: CGFloat
    let cellWidth: CGFloat
    let crownWidth: CGFloat

    init(viewport: CGSize, poemLines: [PoemLine], textScale: CGFloat, showsTrunk: Bool = true) {
        width = min(max(viewport.width - 32, 1), 520)
        let longestLine = max(poemLines.map { $0.text.count }.max() ?? 1, 1)
        trunkHeight = showsTrunk ? min(max(width * 0.34, 96), 136) : 0
        let availableRowHeight = (viewport.height - trunkHeight - 32)
            / CGFloat(max(poemLines.count, 1))
        rowHeight = min(max(availableRowHeight, 22), 30) * textScale
        fontSize = min(rowHeight * 0.82, 22 * textScale)
        cellWidth = min(fontSize + 3, (width - 12) / CGFloat(longestLine))
        crownWidth = cellWidth * CGFloat(longestLine) + 12
    }
}

struct TreeDiagramCanvas: View {
    let poemLines: [PoemLine]
    let levelColors: [Color]
    let layout: TreeDiagramLayout

    var body: some View {
        VStack(spacing: 0) {
            ForEach(poemLines) { line in
                NavigationLink {
                    LineDetailView(
                        lineIndex: line.lineIndex,
                        line: line.text,
                        pinyin: line.pinyin,
                        startingSequence: line.startingSequence
                    )
                } label: {
                    HStack(spacing: 0) {
                        ForEach(Array(line.text.enumerated()), id: \.offset) { _, character in
                            Text(String(character))
                                .font(.system(size: min(layout.fontSize, layout.cellWidth), weight: .bold, design: .serif))
                                .frame(width: layout.cellWidth)
                        }
                    }
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 6)
                    .frame(height: layout.rowHeight)
                    .background(color(for: line.text.count))
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(line.text)
                .accessibilityHint("查看诗句、单字图解和故事")
                .accessibilityIdentifier("treeDiagram.line.\(line.lineIndex)")
            }

            if layout.trunkHeight > 0 {
                TreeTrunkShape()
                    .fill(Color.black)
                    .frame(width: min(layout.crownWidth * 1.08, layout.width), height: layout.trunkHeight)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: layout.width)
    }

    private func color(for count: Int) -> Color {
        guard levelColors.indices.contains(count - 1) else { return .clear }
        return levelColors[count - 1]
    }
}

/// 使用归一化坐标绘制轮廓；顶端枝条承接文字树冠，树干向下加粗并伸出根须。
struct TreeTrunkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        // 主干和向左舒展的主枝。
        path.move(to: CGPoint(x: 0.35, y: 0.94))
        path.addCurve(to: CGPoint(x: 0.46, y: 0.84), control1: CGPoint(x: 0.43, y: 0.92), control2: CGPoint(x: 0.46, y: 0.91))
        path.addCurve(to: CGPoint(x: 0.43, y: 0.43), control1: CGPoint(x: 0.47, y: 0.70), control2: CGPoint(x: 0.47, y: 0.54))
        path.addCurve(to: CGPoint(x: 0.16, y: 0.16), control1: CGPoint(x: 0.38, y: 0.30), control2: CGPoint(x: 0.23, y: 0.26))
        for point in [
            CGPoint(x: 0.07, y: 0.13), CGPoint(x: 0.02, y: 0.05),
            CGPoint(x: 0.12, y: 0.11), CGPoint(x: 0.10, y: 0.00),
            CGPoint(x: 0.19, y: 0.13)
        ] {
            path.addLine(to: point)
        }
        path.addCurve(to: CGPoint(x: 0.47, y: 0.31), control1: CGPoint(x: 0.28, y: 0.22), control2: CGPoint(x: 0.38, y: 0.23))
        path.addCurve(to: CGPoint(x: 0.41, y: 0.12), control1: CGPoint(x: 0.46, y: 0.23), control2: CGPoint(x: 0.44, y: 0.18))
        for point in [
            CGPoint(x: 0.30, y: 0.03), CGPoint(x: 0.40, y: 0.08),
            CGPoint(x: 0.39, y: 0.00), CGPoint(x: 0.45, y: 0.12),
            CGPoint(x: 0.51, y: 0.27)
        ] {
            path.addLine(to: point)
        }
        // 右侧主枝与更细的分叉，避免树干成为一根直立的矩形。
        path.addCurve(to: CGPoint(x: 0.74, y: 0.12), control1: CGPoint(x: 0.59, y: 0.23), control2: CGPoint(x: 0.68, y: 0.21))
        for point in [
            CGPoint(x: 0.79, y: 0.00), CGPoint(x: 0.78, y: 0.13),
            CGPoint(x: 0.91, y: 0.06), CGPoint(x: 0.98, y: 0.00),
            CGPoint(x: 0.94, y: 0.11), CGPoint(x: 0.82, y: 0.20)
        ] {
            path.addLine(to: point)
        }
        path.addCurve(to: CGPoint(x: 0.56, y: 0.46), control1: CGPoint(x: 0.73, y: 0.30), control2: CGPoint(x: 0.61, y: 0.30))
        path.addCurve(to: CGPoint(x: 0.56, y: 0.85), control1: CGPoint(x: 0.53, y: 0.59), control2: CGPoint(x: 0.54, y: 0.76))
        path.addCurve(to: CGPoint(x: 0.68, y: 0.95), control1: CGPoint(x: 0.57, y: 0.92), control2: CGPoint(x: 0.60, y: 0.92))
        for point in [
            CGPoint(x: 0.89, y: 0.99), CGPoint(x: 0.65, y: 0.98),
            CGPoint(x: 0.54, y: 0.96), CGPoint(x: 0.44, y: 0.98),
            CGPoint(x: 0.11, y: 1.00), CGPoint(x: 0.27, y: 0.96)
        ] {
            path.addLine(to: point)
        }
        path.closeSubpath()

        return path.applying(CGAffineTransform(scaleX: rect.width, y: rect.height)
            .concatenating(CGAffineTransform(translationX: rect.minX, y: rect.minY)))
    }
}
