import SwiftUI
import PocketCore

/// The handheld itself: bezel, screen, D-pad, buttons.
struct ConsoleView: View {
    @EnvironmentObject var hub: Hub
    let cart: Cartridge
    @State private var showSettings = false

    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height
            ZStack {
                LinearGradient(colors: [hub.shell.body, hub.shell.bodyShade], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                if landscape {
                    LandscapeBody(cart: cart, size: geo.size, insets: geo.safeAreaInsets, menu: openMenu)
                } else {
                    PortraitBody(cart: cart, size: geo.size, insets: geo.safeAreaInsets, menu: openMenu)
                }
                if hub.menuOpen {
                    MenuOverlay(cart: cart, showSettings: $showSettings)
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.15), value: hub.menuOpen)
        }
        .ignoresSafeArea()
        .statusBar(hidden: true)
        .sheet(isPresented: $showSettings) {
            SettingsView().environmentObject(hub)
        }
    }

    private func openMenu() {
        hub.menuOpen = true
    }
}

struct ScreenBezel: View {
    @EnvironmentObject var hub: Hub

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(hex: 0xE23B3B))
                    .frame(width: 6, height: 6)
                    .shadow(color: Color.red.opacity(0.8), radius: 3)
                Text("BATTERY")
                    .font(Retro.font(7, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.55))
                Spacer()
                Text("PIXEL MATRIX + STEREO SOUND")
                    .font(Retro.font(7, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.55))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            ScreenView(hub: hub)
                .aspectRatio(10.0 / 9.0, contentMode: .fit)
                .overlay(LCDGridOverlay().opacity(hub.lcdGrid ? 1 : 0))
                .overlay(
                    Rectangle().stroke(Color.black.opacity(0.6), lineWidth: 2)
                )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: 0x4A4C5A))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.4), lineWidth: 1))
        )
    }
}

struct MenuChip: View {
    @EnvironmentObject var hub: Hub
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: "line.3.horizontal")
                Text("MENU")
            }
            .font(Retro.font(11))
            .foregroundColor(hub.shell.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.black.opacity(0.18)))
        }
    }
}

struct PortraitBody: View {
    @EnvironmentObject var hub: Hub
    let cart: Cartridge
    let size: CGSize
    let insets: EdgeInsets
    let menu: () -> Void

    var body: some View {
        let pad: CGFloat = 16
        let dpad = min(size.width * 0.36, 150)
        let button = dpad * 0.5
        VStack(spacing: 0) {
            HStack {
                Text("POCKETBOY")
                    .font(.system(size: 15, weight: .black, design: .rounded).italic())
                    .foregroundColor(hub.shell.ink)
                Spacer()
                MenuChip(action: menu)
            }
            .padding(.horizontal, pad + 4)
            .padding(.top, max(insets.top, 10) + 4)
            ScreenBezel()
                .padding(.horizontal, pad)
                .padding(.top, 8)
            Spacer(minLength: 10)
            HStack(alignment: .center) {
                DPadView(size: dpad)
                Spacer()
                ZStack {
                    RoundButton(label: "B", button: .b, diameter: button)
                        .offset(x: -button * 0.62, y: button * 0.42)
                    RoundButton(label: "A", button: .a, diameter: button)
                        .offset(x: button * 0.62, y: -button * 0.42)
                }
                .frame(width: button * 2.5, height: button * 1.9)
            }
            .padding(.horizontal, pad + 8)
            Spacer(minLength: 6)
            HStack(spacing: 22) {
                PillButton(label: "SELECT", button: .select)
                PillButton(label: "START", button: .start)
            }
            Spacer(minLength: 6)
            HStack {
                Spacer()
                SpeakerGrille()
                    .frame(width: 60, height: 56)
                    .padding(.trailing, 30)
            }
            .padding(.bottom, max(insets.bottom, 8))
        }
    }
}

struct LandscapeBody: View {
    @EnvironmentObject var hub: Hub
    let cart: Cartridge
    let size: CGSize
    let insets: EdgeInsets
    let menu: () -> Void

    var body: some View {
        let dpad = min(size.height * 0.5, 150)
        let button = dpad * 0.5
        HStack(spacing: 0) {
            VStack(spacing: 6) {
                Spacer()
                DPadView(size: dpad)
                PillButton(label: "SELECT", button: .select)
                Spacer()
            }
            .frame(width: max(size.width * 0.2, dpad + 20))
            VStack(spacing: 6) {
                HStack {
                    Text("POCKETBOY")
                        .font(.system(size: 13, weight: .black, design: .rounded).italic())
                        .foregroundColor(hub.shell.ink)
                    Spacer()
                    MenuChip(action: menu)
                }
                ScreenBezel()
                    .frame(maxHeight: .infinity)
            }
            .padding(.vertical, max(insets.top, 8) + 4)
            VStack(spacing: 6) {
                Spacer()
                ZStack {
                    RoundButton(label: "B", button: .b, diameter: button)
                        .offset(x: -button * 0.62, y: button * 0.42)
                    RoundButton(label: "A", button: .a, diameter: button)
                        .offset(x: button * 0.62, y: -button * 0.42)
                }
                .frame(width: button * 2.5, height: button * 1.9)
                PillButton(label: "START", button: .start)
                Spacer()
            }
            .frame(width: max(size.width * 0.2, dpad + 20))
        }
        .padding(.leading, max(insets.leading, 8))
        .padding(.trailing, max(insets.trailing, 8))
    }
}

struct MenuOverlay: View {
    @EnvironmentObject var hub: Hub
    let cart: Cartridge
    @Binding var showSettings: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 14) {
                Text(cart.title)
                    .font(Retro.font(18))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                Text("BEST \(hub.highScores[cart.id] ?? 0)")
                    .font(Retro.font(12, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.7))
                menuButton("RESUME", primary: true) { hub.menuOpen = false }
                menuButton("RESTART", primary: false) { hub.restart() }
                menuButton("SETTINGS", primary: false) { showSettings = true }
                menuButton("EJECT CARTRIDGE", primary: false) { hub.eject() }
            }
            .padding(24)
            .frame(maxWidth: 320)
            .background(RoundedRectangle(cornerRadius: 18).fill(Retro.card))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.15), lineWidth: 1))
            .padding(24)
        }
    }

    private func menuButton(_ title: String, primary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Retro.font(14))
                .foregroundColor(primary ? Color.black : Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(primary ? Color(hex: 0xB8E06A) : Color.white.opacity(0.1))
                )
        }
    }
}
