//
//  SpiralDiagramView.swift
//  baizizhongwen
//
//  螺形图一级页面。图片仅用于阅览，不覆盖汉字点击区域；
//  缩放和拖动交给 UIScrollView，以获得系统原生且稳定的手势体验。
//

import SwiftUI
import UIKit

/// “百字中文（螺形图）”一级页面。
///
/// 导航栏标题由 `ContentView` 统一设置。本页面只显示原图，并始终使用白色
/// 背景与图片边缘衔接，不添加任何会触发二级导航的透明按钮。
struct SpiralDiagramView: View {
    var body: some View {
        ZoomableImageView(imageName: "SpiralDiagram")
            .background(Color.white)
            .accessibilityLabel("百字中文螺形图，可双指缩放和拖动")
    }
}

// MARK: - SwiftUI 与 UIScrollView 桥接

/// 将 Assets 中的图片放入原生缩放滚动视图。
///
/// `UIScrollView` 同时处理双指缩放和放大后的拖动，比自行组合 SwiftUI 的
/// MagnifyGesture 与 DragGesture 更适合大图阅览，也能自然处理惯性和边界。
private struct ZoomableImageView: UIViewRepresentable {
    let imageName: String

    func makeUIView(context: Context) -> ZoomingImageScrollView {
        let scrollView = ZoomingImageScrollView()
        scrollView.setImage(named: imageName)
        return scrollView
    }

    func updateUIView(
        _ scrollView: ZoomingImageScrollView,
        context: Context
    ) {
        scrollView.setImage(named: imageName)
    }
}

// MARK: - 原生图片缩放器

/// 专用于单张图片的 UIScrollView。
///
/// 图片视图保持原始像素尺寸，`zoomScale` 负责所有缩放。最小比例按当前容器
/// 完整容纳图片计算，最大比例为最小比例的五倍。容器尺寸变化（例如旋转设备）
/// 时重新完整显示并居中，避免旧偏移使图片跑出屏幕。
private final class ZoomingImageScrollView: UIScrollView, UIScrollViewDelegate {
    private let zoomedImageView = UIImageView()
    private var representedImageName: String?
    private var lastContainerSize = CGSize.zero

    override init(frame: CGRect) {
        super.init(frame: frame)

        delegate = self
        backgroundColor = .white
        showsHorizontalScrollIndicator = true
        showsVerticalScrollIndicator = true
        bounces = true
        bouncesZoom = true
        alwaysBounceHorizontal = false
        alwaysBounceVertical = false
        decelerationRate = .fast

        zoomedImageView.contentMode = .scaleAspectFit
        zoomedImageView.isUserInteractionEnabled = true
        addSubview(zoomedImageView)

        let doubleTap = UITapGestureRecognizer(
            target: self,
            action: #selector(handleDoubleTap(_:))
        )
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 只在资源名变化时重新设置图片，避免 SwiftUI 状态刷新导致缩放位置重置。
    func setImage(named imageName: String) {
        guard representedImageName != imageName else {
            return
        }

        guard let image = UIImage(named: imageName) else {
            assertionFailure("Missing image asset: \(imageName)")
            return
        }

        representedImageName = imageName
        zoomedImageView.image = image
        zoomedImageView.frame = CGRect(origin: .zero, size: image.size)
        contentSize = image.size

        // 强制下次布局重新计算完整显示比例。
        lastContainerSize = .zero
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        if bounds.size != lastContainerSize {
            lastContainerSize = bounds.size
            resetZoomLimitsAndShowEntireImage()
        }

        centerImageWhenSmallerThanViewport()
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        zoomedImageView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerImageWhenSmallerThanViewport()
    }

    /// 双击完整显示时，以触点为中心放大到 2.5 倍；再次双击则还原。
    @objc private func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
        guard minimumZoomScale > 0 else {
            return
        }

        if zoomScale > minimumZoomScale * 1.01 {
            setZoomScale(minimumZoomScale, animated: true)
            return
        }

        let targetScale = min(minimumZoomScale * 2.5, maximumZoomScale)
        let rawPoint = recognizer.location(in: zoomedImageView)
        let point = CGPoint(
            x: min(max(rawPoint.x, 0), zoomedImageView.bounds.width),
            y: min(max(rawPoint.y, 0), zoomedImageView.bounds.height)
        )
        let targetSize = CGSize(
            width: bounds.width / targetScale,
            height: bounds.height / targetScale
        )
        let targetRect = CGRect(
            x: point.x - targetSize.width / 2,
            y: point.y - targetSize.height / 2,
            width: targetSize.width,
            height: targetSize.height
        )

        zoom(to: targetRect, animated: true)
    }

    /// 按容器宽高计算完整显示比例，并将它作为新的最小比例。
    private func resetZoomLimitsAndShowEntireImage() {
        let imageSize = zoomedImageView.bounds.size

        guard
            bounds.width > 0,
            bounds.height > 0,
            imageSize.width > 0,
            imageSize.height > 0
        else {
            return
        }

        let widthScale = bounds.width / imageSize.width
        let heightScale = bounds.height / imageSize.height
        let fitScale = min(widthScale, heightScale)

        minimumZoomScale = fitScale
        maximumZoomScale = fitScale * 5
        setZoomScale(fitScale, animated: false)
        centerImageWhenSmallerThanViewport()
    }

    /// 使用 contentInset 把小于视口的图片放在正中央；放大超过视口后边距归零。
    private func centerImageWhenSmallerThanViewport() {
        let horizontalInset = max((bounds.width - contentSize.width) / 2, 0)
        let verticalInset = max((bounds.height - contentSize.height) / 2, 0)
        let centeredInsets = UIEdgeInsets(
            top: verticalInset,
            left: horizontalInset,
            bottom: verticalInset,
            right: horizontalInset
        )

        if contentInset != centeredInsets {
            contentInset = centeredInsets
        }
    }
}
