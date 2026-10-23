import SwiftUI
import ImageIO

/// 图片按全文字位编号；同一个汉字在不同字位上有各自的图解。
enum CharacterDiagramResources {
    static func url(character: Character, sequence: Int, bundle: Bundle = .main) -> URL? {
        let name = "\(sequence)-\(character)"
        return bundle.url(
            forResource: name,
            withExtension: "png",
            subdirectory: "Resources/Images/156Chinese"
        ) ?? bundle.url(forResource: name, withExtension: "png")
    }
}

struct CharacterDiagramWallView: View {
    let poemLines: [PoemLine]

    private let spacing: CGFloat = 12
    private let captionHeight: CGFloat = 22
    private let background = Color(white: 0.07)

    private var characters: [CharacterSelection] {
        poemLines.flatMap { line in
            line.text.enumerated().map { index, character in
                CharacterSelection(character: character, sequence: line.startingSequence + index)
            }
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let height = max(geometry.size.height - 32, 1)
            let rowCount = min(5, max(1, Int((height + spacing) / 136)))
            let rowHeight = (height - CGFloat(rowCount - 1) * spacing) / CGFloat(rowCount)
            let imageSide = min(160, max(44, rowHeight - captionHeight - 6))

            // LazyHGrid 按列从上到下排列；使用普通滚动惯性，不做分页或吸附。
            ScrollView(.horizontal) {
                LazyHGrid(
                    rows: Array(repeating: GridItem(.fixed(rowHeight), spacing: spacing), count: rowCount),
                    spacing: spacing
                ) {
                    ForEach(characters) { selection in
                        NavigationLink {
                            CharacterDiagramView(character: selection.character, sequence: selection.sequence)
                        } label: {
                            VStack(spacing: 6) {
                                DiagramThumbnail(selection: selection)
                                    .frame(width: imageSide, height: imageSide)

                                Text("\(selection.sequence) · \(String(selection.character))")
                                    .font(.system(.subheadline, design: .serif))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .frame(height: captionHeight)
                            }
                            .frame(width: imageSide, height: rowHeight)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .id(selection.sequence)
                        .accessibilityLabel("第\(selection.sequence)字，\(String(selection.character))字九宫信息图")
                        .accessibilityHint("打开单张图解，可放大查看")
                        .accessibilityIdentifier("characterDiagram.\(selection.sequence)")
                    }
                }
                .padding(16)
            }
            .accessibilityIdentifier("characterDiagramWall")
        }
        .background(background.ignoresSafeArea())
        .toolbarBackground(background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Text("\(characters.count) 字")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct DiagramThumbnail: View {
    let selection: CharacterSelection

    @State private var image: UIImage?
    @State private var unavailable = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else if unavailable {
                Image(systemName: "photo")
                    .foregroundStyle(.gray)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .accessibilityHidden(true)
        .task(id: selection.id) {
            guard let url = CharacterDiagramResources.url(
                character: selection.character, sequence: selection.sequence
            ) else {
                unavailable = true
                return
            }
            let thumbnail = await DiagramThumbnailLoader.shared.image(for: url)
            guard !Task.isCancelled else { return }
            image = thumbnail
            unavailable = thumbnail == nil
        }
    }
}

/// 在独立 actor 上解码小图，避免横向滚动时加载 156 张全分辨率图片。
private actor DiagramThumbnailLoader {
    static let shared = DiagramThumbnailLoader()

    private let cache: NSCache<NSURL, UIImage> = {
        let cache = NSCache<NSURL, UIImage>()
        cache.countLimit = 80
        cache.totalCostLimit = 24 * 1024 * 1024
        return cache
    }()

    func image(for url: URL) -> UIImage? {
        if let cached = cache.object(forKey: url as NSURL) { return cached }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 320,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary)
        else { return nil }

        let image = UIImage(cgImage: thumbnail)
        cache.setObject(image, forKey: url as NSURL, cost: thumbnail.bytesPerRow * thumbnail.height)
        return image
    }
}
