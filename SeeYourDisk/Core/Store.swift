import StoreKit
import Security

/// In-App Purchases (StoreKit 2): monthly subscription and lifetime unlock.
@Observable
final class Store {
    static let monthlyID = "SeeYourDisk.monthly"
    static let lifetimeID = "SeeYourDisk.lifetime"

    var products: [Product] = []
    enum Plan { case monthly, lifetime }
    var plan: Plan?
    var isPro: Bool { plan != nil }
    var monthlyActive = false     // a monthly subscription is still running (matters once Lifetime is owned)
    var busy = false
    var loadFailed = false
    var errorText: String?

    private var updatesTask: Task<Void, Never>?
    private var sessionPlan: Plan?   // set right after a verified purchase, in case the entitlement list lags

    init() {
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let t) = result { await t.finish() }
                await self?.refresh()
            }
        }
        Task { await load(); await refresh() }
    }

    var monthly: Product? { products.first { $0.id == Self.monthlyID } }
    var lifetime: Product? { products.first { $0.id == Self.lifetimeID } }

    func load() async {
        do {
            products = try await Product.products(for: [Self.monthlyID, Self.lifetimeID])
            loadFailed = products.isEmpty
        } catch {
            loadFailed = true
        }
    }

    func refresh() async {
        var found: Plan?
        var seen = 0
        for await result in Transaction.currentEntitlements {
            seen += 1
            switch result {
            case .verified(let t):
                print("[Store] entitlement", t.productID, "revoked:", t.revocationDate as Any)
                guard t.revocationDate == nil else { continue }
                if t.productID == Self.lifetimeID { found = .lifetime }
                else if t.productID == Self.monthlyID, found == nil { found = .monthly }
            case .unverified(let t, let error):
                print("[Store] UNVERIFIED entitlement", t.productID, error)
            }
        }
        if found == nil {
            // Fallback: ask for the latest transaction of each product directly.
            for id in [Self.lifetimeID, Self.monthlyID] {
                guard let latest = await Transaction.latest(for: id), case .verified(let t) = latest,
                      t.revocationDate == nil else { continue }
                print("[Store] latest transaction", id, "expires:", t.expirationDate as Any)
                if id == Self.lifetimeID { found = .lifetime; break }
                if let exp = t.expirationDate, exp > Date() { found = .monthly }
            }
        }
        if let latest = await Transaction.latest(for: Self.monthlyID), case .verified(let t) = latest,
           t.revocationDate == nil, let exp = t.expirationDate, exp > Date() {
            monthlyActive = true
        } else {
            monthlyActive = false
        }
        print("[Store] refresh: \(seen) entitlements, plan =", found as Any, "session =", sessionPlan as Any)
        plan = found ?? sessionPlan
    }

    /// Returns true when the user ends up with Pro.
    func buy(_ product: Product) async -> Bool {
        busy = true; errorText = nil
        defer { busy = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                switch verification {
                case .verified(let t):
                    await t.finish()
                    sessionPlan = t.productID == Self.lifetimeID ? .lifetime : (sessionPlan ?? .monthly)
                    await refresh()
                    return true
                case .unverified(let t, let error):
                    print("[Store] UNVERIFIED purchase", t.productID, error)
                    errorText = String(localized: "The purchase could not be verified.")
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            errorText = error.localizedDescription
        }
        return false
    }

    func restore() async -> Bool {
        busy = true; errorText = nil
        defer { busy = false }
        try? await AppStore.sync()
        await refresh()
        if !isPro { errorText = String(localized: "No purchases to restore.") }
        return isPro
    }
}

/// How many cleanings were done for free. Kept in the Keychain so reinstalling does not reset it.
nonisolated enum FreeCleans {
    private static let service = "SeeYourDisk.freeCleans"
    private static let account = "count"

    static func count() -> Int {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrService as String: service, kSecAttrAccount as String: account,
                                kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data,
              let n = Int(String(decoding: d, as: UTF8.self)) else { return 0 }
        return n
    }

    static func increment() {
        let data = Data(String(count() + 1).utf8)
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                   kSecAttrService as String: service, kSecAttrAccount as String: account]
        if SecItemUpdate(base as CFDictionary, [kSecValueData as String: data] as CFDictionary) == errSecItemNotFound {
            SecItemAdd(base.merging([kSecValueData as String: data]) { $1 } as CFDictionary, nil)
        }
    }
}
