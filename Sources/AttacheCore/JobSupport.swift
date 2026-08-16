import Foundation

public enum JobFinish: Equatable {
    case succeeded
    case cancelled
    case failed(status: Int32)

    /// Maps an hdiutil/process exit into a UI outcome.
    /// Status 15 is SIGTERM, which is how we cancel a running job.
    public static func classify(status: Int32, taskCancelled: Bool) -> JobFinish {
        if taskCancelled { return .cancelled }
        if status == 0 { return .succeeded }
        if status == 15 { return .cancelled }
        return .failed(status: status)
    }
}

public protocol FileMoving {
    func fileExists(atPath path: String) -> Bool
    func moveItem(at src: URL, to dst: URL) throws
    func removeItem(at url: URL) throws
}

extension FileManager: FileMoving {}

public struct ReplacementOutcome: Equatable {
    public var leftoverBackup: URL?

    public init(leftoverBackup: URL? = nil) {
        self.leftoverBackup = leftoverBackup
    }
}

public enum SparseBundleReplacement {
    /// Atomically-enough swap: move the original aside, move the staged bundle
    /// into its place, then delete the aside copy. If the second move fails,
    /// the original is restored. If the aside copy cannot be deleted, the new
    /// image is still valid and leftoverBackup is set.
    public static func replace(
        original: URL,
        with staged: URL,
        files: FileMoving,
        uniqueID: String
    ) throws -> ReplacementOutcome {
        guard files.fileExists(atPath: staged.path) else {
            throw AttacheError.invalidInput("Converted bundle was not created.")
        }
        let trash = original.deletingLastPathComponent()
            .appendingPathComponent(".\(original.lastPathComponent).old-\(uniqueID)")
        try files.moveItem(at: original, to: trash)
        do {
            try files.moveItem(at: staged, to: original)
        } catch {
            try? files.moveItem(at: trash, to: original)
            throw error
        }
        do {
            try files.removeItem(at: trash)
            return ReplacementOutcome(leftoverBackup: nil)
        } catch {
            return ReplacementOutcome(leftoverBackup: trash)
        }
    }
}

public enum StagingName {
    public static func isPartialArtifact(_ name: String) -> Bool {
        name.hasPrefix(".") && name.contains(".partial.")
    }
}

public struct ResizeLimitsSnapshot: Equatable {
    public var sourcePath: String
    public var limits: ResizeLimits

    public init(sourcePath: String, limits: ResizeLimits) {
        self.sourcePath = sourcePath
        self.limits = limits
    }
}

public enum OutputPathGuard {
    public static func standardized(_ url: URL) -> URL {
        url.standardizedFileURL.resolvingSymlinksInPath()
    }

    public static func rejectSameItem(source: URL, output: URL) -> String? {
        if standardized(source).path == standardized(output).path {
            return "Source and destination resolve to the same path."
        }
        return nil
    }

    /// Reject writing an image into the folder that is being imaged.
    public static func rejectOutputInsideSourceFolder(sourceFolder: URL, output: URL) -> String? {
        let folder = standardized(sourceFolder)
        let dest = standardized(output)
        let prefix = folder.path.hasSuffix("/") ? folder.path : folder.path + "/"
        if dest.path == folder.path || dest.path.hasPrefix(prefix) {
            return "The destination is inside the source folder. Imaging would include the file being written."
        }
        return nil
    }

    public static func stagingURL(for final: URL, uniqueID: String) -> URL {
        let dest = standardized(final)
        return dest.deletingLastPathComponent()
            .appendingPathComponent(".\(uniqueID).partial.\(dest.lastPathComponent)")
    }
}

public enum SizeSpec {
    public static func bytes(amount: String, unit: SizeUnit) -> Int64? {
        let trimmed = amount.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard let value = Double(trimmed), value > 0, value.isFinite else { return nil }
        let multiplier: Double
        switch unit {
        case .megabytes: multiplier = 1024 * 1024
        case .gigabytes: multiplier = 1024 * 1024 * 1024
        case .terabytes: multiplier = 1024 * 1024 * 1024 * 1024
        }
        return Int64(value * multiplier)
    }
}

public enum ExclusiveLaunch {
    public static func allow(existingRunning: Bool) -> AttacheError? {
        existingRunning ? .busy : nil
    }
}

public enum ConvertCredentials {
    /// hdiutil −stdinpass accepts one passphrase.
    /// An encrypted source's password unlocks it and is reused if the destination is encrypted.
    /// A dest password is used only when the source has no password (unencrypted input).
    public static func passphrase(
        sourcePassword: String?,
        destEncryption: EncryptionChoice,
        destPassword: String?
    ) -> String? {
        if let source = sanitized(sourcePassword) {
            return source
        }
        if destEncryption != .none {
            return sanitized(destPassword)
        }
        return nil
    }

    public static func validate(
        destEncryption: EncryptionChoice,
        destPassword: String,
        destConfirm: String,
        sourcePassword: String
    ) -> String? {
        if sanitized(sourcePassword) != nil {
            return nil
        }
        guard destEncryption != .none else { return nil }
        let dest = destPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        if dest.isEmpty {
            return "Enter a password for the encrypted destination."
        }
        if dest != destConfirm {
            return "Destination password and confirmation do not match."
        }
        return nil
    }

    private static func sanitized(_ password: String?) -> String? {
        guard let password, !password.isEmpty else { return nil }
        return password
    }
}
