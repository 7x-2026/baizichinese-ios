import SwiftUI

/// 已开放的展示页面；预留的九宫格单元不创建导航目标。
enum HomeDestination: String, Hashable {
    case riverDiagram = "河图字图"
    case treeDiagram = "百字树图"
    case luoshuDiagram = "洛书字图"
    case poem = "百字中文诗"
    case hundredChinese = "百字中文"
    case thousandChinese = "千字中文"
    case characterDiagrams = "百字图解"
    case spiralDiagram = "百字圆圈图"
    case undividedRiverDiagram = "河洛未分图"
}

private struct HomeGridItem {
    let title: String
    let displayTitle: String
    let destination: HomeDestination?
    let colors: [Color]

    private static let teal = Color(red: 0.16, green: 0.64, blue: 0.62)
    private static let mint = Color(red: 0.61, green: 0.83, blue: 0.70)
    private static let yellow = Color(red: 1, green: 0.91, blue: 0.38)
    private static let coral = Color(red: 0.97, green: 0.47, blue: 0.37)
    private static let cream = Color(red: 1, green: 0.98, blue: 0.86)

    /// 按从左到右、从上到下的顺序固定排列。
    static let all: [HomeGridItem] = [
        .init(title: "河图字图", displayTitle: "河图\n字图", destination: .riverDiagram,
              colors: [teal, mint]),
        .init(title: "百字树图", displayTitle: "百字\n树图", destination: .treeDiagram,
              colors: [Color(red: 0.65, green: 0.69, blue: 0.61), cream]),
        .init(title: "洛书字图", displayTitle: "洛书\n字图", destination: .luoshuDiagram,
              colors: [Color(red: 0.70, green: 0.74, blue: 0.67), .white]),
        .init(title: "百字中文诗", displayTitle: "百字\n中文诗", destination: .poem,
              colors: [mint, yellow.opacity(0.65)]),
        .init(title: "百字中文", displayTitle: "百字\n中文", destination: .hundredChinese,
              colors: [Color(red: 1, green: 0.88, blue: 0.22), yellow]),
        .init(title: "千字中文", displayTitle: "千字\n中文", destination: .thousandChinese,
              colors: [teal, yellow.opacity(0.7)]),
        .init(title: "百字图解", displayTitle: "百字\n图解", destination: .characterDiagrams,
              colors: [teal.opacity(0.8), coral]),
        .init(title: "百字圆圈图", displayTitle: "百字\n圆圈图", destination: .spiralDiagram,
              colors: [coral, yellow.opacity(0.8)]),
        .init(title: "河洛未分图", displayTitle: "河洛\n未分图", destination: .undividedRiverDiagram,
              colors: [yellow, coral.opacity(0.8)])
    ]
}

struct HomeGridView: View {
    private let paper = Color(red: 1, green: 0.985, blue: 0.93)

    var body: some View {
        GeometryReader { geometry in
            let side = min(max(geometry.size.width - 32, 0), 640)

            ScrollView(.vertical) {
                grid(side: side)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }
        }
        .background(paper.ignoresSafeArea())
        .toolbarBackground(paper, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private func grid(side: CGFloat) -> some View {
        Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            ForEach(0..<3) { row in
                GridRow {
                    ForEach(0..<3) { column in
                        let item = HomeGridItem.all[row * 3 + column]
                        Group {
                            if let destination = item.destination {
                                NavigationLink(value: destination) {
                                    tile(item, side: side / 3)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(item.title)
                            } else {
                                tile(item, side: side / 3)
                            }
                        }
                    }
                }
            }
        }
        .frame(width: side, height: side)
        .overlay {
            ThirdsGrid()
                .stroke(Color.black.opacity(0.8), lineWidth: 1.5)
                .overlay {
                    Rectangle().strokeBorder(Color.black.opacity(0.8), lineWidth: 2)
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private func tile(_ item: HomeGridItem, side: CGFloat) -> some View {
        Text(item.displayTitle)
            .font(.system(size: min(max(side * 0.23, 18), 42), weight: .medium, design: .serif))
            .foregroundStyle(Color.black)
            .multilineTextAlignment(.center)
            .lineSpacing(side * 0.07)
            .lineLimit(2)
            .minimumScaleFactor(0.7)
            .padding(8)
            .frame(width: side, height: side)
            .background {
                LinearGradient(colors: item.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                    .overlay {
                        ThirdsGrid()
                            .stroke(Color.black.opacity(0.18), style: StrokeStyle(lineWidth: 0.75, dash: [3, 3]))
                    }
            }
            .contentShape(Rectangle())
            .accessibilityLabel(item.title)
            .accessibilityIdentifier("homeTile.\(item.title)")
    }
}

/// 首页分格与每格内部的辅助虚线共用三等分坐标。
private struct ThirdsGrid: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            for index in 1...2 {
                let fraction = CGFloat(index) / 3
                let x = rect.minX + rect.width * fraction
                let y = rect.minY + rect.height * fraction
                path.move(to: CGPoint(x: x, y: rect.minY))
                path.addLine(to: CGPoint(x: x, y: rect.maxY))
                path.move(to: CGPoint(x: rect.minX, y: y))
                path.addLine(to: CGPoint(x: rect.maxX, y: y))
            }
        }
    }
}

#Preview {
    ContentView()
}
