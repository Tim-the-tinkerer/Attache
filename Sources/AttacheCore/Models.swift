import Foundation

public enum SidebarItem: String, CaseIterable, Identifiable, Hashable {
    case attached
    case attach
    case create
    case convert
    case inspect
    case compact
    case bands
    case resize
    case checksum
    case hybrid

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .attached: return "Home"
        case .attach: return "Attach"
        case .create: return "Create"
        case .convert: return "Convert"
        case .inspect: return "Inspect"
        case .compact: return "Compact"
        case .bands: return "Band Size"
        case .resize: return "Resize"
        case .checksum: return "Checksum"
        case .hybrid: return "Hybrid ISO"
        }
    }

    /// Plain-language line for the home cards and sidebar.
    public var summary: String {
        switch self {
        case .attached: return "Overview and mounted images"
        case .attach: return "Mount a .dmg, .iso, or sparse image"
        case .create: return "New blank image, or from a folder"
        case .convert: return "Change image format"
        case .inspect: return "Read metadata and verify"
        case .compact: return "Reclaim unused sparse space"
        case .bands: return "Change sparse-bundle band size"
        case .resize: return "Grow or shrink an image"
        case .checksum: return "Hash the image file"
        case .hybrid: return "Build an HFS+ / ISO hybrid"
        }
    }

    public static var actions: [SidebarItem] {
        allCases.filter { $0 != .attached }
    }

    public var systemImage: String {
        switch self {
        case .attached: return "internaldrive"
        case .attach: return "externaldrive.badge.plus"
        case .create: return "plus.rectangle.on.folder"
        case .convert: return "arrow.triangle.2.circlepath"
        case .inspect: return "magnifyingglass"
        case .compact: return "arrow.down.right.and.arrow.up.left"
        case .bands: return "square.grid.3x3"
        case .resize: return "arrow.left.and.right.square"
        case .checksum: return "number.square"
        case .hybrid: return "opticaldisc"
        }
    }

    public var subtitle: String {
        switch self {
        case .attached: return "Overview"
        case .attach: return "hdiutil attach"
        case .create: return "hdiutil create"
        case .convert: return "hdiutil convert"
        case .inspect: return "imageinfo / verify"
        case .compact: return "hdiutil compact"
        case .bands: return "sparse-band-size"
        case .resize: return "hdiutil resize"
        case .checksum: return "hdiutil checksum"
        case .hybrid: return "hdiutil makehybrid"
        }
    }

    public var section: SidebarSection {
        switch self {
        case .attached:
            return .status
        case .attach, .create, .convert, .inspect:
            return .images
        case .compact, .bands, .resize, .checksum:
            return .maintain
        case .hybrid:
            return .disc
        }
    }
}

public enum SidebarSection: String, CaseIterable, Identifiable {
    case status = "Start"
    case images = "Images"
    case maintain = "Maintain"
    case disc = "Disc"

    public var id: String { rawValue }

    public var items: [SidebarItem] {
        SidebarItem.allCases.filter { $0.section == self }
    }
}

public enum ImageFormat: String, CaseIterable, Identifiable, Hashable {
    case udzo = "UDZO"
    case ulfo = "ULFO"
    case ulmo = "ULMO"
    case udro = "UDRO"
    case udrw = "UDRW"
    case udsp = "UDSP"
    case udsb = "UDSB"
    case udto = "UDTO"
    case udco = "UDCO"
    case ufbi = "UFBI"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .udzo: return "Compressed (zlib)"
        case .ulfo: return "Compressed (lzfse)"
        case .ulmo: return "Compressed (lzma)"
        case .udro: return "Read-only"
        case .udrw: return "Read/write"
        case .udsp: return "Sparse image"
        case .udsb: return "Sparse bundle"
        case .udto: return "DVD/CD master"
        case .udco: return "Compressed (ADC)"
        case .ufbi: return "Entire device"
        }
    }

    public var detail: String {
        switch self {
        case .udzo: return "Default compressed DMG. Best compatibility."
        case .ulfo: return "Faster compression than zlib. macOS 10.11+."
        case .ulmo: return "Smallest files, slower. macOS 10.15+."
        case .udro: return "Uncompressed read-only UDIF."
        case .udrw: return "Read/write UDIF. Grows to the full size on disk."
        case .udsp: return "Single-file sparse image that grows with data."
        case .udsb: return "Directory-backed sparse bundle (Time Machine style). Band size is configurable."
        case .udto: return "Optical master (.cdr) for burning."
        case .udco: return "Older ADC compression."
        case .ufbi: return "Full device image, no compression."
        }
    }

    public var fileExtension: String {
        switch self {
        case .udsp: return "sparseimage"
        case .udsb: return "sparsebundle"
        case .udto: return "cdr"
        default: return "dmg"
        }
    }

    public static var convertCases: [ImageFormat] { allCases }

    public static var folderCreateCases: [ImageFormat] {
        [.udzo, .ulfo, .ulmo, .udro, .udrw, .udsp, .udsb, .udto]
    }
}

public enum BlankImageType: String, CaseIterable, Identifiable, Hashable {
    case udif = "UDIF"
    case sparse = "SPARSE"
    case sparsebundle = "SPARSEBUNDLE"
    case udto = "UDTO"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .udif: return "Read/write disk image"
        case .sparse: return "Sparse image"
        case .sparsebundle: return "Sparse bundle"
        case .udto: return "DVD/CD master"
        }
    }

    public var fileExtension: String {
        switch self {
        case .udif: return "dmg"
        case .sparse: return "sparseimage"
        case .sparsebundle: return "sparsebundle"
        case .udto: return "cdr"
        }
    }
}

public enum DiskFilesystem: String, CaseIterable, Identifiable, Hashable {
    case apfs = "APFS"
    case apfsCase = "Case-sensitive APFS"
    case hfsJournaled = "Journaled HFS+"
    case hfs = "HFS+"
    case hfsCaseJournaled = "Case-sensitive Journaled HFS+"
    case exfat = "ExFAT"
    case fat32 = "MS-DOS FAT32"
    case fat16 = "MS-DOS FAT16"
    case udf = "UDF"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .apfs: return "APFS"
        case .apfsCase: return "APFS (Case-sensitive)"
        case .hfsJournaled: return "Mac OS Extended (Journaled)"
        case .hfs: return "Mac OS Extended"
        case .hfsCaseJournaled: return "Mac OS Extended (Case-sensitive, Journaled)"
        case .exfat: return "ExFAT"
        case .fat32: return "MS-DOS (FAT32)"
        case .fat16: return "MS-DOS (FAT16)"
        case .udf: return "UDF"
        }
    }
}

public enum SizeUnit: String, CaseIterable, Identifiable, Hashable {
    case megabytes = "m"
    case gigabytes = "g"
    case terabytes = "t"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .megabytes: return "MB"
        case .gigabytes: return "GB"
        case .terabytes: return "TB"
        }
    }

    public func spec(_ amount: String) -> String {
        "\(amount)\(rawValue)"
    }
}

public enum EncryptionChoice: String, CaseIterable, Identifiable, Hashable {
    case none = "None"
    case aes128 = "AES-128"
    case aes256 = "AES-256"

    public var id: String { rawValue }

    public var title: String { rawValue }

    public var argument: String? {
        switch self {
        case .none: return nil
        case .aes128: return "AES-128"
        case .aes256: return "AES-256"
        }
    }
}

public enum ChecksumType: String, CaseIterable, Identifiable, Hashable {
    case sha256 = "SHA256"
    case sha512 = "SHA512"
    case sha1 = "SHA1"
    case md5 = "MD5"
    case crc32 = "CRC32"
    case udifCRC = "UDIF-CRC32"
    case udifMD5 = "UDIF-MD5"

    public var id: String { rawValue }

    public var title: String { rawValue }
}

public enum CreateMode: String, CaseIterable, Identifiable, Hashable {
    case blank
    case folder
    case device

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .blank: return "Blank image"
        case .folder: return "From folder"
        case .device: return "From device"
        }
    }
}

public struct AttachedImage: Identifiable, Equatable, Sendable {
    public var imagePath: String
    public var imageType: String?
    public var wholeDisk: String?
    public var mountPoints: [String]
    public var devices: [String]

    public var id: String { imagePath + "|" + (wholeDisk ?? "") }

    public init(
        imagePath: String,
        imageType: String? = nil,
        wholeDisk: String? = nil,
        mountPoints: [String] = [],
        devices: [String] = []
    ) {
        self.imagePath = imagePath
        self.imageType = imageType
        self.wholeDisk = wholeDisk
        self.mountPoints = mountPoints
        self.devices = devices
    }

    public var displayName: String {
        URL(fileURLWithPath: imagePath).lastPathComponent
    }

    public var detachTarget: String? {
        if let wholeDisk, !wholeDisk.isEmpty { return wholeDisk }
        if let first = devices.first, !first.isEmpty { return first }
        return mountPoints.first
    }

    public var primaryMount: String? { mountPoints.first }
}

public struct DiskDevice: Identifiable, Equatable, Sendable, Hashable {
    public var id: String { bsdName }
    public var bsdName: String
    public var name: String
    public var sizeBytes: Int64
    public var isInternal: Bool

    public init(bsdName: String, name: String, sizeBytes: Int64, isInternal: Bool) {
        self.bsdName = bsdName
        self.name = name
        self.sizeBytes = sizeBytes
        self.isInternal = isInternal
    }

    public var devicePath: String {
        bsdName.hasPrefix("/dev/") ? bsdName : "/dev/\(bsdName)"
    }

    public var sizeLabel: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
}

public struct ResizeLimits: Equatable, Sendable {
    public var minSectors: Int64
    public var currentSectors: Int64
    public var maxSectors: Int64

    public init(minSectors: Int64, currentSectors: Int64, maxSectors: Int64) {
        self.minSectors = minSectors
        self.currentSectors = currentSectors
        self.maxSectors = maxSectors
    }

    public var minBytes: Int64 { minSectors * 512 }
    public var currentBytes: Int64 { currentSectors * 512 }
    public var maxBytes: Int64 { maxSectors * 512 }
}

public struct InfoRow: Identifiable, Equatable, Sendable {
    public var id: String
    public var key: String
    public var value: String
    public var level: Int

    public init(id: String, key: String, value: String, level: Int) {
        self.id = id
        self.key = key
        self.value = value
        self.level = level
    }
}

public struct HDIRequest: Equatable, Sendable {
    public var verb: String
    public var arguments: [String]
    public var password: String?
    public var wantsPlist: Bool
    public var wantsProgress: Bool

    public init(
        verb: String,
        arguments: [String] = [],
        password: String? = nil,
        wantsPlist: Bool = false,
        wantsProgress: Bool = false
    ) {
        self.verb = verb
        self.arguments = arguments
        self.password = password
        self.wantsPlist = wantsPlist
        self.wantsProgress = wantsProgress
    }

    public var processArguments: [String] {
        var args = [verb] + arguments
        if let password, !password.isEmpty {
            args.append("-stdinpass")
        }
        if wantsPlist {
            args.append("-plist")
        }
        if wantsProgress {
            args.append("-puppetstrings")
        }
        return args
    }

    public var displayCommand: String {
        var parts = ["hdiutil", verb]
        parts.append(contentsOf: arguments)
        if let password, !password.isEmpty {
            parts.append("-stdinpass")
        }
        if wantsPlist { parts.append("-plist") }
        if wantsProgress { parts.append("-puppetstrings") }
        return parts.map(Self.shellQuote).joined(separator: " ")
    }

    public static func shellQuote(_ value: String) -> String {
        if value.isEmpty { return "''" }
        let safe = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-/=:,"))
        if value.unicodeScalars.allSatisfy({ safe.contains($0) }) {
            return value
        }
        return "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

public enum AttacheError: Error, LocalizedError, Equatable {
    case missingBinary
    case busy
    case invalidInput(String)
    case failed(verb: String, status: Int32, message: String)
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .missingBinary:
            return "Could not find /usr/bin/hdiutil on this Mac."
        case .busy:
            return "Another disk-image operation is already running."
        case .invalidInput(let message):
            return message
        case .failed(let verb, let status, let message):
            if message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "hdiutil \(verb) failed (exit \(status))."
            }
            return message
        case .cancelled:
            return "The operation was cancelled."
        }
    }
}

public enum JobKind: String, Equatable {
    case attach, detach, create, convert, inspect, compact, resize, checksum, hybrid, bands

    public var stronglyDiscourageQuit: Bool {
        switch self {
        case .resize, .compact, .bands:
            return true
        default:
            return false
        }
    }

    public var interruptionMayCorrupt: Bool {
        switch self {
        case .create, .convert, .compact, .resize, .hybrid, .bands:
            return true
        default:
            return false
        }
    }
}

public enum DiskImagePath {
    public static let imageExtensions: Set<String> = [
        "dmg", "iso", "img", "cdr", "sparseimage", "toast", "dmgpart", "shadow", "bin", "nrg"
    ]

    public static func isDiskImage(_ url: URL) -> Bool {
        if url.pathExtension.lowercased() == "sparsebundle" { return true }
        if url.hasDirectoryPath && url.lastPathComponent.lowercased().hasSuffix(".sparsebundle") {
            return true
        }
        return imageExtensions.contains(url.pathExtension.lowercased())
    }

    public static func suggestedName(base: String, ext: String) -> String {
        let trimmed = (base as NSString).deletingPathExtension
        return "\(trimmed).\(ext)"
    }
}
