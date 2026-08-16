import Foundation

/// Sparse-bundle band size. hdiutil wants 512-byte sectors via
/// `sparse-band-size=N`. Valid range is 2048…16777216 sectors (1 MB…8 GB).
public enum BandSizePreset: String, CaseIterable, Identifiable, Hashable {
    case systemDefault
    case mb1, mb2, mb4, mb8, mb16, mb32, mb64, mb128, mb256, mb512
    case gb1, gb2, gb4, gb8
    case custom

    public var id: String { rawValue }

    public var megabytes: Int? {
        switch self {
        case .systemDefault, .custom: return nil
        case .mb1: return 1
        case .mb2: return 2
        case .mb4: return 4
        case .mb8: return 8
        case .mb16: return 16
        case .mb32: return 32
        case .mb64: return 64
        case .mb128: return 128
        case .mb256: return 256
        case .mb512: return 512
        case .gb1: return 1_024
        case .gb2: return 2_048
        case .gb4: return 4_096
        case .gb8: return 8_192
        }
    }

    public var title: String {
        switch self {
        case .systemDefault: return "System default (8 MB)"
        case .custom: return "Custom…"
        case .mb1: return "1 MB"
        case .mb2: return "2 MB"
        case .mb4: return "4 MB"
        case .mb8: return "8 MB"
        case .mb16: return "16 MB"
        case .mb32: return "32 MB"
        case .mb64: return "64 MB"
        case .mb128: return "128 MB"
        case .mb256: return "256 MB"
        case .mb512: return "512 MB"
        case .gb1: return "1 GB"
        case .gb2: return "2 GB"
        case .gb4: return "4 GB"
        case .gb8: return "8 GB"
        }
    }

    /// Presets shown when changing an existing bundle (no “system default”).
    public static var changeCases: [BandSizePreset] {
        allCases.filter { $0 != .systemDefault }
    }
}

public enum SparseBandSize {
    public static let minMegabytes = 1
    public static let maxMegabytes = 8_192
    public static let defaultMegabytes = 8
    public static let bytesPerSector: Int64 = 512
    public static let bytesPerMegabyte: Int64 = 1_024 * 1_024
    public static let minSectors: Int64 = 2_048
    public static let maxSectors: Int64 = 16_777_216

    public static func sectors(megabytes: Int) -> Int64 {
        Int64(megabytes) * bytesPerMegabyte / bytesPerSector
    }

    public static func megabytes(bytes: Int64) -> Int {
        guard bytes > 0 else { return 0 }
        return Int(bytes / bytesPerMegabyte)
    }

    public static func display(bytes: Int64) -> String {
        display(megabytes: megabytes(bytes: bytes))
    }

    public static func display(megabytes: Int) -> String {
        if megabytes <= 0 { return "unknown" }
        if megabytes % 1024 == 0 {
            return "\(megabytes / 1024) GB"
        }
        return "\(megabytes) MB"
    }

    public static func displaySectors(_ sectors: Int64) -> String {
        display(bytes: sectors * bytesPerSector)
    }

    public static func matchingPreset(bytes: Int64) -> BandSizePreset {
        let mb = megabytes(bytes: bytes)
        return BandSizePreset.allCases.first(where: { $0.megabytes == mb }) ?? .custom
    }

    /// `sectors` is nil to omit the image key (hdiutil default). `error` is set on failure.
    public static func resolve(preset: BandSizePreset, customMegabytes: String) -> (sectors: Int64?, error: String?) {
        switch preset {
        case .systemDefault:
            return (nil, nil)
        case .custom:
            let trimmed = customMegabytes.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let mb = Int(trimmed) else {
                return (nil, "Enter a whole number of megabytes for the band size.")
            }
            if let error = validate(megabytes: mb) {
                return (nil, error)
            }
            return (sectors(megabytes: mb), nil)
        default:
            guard let mb = preset.megabytes else {
                return (nil, "Choose a band size.")
            }
            if let error = validate(megabytes: mb) {
                return (nil, error)
            }
            return (sectors(megabytes: mb), nil)
        }
    }

    public static func validate(megabytes: Int) -> String? {
        guard (minMegabytes...maxMegabytes).contains(megabytes) else {
            return "Band size must be between 1 MB and 8 GB."
        }
        let value = sectors(megabytes: megabytes)
        guard (minSectors...maxSectors).contains(value) else {
            return "Band size must be between 1 MB and 8 GB."
        }
        return nil
    }
}

public enum SparseBundleInfo {
    public static func isSparseBundle(_ url: URL) -> Bool {
        url.lastPathComponent.lowercased().hasSuffix(".sparsebundle")
    }

    public static func infoPlistURL(for url: URL) -> URL {
        url.appendingPathComponent("Info.plist")
    }

    public static func readBandSizeBytes(at url: URL) -> Int64? {
        let plistURL = infoPlistURL(for: url)
        guard let data = try? Data(contentsOf: plistURL),
              let dict = try? PlistParsing.plistRoot(data) as? [String: Any]
        else { return nil }
        return int64(dict["band-size"])
    }

    public static func readVirtualSizeBytes(at url: URL) -> Int64? {
        let plistURL = infoPlistURL(for: url)
        guard let data = try? Data(contentsOf: plistURL),
              let dict = try? PlistParsing.plistRoot(data) as? [String: Any]
        else { return nil }
        return int64(dict["size"])
    }

    private static func int64(_ value: Any?) -> Int64? {
        switch value {
        case let n as Int64: return n
        case let n as Int: return Int64(n)
        case let n as NSNumber: return n.int64Value
        case let s as String: return Int64(s)
        default: return nil
        }
    }
}
