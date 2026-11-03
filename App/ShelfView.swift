import SwiftUI
import PocketCore

enum ShelfFilter: String, CaseIterable, Identifiable {
    case all = "ALL"
    case gb = "GB"
    case gbc = "GBC"
    case nes = "NES"
    case n64 = "64"

    var id: String { rawValue }

    func includes(_ cart: Cartridge) -> Bool {
        switch self {
        case .all: return true
        case .gb: return cart.era == .gb
        case .gbc: return cart.era == .gbc
        case .nes: return cart.era == .nes
        case .n64: return cart.era == .n64
        }
    }
}

struct ShelfView: View {
    @EnvironmentObject var hub: Hub
    @State private var filter: ShelfFilter = .all
    @State private var showSettings = false

    private var carts: [Cartridge] {
        return Library.all.filter { filter.includes($0) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Picker("Era", selection: $filter) {
                        ForEach(ShelfFilter.allCases) { f in
                            Text(f.rawValue).tag(f)
                        }
                    }
                    .pickerStyle(.segmented)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 14)], spacing: 14) {
                        ForEach(carts) { cart in
                            NavigationLink(value: cart) {
                                CartridgeCard(cart: cart, best: hub.highScores[cart.id] ?? 0)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Text("\(Library.all.count) cartridges")
                        .font(Retro.font(11, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.4))
                }
                .padding(16)
            }
            .background(Retro.background.ignoresSafeArea())
            .navigationTitle("PocketBoy")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            }
            .navigationDestination(for: Cartridge.self) { cart in
                CartridgeDetail(cart: cart)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView().environmentObject(hub)
        }
        .fullScreenCover(item: $hub.active) { cart in
            ConsoleView(cart: cart).environmentObject(hub)
        }
    }
}

/// A plastic cartridge with a coloured label.
struct CartridgeCard: View {
    let cart: Cartridge
    let best: Int
    var large: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(colors: [Color(hex: 0x9A9A9F), Color(hex: 0x6E6E75)], startPoint: .top, endPoint: .bottom))
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(cart.era.rawValue)
                            .font(Retro.font(large ? 12 : 10))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.black.opacity(0.35)))
                        Spacer()
                        Text(cart.genre.uppercased())
                            .font(Retro.font(large ? 10 : 8, weight: .bold))
                            .foregroundColor(Color.white.opacity(0.85))
                            .lineLimit(1)
                    }
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(LinearGradient(colors: [Color(hex: cart.labelTop), Color(hex: cart.labelBottom)], startPoint: .top, endPoint: .bottom))
                        Text(cart.title)
                            .font(Retro.font(large ? 24 : 15))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.6), radius: 0, x: 1, y: 1)
                            .minimumScaleFactor(0.6)
                            .padding(8)
                    }
                    .frame(height: large ? 130 : 78)
                    HStack {
                        Text("BEST")
                            .font(Retro.font(large ? 10 : 8, weight: .bold))
                            .foregroundColor(Color.white.opacity(0.7))
                        Text(best > 0 ? String(best) : "---")
                            .font(Retro.font(large ? 12 : 10))
                            .foregroundColor(.white)
                        Spacer()
                    }
                }
                .padding(10)
            }
            Rectangle()
                .fill(Color(hex: 0x4A4A50))
                .frame(height: 8)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .padding(.horizontal, 16)
        }
        .padding(.bottom, 6)
        .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 3)
    }
}

struct CartridgeDetail: View {
    @EnvironmentObject var hub: Hub
    let cart: Cartridge

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                CartridgeCard(cart: cart, best: hub.highScores[cart.id] ?? 0, large: true)
                    .frame(maxWidth: 340)
                VStack(alignment: .leading, spacing: 10) {
                    Text(cart.era.fullName.uppercased())
                        .font(Retro.font(11))
                        .foregroundColor(Color(hex: 0xB8E06A))
                    Text(cart.blurb)
                        .font(.body)
                        .foregroundColor(.white)
                    Text("CONTROLS")
                        .font(Retro.font(11))
                        .foregroundColor(Color.white.opacity(0.6))
                        .padding(.top, 4)
                    Text(cart.controls)
                        .font(.callout)
                        .foregroundColor(Color.white.opacity(0.85))
                }
                .frame(maxWidth: 340, alignment: .leading)
                Button {
                    hub.insert(cart)
                } label: {
                    Text("INSERT & PLAY")
                        .font(Retro.font(16))
                        .foregroundColor(.black)
                        .frame(maxWidth: 340)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: 0xB8E06A)))
                }
            }
            .padding(20)
        }
        .background(Retro.background.ignoresSafeArea())
        .navigationTitle(cart.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
