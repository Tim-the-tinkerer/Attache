import Foundation

public enum CommandBuilder {
    public static func info() -> HDIRequest {
        HDIRequest(verb: "info", wantsPlist: true)
    }

    public static func attach(
        image: String,
        readOnly: Bool,
        noMount: Bool,
        skipVerify: Bool,
        autoOpen: Bool,
        mountPoint: String?,
        password: String?
    ) -> HDIRequest {
        if DiskImagePath.isASIF(image) {
            return attachASIF(
                image: image,
                readOnly: readOnly,
                noMount: noMount,
                mountPoint: mountPoint,
                password: password
            )
        }
        var args: [String] = []
        if readOnly { args.append("-readonly") }
        if noMount { args.append("-nomount") }
        if skipVerify { args.append("-noverify") }
        if autoOpen { args.append("-autoopen") }
        if let mountPoint, !mountPoint.isEmpty, !noMount {
            args.append(contentsOf: ["-mountpoint", mountPoint])
        }
        args.append(image)
        return HDIRequest(
            verb: "attach",
            arguments: args,
            password: sanitizedPassword(password),
            wantsPlist: true,
            wantsProgress: true
        )
    }

    public static func detach(target: String, force: Bool, asif: Bool = false) -> HDIRequest {
        if asif {
            var args: [String] = []
            if force { args.append("force") }
            args.append(target)
            return HDIRequest(verb: "eject", arguments: args, tool: .diskutil)
        }
        var args: [String] = []
        if force { args.append("-force") }
        args.append(target)
        return HDIRequest(verb: "detach", arguments: args, wantsPlist: true)
    }

    public static func createBlank(
        sizeSpec: String,
        output: String,
        type: BlankImageType,
        filesystem: DiskFilesystem,
        volumeName: String,
        encryption: EncryptionChoice,
        password: String?,
        overwrite: Bool,
        attachAfter: Bool,
        bandSizeSectors: Int64? = nil
    ) -> HDIRequest {
        if type == .asif {
            return createASIFBlank(
                sizeSpec: sizeSpec,
                output: output,
                filesystem: filesystem,
                volumeName: volumeName,
                encryption: encryption,
                password: password
            )
        }
        var args = ["-size", sizeSpec, "-type", type.rawValue, "-fs", filesystem.rawValue]
        let name = volumeName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty {
            args.append(contentsOf: ["-volname", name])
        }
        appendEncryption(encryption, onto: &args)
        appendBandSize(bandSizeSectors, onto: &args, targetKey: false)
        if overwrite { args.append("-ov") }
        if attachAfter { args.append("-attach") }
        args.append(output)
        return HDIRequest(
            verb: "create",
            arguments: args,
            password: sanitizedPassword(password),
            wantsPlist: true,
            wantsProgress: true
        )
    }

    public static func createFromFolder(
        folder: String,
        output: String,
        format: ImageFormat,
        filesystem: DiskFilesystem?,
        volumeName: String,
        encryption: EncryptionChoice,
        password: String?,
        overwrite: Bool,
        attachAfter: Bool,
        bandSizeSectors: Int64? = nil
    ) -> HDIRequest {
        if format == .asif {
            return createASIFFrom(
                source: folder,
                output: output,
                format: format,
                volumeName: volumeName,
                encryption: encryption,
                password: password
            )
        }
        var args = ["-srcfolder", folder, "-format", format.rawValue]
        if let filesystem {
            args.append(contentsOf: ["-fs", filesystem.rawValue])
        }
        let name = volumeName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty {
            args.append(contentsOf: ["-volname", name])
        }
        appendEncryption(encryption, onto: &args)
        if format == .udsb {
            appendBandSize(bandSizeSectors, onto: &args, targetKey: true)
        }
        if overwrite { args.append("-ov") }
        if attachAfter { args.append("-attach") }
        args.append(output)
        return HDIRequest(
            verb: "create",
            arguments: args,
            password: sanitizedPassword(password),
            wantsPlist: true,
            wantsProgress: true
        )
    }

    public static func createFromDevice(
        device: String,
        output: String,
        format: ImageFormat,
        encryption: EncryptionChoice,
        password: String?,
        overwrite: Bool,
        bandSizeSectors: Int64? = nil
    ) -> HDIRequest {
        if format == .asif {
            return createASIFFrom(
                source: device,
                output: output,
                format: format,
                volumeName: "",
                encryption: encryption,
                password: password
            )
        }
        var args = ["-srcdevice", device, "-format", format.rawValue]
        appendEncryption(encryption, onto: &args)
        if format == .udsb {
            appendBandSize(bandSizeSectors, onto: &args, targetKey: true)
        }
        if overwrite { args.append("-ov") }
        args.append(output)
        return HDIRequest(
            verb: "create",
            arguments: args,
            password: sanitizedPassword(password),
            wantsPlist: true,
            wantsProgress: true
        )
    }

    public static func convert(
        image: String,
        output: String,
        format: ImageFormat,
        encryption: EncryptionChoice,
        password: String?,
        overwrite: Bool,
        bandSizeSectors: Int64? = nil
    ) -> HDIRequest {
        if DiskImagePath.isASIF(image) || format == .asif {
            return createASIFFrom(
                source: image,
                output: output,
                format: format,
                volumeName: "",
                encryption: encryption,
                password: password
            )
        }
        var args = ["-format", format.rawValue, "-o", output]
        appendEncryption(encryption, onto: &args)
        if format == .udsb {
            appendBandSize(bandSizeSectors, onto: &args, targetKey: true)
        }
        if overwrite { args.append("-ov") }
        args.append(image)
        return HDIRequest(
            verb: "convert",
            arguments: args,
            password: sanitizedPassword(password),
            wantsPlist: true,
            wantsProgress: true
        )
    }

    public static func imageInfo(image: String, password: String?) -> HDIRequest {
        if DiskImagePath.isASIF(image) {
            return diskutilImage(
                verb: "info",
                arguments: diskutilFlags(password: password) + [image],
                password: password
            )
        }
        return HDIRequest(
            verb: "imageinfo",
            arguments: [image],
            password: sanitizedPassword(password),
            wantsPlist: true
        )
    }

    public static func isEncrypted(image: String) -> HDIRequest {
        HDIRequest(verb: "isencrypted", arguments: [image], wantsPlist: true)
    }

    public static func verify(image: String, password: String?) -> HDIRequest {
        HDIRequest(
            verb: "verify",
            arguments: [image],
            password: sanitizedPassword(password),
            wantsPlist: true,
            wantsProgress: true
        )
    }

    public static func compact(image: String, batteryAllowed: Bool, password: String?) -> HDIRequest {
        var args: [String] = []
        if batteryAllowed { args.append("-batteryallowed") }
        args.append(image)
        return HDIRequest(
            verb: "compact",
            arguments: args,
            password: sanitizedPassword(password),
            wantsPlist: true,
            wantsProgress: true
        )
    }

    public static func resizeLimits(image: String, password: String?) -> HDIRequest {
        if DiskImagePath.isASIF(image) {
            return diskutilImage(
                verb: "resize",
                arguments: diskutilFlags(password: password) + [image],
                password: password
            )
        }
        return HDIRequest(
            verb: "resize",
            arguments: ["-limits", image],
            password: sanitizedPassword(password),
            wantsPlist: true
        )
    }

    public static func resize(
        image: String,
        sizeSpec: String,
        imageOnly: Bool,
        partitionOnly: Bool,
        password: String?
    ) -> HDIRequest {
        if DiskImagePath.isASIF(image) {
            var args = diskutilFlags(password: password)
            args.append(contentsOf: ["--size", sizeSpec])
            if imageOnly && !partitionOnly {
                args.append("--image-only")
            }
            args.append(image)
            return diskutilImage(verb: "resize", arguments: args, password: password)
        }
        var args = ["-size", sizeSpec]
        if imageOnly && !partitionOnly { args.append("-imageonly") }
        if partitionOnly && !imageOnly { args.append("-partitiononly") }
        args.append(image)
        return HDIRequest(
            verb: "resize",
            arguments: args,
            password: sanitizedPassword(password),
            wantsPlist: true,
            wantsProgress: true
        )
    }

    public static func checksum(image: String, type: ChecksumType, password: String?) -> HDIRequest {
        HDIRequest(
            verb: "checksum",
            arguments: ["-type", type.rawValue, image],
            password: sanitizedPassword(password),
            wantsPlist: true,
            wantsProgress: true
        )
    }

    public static func makeHybrid(
        source: String,
        output: String,
        hfs: Bool,
        iso: Bool,
        joliet: Bool,
        udf: Bool,
        volumeName: String,
        overwrite: Bool
    ) -> HDIRequest {
        var args = ["-o", output]
        if hfs { args.append("-hfs") }
        if iso { args.append("-iso") }
        if joliet { args.append("-joliet") }
        if udf { args.append("-udf") }
        let name = volumeName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty {
            args.append(contentsOf: ["-default-volume-name", name])
        }
        if overwrite { args.append("-ov") }
        args.append(source)
        return HDIRequest(verb: "makehybrid", arguments: args, wantsProgress: true)
    }

    public static func parsePercentLine(_ line: String) -> Double? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefixes = ["PERCENT:", "PERCENTAGE:", "PERCENT", "PERCENTAGE"]
        for prefix in prefixes where trimmed.uppercased().hasPrefix(prefix) {
            var rest = String(trimmed.dropFirst(prefix.count))
            if rest.hasPrefix(":") {
                rest.removeFirst()
            }
            rest = rest.trimmingCharacters(in: .whitespaces)
            if let value = Double(rest) {
                return value < 0 ? -1 : min(max(value, 0), 100)
            }
        }
        let lower = trimmed.lowercased()
        if lower.contains("% completed"), !lower.contains("fail"), !lower.contains("error") {
            return lastCompletedPercent(in: trimmed)
        }
        return nil
    }

    /// Why an ASIF create or convert cannot use the chosen format, filesystem, or cipher.
    /// Nil means the diskutil image command can run.
    public static func asifRequestError(
        source: String?,
        format: ImageFormat?,
        blankFilesystem: DiskFilesystem?,
        encryption: EncryptionChoice,
        bandSizeSectors: Int64?
    ) -> String? {
        let sourceIsASIF = source.map(DiskImagePath.isASIF) ?? false
        let destIsASIF = format == .asif
        guard sourceIsASIF || destIsASIF || blankFilesystem != nil else { return nil }
        if encryption == .aes128 {
            return "ASIF encryption is AES-256."
        }
        if let blankFilesystem, blankFilesystem.diskutilFilesystem == nil {
            return "An ASIF blank image can use APFS, ExFAT, or MS-DOS."
        }
        if let format, (sourceIsASIF || destIsASIF), format.diskutilFormat == nil {
            return "\(format.rawValue) is not available for Apple Sparse Image conversion. diskutil image can write ASIF, RAW, UDRO, UDZO, ULFO, ULMO, and UDSB."
        }
        if sourceIsASIF, format == .udsb, bandSizeSectors != nil {
            return "Band size cannot be set when converting an ASIF image to a sparse bundle. diskutil image uses the system default."
        }
        return nil
    }

    public static func unsupportedASIFOperation(_ operation: String, path: String) -> String? {
        guard DiskImagePath.isASIF(path) else { return nil }
        return "\(operation) is not available for an Apple Sparse Image (.asif). Attach, inspect, create, convert, and resize support ASIF."
    }

    public static func convert(
        image: String,
        output: String,
        format: ImageFormat,
        sourcePassword: String?,
        destEncryption: EncryptionChoice,
        destPassword: String?,
        overwrite: Bool,
        bandSizeSectors: Int64? = nil
    ) -> HDIRequest {
        convert(
            image: image,
            output: output,
            format: format,
            encryption: destEncryption,
            password: ConvertCredentials.passphrase(
                sourcePassword: sourcePassword,
                destEncryption: destEncryption,
                destPassword: destPassword
            ),
            overwrite: overwrite,
            bandSizeSectors: bandSizeSectors
        )
    }

    public static func validatePassword(encryption: EncryptionChoice, password: String, confirm: String) -> String? {
        guard encryption != .none else { return nil }
        if password.isEmpty {
            return "Enter a password for the encrypted image."
        }
        if password != confirm {
            return "Password and confirmation do not match."
        }
        return nil
    }

    private static func attachASIF(
        image: String,
        readOnly: Bool,
        noMount: Bool,
        mountPoint: String?,
        password: String?
    ) -> HDIRequest {
        var args: [String] = []
        if readOnly { args.append("--readOnly") }
        if noMount { args.append("--noMount") }
        if let mountPoint, !mountPoint.isEmpty, !noMount {
            args.append(contentsOf: ["--mountPoint", mountPoint])
        }
        args.append(contentsOf: diskutilFlags(password: password))
        args.append(image)
        return diskutilImage(verb: "attach", arguments: args, password: password)
    }

    private static func createASIFBlank(
        sizeSpec: String,
        output: String,
        filesystem: DiskFilesystem,
        volumeName: String,
        encryption: EncryptionChoice,
        password: String?
    ) -> HDIRequest {
        var args = ["blank"]
        if encryption == .aes256 { args.append("--encrypt") }
        args.append(contentsOf: diskutilFlags(password: password))
        args.append(contentsOf: ["--format", "ASIF", "--size", sizeSpec])
        let name = volumeName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty {
            args.append(contentsOf: ["--volumeName", name])
        }
        if let fs = filesystem.diskutilFilesystem {
            args.append(contentsOf: ["--fs", fs])
        }
        args.append(output)
        return diskutilImage(verb: "create", arguments: args, password: password)
    }

    private static func createASIFFrom(
        source: String,
        output: String,
        format: ImageFormat,
        volumeName: String,
        encryption: EncryptionChoice,
        password: String?
    ) -> HDIRequest {
        var args = ["from"]
        if encryption == .aes256 { args.append("--encrypt") }
        args.append(contentsOf: diskutilFlags(password: password))
        let formatName = format.diskutilFormat ?? format.rawValue
        args.append(contentsOf: ["--format", formatName])
        let name = volumeName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty {
            args.append(contentsOf: ["--volumeName", name])
        }
        args.append(source)
        args.append(output)
        return diskutilImage(verb: "create", arguments: args, password: password)
    }

    private static func diskutilImage(verb: String, arguments: [String], password: String?) -> HDIRequest {
        HDIRequest(
            verb: verb,
            arguments: arguments,
            password: sanitizedPassword(password),
            wantsPlist: false,
            wantsProgress: false,
            tool: .diskutil,
            argumentPrefix: ["image"],
            newlinePassphrase: true
        )
    }

    /// `--stdinpass` and `--plist` before the positional paths.
    private static func diskutilFlags(password: String?) -> [String] {
        var flags: [String] = []
        if sanitizedPassword(password) != nil {
            flags.append("--stdinpass")
        }
        flags.append("--plist")
        return flags
    }

    private static func lastCompletedPercent(in line: String) -> Double? {
        guard let expression = try? NSRegularExpression(pattern: #"(\d+(?:\.\d+)?)%\s+completed"#) else {
            return nil
        }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        let matches = expression.matches(in: line, range: range)
        guard let last = matches.last, last.numberOfRanges > 1,
              let valueRange = Range(last.range(at: 1), in: line),
              let value = Double(line[valueRange])
        else { return nil }
        return min(max(value, 0), 100)
    }

    private static func appendEncryption(_ encryption: EncryptionChoice, onto args: inout [String]) {
        if let method = encryption.argument {
            args.append(contentsOf: ["-encryption", method])
        }
    }

    private static func appendBandSize(_ sectors: Int64?, onto args: inout [String], targetKey: Bool) {
        guard let sectors else { return }
        let flag = targetKey ? "-tgtimagekey" : "-imagekey"
        args.append(contentsOf: [flag, "sparse-band-size=\(sectors)"])
    }

    private static func sanitizedPassword(_ password: String?) -> String? {
        guard let password, !password.isEmpty else { return nil }
        return password
    }
}
