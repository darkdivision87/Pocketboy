import SwiftUI
import UIKit
import PocketCore

/// Drives the console from a display link and shows its frame with crisp, nearest-neighbour scaling.
struct ScreenView: UIViewRepresentable {
    let hub: Hub

    func makeUIView(context: Context) -> ScreenUIView {
        return ScreenUIView(hub: hub)
    }

    func updateUIView(_ uiView: ScreenUIView, context: Context) {}
}

final class ScreenUIView: UIView {
    private let hub: Hub
    private var link: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var lastRender = -1
    private let colorSpace = CGColorSpaceCreateDeviceRGB()

    init(hub: Hub) {
        self.hub = hub
        super.init(frame: .zero)
        backgroundColor = .black
        isOpaque = true
        layer.magnificationFilter = .nearest
        layer.minificationFilter = .nearest
        layer.contentsGravity = .resize
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { startLink() } else { stopLink() }
    }

    private func startLink() {
        stopLink()
        lastTimestamp = 0
        lastRender = -1
        let newLink = CADisplayLink(target: self, selector: #selector(step(_:)))
        newLink.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        newLink.add(to: .main, forMode: .common)
        link = newLink
    }

    private func stopLink() {
        link?.invalidate()
        link = nil
    }

    @objc private func step(_ displayLink: CADisplayLink) {
        let now = displayLink.timestamp
        let dt: Double = lastTimestamp == 0 ? 1.0 / 60.0 : now - lastTimestamp
        lastTimestamp = now
        hub.runFrame(dt: dt)
        present()
    }

    private func present() {
        let console = hub.console
        if console.renderCount == lastRender { return }
        lastRender = console.renderCount
        let w = console.screenWidth
        let h = console.screenHeight
        if console.frame.count != w * h { return }
        let data = console.frame.withUnsafeBufferPointer { Data(buffer: $0) }
        guard let provider = CGDataProvider(data: data as CFData) else { return }
        let info = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)
        guard let image = CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32,
                                  bytesPerRow: w * 4, space: colorSpace, bitmapInfo: info,
                                  provider: provider, decode: nil, shouldInterpolate: false,
                                  intent: .defaultIntent) else { return }
        layer.contents = image
    }
}

/// Faint dot-matrix grid laid over the screen.
struct LCDGridOverlay: View {
    var columns: Int = 160
    var rows: Int = 144

    var body: some View {
        Canvas { context, size in
            var path = Path()
            let cw = size.width / CGFloat(columns)
            let ch = size.height / CGFloat(rows)
            if cw >= 1.6 && ch >= 1.6 {
                for i in 1..<columns {
                    let x = CGFloat(i) * cw
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                }
                for j in 1..<rows {
                    let y = CGFloat(j) * ch
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }
            }
            context.stroke(path, with: .color(Color.black.opacity(0.13)), lineWidth: 0.6)
        }
        .allowsHitTesting(false)
    }
}
