import SwiftUI
import AppKit

/// Gear button in the title bar: license, support.
struct SettingsMenu: View {
    @Bindable var model: AppModel
    private var store: Store { model.store }

    var body: some View {
        Menu {
            switch store.plan {
            case .lifetime:
                Text("License: Lifetime")
                if store.monthlyActive {
                    Button("Cancel monthly subscription…") { open("https://apps.apple.com/account/subscriptions") }
                }
            case .monthly:
                Text("License: Monthly subscription")
                Button("Upgrade to Lifetime…") { model.showPaywall = true }
                Button("Manage subscription…") { open("https://apps.apple.com/account/subscriptions") }
            case nil:
                Text("License: none")
                Button("Buy license…") { model.showPaywall = true }
            }
            Button("Restore purchases") { Task { _ = await store.restore() } }
            Divider()
            Button("Support…") {
                open("mailto:\(AppLinks.support)?subject=See%20Your%20Disk%20support")
            }
            Button("Privacy Policy") { NSWorkspace.shared.open(AppLinks.privacy) }
            Button("Terms of Use") { NSWorkspace.shared.open(AppLinks.terms) }
        } label: {
            Image(systemName: "gearshape")
        }
        .menuIndicator(.hidden)
        .help("Settings")
    }

    private func open(_ s: String) {
        if let u = URL(string: s) { NSWorkspace.shared.open(u) }
    }
}
