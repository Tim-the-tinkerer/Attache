import Foundation

public enum PlistParsing {
    public static func parseAttached(from data: Data) throws -> [AttachedImage] {
        let root = try plistRoot(data)
        guard let dict = root as? [String: Any] else { return [] }
        let images = (dict["images"] as? [[String: Any]]) ?? []
        return images.compactMap(parseAttachedImage)
    }

    public static func parseFrameworkVersion(from data: Data) -> String? {
        guard let dict = try? plistRoot(data) as? [String: Any] else { return nil }
        if let framework = dict["framework"] as? String, !framework.isEmpty {
            return framework
        }
        return nil
    }

    public static func parseEncrypted(from data: Data) -> Bool? {
        guard let dict = try? plistRoot(data) as? [String: Any] else { return nil }
        if let flag = boolish(dict["encrypted"]) { return flag }
        if let flag = boolish(dict["Encrypted"]) { return flag }
        if let info = dict["Encryption Info"] as? [String: Any] {
            return boolish(info["Is Encrypted"])
        }
        return nil
    }

    /// hdiutil resize -limits reports 512-byte sectors. diskutil image resize reports bytes.
    public static func parseDiskutilResizeLimits(from data: Data) throws -> ResizeLimits {
        let root = try plistRoot(data)
        guard let dict = root as? [String: Any],
              let min = int64(dict["min"]),
              let current = int64(dict["current"]),
              let max = int64(dict["max"])
        else {
            throw AttacheError.invalidInput("Could not read resize limits from diskutil image.")
        }
        return ResizeLimits(
            minSectors: sectors(fromBytes: min),
            currentSectors: sectors(fromBytes: current),
            maxSectors: sectors(fromBytes: max)
        )
    }

    public static func imageInfoSummary(_ dict: [String: Any]) -> [String: String] {
        var summary: [String: String] = [:]
        if let format = stringValue(in: dict, keys: ["Format", "format", "Image Format", "Format Description", "Class Name"]) {
            summary["Format"] = format
        }
        if let checksum = stringValue(in: dict, keys: ["Checksum Type", "Checksum"]) {
            summary["Checksum"] = checksum
        }
        if let size = (dict["Size Information"] as? [String: Any]) ?? (dict["Size Info"] as? [String: Any]),
           let total = stringValue(in: size, keys: ["Total Bytes", "Compressed Bytes"]) {
            summary["Total Bytes"] = total
        }
        if let info = dict["Encryption Info"] as? [String: Any], let flag = boolish(info["Is Encrypted"]) {
            summary["Encrypted"] = flag ? "yes" : "no"
        }
        return summary
    }

    public static func parseResizeLimits(from data: Data) throws -> ResizeLimits {
        let root = try plistRoot(data)
        if let dict = root as? [String: Any] {
            if let limits = limits(from: dict) { return limits }
        }
        if let array = root as? [Any] {
            for item in array {
                if let dict = item as? [String: Any], let limits = limits(from: dict) {
                    return limits
                }
            }
        }
        throw AttacheError.invalidInput("Could not read resize limits from hdiutil.")
    }

    public static func flatten(_ value: Any, prefix: String = "", level: Int = 0) -> [InfoRow] {
        var rows: [InfoRow] = []
        appendFlattened(value, prefix: prefix, level: level, into: &rows, path: prefix.isEmpty ? "root" : prefix)
        return rows
    }

    public static func stringValue(in dict: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = dict[key] {
                let text = scalarString(value)
                if !text.isEmpty { return text }
            }
        }
        return nil
    }

    public static func parseChecksum(from data: Data) -> String? {
        guard let root = try? plistRoot(data) else {
            return nil
        }
        if let dict = root as? [String: Any] {
            if let value = stringValue(in: dict, keys: [
                "Checksum Value", "checksum-value", "checksum", "Checksum", "calculated-checksum", "value"
            ]) {
                return value.hasPrefix("$") ? String(value.dropFirst()) : value
            }
            return firstScalar(in: dict)
        }
        return scalarString(root)
    }

    public static func plistRoot(_ data: Data) throws -> Any {
        try PropertyListSerialization.propertyList(from: plistPayload(data), options: [], format: nil)
    }

    /// hdiutil -plist -puppetstrings writes PERCENT lines ahead of the plist on stdout.
    static func plistPayload(_ data: Data) -> Data {
        let xml = Data("<?xml".utf8)
        let binary = Data("bplist".utf8)
        let xmlAt = data.range(of: xml)?.lowerBound
        let binaryAt = data.range(of: binary)?.lowerBound
        let start: Data.Index?
        switch (xmlAt, binaryAt) {
        case let (xml?, binary?):
            start = min(xml, binary)
        case let (xml?, nil):
            start = xml
        case let (nil, binary?):
            start = binary
        default:
            start = nil
        }
        guard let start, start > data.startIndex else { return data }
        return data.subdata(in: start..<data.endIndex)
    }

    public static func parseDiskutilDevices(from data: Data) -> [DiskDevice] {
        guard let dict = try? plistRoot(data) as? [String: Any] else { return [] }
        let whole = (dict["WholeDisks"] as? [String]) ?? []
        let infos = (dict["AllDisksAndPartitions"] as? [[String: Any]]) ?? []
        var devices: [DiskDevice] = []
        for bsd in whole {
            let info = infos.first(where: { ($0["DeviceIdentifier"] as? String) == bsd })
            let size = int64(info?["Size"]) ?? 0
            let name = (info?["VolumeName"] as? String)
                ?? (info?["Content"] as? String)
                ?? bsd
            let internalDisk = (info?["Internal"] as? Bool) ?? false
            devices.append(
                DiskDevice(
                    bsdName: bsd,
                    name: name,
                    sizeBytes: size,
                    isInternal: internalDisk
                )
            )
        }
        return devices
    }

    private static func parseAttachedImage(_ dict: [String: Any]) -> AttachedImage? {
        let path = (dict["image-path"] as? String)
            ?? (dict["image-alias"] as? String)
            ?? ""
        if path.isEmpty { return nil }
        let type = dict["image-type"] as? String
        let entities = (dict["system-entities"] as? [[String: Any]]) ?? []
        var devices: [String] = []
        var mounts: [String] = []
        var whole: String?
        for entity in entities {
            if let dev = entity["dev-entry"] as? String, !dev.isEmpty {
                devices.append(dev)
                if whole == nil && isWholeDisk(dev) {
                    whole = dev
                }
            }
            if let mount = entity["mount-point"] as? String, !mount.isEmpty {
                mounts.append(mount)
            }
        }
        if whole == nil {
            whole = devices.first(where: isWholeDisk) ?? devices.first
        }
        return AttachedImage(
            imagePath: path,
            imageType: type,
            wholeDisk: whole,
            mountPoints: mounts,
            devices: devices
        )
    }

    private static func isWholeDisk(_ dev: String) -> Bool {
        let name = dev.replacingOccurrences(of: "/dev/", with: "")
        guard name.hasPrefix("disk") else { return false }
        return !name.matchesSlicePattern
    }

    private static func limits(from dict: [String: Any]) -> ResizeLimits? {
        let min = int64(
            dict["resize-min"]
                ?? dict["min"]
                ?? dict["content-min-length"]
                ?? dict["image-min"]
        )
        let current = int64(
            dict["resize-current"]
                ?? dict["current"]
                ?? dict["content-length"]
                ?? dict["image-current"]
        )
        let max = int64(
            dict["resize-max"]
                ?? dict["max"]
                ?? dict["content-max-length"]
                ?? dict["image-max"]
        )
        guard let min, let current, let max else { return nil }
        return ResizeLimits(minSectors: min, currentSectors: current, maxSectors: max)
    }

    private static func sectors(fromBytes bytes: Int64) -> Int64 {
        guard bytes > 0 else { return 0 }
        return bytes / 512
    }

    static func boolish(_ value: Any?) -> Bool? {
        switch value {
        case let flag as Bool:
            return flag
        case let number as NSNumber:
            return number.boolValue
        case let text as String:
            switch text.lowercased() {
            case "yes", "true", "1": return true
            case "no", "false", "0": return false
            default: return nil
            }
        default:
            return nil
        }
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

    private static func appendFlattened(
        _ value: Any,
        prefix: String,
        level: Int,
        into rows: inout [InfoRow],
        path: String
    ) {
        if let dict = value as? [String: Any] {
            let keys = dict.keys.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            for key in keys {
                guard let child = dict[key] else { continue }
                let nextPath = path + "." + key
                if isScalar(child) {
                    rows.append(InfoRow(id: nextPath, key: key, value: scalarString(child), level: level))
                } else {
                    rows.append(InfoRow(id: nextPath, key: key, value: "", level: level))
                    appendFlattened(child, prefix: key, level: level + 1, into: &rows, path: nextPath)
                }
            }
            return
        }
        if let array = value as? [Any] {
            for (index, child) in array.enumerated() {
                let key = prefix.isEmpty ? "[\(index)]" : "\(prefix)[\(index)]"
                let nextPath = path + "[\(index)]"
                if isScalar(child) {
                    rows.append(InfoRow(id: nextPath, key: key, value: scalarString(child), level: level))
                } else {
                    rows.append(InfoRow(id: nextPath, key: key, value: "", level: level))
                    appendFlattened(child, prefix: "", level: level + 1, into: &rows, path: nextPath)
                }
            }
            return
        }
        rows.append(InfoRow(id: path, key: prefix.isEmpty ? "Value" : prefix, value: scalarString(value), level: level))
    }

    private static func isScalar(_ value: Any) -> Bool {
        value is String || value is NSNumber || value is Bool || value is NSNull
    }

    private static func scalarString(_ value: Any) -> String {
        switch value {
        case let s as String: return s
        case let b as Bool: return b ? "yes" : "no"
        case let n as NSNumber:
            if CFGetTypeID(n) == CFBooleanGetTypeID() {
                return n.boolValue ? "yes" : "no"
            }
            return n.stringValue
        case is NSNull: return ""
        default: return String(describing: value)
        }
    }

    private static func firstScalar(in dict: [String: Any]) -> String? {
        for key in dict.keys.sorted() {
            if let value = dict[key], isScalar(value) {
                let text = scalarString(value)
                if !text.isEmpty { return text }
            }
        }
        return nil
    }
}

private extension String {
    var matchesSlicePattern: Bool {
        // diskNsM
        range(of: #"disk\d+s\d+"#, options: .regularExpression) != nil
    }
}
