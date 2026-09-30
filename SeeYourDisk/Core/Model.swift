import Foundation

nonisolated enum NodeKind: String, Sendable {
    /// `systemData` = "System Data" in macOS Settings (caches, logs, /Library, /private…); `system` = macOS itself.
    case systemData, developer, apps, documents, media, appData, system, other
}

/// One block of the disk map. Directories keep only their significant children;
/// the rest is folded into a synthetic "smaller items" leaf.
nonisolated final class FileNode: Identifiable, @unchecked Sendable {
    let id: String
    let name: String
    let url: URL?
    var size: Int64
    let isDirectory: Bool
    let kind: NodeKind
    var children: [FileNode]
    let synthetic: Bool
    /// For a folded "small items" block: what is inside (largest first).
    var folded: [(name: String, size: Int64)] = []

    init(id: String, name: String, url: URL?, size: Int64, isDirectory: Bool,
         kind: NodeKind, children: [FileNode] = [], synthetic: Bool = false) {
        self.id = id
        self.name = name
        self.url = url
        self.size = size
        self.isDirectory = isDirectory
        self.kind = kind
        self.children = children
        self.synthetic = synthetic
    }

    var canDrill: Bool { !synthetic && !children.isEmpty }
}

nonisolated struct VolumeInfo: Sendable {
    let total: Int64
    let used: Int64
    var free: Int64 { max(0, total - used) }

    static func read() -> VolumeInfo? {
        let url = URL(fileURLWithPath: "/")
        guard let v = try? url.resourceValues(forKeys: [.volumeTotalCapacityKey,
                                                        .volumeAvailableCapacityForImportantUsageKey]),
              let total = v.volumeTotalCapacity,
              let free = v.volumeAvailableCapacityForImportantUsage else { return nil }
        return VolumeInfo(total: Int64(total), used: Int64(total) - free)
    }
}

nonisolated func formatBytes(_ bytes: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
}
