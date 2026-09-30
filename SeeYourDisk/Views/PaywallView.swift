import SwiftUI
import StoreKit
import AppKit

struct PaywallView: View {
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss
    private var store: Store { model.store }
    private var upgrading: Bool { store.plan == .monthly }

    @State private var upgradedNotice = false

    var body: some View {
        if upgradedNotice { notice } else { purchaseBody }
    }

    /// After moving from Monthly to Lifetime: the monthly plan keeps renewing until it is cancelled.
    private var notice: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 38)).foregroundStyle(.green)
            Text("You now have Lifetime").font(.title2.bold())
            Text("Your monthly subscription is still active. Cancel it in your Apple account so you are not charged again.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Manage subscription") {
                    if let u = URL(string: "https://apps.apple.com/account/subscriptions") { NSWorkspace.shared.open(u) }
                }
                Button("Done") { finish() }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
            }
            .controlSize(.large)
        }
        .padding(28)
        .frame(width: 400)
    }

    private var purchaseBody: some View {
        VStack(spacing: 18) {
            Image(systemName: "sparkles").font(.system(size: 34)).foregroundStyle(.tint)
            Text(upgrading ? "Upgrade to Lifetime" : "Keep your disk clean").font(.title.bold())
            Text(upgrading ? "Pay once and never pay monthly again." : "Get unlimited cleaning with See Your Disk Pro.")
                .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)

            if store.lifetime == nil && (upgrading || store.monthly == nil) {
                if store.loadFailed {
                    Text("Could not load prices.").foregroundStyle(.secondary)
                    Button("Try again") { Task { await store.load() } }
                } else {
                    ProgressView()
                }
            } else {
                VStack(spacing: 10) {
                    if let p = store.lifetime {
                        Button { buy(p) } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Lifetime").font(.headline)
                                    Text("Pay once, keep it forever").font(.caption)
                                }
                                Spacer()
                                Text(verbatim: p.displayPrice).font(.title3.weight(.semibold))
                            }
                            .padding(6)
                        }
                        .buttonStyle(.borderedProminent).controlSize(.large)
                    }
                    if !upgrading, let p = store.monthly {
                        Button { buy(p) } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Monthly").font(.headline)
                                    Text("Cancel any time").font(.caption)
                                }
                                Spacer()
                                Text("\(p.displayPrice) / month").font(.title3.weight(.semibold))
                            }
                            .padding(6)
                        }
                        .controlSize(.large)
                    }
                }
                .disabled(store.busy)
            }

            if let e = store.errorText { Text(verbatim: e).font(.caption).foregroundStyle(.red) }
            if store.busy { ProgressView().controlSize(.small) }

            HStack {
                Button("Restore purchases") { Task { if await store.restore() { finish() } } }
                Spacer()
                Button("Not now") { model.showPaywall = false; dismiss() }
            }
            .buttonStyle(.link).font(.callout)

            HStack(spacing: 14) {
                Link("Terms of Use", destination: AppLinks.terms)
                Link("Privacy Policy", destination: AppLinks.privacy)
            }
            .font(.caption)
                        Text("The subscription renews every month until you cancel it in your Apple account settings. Payment is charged to your Apple account.")
                .font(.caption2).foregroundStyle(.tertiary).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(28)
        .frame(width: 400)
    }

    private func buy(_ p: Product) {
        let wasMonthly = store.plan == .monthly
        Task {
            if await store.buy(p) {
                try? await Task.sleep(for: .milliseconds(250))
                if wasMonthly && p.id == Store.lifetimeID && store.monthlyActive { upgradedNotice = true } else { finish() }
            }
        }
    }

    private func finish() {
        model.paywallUnlocked()
        dismiss()
    }
}
