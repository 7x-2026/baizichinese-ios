//
//  ContentView.swift
//  baizizhongwen
//
//  Created by 7x on 2026/8/5.
//

import SwiftUI

/// 全站唯一的诗句导航数据。
///
/// `lineIndex` 使用零基行号；故事素材使用一基行号（第 0 行对应 `Line1`）；
/// `startingSequence` 是该句首字在全文中的一基序号，供三级单字页生成标题。
/// 树形图、河图和洛书都传递同一个模型，从而不会各自维护不同的行号规则。
struct PoemLine: Identifiable {
    let lineIndex: Int
    let text: String
    /// 与 `text` 中汉字严格一一对应的带声调拼音。
    /// 使用人工校对数据，避免“乐、行、恶、数”等多音字被系统自动转写错误。
    let pinyin: [String]
    let startingSequence: Int

    var id: Int {
        lineIndex
    }
}

/// 二级页面使用的逐字拼音表。
///
/// 键必须与 `poemText` 中的一整行完全一致；每个数组元素对应同位置的一个汉字。
/// 树形图、河图和洛书共享 `PoemLine`，因此只需在这里维护一份拼音数据。
private enum PoemLinePronunciation {
    static let syllablesByLine: [String: [String]] = [
        "元": ["yuán"],
        "道": ["dào"],
        "阴阳": ["yīn", "yáng"],
        "男女": ["nán", "nǚ"],
        "天地人": ["tiān", "dì", "rén"],
        "日月星": ["rì", "yuè", "xīng"],
        "东南西北": ["dōng", "nán", "xī", "běi"],
        "春夏秋冬": ["chūn", "xià", "qiū", "dōng"],
        "木火土金水": ["mù", "huǒ", "tǔ", "jīn", "shuǐ"],
        "青赤黄白黑": ["qīng", "chì", "huáng", "bái", "hēi"],
        "草植虫鱼鸟兽": ["cǎo", "zhí", "chóng", "yú", "niǎo", "shòu"],
        "首面身心手足": ["shǒu", "miàn", "shēn", "xīn", "shǒu", "zú"],
        "刀匕斤矢弓戈矛": ["dāo", "bǐ", "jīn", "shǐ", "gōng", "gē", "máo"],
        "喜怒哀惧爱恶欲": ["xǐ", "nù", "āi", "jù", "ài", "wù", "yù"],
        "云川电雨雷风山谷": ["yún", "chuān", "diàn", "yǔ", "léi", "fēng", "shān", "gǔ"],
        "笙埙革柷石钟丝竹": ["shēng", "xūn", "gé", "zhù", "shí", "zhōng", "sī", "zhú"],
        "衣食居行皿用鼎市井": ["yī", "shí", "jū", "xíng", "mǐn", "yòng", "dǐng", "shì", "jǐng"],
        "祖父母兄弟姐妹子孙": ["zǔ", "fù", "mǔ", "xiōng", "dì", "jiě", "mèi", "zǐ", "sūn"],
        "礼乐射御书数琴棋诗画": ["lǐ", "yuè", "shè", "yù", "shū", "shù", "qín", "qí", "shī", "huà"],
        "仁义礼智信福寿康乐宁": ["rén", "yì", "lǐ", "zhì", "xìn", "fú", "shòu", "kāng", "lè", "níng"],
        "羽毛隹肉爪虎飞豸齿骨贝": ["yǔ", "máo", "zhuī", "ròu", "zhǎo", "hǔ", "fēi", "zhì", "chǐ", "gǔ", "bèi"],
        "示丰主歹毒巫妖魔镇鬼神": ["shì", "fēng", "zhǔ", "dǎi", "dú", "wū", "yāo", "mó", "zhèn", "guǐ", "shén"],
        "鼠牛虎兔龙蛇马羊猴鸡犬豕": ["shǔ", "niú", "hǔ", "tù", "lóng", "shé", "mǎ", "yáng", "hóu", "jī", "quǎn", "shǐ"],
        "子丑寅卯辰巳午未申酉戌亥": ["zǐ", "chǒu", "yín", "mǎo", "chén", "sì", "wǔ", "wèi", "shēn", "yǒu", "xū", "hài"]
    ]

    static func syllables(for line: String) -> [String] {
        guard let syllables = syllablesByLine[line] else {
            assertionFailure("Missing pinyin for poem line: \(line)")
            return Array(repeating: "", count: line.count)
        }

        assert(
            syllables.count == line.count,
            "Pinyin count does not match character count for: \(line)"
        )
        return syllables
    }
}

struct ContentView: View {
    let levelColors: [Color] = [
        Color(red: 1.0,        green: 0.0,      blue: 0.0),       // 1 正红
        Color(red: 1.0,        green: 0.4,      blue: 0.0),       // 2 深橙
        Color(red: 1.0,        green: 0.6,      blue: 0.133),     // 3 浅橙
        Color(red: 1.0,        green: 0.867,    blue: 0.0),       // 4 亮黄
        Color(red: 1.0,        green: 0.933,    blue: 0.2),       // 5 嫩黄
        Color(red: 0.533,      green: 0.933,    blue: 0.267),     // 6 浅绿
        Color(red: 0.2,        green: 0.867,    blue: 0.333),     // 7 草绿
        Color(red: 0.133,      green: 0.8,      blue: 0.467),     // 8 翠绿
        Color(red: 0.133,      green: 0.867,    blue: 0.867),     // 9 青色
        Color(red: 0.133,      green: 0.267,    blue: 0.867),     // 10 宝蓝
        Color(red: 0.867,      green: 0.133,    blue: 0.8),       // 11 品红
        Color(red: 0.533,      green: 0.133,    blue: 0.8)        // 12 紫罗兰紫
    ]

    /// 百字正文的唯一数据源。
    ///
    /// 修改诗句时只应编辑这里；`poemLines` 会统一计算行号与全文序号，
    /// 其他页面再按完整诗句文字查找对应的 `PoemLine`。
    let poemText = """
                    元
                    道
                    阴阳
                    男女
                    天地人
                    日月星
                    东南西北
                    春夏秋冬
                    木火土金水
                    青赤黄白黑
                    草植虫鱼鸟兽
                    首面身心手足
                    刀匕斤矢弓戈矛
                    喜怒哀惧爱恶欲
                    云川电雨雷风山谷
                    笙埙革柷石钟丝竹
                    衣食居行皿用鼎市井
                    祖父母兄弟姐妹子孙
                    礼乐射御书数琴棋诗画
                    仁义礼智信福寿康乐宁
                    羽毛隹肉爪虎飞豸齿骨贝
                    示丰主歹毒巫妖魔镇鬼神
                    鼠牛虎兔龙蛇马羊猴鸡犬豕
                    子丑寅卯辰巳午未申酉戌亥
                    """

    /// 将正文解析为导航模型，并累计每行在全文中的起始序号。
    /// 重复汉字不会合并，因此三级页面的序号始终对应它在全文中的实际位置。
    private var poemLines: [PoemLine] {
        let lines = poemText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var nextSequence = 1

        return lines.enumerated().map { lineIndex, line in
            let poemLine = PoemLine(
                lineIndex: lineIndex,
                text: line,
                pinyin: PoemLinePronunciation.syllables(for: line),
                startingSequence: nextSequence
            )

            nextSequence += line.count
            return poemLine
        }
    }

    var body: some View {
        NavigationStack {
            HomeGridView()
                .navigationTitle("百字中文九宫格")
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(for: HomeDestination.self) { destination in
                    destinationContent(for: destination)
                        .navigationTitle(destination.rawValue)
                        .navigationBarTitleDisplayMode(.inline)
                }
        }
    }

    @ViewBuilder
    private func destinationContent(for destination: HomeDestination) -> some View {
        switch destination {
        case .treeDiagram:
            ScrollView(.vertical) {
                treeDiagram
            }

        case .spiralDiagram:
            SpiralDiagramView()

        case .riverDiagram:
            RiverDiagramView(poemLines: poemLines)

        case .luoshuDiagram:
            LuoshuDiagramView(poemLines: poemLines)

        case .undividedRiverDiagram:
            UndividedRiverDiagramView(poemLines: poemLines)

        case .poem:
            PoemView()

        case .characterDiagrams:
            CharacterDiagramWallView(poemLines: poemLines)
        }
    }

    private var treeDiagram: some View {
        VStack(spacing: 0) {
            ForEach(poemLines) { poemLine in
                let charCount = poemLine.text.count
                let backgroundColor: Color = {
                    if (1...12).contains(charCount) {
                        return levelColors[charCount - 1]
                    }
                    return .clear
                }()

                NavigationLink {
                    LineDetailView(
                        lineIndex: poemLine.lineIndex,
                        line: poemLine.text,
                        pinyin: poemLine.pinyin,
                        startingSequence: poemLine.startingSequence
                    )
                } label: {
                    HStack {
                        Spacer()
                        Text(poemLine.text)
                            .font(.system(size: 22, weight: .bold, design: .serif))
                            .foregroundColor(.black)
                            .background(backgroundColor)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
