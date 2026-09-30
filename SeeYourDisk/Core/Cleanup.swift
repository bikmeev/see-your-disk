import Foundation

nonisolated enum Safety: Int, Sendable, Comparable {
    case safe, review, protected
    static func < (a: Safety, b: Safety) -> Bool { a.rawValue < b.rawValue }
}

nonisolated struct Candidate: Identifiable, Hashable, Sendable {
    var id: String { url.path }
    let url: URL
    let title: String        // shown verbatim (file / folder name)
    let group: String        // localization key
    let detail: String       // localization key
    let safety: Safety
    let permanent: Bool      // true = lives in Trash, can only be deleted for good
    var size: Int64
}

nonisolated struct CleanResult: Sendable {
    var freed: Int64 = 0
    var done = 0
    var failed = 0
    var movedToTrash = false
    var trashed: Int64 = 0
    var removed: Set<String> = []
}

nonisolated enum Cleanup {
    private enum Mode {
        case whole, children(minSize: Int64)
        var isWhole: Bool { if case .whole = self { return true } else { return false } }
    }
    private struct Rule {
        let path: String   // relative to home
        let mode: Mode
        let group: String
        let detail: String
        let safety: Safety
        var permanent = false
    }

    private static let mb: Int64 = 1024 * 1024

    private static let rules: [Rule] = [
        Rule(path: "Library/Caches", mode: .children(minSize: 10 * mb), group: "App caches",
             detail: "Apps rebuild this cache automatically the next time they run.", safety: .safe),
        Rule(path: "Library/Application Support/Google/GoogleUpdater/crx_cache", mode: .whole, group: "App caches",
             detail: "Downloaded Chrome update packages. Re-downloaded if needed.", safety: .safe),
        Rule(path: "Library/Logs", mode: .children(minSize: 1 * mb), group: "Logs & Trash",
             detail: "Old log files. Safe to remove.", safety: .safe),
        Rule(path: ".Trash", mode: .children(minSize: 0), group: "Logs & Trash",
             detail: "Already in the Trash. Removing it frees space permanently.", safety: .safe, permanent: true),
        Rule(path: "Library/Developer/Xcode/DerivedData", mode: .children(minSize: 1 * mb), group: "Developer",
             detail: "Xcode build products. Xcode regenerates them on the next build.", safety: .safe),
        Rule(path: "Library/Developer/Xcode/iOS DeviceSupport", mode: .children(minSize: 1 * mb), group: "Developer",
             detail: "Debug symbols for connected devices. Copied again when you plug the device in.", safety: .safe),
        Rule(path: "Library/Developer/CoreSimulator/Caches", mode: .whole, group: "Developer",
             detail: "Simulator caches. Rebuilt on demand.", safety: .safe),
        Rule(path: ".npm", mode: .whole, group: "Developer",
             detail: "npm download cache. Packages are downloaded again when needed.", safety: .safe),
        Rule(path: "Library/Developer/Xcode/Archives", mode: .children(minSize: 1 * mb), group: "Developer",
             detail: "App archives. Keep the ones you may still need to submit or symbolicate.", safety: .review),
        Rule(path: "Library/Developer/CoreSimulator/Devices", mode: .children(minSize: 50 * mb), group: "Developer",
             detail: "Simulator devices with their apps and data. Apps inside lose their data.", safety: .review),
        Rule(path: ".gradle/caches", mode: .whole, group: "Developer",
             detail: "Gradle dependency cache. Re-downloaded on the next build.", safety: .review),
        Rule(path: ".cache", mode: .children(minSize: 10 * mb), group: "Developer",
             detail: "Tool cache (for example AI models). Removing it means downloading again, which may be large.",
             safety: .review),
        Rule(path: "Library/Application Support/com.apple.wallpaper/aerials/videos", mode: .children(minSize: 10 * mb),
             group: "Other", detail: "Downloaded aerial wallpaper videos. macOS downloads them again on demand.",
             safety: .review),
        Rule(path: "Library/Containers/com.docker.docker/Data/vms", mode: .whole, group: "Protected",
             detail: "Docker's virtual disk. Do not delete it. Free space from Docker Desktop instead (Troubleshoot → Clean / Purge data or docker system prune).",
             safety: .protected),
    ]

    /// Sizes every rule location. Runs off the main thread.
    static func scanRules() async -> [Candidate] {
        let home = realHomeURL()
        var pending: [(URL, Rule)] = []
        for r in rules {
            let base = r.path.hasPrefix("/") ? URL(fileURLWithPath: r.path) : home.appendingPathComponent(r.path)
            switch r.mode {
            case .whole:
                if FileManager.default.fileExists(atPath: base.path) { pending.append((base, r)) }
            case .children:
                let kids = (try? FileManager.default.contentsOfDirectory(at: base, includingPropertiesForKeys: nil)) ?? []
                for k in kids where k.lastPathComponent != ".DS_Store" { pending.append((k, r)) }
            }
        }
        let sized = await withTaskGroup(of: Candidate?.self) { group in
            for (url, r) in pending {
                group.addTask {
                    let size = allocatedSize(of: url)
                    var minSize: Int64 = 1
                    if case .children(let m) = r.mode { minSize = max(m, 1) }
                    guard size >= minSize else { return nil }
                    let title = r.mode.isWhole ? url.path.replacingOccurrences(of: home.path + "/", with: "~/") : url.lastPathComponent
                    return Candidate(url: url, title: title, group: r.group, detail: r.detail,
                                     safety: r.safety, permanent: r.permanent, size: size)
                }
            }
            var out: [Candidate] = []
            for await c in group { if let c { out.append(c) } }
            return out
        }
        return sized.sorted { $0.size > $1.size }
    }

    /// Big files in the map that no rule already covers. Never auto-selected.
    static func largeFileCandidates(_ files: [LargeFile], excluding existing: [Candidate]) -> [Candidate] {
        let home = realHomeURL().path
        let roots = rules.map { home + "/" + $0.path + "/" }
        return files.compactMap { f in
            let p = f.url.path
            guard p.hasPrefix(home + "/"), !roots.contains(where: { p.hasPrefix($0) }),
                  !existing.contains(where: { p.hasPrefix($0.url.path + "/") || p == $0.url.path }) else { return nil }
            return Candidate(url: f.url, title: f.url.lastPathComponent, group: "Large files",
                             detail: "A large file of yours. Check that you no longer need it before removing.",
                             safety: .review, permanent: false, size: f.size)
        }
        .sorted { $0.size > $1.size }
    }

    static func allocatedSize(of url: URL) -> Int64 {
        let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isRegularFileKey]
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }
        if !isDir.boolValue {
            let v = try? url.resourceValues(forKeys: Set(keys))
            return Int64(v?.totalFileAllocatedSize ?? v?.fileAllocatedSize ?? 0)
        }
        guard let en = FileManager.default.enumerator(at: url, includingPropertiesForKeys: keys, options: []) else { return 0 }
        var total: Int64 = 0
        for case let f as URL in en {
            let v = try? f.resourceValues(forKeys: Set(keys))
            total += Int64(v?.totalFileAllocatedSize ?? v?.fileAllocatedSize ?? 0)
        }
        return total
    }

    /// Safe items (regenerable caches, logs) are deleted for good so the space is freed at once;
    /// everything else goes to the Trash and stays recoverable.
    static func clean(_ items: [Candidate],
                      progress: @Sendable (_ done: Int, _ total: Int, _ bytes: Int64, _ current: String) -> Void = { _, _, _, _ in }) -> CleanResult {
        let home = realHomeURL().path
        var result = CleanResult()
        let todo = items.filter { $0.safety != .protected }
        for (index, c) in todo.enumerated() {
            progress(index, todo.count, result.freed + result.trashed, c.title)
            let p = c.url.standardizedFileURL.path
            // Hard guard: only paths inside the Home folder (two levels deep, or a dot-folder like ~/.npm).
            guard p.hasPrefix(home + "/"),
                  p.dropFirst(home.count + 1).contains("/") || p.hasPrefix(home + "/.") else {
                result.failed += 1; continue
            }
            do {
                if c.safety == .safe || c.permanent {
                    try FileManager.default.removeItem(at: c.url)
                    result.freed += c.size
                } else {
                    try FileManager.default.trashItem(at: c.url, resultingItemURL: nil)
                    result.movedToTrash = true
                    result.trashed += c.size
                }
                result.done += 1
                result.removed.insert(c.id)
            } catch {
                result.failed += 1
            }
        }
        progress(todo.count, todo.count, result.freed + result.trashed, "")
        return result
    }
}
