import SwiftUI
import PocketCore

struct SettingsView: View {
    @EnvironmentObject var hub: Hub
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Display")) {
                    Picker("Color depth", selection: $hub.colorMode) {
                        Text("Color 15-bit").tag(true)
                        Text("Classic 2-bit").tag(false)
                    }
                    .pickerStyle(.segmented)
                    if !hub.colorMode {
                        Picker("LCD tint", selection: $hub.tint) {
                            ForEach(DMGTint.allCases) { tint in
                                Text(tint.name).tag(tint)
                            }
                        }
                    }
                    Toggle("LCD pixel grid", isOn: $hub.lcdGrid)
                }
                Section(header: Text("Console")) {
                    ShellPicker()
                    Toggle("Sound", isOn: $hub.soundOn)
                    Toggle("Haptics", isOn: $hub.haptics)
                }
                Section(header: Text("About")) {
                    Text("Every game here is original and runs on a built-in engine. Classic mode squeezes the picture to four shades like the first handhelds; Color mode uses 15-bit palettes like the Color model; 64 cartridges render in true color at double resolution.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct ShellPicker: View {
    @EnvironmentObject var hub: Hub

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Shell color: \(hub.shell.name)")
                .font(.subheadline)
            HStack(spacing: 12) {
                ForEach(ShellColor.allCases) { shell in
                    Circle()
                        .fill(shell.body)
                        .frame(width: 34, height: 34)
                        .overlay(
                            Circle().stroke(Color.white, lineWidth: hub.shell == shell ? 3 : 0)
                        )
                        .overlay(Circle().fill(shell.accent).frame(width: 10, height: 10))
                        .onTapGesture { hub.shell = shell }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
