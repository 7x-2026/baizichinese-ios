//
//  DiagramViews.swift
//  baizizhongwen
//
//  河图使用静态图片配合透明点击热点；洛书继续使用逻辑坐标矢量绘制。
//  两种页面共享诗句导航信息，但各自使用符合显示方式的数据模型，
//  避免图片页面携带无效的颜色、连线等矢量属性。
//

import SwiftUI

// MARK: - 河图图片热点数据

/// 河图图片中一个可以点击的汉字。
///
/// `position` 直接采用原始 1254 × 1254 图片的像素坐标。页面缩放图片时，
/// 会用相同比例缩放该坐标，因此点击区域始终与图片上的汉字圆圈重合。
private struct RiverHotspot: Identifiable {
    let id: String
    let character: Character
    let position: CGPoint
}

/// 河图中属于同一句诗的一组点击热点。
///
/// 组内任意汉字都导航到同一个 `LineDetailView`。例如上下两排艺术字虽然
/// 在图片上分开排列，仍共享“礼乐射御书数琴棋诗画”的二级页面。
private struct RiverHotspotGroup: Identifiable {
    let id: String
    let poemLine: PoemLine
    let hotspots: [RiverHotspot]
}

// MARK: - 洛书矢量图数据

private struct DiagramNode: Identifiable {
    enum Style {
        case light
        case dark
    }

    let id: String
    let character: Character
    let position: CGPoint
    let style: Style
}

private struct DiagramConnection: Identifiable {
    let id: String
    let fromNodeIndex: Int
    let toNodeIndex: Int
}

private struct DiagramGroup: Identifiable {
    let id: String
    let poemLine: PoemLine
    let nodes: [DiagramNode]
    let connections: [DiagramConnection]
}

// MARK: - 河图未分图数据

/// 河图未分图中的一条长方形横行。
///
/// 左侧诗句由 1 字逐行增加到 12 字，右侧诗句则由 12 字逐行减少到 1 字；
/// 两侧字数之和恒为 13，因此十二行可以使用完全相同的总宽度。
private struct UndividedDiagramRow: Identifiable {
    let leftCharacterCount: Int
    let leftLine: PoemLine
    let rightLine: PoemLine

    var id: Int {
        leftCharacterCount
    }
}

private enum DiagramData {
    /// 建立河图的图片点击热点。
    ///
    /// 坐标以资源 `RiverDiagram` 的原始 1254 × 1254 像素尺寸为基准；
    /// 此处只保存导航真正需要的字符与位置，不再生成矢量图使用的样式或连线。
    static func riverGroups(from poemLines: [PoemLine]) -> [RiverHotspotGroup] {
        [
            makeRiverGroup(
                id: "river-tools",
                text: "刀匕斤矢弓戈矛",
                positions: [
                    CGPoint(x: 340, y: 192), CGPoint(x: 430, y: 148),
                    CGPoint(x: 519, y: 122), CGPoint(x: 617, y: 122),
                    CGPoint(x: 709, y: 133), CGPoint(x: 800, y: 144),
                    CGPoint(x: 890, y: 175)
                ],
                poemLines: poemLines
            ),
            makeRiverGroup(
                id: "river-yinyang",
                text: "阴阳",
                positions: [
                    CGPoint(x: 600, y: 308), CGPoint(x: 684, y: 308)
                ],
                poemLines: poemLines
            ),
            makeRiverGroup(
                id: "river-people",
                text: "天地人",
                positions: [
                    CGPoint(x: 212, y: 505), CGPoint(x: 211, y: 604),
                    CGPoint(x: 211, y: 709)
                ],
                poemLines: poemLines
            ),
            makeRiverGroup(
                id: "river-directions",
                text: "东南西北",
                positions: [
                    CGPoint(x: 952, y: 505), CGPoint(x: 982, y: 612),
                    CGPoint(x: 990, y: 735), CGPoint(x: 989, y: 834)
                ],
                poemLines: poemLines
            ),
            makeRiverGroup(
                id: "river-elements",
                text: "木火土金水",
                positions: [
                    CGPoint(x: 543, y: 636), CGPoint(x: 623, y: 549),
                    CGPoint(x: 623, y: 636), CGPoint(x: 701, y: 636),
                    CGPoint(x: 623, y: 730)
                ],
                poemLines: poemLines
            ),
            makeRiverGroup(
                id: "river-animals",
                text: "草植虫鱼鸟兽",
                positions: [
                    CGPoint(x: 374, y: 1_091), CGPoint(x: 471, y: 1_127),
                    CGPoint(x: 563, y: 1_139), CGPoint(x: 650, y: 1_140),
                    CGPoint(x: 742, y: 1_106), CGPoint(x: 843, y: 1_033)
                ],
                poemLines: poemLines
            ),
            makeRiverGroup(
                id: "river-weather",
                text: "云川电雨雷风山谷",
                positions: [
                    CGPoint(x: 117, y: 376), CGPoint(x: 92, y: 445),
                    CGPoint(x: 77, y: 522), CGPoint(x: 71, y: 600),
                    CGPoint(x: 74, y: 691), CGPoint(x: 98, y: 777),
                    CGPoint(x: 129, y: 859), CGPoint(x: 172, y: 940)
                ],
                poemLines: poemLines
            ),
            makeRiverGroup(
                id: "river-daily-life",
                text: "衣食居行皿用鼎市井",
                positions: [
                    CGPoint(x: 1_087, y: 326), CGPoint(x: 1_129, y: 409),
                    CGPoint(x: 1_152, y: 489), CGPoint(x: 1_167, y: 577),
                    CGPoint(x: 1_167, y: 665), CGPoint(x: 1_151, y: 757),
                    CGPoint(x: 1_127, y: 841), CGPoint(x: 1_098, y: 927),
                    CGPoint(x: 1_046, y: 1_001)
                ],
                poemLines: poemLines
            ),
            makeRiverGroup(
                id: "river-arts",
                text: "礼乐射御书数琴棋诗画",
                positions: [
                    CGPoint(x: 466, y: 440), CGPoint(x: 550, y: 440),
                    CGPoint(x: 622, y: 440), CGPoint(x: 696, y: 440),
                    CGPoint(x: 770, y: 440), CGPoint(x: 458, y: 855),
                    CGPoint(x: 544, y: 855), CGPoint(x: 620, y: 855),
                    CGPoint(x: 696, y: 855), CGPoint(x: 768, y: 855)
                ],
                poemLines: poemLines
            ),
            makeRiverGroup(
                id: "river-origin",
                text: "元",
                positions: [CGPoint(x: 628, y: 1_008)],
                poemLines: poemLines
            )
        ].compactMap { $0 }
    }

    static func luoshuGroups(from poemLines: [PoemLine]) -> [DiagramGroup] {
        [
            makeGroup(
                id: "luoshu-family",
                text: "祖父母兄弟姐妹子孙",
                positions: [
                    CGPoint(x: 185, y: 75), CGPoint(x: 265, y: 75),
                    CGPoint(x: 345, y: 75), CGPoint(x: 425, y: 75),
                    CGPoint(x: 505, y: 75), CGPoint(x: 585, y: 75),
                    CGPoint(x: 665, y: 75), CGPoint(x: 745, y: 75),
                    CGPoint(x: 825, y: 75)
                ],
                style: .light,
                connections: sequentialConnections(count: 9),
                poemLines: poemLines
            ),
            makeGroup(
                id: "luoshu-directions",
                text: "东南西北",
                positions: [
                    CGPoint(x: 105, y: 200), CGPoint(x: 175, y: 145),
                    CGPoint(x: 235, y: 215), CGPoint(x: 165, y: 275)
                ],
                style: .dark,
                connections: closedConnections(count: 4),
                poemLines: poemLines
            ),
            makeGroup(
                id: "luoshu-yinyang",
                text: "阴阳",
                positions: [
                    CGPoint(x: 840, y: 205), CGPoint(x: 905, y: 140)
                ],
                style: .dark,
                connections: sequentialConnections(count: 2),
                poemLines: poemLines
            ),
            makeGroup(
                id: "luoshu-emotions",
                text: "喜怒哀惧爱恶欲",
                positions: [
                    CGPoint(x: 900, y: 320), CGPoint(x: 900, y: 390),
                    CGPoint(x: 900, y: 460), CGPoint(x: 900, y: 530),
                    CGPoint(x: 900, y: 600), CGPoint(x: 900, y: 670),
                    CGPoint(x: 900, y: 740)
                ],
                style: .light,
                connections: sequentialConnections(count: 7),
                poemLines: poemLines
            ),
            makeGroup(
                id: "luoshu-people",
                text: "天地人",
                positions: [
                    CGPoint(x: 115, y: 440), CGPoint(x: 115, y: 525),
                    CGPoint(x: 115, y: 610)
                ],
                style: .light,
                connections: sequentialConnections(count: 3),
                poemLines: poemLines
            ),
            makeGroup(
                id: "luoshu-elements",
                text: "木火土金水",
                positions: [
                    CGPoint(x: 390, y: 520), CGPoint(x: 500, y: 390),
                    CGPoint(x: 500, y: 520), CGPoint(x: 610, y: 520),
                    CGPoint(x: 500, y: 650)
                ],
                style: .light,
                connections: crossConnections,
                poemLines: poemLines
            ),
            makeGroup(
                id: "luoshu-weather",
                text: "云川电雨雷风山谷",
                positions: [
                    CGPoint(x: 70, y: 890), CGPoint(x: 150, y: 970),
                    CGPoint(x: 160, y: 830), CGPoint(x: 240, y: 910),
                    CGPoint(x: 250, y: 770), CGPoint(x: 330, y: 850),
                    CGPoint(x: 340, y: 710), CGPoint(x: 420, y: 790)
                ],
                style: .dark,
                connections: weatherConnections,
                poemLines: poemLines
            ),
            makeGroup(
                id: "luoshu-animals",
                text: "草植虫鱼鸟兽",
                positions: [
                    CGPoint(x: 680, y: 810), CGPoint(x: 750, y: 740),
                    CGPoint(x: 800, y: 820), CGPoint(x: 850, y: 900),
                    CGPoint(x: 780, y: 970), CGPoint(x: 730, y: 890)
                ],
                style: .dark,
                connections: animalConnections,
                poemLines: poemLines
            ),
            makeGroup(
                id: "luoshu-origin",
                text: "元",
                positions: [CGPoint(x: 500, y: 930)],
                style: .light,
                poemLines: poemLines
            )
        ].compactMap { $0 }
    }

    /// 使用正文中每种字数的两句诗生成河图未分图。
    ///
    /// 同一字数下，正文中较早出现的一句属于左侧黑色三角形，较晚出现的一句
    /// 属于右侧红色三角形。右侧按字数倒序取值，最终得到：
    /// `1 + 12`、`2 + 11`……`12 + 1` 的十二行结构。
    static func undividedRows(from poemLines: [PoemLine]) -> [UndividedDiagramRow] {
        let linesByCharacterCount = Dictionary(
            grouping: poemLines,
            by: { $0.text.count }
        )

        // 当前正文应当在 1...12 的每一种字数下都恰好包含两句。
        // 先完整验证数据，避免正文日后调整时静默生成缺行或错误配对。
        for characterCount in 1...12 {
            guard linesByCharacterCount[characterCount]?.count == 2 else {
                assertionFailure(
                    "Undivided diagram requires two poem lines with \(characterCount) characters"
                )
                return []
            }
        }

        return (1...12).compactMap { leftCharacterCount in
            let rightCharacterCount = 13 - leftCharacterCount

            guard
                let leftPair = linesByCharacterCount[leftCharacterCount]?
                    .sorted(by: { $0.lineIndex < $1.lineIndex }),
                let rightPair = linesByCharacterCount[rightCharacterCount]?
                    .sorted(by: { $0.lineIndex < $1.lineIndex }),
                let leftLine = leftPair.first,
                let rightLine = rightPair.last
            else {
                assertionFailure("Unable to build undivided diagram row")
                return nil
            }

            return UndividedDiagramRow(
                leftCharacterCount: leftCharacterCount,
                leftLine: leftLine,
                rightLine: rightLine
            )
        }
    }

    private static let crossConnections = [
        DiagramConnection(id: "0-2", fromNodeIndex: 0, toNodeIndex: 2),
        DiagramConnection(id: "1-2", fromNodeIndex: 1, toNodeIndex: 2),
        DiagramConnection(id: "2-3", fromNodeIndex: 2, toNodeIndex: 3),
        DiagramConnection(id: "2-4", fromNodeIndex: 2, toNodeIndex: 4)
    ]

    private static let weatherConnections = [
        // 两条平行斜线：云-电-雷-山，川-雨-风-谷。
        connection(0, 2), connection(2, 4), connection(4, 6),
        connection(1, 3), connection(3, 5), connection(5, 7),
        // 将上下两条斜线的对应节点连接。
        connection(0, 1), connection(2, 3), connection(6, 7)
    ]

    private static let animalConnections = [
        // 两条等距平行线：草-兽-鸟、植-虫-鱼。
        connection(0, 5), connection(5, 4),
        connection(1, 2), connection(2, 3),
        // 三条等长平行线：草-植、兽-虫、鸟-鱼。
        connection(0, 1), connection(5, 2), connection(4, 3)
    ]

    /// 把一行诗和图片坐标组合成河图热点组。
    ///
    /// 诗句缺失或字符数与坐标数不一致时，在 Debug 构建中立即报告，避免出现
    /// 点击汉字进入错误诗句、或热点数量与图片内容不一致的问题。
    private static func makeRiverGroup(
        id: String,
        text: String,
        positions: [CGPoint],
        poemLines: [PoemLine]
    ) -> RiverHotspotGroup? {
        guard let poemLine = poemLines.first(where: { $0.text == text }) else {
            assertionFailure("River diagram text is missing from poem data: \(text)")
            return nil
        }

        let characters = Array(text)

        guard characters.count == positions.count else {
            assertionFailure("River hotspot count does not match: \(text)")
            return nil
        }

        let hotspots = zip(characters, positions).enumerated().map { index, pair in
            RiverHotspot(
                id: "\(id)-\(index)",
                character: pair.0,
                position: pair.1
            )
        }

        return RiverHotspotGroup(
            id: id,
            poemLine: poemLine,
            hotspots: hotspots
        )
    }

    /// 建立洛书的矢量节点组。洛书需要节点颜色与节点间连线，因而继续使用
    /// `DiagramNode`、`DiagramConnection` 和 `DiagramGroup`。
    private static func makeGroup(
        id: String,
        text: String,
        positions: [CGPoint],
        style: DiagramNode.Style,
        connections: [DiagramConnection] = [],
        poemLines: [PoemLine]
    ) -> DiagramGroup? {
        guard let poemLine = poemLines.first(where: { $0.text == text }) else {
            assertionFailure("Diagram text is missing from poem data: \(text)")
            return nil
        }

        let characters = Array(text)

        guard characters.count == positions.count else {
            assertionFailure("Diagram position count does not match: \(text)")
            return nil
        }

        let nodes = zip(characters, positions).enumerated().map { index, pair in
            DiagramNode(
                id: "\(id)-\(index)",
                character: pair.0,
                position: pair.1,
                style: style
            )
        }

        return DiagramGroup(
            id: id,
            poemLine: poemLine,
            nodes: nodes,
            connections: connections
        )
    }

    private static func connection(_ from: Int, _ to: Int) -> DiagramConnection {
        DiagramConnection(
            id: "\(from)-\(to)",
            fromNodeIndex: from,
            toNodeIndex: to
        )
    }

    private static func sequentialConnections(count: Int) -> [DiagramConnection] {
        sequentialConnections(indices: Array(0..<count))
    }

    private static func sequentialConnections(indices: [Int]) -> [DiagramConnection] {
        guard indices.count > 1 else {
            return []
        }

        return zip(indices, indices.dropFirst()).map { connection($0, $1) }
    }

    private static func closedConnections(count: Int) -> [DiagramConnection] {
        sequentialConnections(count: count) + [connection(count - 1, 0)]
    }
}

// MARK: - 页面

struct RiverDiagramView: View {
    let poemLines: [PoemLine]

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical) {
                // 外层容器至少与页面可用高度相同，使河图在内容较矮时
                // 垂直居中；图形本身的尺寸、比例和点击热点保持不变。
                VStack {
                    RiverImageCanvas(groups: DiagramData.riverGroups(from: poemLines))
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 12)
                }
                .frame(
                    maxWidth: .infinity,
                    minHeight: geometry.size.height,
                    alignment: .center
                )
            }
        }
        .background(Color(.systemBackground))
    }
}

struct LuoshuDiagramView: View {
    let poemLines: [PoemLine]

    var body: some View {
        DiagramPage(
            logicalSize: CGSize(width: 1_000, height: 1_060),
            groups: DiagramData.luoshuGroups(from: poemLines)
        )
    }
}

/// “河图未分图”一级页面。
///
/// 页面不复刻参考草图中的圆圈，而是把每个圆圈直接替换成一个等宽汉字单元。
/// 黑色文字逐行增多、红色文字逐行减少，两组共同填满一个 13 × 12 的长方形。
struct UndividedRiverDiagramView: View {
    let poemLines: [PoemLine]

    /// 字间距压缩到 1 点，黑红两组的分界只保留 4 点。字位宽度再根据页面
    /// 实际宽度动态计算，使十三个字可以在一页内完整显示并继续保持列对齐。
    private let preferredCharacterCellWidth: CGFloat = 30
    private let characterSpacing: CGFloat = 1
    private let groupSpacing: CGFloat = 4
    private let horizontalPadding: CGFloat = 8
    private let rowHeight: CGFloat = 40
    private let characterFontSize: CGFloat = 22

    private var rows: [UndividedDiagramRow] {
        DiagramData.undividedRows(from: poemLines)
    }

    var body: some View {
        GeometryReader { geometry in
            let characterCellWidth = fittedCharacterCellWidth(
                for: geometry.size.width
            )

            ScrollView(.vertical) {
                VStack {
                    diagramRows(characterCellWidth: characterCellWidth)
                        .padding(.horizontal, horizontalPadding)
                }
                .frame(
                    maxWidth: .infinity,
                    minHeight: geometry.size.height,
                    alignment: .center
                )
            }
        }
        // 黑色文字在深色模式下也必须保持参考图中的视觉含义。
        .background(Color.white)
    }

    private func diagramRows(characterCellWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(rows) { row in
                HStack(spacing: groupSpacing) {
                    poemLineLink(
                        row.leftLine,
                        color: .black,
                        characterCellWidth: characterCellWidth
                    )
                    poemLineLink(
                        row.rightLine,
                        color: .red,
                        characterCellWidth: characterCellWidth
                    )
                }
                .frame(height: rowHeight)
            }
        }
        // 采用十三个字位的自然宽度，不允许父视图压缩其中任何一行。
        .fixedSize(horizontal: true, vertical: true)
        .padding(.vertical, 16)
    }

    /// 一句诗对应一个整体点击区域；字与字之间的透明间隙也属于该句。
    /// 这里刻意不为单字建立按钮，避免同一句诗出现多个重复导航链接。
    private func poemLineLink(
        _ poemLine: PoemLine,
        color: Color,
        characterCellWidth: CGFloat
    ) -> some View {
        NavigationLink {
            LineDetailView(
                lineIndex: poemLine.lineIndex,
                line: poemLine.text,
                pinyin: poemLine.pinyin,
                startingSequence: poemLine.startingSequence
            )
        } label: {
            HStack(spacing: characterSpacing) {
                ForEach(Array(poemLine.text.enumerated()), id: \.offset) { _, character in
                    Text(String(character))
                        .font(
                            .system(
                                size: characterFontSize,
                                weight: .semibold,
                                design: .serif
                            )
                        )
                        .foregroundStyle(color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .frame(width: characterCellWidth, height: rowHeight)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(poemLine.text)，进入二级页面")
    }

    /// 每行共有十三个字位、十一个普通字间距和一个黑红分界间距。
    /// 先扣除页面边距与间距，再把剩余宽度平均分配给十三个字位；大屏上
    /// 最高使用首选宽度，避免内容被无意义地拉宽。
    private func fittedCharacterCellWidth(for pageWidth: CGFloat) -> CGFloat {
        let availableWidth = pageWidth - horizontalPadding * 2
        let totalSpacing = characterSpacing * 11 + groupSpacing
        let fittedWidth = (availableWidth - totalSpacing) / 13

        return min(preferredCharacterCellWidth, max(20, fittedWidth))
    }
}

private struct RiverImageCanvas: View {
    /// 必须与 `RiverDiagram.imageset` 中图片的实际像素尺寸一致。
    /// 所有热点坐标都以此尺寸标定。
    private let logicalSize = CGSize(width: 1_254, height: 1_254)
    let groups: [RiverHotspotGroup]

    var body: some View {
        GeometryReader { geometry in
            // 图片为正方形且以 `.scaledToFit()` 显示，因此宽度缩放比例也就是
            // x、y 坐标的统一缩放比例，不会发生热点纵横方向不一致的问题。
            let scale = geometry.size.width / logicalSize.width

            // 72 像素接近原图中文字圆圈直径；小屏幕上保留至少 32 点，
            // 使点击区域仍然易用，同时圆形区域之间不会覆盖大片空白。
            let tapDiameter = max(72 * scale, 32)

            ZStack {
                Image("RiverDiagram")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .allowsHitTesting(false)

                ForEach(groups) { group in
                    ForEach(group.hotspots) { hotspot in
                        NavigationLink {
                            LineDetailView(
                                lineIndex: group.poemLine.lineIndex,
                                line: group.poemLine.text,
                                pinyin: group.poemLine.pinyin,
                                startingSequence: group.poemLine.startingSequence
                            )
                        } label: {
                            Circle()
                                .fill(Color.white.opacity(0.001))
                                .frame(width: tapDiameter, height: tapDiameter)
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .position(scaled(hotspot.position, by: scale))
                        .accessibilityLabel(
                            "\(String(hotspot.character))，进入\(group.poemLine.text)"
                        )
                    }
                }
            }
        }
        .aspectRatio(logicalSize.width / logicalSize.height, contentMode: .fit)
    }

    private func scaled(_ point: CGPoint, by scale: CGFloat) -> CGPoint {
        CGPoint(x: point.x * scale, y: point.y * scale)
    }
}

private struct DiagramPage: View {
    let logicalSize: CGSize
    let groups: [DiagramGroup]

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical) {
                // 洛书沿用原矢量画布，只由这一层负责在剩余屏幕中居中。
                // 当画布高度超过可用空间时，VStack 会自然增高并继续滚动。
                VStack {
                    DiagramCanvas(
                        logicalSize: logicalSize,
                        groups: groups
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 12)
                }
                .frame(
                    maxWidth: .infinity,
                    minHeight: geometry.size.height,
                    alignment: .center
                )
            }
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - 逻辑坐标画布

private struct DiagramCanvas: View {
    let logicalSize: CGSize
    let groups: [DiagramGroup]

    var body: some View {
        GeometryReader { geometry in
            let scale = geometry.size.width / logicalSize.width

            ZStack {
                connectionsLayer(scale: scale)
                    .allowsHitTesting(false)

                nodesLayer(scale: scale)
            }
        }
        .aspectRatio(logicalSize.width / logicalSize.height, contentMode: .fit)
    }

    private func connectionsLayer(scale: CGFloat) -> some View {
        Path { path in
            for group in groups {
                for connection in group.connections {
                    guard
                        group.nodes.indices.contains(connection.fromNodeIndex),
                        group.nodes.indices.contains(connection.toNodeIndex)
                    else {
                        continue
                    }

                    let from = group.nodes[connection.fromNodeIndex].position
                    let to = group.nodes[connection.toNodeIndex].position

                    path.move(to: scaled(from, by: scale))
                    path.addLine(to: scaled(to, by: scale))
                }
            }
        }
        .stroke(Color.black.opacity(0.8), lineWidth: max(1, 2 * scale))
    }

    private func nodesLayer(scale: CGFloat) -> some View {
        ForEach(groups) { group in
            ForEach(group.nodes) { node in
                NavigationLink {
                    LineDetailView(
                        lineIndex: group.poemLine.lineIndex,
                        line: group.poemLine.text,
                        pinyin: group.poemLine.pinyin,
                        startingSequence: group.poemLine.startingSequence
                    )
                } label: {
                    DiagramNodeView(node: node, scale: scale)
                }
                .buttonStyle(.plain)
                .position(scaled(node.position, by: scale))
                .accessibilityLabel("\(String(node.character))，进入\(group.poemLine.text)")
            }
        }
    }

    private func scaled(_ point: CGPoint, by scale: CGFloat) -> CGPoint {
        CGPoint(x: point.x * scale, y: point.y * scale)
    }
}

private struct DiagramNodeView: View {
    let node: DiagramNode
    let scale: CGFloat

    private var visibleDiameter: CGFloat {
        58 * scale
    }

    private var tapDiameter: CGFloat {
        max(visibleDiameter, 28)
    }

    var body: some View {
        Text(String(node.character))
            .font(.system(size: max(14, 34 * scale), design: .serif))
            .foregroundStyle(node.style == .dark ? Color.white : Color.black)
            .frame(width: visibleDiameter, height: visibleDiameter)
            .background(
                Circle()
                    .fill(node.style == .dark ? Color.black : Color.white)
            )
            .overlay {
                Circle()
                    .stroke(Color.black, lineWidth: max(1, 2 * scale))
            }
            .frame(width: tapDiameter, height: tapDiameter)
            .contentShape(Circle())
    }
}
