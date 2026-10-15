//
//  RegularScriptPoemView.swift
//  baizizhongwen
//
//  中文百字诗的纯文本阅览页。原图仅用于校对文字、颜色和分行，
//  页面本身不依赖图片，因此可以清晰缩放并支持纵向滚动。
//

import SwiftUI

// MARK: - 彩色诗文数据

/// 原稿使用的三种文字颜色。
///
/// 使用固定的 sRGB 色值而不是系统语义色，确保深色模式下仍保持原图的
/// 黑、正红和亮蓝效果。蓝色依据用户提供图片中的文字颜色近似标定。
private enum PoemInk {
    case black
    case red
    case blue

    var color: Color {
        switch self {
        case .black:
            return Color(red: 0, green: 0, blue: 0)
        case .red:
            return Color(red: 1, green: 0, blue: 0)
        case .blue:
            return Color(red: 0, green: 0.50, blue: 0.82)
        }
    }
}

/// 一段颜色连续的诗文。
/// 同一行可以由多个片段组成，从而准确还原单字或词组的颜色变化。
private struct PoemTextSegment {
    let text: String
    let ink: PoemInk
}

/// 一个汉字显示单元。拼音只属于该字，标点的 pinyin 为 nil。
private struct PoemDisplayGlyph {
    let character: Character
    let ink: PoemInk
    let pinyin: String?
}

/// 一行诗中的半句：三个汉字及其标点。
private struct PoemDisplayPhrase {
    let pinyin: String
    let segments: [PoemTextSegment]

    /// 将带声调拼音按空格拆成音节，再依次分配给每个非标点汉字。
    /// 这样每个拼音都能使用与对应汉字相同的固定宽度并居中显示。
    var glyphs: [PoemDisplayGlyph] {
        let syllables = pinyin
            .split { character in
                character.isWhitespace || Self.punctuation.contains(character)
            }
            .map(String.init)
        var syllableIndex = 0
        var result: [PoemDisplayGlyph] = []

        for segment in segments {
            for character in segment.text {
                if Self.punctuation.contains(character) {
                    result.append(
                        PoemDisplayGlyph(
                            character: character,
                            ink: segment.ink,
                            pinyin: nil
                        )
                    )
                } else {
                    let syllable = syllableIndex < syllables.count
                        ? syllables[syllableIndex]
                        : nil

                    result.append(
                        PoemDisplayGlyph(
                            character: character,
                            ink: segment.ink,
                            pinyin: syllable
                        )
                    )
                    syllableIndex += 1
                }
            }
        }

        assert(
            syllableIndex == syllables.count,
            "Pinyin syllable count does not match Chinese character count"
        )
        return result
    }

    private static let punctuation: Set<Character> = ["，", "。", "；"]
}

/// 屏幕中显示的一行诗文。
private struct PoemDisplayLine: Identifiable {
    let id: Int
    /// 已人工校对多音字并保留声调符号的整行拼音。
    let pinyin: String
    let segments: [PoemTextSegment]

    /// 以第一个中文逗号为界，将一行拆成前、后两个三字短句。
    /// 拼音也用同一标点拆分，确保两组拼音分别从对应汉字的正上方开始。
    var phrases: [PoemDisplayPhrase] {
        let textParts = splitSegmentsAtFirstComma()
        let pinyinParts = splitPinyinAtFirstComma()

        guard textParts.count == pinyinParts.count else {
            assertionFailure("Pinyin phrase count does not match poem text")
            return [PoemDisplayPhrase(pinyin: pinyin, segments: segments)]
        }

        return zip(pinyinParts, textParts).map { pinyin, segments in
            PoemDisplayPhrase(pinyin: pinyin, segments: segments)
        }
    }

    /// 切分文字时保留每个字符原来的颜色，并把第一个逗号留在前半句。
    private func splitSegmentsAtFirstComma() -> [[PoemTextSegment]] {
        var first: [PoemTextSegment] = []
        var second: [PoemTextSegment] = []
        var foundComma = false

        for segment in segments {
            guard !foundComma else {
                second.append(segment)
                continue
            }

            guard let commaIndex = segment.text.firstIndex(of: "，") else {
                first.append(segment)
                continue
            }

            let afterComma = segment.text.index(after: commaIndex)
            let firstText = String(segment.text[..<afterComma])
            let secondText = String(segment.text[afterComma...])

            first.append(PoemTextSegment(text: firstText, ink: segment.ink))

            if !secondText.isEmpty {
                second.append(PoemTextSegment(text: secondText, ink: segment.ink))
            }

            foundComma = true
        }

        return foundComma ? [first, second] : [first]
    }

    /// 拼音使用与正文相同的全角逗号，并同样将逗号保留在前半句。
    private func splitPinyinAtFirstComma() -> [String] {
        guard let commaIndex = pinyin.firstIndex(of: "，") else {
            return [pinyin]
        }

        let afterComma = pinyin.index(after: commaIndex)
        return [
            String(pinyin[..<afterComma]),
            String(pinyin[afterComma...])
        ]
    }
}

/// “百字诗”一级页面。
///
/// 导航栏已经由 `ContentView` 显示“百字中文（百字诗）”，所以正文不再重复
/// 图片中的“中文百字诗”标题，只呈现可滚动阅读的诗句。
struct RegularScriptPoemView: View {
    /// 每个汉字拥有相同的显示宽度，使拼音可以严格位于字心正上方。
    /// 标点不需要拼音，因此使用更窄的单元，避免两组三字相距过远。
    private static let characterCellWidth: CGFloat = 36
    private static let punctuationCellWidth: CGFloat = 18
    private static let phraseSpacing: CGFloat = 10

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 13) {
                ForEach(Self.lines) { line in
                    HStack(alignment: .top, spacing: Self.phraseSpacing) {
                        ForEach(Array(line.phrases.enumerated()), id: \.offset) { _, phrase in
                            HStack(alignment: .top, spacing: 0) {
                                ForEach(Array(phrase.glyphs.enumerated()), id: \.offset) { _, glyph in
                                    glyphView(glyph)
                                }
                            }
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        line.segments.map(\.text).joined()
                    )
                }
            }
            // 让诗文列采用最长一行的自然宽度，再将整列放到屏幕中央。
            // 行内仍保持左对齐，所有诗句拥有统一而整齐的左边缘。
            .fixedSize(horizontal: true, vertical: false)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
        }
        .background(Color.white)
    }

    /// 单字的拼音与汉字共享一个居中列；标点用透明占位保留拼音行高度，
    /// 因而所有汉字和标点仍在同一基准线上。
    private func glyphView(_ glyph: PoemDisplayGlyph) -> some View {
        let isPunctuation = glyph.pinyin == nil
        let cellWidth = isPunctuation
            ? Self.punctuationCellWidth
            : Self.characterCellWidth

        return VStack(spacing: 2) {
            if let pinyin = glyph.pinyin {
                Text(pinyin)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Color.gray)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } else {
                Text(" ")
                    .font(.system(size: 11, weight: .regular))
                    .hidden()
            }

            Text(String(glyph.character))
                .font(.system(size: 26, weight: .regular, design: .serif))
                .foregroundStyle(glyph.ink.color)
                .fixedSize()
        }
        .frame(width: cellWidth)
    }
}

// MARK: - 原稿逐行转写

private extension RegularScriptPoemView {
    /// 以下数据严格按原稿顺序分行；标点单独保持黑色。
    /// 使用辅助方法 `b`、`r`、`u` 分别表示黑、红、蓝，便于以后对照原稿微调。
    static let lines: [PoemDisplayLine] = {
        // 拼音与下方 content 一一对应。这里使用静态校对结果而不是运行时自动
        // 转写，以正确处理“行、数、恶、柷、豸”等多音字或少见字。
        let pinyin = [
            "yuán yǒu dào，dào shēng yī。",
            "fēn yīn yáng，hé nán nǚ。",
            "yī shēng èr，èr shēng sān，",
            "sān cái zhě，tiān dì rén，",
            "sān guāng zhě，rì yuè xīng。",
            "yuē chūn xià，yuē qiū dōng，",
            "cǐ sì jì，yùn bù qióng。",
            "yuē nán běi，yuē xī dōng，",
            "cǐ sì fāng，yìng hū zhōng。",
            "yuē mù huǒ，tǔ jīn shuǐ，",
            "cǐ wǔ xíng，běn hū shù。",
            "qīng chì huáng，jí bái hēi，",
            "cǐ wǔ sè，mù suǒ shí。",
            "mù ěr bí，jí kǒu shé，",
            "wǔ wèi xiāng，biàn shēng sè。",
            "cǎo zhí chóng，yú niǎo shòu，",
            "cǐ liù shēng，yuán yú yě。",
            "mài mǐ dòu，hé guā guǒ，",
            "cǐ liù shí，cǎi yú tián。",
            "shǒu miàn shēn，xīn shǒu zú，",
            "lì jǔ zhǐ，sī yán xíng。",
            "dāo jiē bǐ，jīn duì shǐ，",
            "gōng gē máo，qī qì quán。",
            "yuē xǐ nù，yuē āi jù，",
            "ài wù yù，qī qíng jù。",
            "yún chuān diàn，yǔ léi fēng，",
            "shān yǔ gǔ，bā guà duì。",
            "shēng xūn gǔ，zhù shí zhōng，",
            "sī yǔ zhú，bā yīn tóng。",
            "yī shí jū，xíng mǐn yòng，",
            "dǐng shì jǐng，jiàn jiǔ gōng。",
            "zǔ fù ān，mǔ nǚ qīn，",
            "xiōng dì yǒu，jiě mèi hé；",
            "zǐ sūn xīng，jiǔ zú níng。",
            "lǐ yuè shè，yù shū shù，",
            "qín duì qí，shī pèi huà。",
            "yuē lǐ yì，rén zhì xìn，",
            "yuē fú shòu，kāng lè níng。",
            "yǔ máo zhuī，ròu zhǎo hǔ，",
            "fēi xíng zhì，chǐ gǔ bèi。",
            "shì fēng zhǔ，dǎi dú wū，",
            "píng yāo mó，zhèn guǐ shén。",
            "tiān gān zhě，jiǎ zhì guǐ。",
            "shí èr zhī，zǐ zhì hài。",
            "shǔ niú hǔ，tù lóng shé，",
            "mǎ yáng hóu，jī quǎn shǐ。",
            "rén fǎ dì，dì fǎ tiān，",
            "tiān fǎ dào，wàn nián qīng。"
        ]

        let content: [[PoemTextSegment]] = [
            [b("元"), u("有"), b("道，道"), u("生"), b("一。")],
            [u("分"), b("阴阳，"), u("合"), b("男女。")],
            [b("一"), u("生"), b("二，二"), u("生"), b("三，")],
            [b("三"), u("才者"), b("，天地"), r("人"), b("，")],
            [b("三"), u("光者"), b("，"), r("日月"), b("星。")],
            [u("曰"), b("春夏，"), u("曰"), b("秋冬，")],
            [u("此四季，运不穷"), b("。")],
            [u("曰"), b("南北，"), u("曰"), r("西"), b("东，")],
            [u("此四方，应乎中"), b("。")],
            [u("曰"), r("木火，土金水"), b("，")],
            [u("此五行，本乎数"), b("。")],
            [r("青赤"), b("黄，"), u("及"), b("白"), r("黑"), b("，")],
            [u("此五色"), b("，目"), u("所识"), b("。")],
            [r("目耳鼻"), b("，"), u("及"), r("口舌"), b("，")],
            [b("五"), u("味香"), b("，"), u("辨声色"), b("。")],
            [b("草植"), r("虫，鱼鸟"), b("兽，")],
            [u("此六生，源于野"), b("。")],
            [r("麦米豆，禾瓜果"), b("，")],
            [u("此六食，采于田"), b("。")],
            [b("首面"), r("身，心手足"), b("，")],
            [r("立举止"), b("，思"), r("言"), b("行。")],
            [r("刀"), b("接"), r("匕"), b("，"), r("斤"), b("对"), r("矢"), b("，")],
            [r("弓戈矛"), b("，"), u("七器全"), b("。")],
            [u("曰"), b("喜怒，"), u("曰"), b("哀惧，")],
            [b("爱恶欲，"), u("七情具"), b("。")],
            [b("云"), r("川"), b("电，"), r("雨雷风"), b("，")],
            [r("山"), u("与"), r("谷"), b("，"), u("八卦对"), b("。")],
            [b("笙埙"), r("鼓"), b("，柷"), r("石"), b("钟，")],
            [r("丝"), u("与"), r("竹"), b("，"), u("八音同"), b("。")],
            [r("衣食"), b("居，行"), r("皿用"), b("，")],
            [b("鼎"), r("市井"), b("，"), u("建九宫"), b("。")],
            [b("祖"), r("父"), b("安，"), r("母女"), u("亲"), b("，")],
            [b("兄弟"), u("友"), b("，姐妹"), u("和"), b("；")],
            [r("子"), u("孙"), b("兴，九族宁。")],
            [b("礼乐射，御书数，")],
            [b("琴"), u("对"), b("棋，诗"), u("配"), b("画。")],
            [u("曰"), b("礼义，仁智信，")],
            [u("曰"), b("福寿，康乐宁。")],
            [r("羽毛隹，肉爪"), b("虎，")],
            [r("飞"), b("行"), r("豸，齿骨贝"), b("。")],
            [r("示"), b("丰主，"), r("歹"), b("毒"), r("巫"), b("，")],
            [u("平"), b("妖魔，镇鬼神。")],
            [b("天"), u("干者"), b("，甲"), u("至"), b("癸。")],
            [b("十二"), u("支"), b("，子"), u("至"), b("亥。")],
            [b("鼠"), r("牛"), b("虎，兔龙蛇，")],
            [r("马羊"), b("猴，鸡"), r("犬豕"), b("。")],
            [b("人"), u("法"), b("地，地"), u("法"), b("天，")],
            [b("天"), u("法"), b("道，"), u("万年"), b("青。")]
        ]

        precondition(
            pinyin.count == content.count,
            "Each poem line must have exactly one pinyin line"
        )

        return zip(content, pinyin).enumerated().map { index, pair in
            PoemDisplayLine(
                id: index,
                pinyin: pair.1,
                segments: pair.0
            )
        }
    }()

    static func b(_ text: String) -> PoemTextSegment {
        PoemTextSegment(text: text, ink: .black)
    }

    static func r(_ text: String) -> PoemTextSegment {
        PoemTextSegment(text: text, ink: .red)
    }

    static func u(_ text: String) -> PoemTextSegment {
        PoemTextSegment(text: text, ink: .blue)
    }
}
