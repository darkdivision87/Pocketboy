import SwiftUI
import PocketCore

struct DPadView: View {
    @EnvironmentObject var hub: Hub
    let size: CGFloat
    @State private var current: Buttons = []

    var body: some View {
        let arm = size / 3
        ZStack {
            DPadShape()
                .fill(Color(hex: 0x24242C))
            DPadShape()
                .stroke(Color.black.opacity(0.5), lineWidth: 1)
            Circle()
                .fill(Color.black.opacity(0.25))
                .frame(width: arm * 0.62, height: arm * 0.62)
            arrow("arrowtriangle.up.fill", highlighted: current.contains(.up))
                .offset(y: -arm * 0.95)
            arrow("arrowtriangle.down.fill", highlighted: current.contains(.down))
                .offset(y: arm * 0.95)
            arrow("arrowtriangle.left.fill", highlighted: current.contains(.left))
                .offset(x: -arm * 0.95)
            arrow("arrowtriangle.right.fill", highlighted: current.contains(.right))
                .offset(x: arm * 0.95)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 3)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in update(value.location) }
                .onEnded { _ in update(nil) }
        )
    }

    private func arrow(_ name: String, highlighted: Bool) -> some View {
        Image(systemName: name)
            .font(.system(size: size * 0.1))
            .foregroundColor(highlighted ? Color.white : Color.white.opacity(0.28))
    }

    private func update(_ point: CGPoint?) {
        var next: Buttons = []
        if let p = point {
            let dx = p.x - size / 2
            let dy = p.y - size / 2
            let dead = size * 0.1
            let ax = abs(dx)
            let ay = abs(dy)
            if ax > dead || ay > dead {
                let horizontal = ax > ay * 0.45
                let vertical = ay > ax * 0.45
                if horizontal { next.insert(dx > 0 ? .right : .left) }
                if vertical { next.insert(dy > 0 ? .down : .up) }
            }
        }
        if next != current {
            current = next
            hub.touchDirection(next)
        }
    }
}

struct DPadShape: Shape {
    func path(in rect: CGRect) -> Path {
        let a = rect.width / 3
        let r: CGFloat = a * 0.18
        var path = Path()
        path.addRoundedRect(in: CGRect(x: rect.minX + a, y: rect.minY, width: a, height: rect.height),
                            cornerSize: CGSize(width: r, height: r))
        path.addRoundedRect(in: CGRect(x: rect.minX, y: rect.minY + a, width: rect.width, height: a),
                            cornerSize: CGSize(width: r, height: r))
        return path
    }
}

/// The big A / B buttons.
struct RoundButton: View {
    @EnvironmentObject var hub: Hub
    let label: String
    let button: Buttons
    let diameter: CGFloat
    @State private var down = false

    var body: some View {
        ZStack {
            Circle()
                .fill(hub.shell.accent)
                .overlay(Circle().stroke(Color.black.opacity(0.35), lineWidth: 1.5))
                .shadow(color: .black.opacity(down ? 0.1 : 0.4), radius: down ? 1 : 4, x: 0, y: down ? 1 : 4)
            Circle()
                .fill(LinearGradient(colors: [Color.white.opacity(0.28), Color.clear], startPoint: .top, endPoint: .center))
                .padding(3)
            Text(label)
                .font(Retro.font(diameter * 0.3))
                .foregroundColor(Color.black.opacity(0.35))
        }
        .frame(width: diameter, height: diameter)
        .scaleEffect(down ? 0.93 : 1)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !down {
                        down = true
                        hub.touch(button, down: true)
                    }
                }
                .onEnded { _ in
                    down = false
                    hub.touch(button, down: false)
                }
        )
    }
}

/// START / SELECT pills.
struct PillButton: View {
    @EnvironmentObject var hub: Hub
    let label: String
    let button: Buttons
    @State private var down = false

    var body: some View {
        VStack(spacing: 4) {
            Capsule()
                .fill(Color(hex: 0x5A5A66))
                .frame(width: 48, height: 14)
                .overlay(Capsule().stroke(Color.black.opacity(0.4), lineWidth: 1))
                .scaleEffect(down ? 0.94 : 1)
                .brightness(down ? -0.15 : 0)
            Text(label)
                .font(Retro.font(9))
                .foregroundColor(hub.shell.ink)
        }
        .padding(8)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !down {
                        down = true
                        hub.touch(button, down: true)
                    }
                }
                .onEnded { _ in
                    down = false
                    hub.touch(button, down: false)
                }
        )
        .rotationEffect(.degrees(-25))
    }
}

struct SpeakerGrille: View {
    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<6, id: \.self) { _ in
                Capsule()
                    .fill(Color.black.opacity(0.28))
                    .frame(width: 4, height: 36)
            }
        }
        .rotationEffect(.degrees(25))
    }
}
