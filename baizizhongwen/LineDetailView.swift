//
//  LineDetailView.swift
//  baizizhongwen
//
//  Created by 7x on 2026/8/5.
//

import SwiftUI
import UIKit
import AVFoundation
import Combine

// MARK: - 单字图解数据

struct CharacterSelection: Identifiable, Hashable {
    let character: Character
    let sequence: Int

    var id: Int {
        sequence
    }
}

enum ChineseNumberFormatter {
    private static let digits = [
        "零", "一", "二", "三", "四", "五", "六", "七", "八", "九"
    ]

    static func string(from number: Int) -> String {
        guard number > 0 else {
            return digits[0]
        }

        if number < 10 {
            return digits[number]
        }

        if number < 100 {
            let tens = number / 10
            let ones = number % 10
            let tensText = tens == 1 ? "十" : "\(digits[tens])十"

            return ones == 0 ? tensText : "\(tensText)\(digits[ones])"
        }

        if number < 1_000 {
            let hundreds = number / 100
            let remainder = number % 100
            var result = "\(digits[hundreds])百"

            guard remainder > 0 else {
                return result
            }

            if remainder < 10 {
                return result + digits[0] + digits[remainder]
            }

            let tens = remainder / 10
            let ones = remainder % 10
            result += "\(digits[tens])十"

            return ones == 0 ? result : result + digits[ones]
        }

        return String(number)
    }
}

// MARK: - 音频播放管理器

final class AudioPlayerManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var errorMessage: String?

    private var player: AVAudioPlayer?
    private var timer: Timer?

    func load(url: URL) {
        stop()

        do {
            let audioSession = AVAudioSession.sharedInstance()

            try audioSession.setCategory(
                .playback,
                mode: .default,
                options: []
            )

            try audioSession.setActive(true)

            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.delegate = self
            newPlayer.prepareToPlay()

            player = newPlayer
            duration = newPlayer.duration
            currentTime = 0
            errorMessage = nil

            print("Loaded audio: \(url.lastPathComponent)")
            print("Duration: \(newPlayer.duration) seconds")
        } catch {
            player = nil
            duration = 0
            currentTime = 0
            errorMessage = "音频加载失败：\(error.localizedDescription)"

            print("Audio URL:", url.absoluteString)
            print("Audio file:", url.lastPathComponent)
            print("Audio error:", error)
            print("Audio error description:", error.localizedDescription)
        }
    }

    func playPause() {
        guard let player else {
            print("Cannot play: audio player is not loaded")
            return
        }

        if player.isPlaying {
            pause()
        } else {
            // 完整播放后再次点击，从头重播。
            if currentTime >= duration {
                player.currentTime = 0
                currentTime = 0
            }
            let didStartPlaying = player.play()

            if didStartPlaying {
                isPlaying = true
                errorMessage = nil
                startTimer()
            } else {
                isPlaying = false
                errorMessage = "音频播放失败"
                print("Audio player failed to start")
            }
        }
    }

    func pause() {
        player?.pause()
        currentTime = player?.currentTime ?? currentTime
        isPlaying = false
        stopTimer()
    }

    func seek(to time: TimeInterval) {
        guard let player else {
            return
        }

        let clampedTime = min(
            max(time, 0),
            max(player.duration, 0)
        )

        player.currentTime = clampedTime
        currentTime = clampedTime
    }

    func stop() {
        player?.stop()
        player = nil

        isPlaying = false
        currentTime = 0
        duration = 0
        errorMessage = nil

        stopTimer()
    }

    private func startTimer() {
        stopTimer()

        timer = Timer.scheduledTimer(
            withTimeInterval: 0.1,
            repeats: true
        ) { [weak self] _ in
            guard let self, let player = self.player else {
                return
            }

            self.currentTime = player.currentTime

            if !player.isPlaying {
                self.isPlaying = false
                self.stopTimer()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    func audioPlayerDidFinishPlaying(
        _ player: AVAudioPlayer,
        successfully flag: Bool
    ) {
        isPlaying = false
        stopTimer()
        currentTime = flag ? duration : player.currentTime
        if !flag {
            errorMessage = "音频播放未完成，请重试"
        }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        pause()
        errorMessage = "音频播放失败，请重试"
    }

    deinit {
        stopTimer()
    }
}

// MARK: - 详细页

struct LineDetailView: View {
    let lineIndex: Int
    let line: String
    let pinyin: [String]
    let startingSequence: Int

    @State private var selectedCharacter: CharacterSelection?

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 0) {
                // 诗句不再作为导航标题重复出现，而是在宫格上方逐字展示。
                // 拼音单元按可用宽度自动换行；无论诗句长短，下面都保留
                // 固定空隙，让整个宫格（包括其中汉字）作为整体适当下移。
                PronouncedLineHeader(line: line, pinyin: pinyin)
                    .padding(.top, 8)
                    .padding(.bottom, 36)

                TwentySevenGrid(text: line) { character, characterIndex in
                    selectedCharacter = CharacterSelection(
                        character: character,
                        sequence: startingSequence + characterIndex
                    )
                }
                .frame(width: 300, height: 300)

                StoryAudioSection(lineIndex: lineIndex)
                    .id(lineIndex)
                    .padding(.top, 24)

                Color.clear
                    .frame(height: 24)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
        }
        .navigationTitle("百字中文")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedCharacter) { selection in
            CharacterDiagramView(
                character: selection.character,
                sequence: selection.sequence
            )
        }
    }
}

// MARK: - 二级页逐字拼音标题

/// 将一个拼音固定放在对应汉字的正上方。
/// 单元宽度取拼音与汉字的较大者，保证两者始终以同一中心线对齐。
private struct PronouncedLineHeader: View {
    let line: String
    let pinyin: [String]

    private var characters: [Character] {
        Array(line)
    }

    var body: some View {
        CenteredFlowLayout(horizontalSpacing: 12, verticalSpacing: 10) {
            ForEach(characters.indices, id: \.self) { index in
                VStack(spacing: 3) {
                    Text(pinyin.indices.contains(index) ? pinyin[index] : "")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize()

                    Text(String(characters[index]))
                        .font(.system(size: 32, weight: .bold, design: .serif))
                        .foregroundStyle(.primary)
                        .fixedSize()
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    "\(String(characters[index]))，\(pinyin.indices.contains(index) ? pinyin[index] : "")"
                )
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }
}

/// 一个按实际单元宽度自动换行、并让每一行分别居中的 SwiftUI 布局。
///
/// 与固定“每行六字”相比，这种布局会同时考虑拼音长度和设备宽度：
/// 当前行放不下下一个单元时才换行，较长拼音不会挤入相邻汉字上方。
private struct CenteredFlowLayout: Layout {
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let availableWidth = normalizedWidth(proposal.width)
        let measurements = subviews.map { $0.sizeThatFits(.unspecified) }
        let rows = makeRows(measurements: measurements, availableWidth: availableWidth)
        let contentWidth = rows.map(\.width).max() ?? 0
        let contentHeight = rows.enumerated().reduce(CGFloat.zero) { result, entry in
            result + entry.element.height + (entry.offset == 0 ? 0 : verticalSpacing)
        }

        return CGSize(
            width: proposal.width?.isFinite == true ? availableWidth : contentWidth,
            height: contentHeight
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let measurements = subviews.map { $0.sizeThatFits(.unspecified) }
        let rows = makeRows(measurements: measurements, availableWidth: bounds.width)
        var y = bounds.minY

        for row in rows {
            // 每一行使用自己的实际宽度计算起点，所以换行后的短行也会居中。
            var x = bounds.minX + max(0, (bounds.width - row.width) / 2)

            for index in row.indices {
                let size = measurements[index]
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(width: size.width, height: size.height)
                )
                x += size.width + horizontalSpacing
            }

            y += row.height + verticalSpacing
        }
    }

    private func makeRows(
        measurements: [CGSize],
        availableWidth: CGFloat
    ) -> [Row] {
        guard !measurements.isEmpty else {
            return []
        }

        var rows: [Row] = []
        var current = Row()

        for (index, size) in measurements.enumerated() {
            let spacing = current.indices.isEmpty ? 0 : horizontalSpacing
            let proposedRowWidth = current.width + spacing + size.width

            if !current.indices.isEmpty && proposedRowWidth > availableWidth {
                rows.append(current)
                current = Row()
            }

            let itemSpacing = current.indices.isEmpty ? 0 : horizontalSpacing
            current.indices.append(index)
            current.width += itemSpacing + size.width
            current.height = max(current.height, size.height)
        }

        if !current.indices.isEmpty {
            rows.append(current)
        }

        return rows
    }

    private func normalizedWidth(_ proposedWidth: CGFloat?) -> CGFloat {
        guard let proposedWidth, proposedWidth.isFinite else {
            return .greatestFiniteMagnitude
        }
        return max(0, proposedWidth)
    }
}

// MARK: - 27 宫格

struct TwentySevenGrid: View {
    let text: String
    let onCharacterTap: ((Character, Int) -> Void)?

    init(
        text: String,
        onCharacterTap: ((Character, Int) -> Void)? = nil
    ) {
        self.text = text
        self.onCharacterTap = onCharacterTap
    }

    private let rows = 27
    private let columns = 27

    private struct GridCoordinate {
        let x: CGFloat
        let y: CGFloat
    }

    private var characters: [Character] {
        Array(text)
    }

    // MARK: - 精确坐标
    // 整个网格使用连续的 0...27 二维坐标：
    // 左上 (0, 0)，右下 (27, 27)，中心 (13.5, 13.5)。
    // 每个字都可以独立使用小数坐标微调，不再依赖九宫格固定锚点。
    private var exactPositions: [GridCoordinate]? {
        switch text {
        case "元", "道":
            return [
                GridCoordinate(x: 13.5, y: 13.5)
            ]

        case "阴阳":
            return [
                GridCoordinate(x: 9.0, y: 9.0),
                GridCoordinate(x: 18.0, y: 18.0)
            ]

        case "男女":
            return [
                GridCoordinate(x: 18.0, y: 9.0),
                GridCoordinate(x: 9.0, y: 18.0)
            ]

        case "天地人":
            return [
                GridCoordinate(x: 13.5, y: 9.0),
                GridCoordinate(x: 9.0, y: 18.0),
                GridCoordinate(x: 18.0, y: 18.0)
            ]

        case "日月星":
            return [
                GridCoordinate(x: 9.0, y: 9.0),
                GridCoordinate(x: 18.0, y: 9.0),
                GridCoordinate(x: 13.5, y: 18.0)
            ]

        case "东南西北":
            return [
                GridCoordinate(x: 22.5, y: 13.5),
                GridCoordinate(x: 13.5, y: 22.5),
                GridCoordinate(x: 4.5, y: 13.5),
                GridCoordinate(x: 13.5, y: 4.5)
            ]

        case "春夏秋冬":
            return [
                GridCoordinate(x: 22.5, y: 22.5),
                GridCoordinate(x: 4.5, y: 22.5),
                GridCoordinate(x: 4.5, y: 4.5),
                GridCoordinate(x: 22.5, y: 4.5)
            ]

        case "木火土金水":
            return [
                GridCoordinate(x: 22.5, y: 13.5),
                GridCoordinate(x: 13.5, y: 22.5),
                GridCoordinate(x: 13.5, y: 13.5),
                GridCoordinate(x: 4.5, y: 13.5),
                GridCoordinate(x: 13.5, y: 4.5)
            ]

        case "青赤黄白黑":
            return [
                GridCoordinate(x: 22.5, y: 22.5),
                GridCoordinate(x: 4.5, y: 22.5),
                GridCoordinate(x: 13.5, y: 13.5),
                GridCoordinate(x: 4.5, y: 4.5),
                GridCoordinate(x: 22.5, y: 4.5)
            ]

        case "草植虫鱼鸟兽":
            return [
                GridCoordinate(x: 4.5, y: 22.5),
                GridCoordinate(x: 22.5, y: 22.5),
                GridCoordinate(x: 22.5, y: 13.5),
                GridCoordinate(x: 13.5, y: 13.5),
                GridCoordinate(x: 4.5, y: 13.5),
                GridCoordinate(x: 13.5, y: 4.5)
            ]

        case "首面身心手足":
            return [
                GridCoordinate(x: 4.5, y: 4.5),
                GridCoordinate(x: 22.5, y: 4.5),
                GridCoordinate(x: 4.5, y: 13.5),
                GridCoordinate(x: 13.5, y: 13.5),
                GridCoordinate(x: 22.5, y: 13.5),
                GridCoordinate(x: 13.5, y: 22.5)
            ]

        case "刀匕斤矢弓戈矛":
            return [
                GridCoordinate(x: 9.0, y: 4.5),
                GridCoordinate(x: 18.0, y: 4.5),
                GridCoordinate(x: 4.5, y: 13.5),
                GridCoordinate(x: 13.5, y: 13.5),
                GridCoordinate(x: 22.5, y: 13.5),
                GridCoordinate(x: 9.0, y: 22.5),
                GridCoordinate(x: 18.0, y: 22.5)
            ]

        case "喜怒哀惧爱恶欲":
            return [
                GridCoordinate(x: 4.5, y: 9.0),
                GridCoordinate(x: 13.5, y: 4.5),
                GridCoordinate(x: 22.5, y: 9.0),
                GridCoordinate(x: 4.5, y: 18.0),
                GridCoordinate(x: 13.5, y: 13.5),
                GridCoordinate(x: 22.5, y: 18.0),
                GridCoordinate(x: 13.5, y: 22.5)
            ]

        case "云川电雨雷风山谷":
            // 依据原始扫描页透视归一化后的字心位置重新标定。
            // “云”高于“谷/风”；“川”也并非与“雷/山”严格共线。
            return [
                GridCoordinate(x: 13.45, y: 4.55),   // 云
                GridCoordinate(x: 13.50, y: 22.30),  // 川
                GridCoordinate(x: 4.65,  y: 13.20),  // 电
                GridCoordinate(x: 22.20, y: 13.20),  // 雨
                GridCoordinate(x: 6.40,  y: 20.70),  // 雷
                GridCoordinate(x: 20.80, y: 6.35),   // 风
                GridCoordinate(x: 21.05, y: 20.70),  // 山
                GridCoordinate(x: 6.40,  y: 6.40)    // 谷
            ]

        case "笙埙革柷石钟丝竹":
            return [
                GridCoordinate(x: 11.0, y: 4.5),
                GridCoordinate(x: 16.0, y: 4.5),
                GridCoordinate(x: 22.5, y: 11.0),
                GridCoordinate(x: 22.5, y: 16.0),
                GridCoordinate(x: 16.0, y: 22.5),
                GridCoordinate(x: 11.0, y: 22.5),
                GridCoordinate(x: 4.5, y: 16.0),
                GridCoordinate(x: 4.5, y: 11.0)
            ]

        case "衣食居行皿用鼎市井":
            return [
                GridCoordinate(x: 4.5, y: 4.5),
                GridCoordinate(x: 4.5, y: 13.5),
                GridCoordinate(x: 4.5, y: 22.5),
                GridCoordinate(x: 13.5, y: 4.5),
                GridCoordinate(x: 13.5, y: 13.5),
                GridCoordinate(x: 13.5, y: 22.5),
                GridCoordinate(x: 22.5, y: 4.5),
                GridCoordinate(x: 22.5, y: 13.5),
                GridCoordinate(x: 22.5, y: 22.5)
            ]

        // 教材正文使用“子孙”，这里必须与唯一诗文数据完全一致，
        // 否则会落入通用九字布局，失去本句专属坐标。
        case "祖父母兄弟姐妹子孙":
            return [
                GridCoordinate(x: 13.5, y: 4.5),
                GridCoordinate(x: 4.5, y: 4.5),
                GridCoordinate(x: 22.5, y: 4.5),
                GridCoordinate(x: 4.5, y: 13.5),
                GridCoordinate(x: 4.5, y: 22.5),
                GridCoordinate(x: 22.5, y: 13.5),
                GridCoordinate(x: 22.5, y: 22.5),
                GridCoordinate(x: 13.5, y: 13.5),
                GridCoordinate(x: 13.5, y: 22.5)
            ]

        case "礼乐射御书数琴棋诗画":
            // 依据原始扫描页重新标定。
            // 顶部“射”明显高于“乐/御”，底部“棋”明显低于“诗/琴”。
            return [
                GridCoordinate(x: 4.45,  y: 10.55),  // 礼
                GridCoordinate(x: 7.25,  y: 4.65),   // 乐
                GridCoordinate(x: 13.50, y: 3.15),   // 射（考虑 54pt 字号，避免顶部裁切）
                GridCoordinate(x: 20.00, y: 4.70),   // 御
                GridCoordinate(x: 22.45, y: 10.35),  // 书
                GridCoordinate(x: 22.40, y: 16.65),  // 数
                GridCoordinate(x: 20.00, y: 22.40),  // 琴
                GridCoordinate(x: 13.35, y: 23.80),  // 棋（保持明显低于诗/琴，同时避免底部裁切）
                GridCoordinate(x: 7.35,  y: 22.40),  // 诗
                GridCoordinate(x: 4.80,  y: 16.65)   // 画
            ]

        case "仁义礼智信福寿康乐宁":
            // 依据原始扫描页重新标定。
            // “康”位于下部中央，但明显高于“寿/宁”。
            return [
                GridCoordinate(x: 5.40,  y: 3.40),   // 仁
                GridCoordinate(x: 5.45,  y: 8.50),   // 义
                GridCoordinate(x: 13.60, y: 5.95),   // 礼
                GridCoordinate(x: 21.05, y: 3.55),   // 智
                GridCoordinate(x: 21.05, y: 8.55),   // 信
                GridCoordinate(x: 5.40,  y: 17.70),  // 福
                GridCoordinate(x: 5.45,  y: 23.70),  // 寿
                GridCoordinate(x: 13.40, y: 21.55),  // 康
                GridCoordinate(x: 21.00, y: 18.00),  // 乐
                GridCoordinate(x: 21.00, y: 23.90)   // 宁
            ]

        case "羽毛隹肉爪虎飞豸齿骨贝":
            return [
                GridCoordinate(x: 4.5, y: 4.5),    // 羽
                GridCoordinate(x: 7.5, y: 7.5),    // 毛
                GridCoordinate(x: 10.5, y: 10.5),  // 隹
                GridCoordinate(x: 13.5, y: 13.5),  // 肉
                GridCoordinate(x: 16.5, y: 16.5),  // 爪
                GridCoordinate(x: 19.5, y: 19.5),  // 虎
                GridCoordinate(x: 7.5, y: 19.5),   // 飞
                GridCoordinate(x: 10.5, y: 16.5),  // 豸
                GridCoordinate(x: 16.5, y: 10.5),  // 齿
                GridCoordinate(x: 19.5, y: 7.5),   // 骨
                GridCoordinate(x: 22.5, y: 4.5)    // 贝
            ]

        case "示丰主歹毒巫妖魔镇鬼神":
            return [
                GridCoordinate(x: 4.5, y: 22.5),    // 示
                GridCoordinate(x: 7.5, y: 19.5),    // 丰
                GridCoordinate(x: 10.5, y: 16.5),   // 主
                GridCoordinate(x: 13.5, y: 13.5),   // 歹
                GridCoordinate(x: 16.5, y: 10.5),   // 毒
                GridCoordinate(x: 19.5, y: 7.5),    // 巫
                GridCoordinate(x: 7.5, y: 7.5),     // 妖
                GridCoordinate(x: 10.5, y: 10.5),   // 魔
                GridCoordinate(x: 16.5, y: 16.5),   // 镇
                GridCoordinate(x: 19.5, y: 19.5),   // 鬼
                GridCoordinate(x: 22.5, y: 22.5)    // 神
            ]

        case "鼠牛虎兔龙蛇马羊猴鸡犬豕":
            return [
                GridCoordinate(x: 18.90, y: 4.05),
                GridCoordinate(x: 22.41, y: 8.64),
                GridCoordinate(x: 23.22, y: 13.50),
                GridCoordinate(x: 22.14, y: 18.36),
                GridCoordinate(x: 18.36, y: 22.41),
                GridCoordinate(x: 13.50, y: 23.76),
                GridCoordinate(x: 8.64, y: 22.41),
                GridCoordinate(x: 4.86, y: 18.36),
                GridCoordinate(x: 3.78, y: 13.50),
                GridCoordinate(x: 4.59, y: 8.64),
                GridCoordinate(x: 8.64, y: 4.05),
                GridCoordinate(x: 13.50, y: 2.70)
            ]

        case "子丑寅卯辰巳午未申酉戌亥":
            return [
                GridCoordinate(x: 18.90, y: 4.05),
                GridCoordinate(x: 22.41, y: 8.64),
                GridCoordinate(x: 23.22, y: 13.50),
                GridCoordinate(x: 22.14, y: 18.36),
                GridCoordinate(x: 18.36, y: 22.41),
                GridCoordinate(x: 13.50, y: 23.76),
                GridCoordinate(x: 8.64, y: 22.41),
                GridCoordinate(x: 4.86, y: 18.36),
                GridCoordinate(x: 3.78, y: 13.50),
                GridCoordinate(x: 4.59, y: 8.64),
                GridCoordinate(x: 8.64, y: 4.05),
                GridCoordinate(x: 13.50, y: 2.70)
            ]

        default:
            return nil
        }
    }

    // MARK: - 未知文本兜底布局
    // 只在 exactPositions 没有对应内容时使用。
    // 已配置的教材页面永远优先使用各自独立的精确坐标。
    private var fallbackPositions: [GridCoordinate] {
        switch characters.count {
        case 0:
            return []

        case 1:
            return [GridCoordinate(x: 13.5, y: 13.5)]

        case 2:
            return [
                GridCoordinate(x: 9.0, y: 9.0),
                GridCoordinate(x: 18.0, y: 18.0)
            ]

        case 3:
            return [
                GridCoordinate(x: 13.5, y: 4.5),
                GridCoordinate(x: 9.0, y: 18.0),
                GridCoordinate(x: 18.0, y: 18.0)
            ]

        case 4:
            return [
                GridCoordinate(x: 4.5, y: 4.5),
                GridCoordinate(x: 22.5, y: 4.5),
                GridCoordinate(x: 4.5, y: 22.5),
                GridCoordinate(x: 22.5, y: 22.5)
            ]

        case 5:
            return [
                GridCoordinate(x: 13.5, y: 4.5),
                GridCoordinate(x: 4.5, y: 13.5),
                GridCoordinate(x: 13.5, y: 13.5),
                GridCoordinate(x: 22.5, y: 13.5),
                GridCoordinate(x: 13.5, y: 22.5)
            ]

        case 6:
            return [
                GridCoordinate(x: 4.5, y: 4.5),
                GridCoordinate(x: 13.5, y: 4.5),
                GridCoordinate(x: 22.5, y: 4.5),
                GridCoordinate(x: 4.5, y: 22.5),
                GridCoordinate(x: 13.5, y: 22.5),
                GridCoordinate(x: 22.5, y: 22.5)
            ]

        case 7:
            return [
                GridCoordinate(x: 9.0, y: 4.5),
                GridCoordinate(x: 18.0, y: 4.5),
                GridCoordinate(x: 4.5, y: 13.5),
                GridCoordinate(x: 13.5, y: 13.5),
                GridCoordinate(x: 22.5, y: 13.5),
                GridCoordinate(x: 9.0, y: 22.5),
                GridCoordinate(x: 18.0, y: 22.5)
            ]

        case 8:
            return [
                GridCoordinate(x: 9.0, y: 4.5),
                GridCoordinate(x: 18.0, y: 4.5),
                GridCoordinate(x: 4.5, y: 9.0),
                GridCoordinate(x: 22.5, y: 9.0),
                GridCoordinate(x: 4.5, y: 18.0),
                GridCoordinate(x: 22.5, y: 18.0),
                GridCoordinate(x: 9.0, y: 22.5),
                GridCoordinate(x: 18.0, y: 22.5)
            ]

        case 9:
            return [
                GridCoordinate(x: 4.5, y: 4.5),
                GridCoordinate(x: 13.5, y: 4.5),
                GridCoordinate(x: 22.5, y: 4.5),
                GridCoordinate(x: 4.5, y: 13.5),
                GridCoordinate(x: 13.5, y: 13.5),
                GridCoordinate(x: 22.5, y: 13.5),
                GridCoordinate(x: 4.5, y: 22.5),
                GridCoordinate(x: 13.5, y: 22.5),
                GridCoordinate(x: 22.5, y: 22.5)
            ]

        case 10:
            return [
                GridCoordinate(x: 9.0, y: 4.5),
                GridCoordinate(x: 13.5, y: 4.5),
                GridCoordinate(x: 18.0, y: 4.5),
                GridCoordinate(x: 4.5, y: 9.0),
                GridCoordinate(x: 22.5, y: 9.0),
                GridCoordinate(x: 4.5, y: 18.0),
                GridCoordinate(x: 22.5, y: 18.0),
                GridCoordinate(x: 9.0, y: 22.5),
                GridCoordinate(x: 13.5, y: 22.5),
                GridCoordinate(x: 18.0, y: 22.5)
            ]

        case 11:
            return [
                GridCoordinate(x: 4.5, y: 4.5),
                GridCoordinate(x: 7.5, y: 7.5),
                GridCoordinate(x: 10.5, y: 10.5),
                GridCoordinate(x: 13.5, y: 13.5),
                GridCoordinate(x: 16.5, y: 16.5),
                GridCoordinate(x: 19.5, y: 19.5),
                GridCoordinate(x: 7.5, y: 19.5),
                GridCoordinate(x: 10.5, y: 16.5),
                GridCoordinate(x: 16.5, y: 10.5),
                GridCoordinate(x: 19.5, y: 7.5),
                GridCoordinate(x: 22.5, y: 4.5)
            ]

        default:
            // 当前教材最多 12 个字。未知的 12 字文本使用环形兜底。
            // 如果以后出现 12 字以上文本，多出的字暂时放在中心，
            // 后续应为该教材页补充 exactPositions，而不是依赖兜底。
            let ring: [GridCoordinate] = [
                GridCoordinate(x: 13.50, y: 2.70),
                GridCoordinate(x: 18.90, y: 4.05),
                GridCoordinate(x: 22.41, y: 8.64),
                GridCoordinate(x: 23.22, y: 13.50),
                GridCoordinate(x: 22.14, y: 18.36),
                GridCoordinate(x: 18.36, y: 22.41),
                GridCoordinate(x: 13.50, y: 23.76),
                GridCoordinate(x: 8.64, y: 22.41),
                GridCoordinate(x: 4.86, y: 18.36),
                GridCoordinate(x: 3.78, y: 13.50),
                GridCoordinate(x: 4.59, y: 8.64),
                GridCoordinate(x: 8.64, y: 4.05)
            ]

            if characters.count <= ring.count {
                return Array(ring.prefix(characters.count))
            }

            return ring + Array(
                repeating: GridCoordinate(x: 13.5, y: 13.5),
                count: characters.count - ring.count
            )
        }
    }

    private var characterPositions: [GridCoordinate] {
        exactPositions ?? fallbackPositions
    }

    // 1 个字 72pt；每增加 1 个字，字号减少 2pt。
    // 1...12 个字依次为：72, 70, 68, 66, 64, 62, 60, 58, 56, 54, 52, 50。
    private var characterFontSize: CGFloat {
        let count = max(characters.count, 1)
        return max(72 - CGFloat(count - 1) * 3, 30)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                fineGrid(in: geometry.size)
                    .allowsHitTesting(false)
                majorGrid(in: geometry.size)
                    .allowsHitTesting(false)
                charactersLayer(in: geometry.size)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func fineGrid(in size: CGSize) -> some View {
        Path { path in
            for column in 0...columns {
                let x = size.width * CGFloat(column) / CGFloat(columns)

                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }

            for row in 0...rows {
                let y = size.height * CGFloat(row) / CGFloat(rows)

                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
        }
        .stroke(
            Color.gray.opacity(0.35),
            lineWidth: 0.5
        )
    }

    private func majorGrid(in size: CGSize) -> some View {
        ZStack {
            Path { path in
                for division in [CGFloat(1.0 / 3.0), CGFloat(2.0 / 3.0)] {
                    let x = size.width * division

                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))

                    let y = size.height * division

                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }
            }
            .stroke(
                Color.black.opacity(0.7),
                lineWidth: 1.5
            )

            Rectangle()
                .stroke(Color.black, lineWidth: 2)
        }
    }

    private func charactersLayer(in size: CGSize) -> some View {
        ForEach(Array(characters.enumerated()), id: \.offset) { index, character in
            if index < characterPositions.count {
                let position = characterPositions[index]

                if let onCharacterTap {
                    Button {
                        onCharacterTap(character, index)
                    } label: {
                        characterLabel(character)
                            .frame(
                                width: max(characterFontSize, 44),
                                height: max(characterFontSize, 44)
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(character))
                    .position(
                        x: size.width * position.x / 27.0,
                        y: size.height * position.y / 27.0
                    )
                } else {
                    characterLabel(character)
                        .position(
                            x: size.width * position.x / 27.0,
                            y: size.height * position.y / 27.0
                        )
                }
            }
        }
    }

    private func characterLabel(_ character: Character) -> some View {
        Text(String(character))
            .font(
                .system(
                    size: characterFontSize,
                    weight: .bold,
                    design: .serif
                )
            )
            .foregroundColor(.black)
            .lineLimit(1)
            .fixedSize()
    }
}

// MARK: - 单字图解页

struct CharacterDiagramView: View {
    let character: Character
    let sequence: Int

    private var diagramImage: UIImage? {
        // 图片按全文字位编号；重复汉字也使用各自位置对应的图片。
        let resourceName = "\(sequence)-\(character)"
        guard let url = Bundle.main.url(
            forResource: resourceName,
            withExtension: "png",
            subdirectory: "156Chinese"
        ) ?? Bundle.main.url(forResource: resourceName, withExtension: "png") else {
            return nil
        }

        return UIImage(contentsOfFile: url.path)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let diagramImage {
                    Image(uiImage: diagramImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 360)
                        .accessibilityLabel("\(String(character))字图解")
                } else {
                    ContentUnavailableView(
                        "暂无单字图解",
                        systemImage: "photo",
                        description: Text("\(String(character))字的图片暂时无法显示")
                    )
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("此处放置文本")
                        .foregroundColor(.secondary)

                    Color.clear
                        .frame(height: 400)
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .navigationTitle(
            "中华百字图解（\(ChineseNumberFormatter.string(from: sequence)))"
        )
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        LineDetailView(
            lineIndex: 0,
            line: "元",
            pinyin: ["yuán"],
            startingSequence: 1
        )
    }
}
