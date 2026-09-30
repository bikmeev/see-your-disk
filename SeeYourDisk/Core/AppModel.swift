import SwiftUI
import Observation

@Observable
final class AppModel {
    enum Phase { case idle, scanning, done }

    var phase: Phase = .idle
    var volume: VolumeInfo?
    var root: FileNode?
    var trail: [FileNode] = []          // navigation stack, last = current block
    var hovered: FileNode?
    var selected: FileNode?             // block picked on the map (nil = the current folder itself)
    var candidates: [Candidate] = []
    var selection: Set<String> = []     // candidates ticked for cleaning
    var pending: [Candidate]?           // waiting for the user's confirmation
    var scannedFiles = 0
    var scannedBytes: Int64 = 0
    var skippedDirs = 0
    var progress = 0.0
    var scanStart = Date()
    var gameActive = false
    var isCleaning = false
    var cleanDone = 0
    var cleanTotal = 0
    var cleanBytes: Int64 = 0
    var cleanCurrent = ""
    var lastResult: CleanResult?

    private var scanTask: Task<Void, Never>?

    var current: FileNode? { trail.last }

    var selectedCandidates: [Candidate] { candidates.filter { selection.contains($0.id) } }
    var selectedBytes: Int64 { selectedCandidates.reduce(0) { $0 + $1.size } }
    var safeCandidates: [Candidate] { candidates.filter { $0.safety == .safe } }
    var reclaimableSafe: Int64 { safeCandidates.reduce(0) { $0 + $1.size } }

    func startScan() {
        scanTask?.cancel()
        phase = .scanning
        scannedFiles = 0; scannedBytes = 0; skippedDirs = 0
        progress = 0; scanStart = Date()
        volume = VolumeInfo.read()
        let vol = volume
        scanTask = Task {
            let ctx = ScanContext()
            let poll = Task {
                while !Task.isCancelled {
                    let s = ctx.snapshot()
                    scannedFiles = s.files; scannedBytes = s.bytes; skippedDirs = s.skipped
                    // Estimate: nearly all used space gets read (a little is unreadable without Full Disk Access).
                    let expected = Double(max(Double(vol?.used ?? 0) * 0.92, 1_000_000_000))
                    // Real progress by bytes is stuck near 0 at first (big folders finish late), so blend in a
                    // slow time-based creep and ease the bar toward the target instead of jumping.
                    let elapsed = Date().timeIntervalSince(scanStart)
                    let creep = 0.85 * (1 - exp(-elapsed / 40))
                    let target = min(0.99, max(Double(s.bytes) / expected, creep))
                    progress = max(progress, progress + (target - progress) * 0.12)
                    try? await Task.sleep(for: .milliseconds(120))
                }
            }
            let rulesTask = Task.detached { await Cleanup.scanRules() }
            let output = await Task.detached { await DiskScanner.scan(ctx: ctx, volume: vol) }.value
            let rules = await rulesTask.value
            poll.cancel()
            guard !Task.isCancelled else { return }
            let large = Cleanup.largeFileCandidates(output.large, excluding: rules)
            let all = rules + large
            root = output.root
            trail = [output.root]
            selected = nil
            candidates = all
            selection = Set(all.filter { $0.safety == .safe }.map(\.id))
            skippedDirs = output.skipped
            progress = 1
            phase = .done
            if !NSApp.isActive { NSApp.requestUserAttention(.informationalRequest) }   // bounce the Dock icon
        }
    }

    func open(_ node: FileNode) {
        guard node.canDrill else { return }
        trail.append(node)
        hovered = nil
        selected = nil
    }

    func goTo(_ index: Int) {
        guard index < trail.count else { return }
        trail = Array(trail.prefix(index + 1))
        selected = nil
    }

    func back() { if trail.count > 1 { trail.removeLast(); selected = nil } }

    /// Cleanup candidates that live inside `node`, or that contain it.
    func candidates(in node: FileNode) -> [Candidate] {
        if node.id == "/" { return candidates }
        guard let p = node.url?.path else { return [] }
        return candidates.filter {
            let c = $0.url.path
            return c == p || c.hasPrefix(p + "/") || p.hasPrefix(c + "/")
        }
    }

    /// Ticks the safe items inside `node` and unticks the rest there.
    func autoSelect(in node: FileNode) {
        for c in candidates(in: node) {
            if c.safety == .safe { selection.insert(c.id) } else { selection.remove(c.id) }
        }
    }

    func deselect(in node: FileNode) {
        for c in candidates(in: node) { selection.remove(c.id) }
    }

    func toggle(_ c: Candidate) {
        guard c.safety != .protected else { return }
        if selection.contains(c.id) { selection.remove(c.id) } else { selection.insert(c.id) }
    }

    /// Asks for confirmation; `confirmPending()` performs the cleaning.
    func requestClean(_ items: [Candidate]) {
        let ok = items.filter { $0.safety != .protected }
        guard !ok.isEmpty, !isCleaning else { return }
        pending = ok
    }

    func confirmPending() {
        guard let items = pending else { return }
        pending = nil
        isCleaning = true
        lastResult = nil
        cleanDone = 0; cleanTotal = items.filter { $0.safety != .protected }.count; cleanBytes = 0; cleanCurrent = ""
        Task {
            let result = await Task.detached {
                Cleanup.clean(items) { done, total, bytes, current in
                    Task { @MainActor in
                        self.cleanDone = done; self.cleanTotal = total; self.cleanBytes = bytes; self.cleanCurrent = current
                    }
                }
            }.value
            // Reflect the result right away; the user rescans when they want fresh sizes.
            candidates.removeAll { result.removed.contains($0.id) }
            selection.subtract(result.removed)
            lastResult = result
            isCleaning = false
        }
    }

    func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

}

enum Palette {
    static func color(_ kind: NodeKind) -> Color {
        switch kind {
        case .systemData: return Color(red: 0.62, green: 0.55, blue: 1.0)
        case .developer: return Color(red: 0.30, green: 0.88, blue: 0.55)
        case .apps: return Color(red: 1.0, green: 0.62, blue: 0.22)
        case .documents: return Color(red: 1.0, green: 0.84, blue: 0.20)
        case .media: return Color(red: 1.0, green: 0.42, blue: 0.68)
        case .appData: return Color(red: 0.30, green: 0.68, blue: 1.0)
        case .system: return Color(red: 0.56, green: 0.64, blue: 0.76)
        case .other: return Color(red: 1.0, green: 0.36, blue: 0.36)
        }
    }

    static func label(_ kind: NodeKind) -> LocalizedStringKey {
        switch kind {
        case .systemData: return "System Data"
        case .developer: return "Developer"
        case .apps: return "Applications"
        case .documents: return "Documents"
        case .media: return "Media"
        case .appData: return "App data"
        case .system: return "macOS"
        case .other: return "Other users & shared"
        }
    }
}

extension FileNode {
    /// Localized, human-readable block name.
    var displayName: String {
        if id == "/" { return String(localized: "Your laptop") }
        if id == "#system" { return String(localized: "System Data") }
        if id.hasSuffix("#rest") { return String(localized: "Small items (\(name))") }
        return name
    }
}
