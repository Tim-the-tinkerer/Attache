import Foundation
import AttacheCore

var failed = 0

func check(_ condition: @autoclosure () -> Bool, _ name: String) {
    if condition() {
        print("ok   \(name)")
    } else {
        failed += 1
        print("FAIL \(name)")
    }
}

let attach = CommandBuilder.attach(
    image: "/tmp/Test.dmg",
    readOnly: true,
    noMount: true,
    skipVerify: true,
    autoOpen: false,
    mountPoint: "/Volumes/Skip",
    password: "secret"
)
check(attach.verb == "attach", "attach verb")
check(attach.processArguments == [
    "attach", "-readonly", "-nomount", "-noverify",
    "/tmp/Test.dmg", "-stdinpass", "-plist", "-puppetstrings"
], "attach argv omits mountpoint when nomount")
check(!attach.displayCommand.contains("secret"), "password not in display command")
check(attach.displayCommand.contains("-stdinpass"), "display command notes stdinpass")

let mounted = CommandBuilder.attach(
    image: "/tmp/A.dmg",
    readOnly: false,
    noMount: false,
    skipVerify: false,
    autoOpen: true,
    mountPoint: "/tmp/mnt",
    password: nil
)
check(mounted.arguments == ["-autoopen", "-mountpoint", "/tmp/mnt", "/tmp/A.dmg"], "attach mountpoint")

let blank = CommandBuilder.createBlank(
    sizeSpec: "2g",
    output: "/tmp/Blank.dmg",
    type: .sparse,
    filesystem: .apfs,
    volumeName: "Vault",
    encryption: .aes256,
    password: "hunter2",
    overwrite: true,
    attachAfter: true
)
check(blank.processArguments.contains("-encryption"), "create encryption")
check(blank.processArguments.contains("AES-256"), "create AES-256")
check(blank.processArguments.contains("-stdinpass"), "create stdinpass")
check(!blank.processArguments.contains("-passphrase"), "never uses -passphrase")
check(!blank.processArguments.contains("hunter2"), "password not in argv")
check(blank.processArguments.contains("-ov"), "create overwrite")
check(blank.processArguments.contains("-attach"), "create attach")

let folder = CommandBuilder.createFromFolder(
    folder: "/Users/me/Folder",
    output: "/tmp/Folder.dmg",
    format: .ulfo,
    filesystem: .hfsJournaled,
    volumeName: "Stuff",
    encryption: .none,
    password: nil,
    overwrite: false,
    attachAfter: false
)
check(folder.arguments == [
    "-srcfolder", "/Users/me/Folder",
    "-format", "ULFO",
    "-fs", "Journaled HFS+",
    "-volname", "Stuff",
    "/tmp/Folder.dmg"
], "create from folder")

let convert = CommandBuilder.convert(
    image: "/tmp/In.dmg",
    output: "/tmp/Out.sparseimage",
    format: .udsp,
    encryption: .none,
    password: nil,
    overwrite: true
)
check(convert.arguments == [
    "-format", "UDSP", "-o", "/tmp/Out.sparseimage", "-ov", "/tmp/In.dmg"
], "convert")

check(SparseBandSize.sectors(megabytes: 8) == 16384, "8 MB is 16384 sectors")
check(SparseBandSize.sectors(megabytes: 1) == 2048, "1 MB is 2048 sectors")
check(SparseBandSize.sectors(megabytes: 8192) == 16_777_216, "8 GB is max sectors")
check(SparseBandSize.display(bytes: 8_388_608) == "8 MB", "display 8 MB")
check(SparseBandSize.matchingPreset(bytes: 8_388_608) == .mb8, "preset match 8 MB")

let defaultResolve = SparseBandSize.resolve(preset: .systemDefault, customMegabytes: "8")
check(defaultResolve.error == nil && defaultResolve.sectors == nil, "system default omits imagekey")
let mb16 = SparseBandSize.resolve(preset: .mb16, customMegabytes: "")
check(mb16.error == nil && mb16.sectors == 32768, "16 MB sectors")
let custom12 = SparseBandSize.resolve(preset: .custom, customMegabytes: "12")
check(custom12.error == nil && custom12.sectors == SparseBandSize.sectors(megabytes: 12), "custom 12 MB")
let oversized = SparseBandSize.resolve(preset: .custom, customMegabytes: "99999")
check(oversized.error != nil, "custom rejects oversized band")

let bundleCreate = CommandBuilder.createBlank(
    sizeSpec: "1g",
    output: "/tmp/B.sparsebundle",
    type: .sparsebundle,
    filesystem: .apfs,
    volumeName: "Bands",
    encryption: .none,
    password: nil,
    overwrite: false,
    attachAfter: false,
    bandSizeSectors: 2048
)
check(bundleCreate.arguments.contains("-imagekey"), "create uses -imagekey")
check(bundleCreate.arguments.contains("sparse-band-size=2048"), "create band size 1 MB")
check(!bundleCreate.arguments.contains("-tgtimagekey"), "create blank is not tgtimagekey")

let noBand = CommandBuilder.createBlank(
    sizeSpec: "1g",
    output: "/tmp/B.sparsebundle",
    type: .sparsebundle,
    filesystem: .apfs,
    volumeName: "Bands",
    encryption: .none,
    password: nil,
    overwrite: false,
    attachAfter: false,
    bandSizeSectors: nil
)
check(!noBand.arguments.contains("-imagekey"), "default band size omitted")

let folderBundle = CommandBuilder.createFromFolder(
    folder: "/tmp/src",
    output: "/tmp/F.sparsebundle",
    format: .udsb,
    filesystem: nil,
    volumeName: "F",
    encryption: .none,
    password: nil,
    overwrite: false,
    attachAfter: false,
    bandSizeSectors: 32768
)
check(folderBundle.arguments.contains("-tgtimagekey"), "folder UDSB uses tgtimagekey")
check(folderBundle.arguments.contains("sparse-band-size=32768"), "folder band size 16 MB")

let convertBundle = CommandBuilder.convert(
    image: "/tmp/In.sparsebundle",
    output: "/tmp/Out.sparsebundle",
    format: .udsb,
    encryption: .none,
    password: nil,
    overwrite: true,
    bandSizeSectors: 16384
)
check(convertBundle.arguments.contains("-tgtimagekey"), "convert UDSB uses tgtimagekey")
check(convertBundle.arguments.contains("sparse-band-size=16384"), "convert band size 8 MB")

let convertOther = CommandBuilder.convert(
    image: "/tmp/In.dmg",
    output: "/tmp/Out.dmg",
    format: .udzo,
    encryption: .none,
    password: nil,
    overwrite: false,
    bandSizeSectors: 16384
)
check(!convertOther.arguments.contains("sparse-band-size=16384"), "non-UDSB convert ignores band size")

let bandPlist = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>band-size</key>
    <integer>8388608</integer>
    <key>size</key>
    <integer>1073741824</integer>
</dict>
</plist>
""".data(using: .utf8)!
// write temp bundle to test SparseBundleInfo
let tmpBundle = URL(fileURLWithPath: FileManager.default.temporaryDirectory.path)
    .appendingPathComponent("AttacheBandTest.sparsebundle")
try? FileManager.default.removeItem(at: tmpBundle)
try? FileManager.default.createDirectory(at: tmpBundle, withIntermediateDirectories: true)
try? bandPlist.write(to: tmpBundle.appendingPathComponent("Info.plist"))
check(SparseBundleInfo.isSparseBundle(tmpBundle), "detect sparsebundle")
check(SparseBundleInfo.readBandSizeBytes(at: tmpBundle) == 8_388_608, "read band-size bytes")
check(SparseBundleInfo.readVirtualSizeBytes(at: tmpBundle) == 1_073_741_824, "read virtual size")
try? FileManager.default.removeItem(at: tmpBundle)

check(
    CommandBuilder.detach(target: "/dev/disk4", force: true).arguments == ["-force", "/dev/disk4"],
    "detach force"
)

let limits = CommandBuilder.resizeLimits(image: "/tmp/A.sparseimage", password: nil)
check(limits.arguments == ["-limits", "/tmp/A.sparseimage"], "resize limits")

let resize = CommandBuilder.resize(
    image: "/tmp/A.sparseimage",
    sizeSpec: "10g",
    imageOnly: true,
    partitionOnly: false,
    password: nil
)
check(resize.arguments == ["-size", "10g", "-imageonly", "/tmp/A.sparseimage"], "resize")

let hybrid = CommandBuilder.makeHybrid(
    source: "/tmp/src",
    output: "/tmp/disc.iso",
    hfs: true,
    iso: true,
    joliet: true,
    udf: false,
    volumeName: "Install",
    overwrite: true
)
check(hybrid.verb == "makehybrid", "hybrid verb")
check(hybrid.arguments == [
    "-o", "/tmp/disc.iso", "-hfs", "-iso", "-joliet",
    "-default-volume-name", "Install", "-ov", "/tmp/src"
], "hybrid argv")

check(CommandBuilder.parsePercentLine("PERCENT:12.5") == 12.5, "percent 12.5")
check(CommandBuilder.parsePercentLine("PERCENTAGE:-1") == -1, "percent indeterminate")
check(CommandBuilder.parsePercentLine("PERCENT:150") == 100, "percent clamp")
check(CommandBuilder.parsePercentLine("hello") == nil, "percent ignore")

check(CommandBuilder.validatePassword(encryption: .none, password: "", confirm: "") == nil, "no password when unencrypted")
check(CommandBuilder.validatePassword(encryption: .aes256, password: "", confirm: "") != nil, "require password")
check(CommandBuilder.validatePassword(encryption: .aes256, password: "a", confirm: "b") != nil, "mismatch")
check(CommandBuilder.validatePassword(encryption: .aes128, password: "a", confirm: "a") == nil, "matching password")

let plist = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>images</key>
    <array>
        <dict>
            <key>image-path</key>
            <string>/tmp/Demo.dmg</string>
            <key>image-type</key>
            <string>udif</string>
            <key>system-entities</key>
            <array>
                <dict>
                    <key>dev-entry</key>
                    <string>/dev/disk4</string>
                </dict>
                <dict>
                    <key>dev-entry</key>
                    <string>/dev/disk4s1</string>
                    <key>mount-point</key>
                    <string>/Volumes/Demo</string>
                </dict>
            </array>
        </dict>
    </array>
</dict>
</plist>
""".data(using: .utf8)!

do {
    let images = try PlistParsing.parseAttached(from: plist)
    check(images.count == 1, "parse one image")
    check(images.first?.displayName == "Demo.dmg", "display name")
    check(images.first?.wholeDisk == "/dev/disk4", "whole disk")
    check(images.first?.primaryMount == "/Volumes/Demo", "mount point")
    check(images.first?.detachTarget == "/dev/disk4", "detach target")
} catch {
    failed += 1
    print("FAIL parse attached: \(error)")
}

let checksumPlist = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Checksum Type</key>
    <string>SHA256</string>
    <key>Checksum Value</key>
    <string>$A319E512EF5058A4</string>
</dict>
</plist>
""".data(using: .utf8)!
check(PlistParsing.parseChecksum(from: checksumPlist) == "A319E512EF5058A4", "checksum value strips $")

let limitsPlist = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>content-min-length</key>
    <integer>8272</integer>
    <key>content-length</key>
    <integer>40960</integer>
    <key>content-max-length</key>
    <integer>274877906944</integer>
</dict>
</plist>
""".data(using: .utf8)!
do {
    let limits = try PlistParsing.parseResizeLimits(from: limitsPlist)
    check(limits.minSectors == 8272, "resize min")
    check(limits.currentSectors == 40960, "resize current")
    check(limits.currentBytes == 40960 * 512, "resize bytes")
} catch {
    failed += 1
    print("FAIL parse limits: \(error)")
}

check(HDIRequest.shellQuote("plain") == "plain", "quote plain")
check(HDIRequest.shellQuote("has space") == "'has space'", "quote space")
check(HDIRequest.shellQuote("it's") == "'it'\\''s'", "quote apostrophe")

// Source password must not imply destination encryption.
let unlocked = CommandBuilder.convert(
    image: "/tmp/In.sparsebundle",
    output: "/tmp/Out.sparsebundle",
    format: .udsb,
    sourcePassword: "secret",
    destEncryption: .none,
    destPassword: nil,
    overwrite: false,
    bandSizeSectors: 16384
)
check(unlocked.processArguments.contains("-stdinpass"), "source password uses stdinpass")
check(!unlocked.processArguments.contains("-encryption"), "source password does not encrypt dest")
check(!unlocked.processArguments.contains("secret"), "source password not on argv")
check(unlocked.processArguments.contains("sparse-band-size=16384"), "rewrite still sets band size")

let reencrypt = CommandBuilder.convert(
    image: "/tmp/In.sparsebundle",
    output: "/tmp/Out.sparsebundle",
    format: .udsb,
    sourcePassword: "old",
    destEncryption: .aes128,
    destPassword: "new",
    overwrite: true,
    bandSizeSectors: 32768
)
check(reencrypt.processArguments.contains("-encryption"), "explicit dest encryption")
check(reencrypt.processArguments.contains("AES-128"), "keeps AES-128 not AES-256")
check(reencrypt.processArguments.contains("-stdinpass"), "dest encrypt uses stdinpass")
check(!reencrypt.processArguments.contains("old"), "old password not on argv")
check(!reencrypt.processArguments.contains("new"), "ignored dest password not on argv")
check(
    ConvertCredentials.passphrase(sourcePassword: "old", destEncryption: .aes128, destPassword: "new") == "old",
    "encrypted source reuses source password; dest password is ignored"
)

let newEncrypt = CommandBuilder.convert(
    image: "/tmp/In.sparsebundle",
    output: "/tmp/Out.sparsebundle",
    format: .udsb,
    sourcePassword: nil,
    destEncryption: .aes256,
    destPassword: "only",
    overwrite: false,
    bandSizeSectors: 16384
)
check(newEncrypt.processArguments.contains("-encryption"), "unencrypted source can encrypt dest")
check(newEncrypt.processArguments.contains("AES-256"), "new dest uses chosen cipher")
check(
    ConvertCredentials.passphrase(sourcePassword: nil, destEncryption: .aes256, destPassword: "only") == "only",
    "unencrypted source sends dest password"
)

check(
    ConvertCredentials.passphrase(sourcePassword: "src", destEncryption: .none, destPassword: "dest") == "src",
    "unencrypted dest uses source password only"
)
check(
    ConvertCredentials.passphrase(sourcePassword: "src", destEncryption: .aes256, destPassword: nil) == "src",
    "encrypted dest reuses source password"
)
check(
    ConvertCredentials.passphrase(sourcePassword: nil, destEncryption: .none, destPassword: "dest") == nil,
    "no passphrase when dest is unencrypted and source has none"
)
check(
    ConvertCredentials.validate(destEncryption: .none, destPassword: "", destConfirm: "", sourcePassword: "") == nil,
    "no dest password required when dest is unencrypted"
)
check(
    ConvertCredentials.validate(destEncryption: .aes256, destPassword: "", destConfirm: "", sourcePassword: "src") == nil,
    "source password is enough when dest is encrypted"
)
check(
    ConvertCredentials.validate(destEncryption: .aes256, destPassword: "", destConfirm: "", sourcePassword: "") != nil,
    "unencrypted source needs a dest password"
)
check(
    ConvertCredentials.validate(destEncryption: .aes256, destPassword: "a", destConfirm: "b", sourcePassword: "") != nil,
    "dest password mismatch"
)
check(
    ConvertCredentials.validate(destEncryption: .aes256, destPassword: "a", destConfirm: "a", sourcePassword: "") == nil,
    "matching dest password for new encryption"
)

let bothResize = CommandBuilder.resize(
    image: "/tmp/A.sparseimage",
    sizeSpec: "10g",
    imageOnly: true,
    partitionOnly: true,
    password: nil
)
check(!bothResize.arguments.contains("-imageonly"), "resize drops imageonly when both set")
check(!bothResize.arguments.contains("-partitiononly"), "resize drops partitiononly when both set")

check(JobFinish.classify(status: 0, taskCancelled: false) == .succeeded, "exit 0 is success")
check(JobFinish.classify(status: 1, taskCancelled: false) == .failed(status: 1), "nonzero is failure")
check(JobFinish.classify(status: 15, taskCancelled: false) == .cancelled, "SIGTERM is cancel")
check(JobFinish.classify(status: 0, taskCancelled: true) == .cancelled, "task cancel wins over exit 0")
check(JobFinish.classify(status: 1, taskCancelled: true) == .cancelled, "task cancel wins over failure")

final class FakeFiles: FileMoving {
    var paths: Set<String>
    var failMoveFrom: String?
    var failRemove = false
    var removed: [String] = []
    var moves: [(String, String)] = []

    init(paths: [String]) { self.paths = Set(paths) }

    func fileExists(atPath path: String) -> Bool { paths.contains(path) }

    func moveItem(at src: URL, to dst: URL) throws {
        if src.path == failMoveFrom {
            throw AttacheError.invalidInput("simulated move failure")
        }
        guard paths.contains(src.path) else {
            throw AttacheError.invalidInput("missing \(src.lastPathComponent)")
        }
        paths.remove(src.path)
        paths.insert(dst.path)
        moves.append((src.path, dst.path))
    }

    func removeItem(at url: URL) throws {
        if failRemove {
            throw AttacheError.invalidInput("simulated remove failure")
        }
        paths.remove(url.path)
        removed.append(url.path)
    }
}

do {
    let root = URL(fileURLWithPath: "/tmp/bundles")
    let original = root.appendingPathComponent("Vault.sparsebundle")
    let staged = root.appendingPathComponent(".new.sparsebundle")
    let files = FakeFiles(paths: [original.path, staged.path])
    let outcome = try SparseBundleReplacement.replace(original: original, with: staged, files: files, uniqueID: "ID")
    check(files.paths.contains(original.path), "replace puts staged at original path")
    check(!files.paths.contains(staged.path), "replace removes staged path")
    check(files.removed.contains { $0.contains(".old-ID") }, "aside copy is deleted after success")
    check(outcome.leftoverBackup == nil, "successful delete leaves no leftover")
} catch {
    failed += 1
    print("FAIL replace success: \(error)")
}

do {
    let root = URL(fileURLWithPath: "/tmp/bundles")
    let original = root.appendingPathComponent("Vault.sparsebundle")
    let staged = root.appendingPathComponent(".missing.sparsebundle")
    let files = FakeFiles(paths: [original.path])
    try SparseBundleReplacement.replace(original: original, with: staged, files: files, uniqueID: "ID")
    failed += 1
    print("FAIL missing staged should throw")
} catch {
    check(true, "missing staged throws")
}

do {
    let root = URL(fileURLWithPath: "/tmp/bundles")
    let original = root.appendingPathComponent("Vault.sparsebundle")
    let staged = root.appendingPathComponent(".new.sparsebundle")
    let files = FakeFiles(paths: [original.path, staged.path])
    files.failMoveFrom = staged.path
    do {
        try SparseBundleReplacement.replace(original: original, with: staged, files: files, uniqueID: "ID")
        failed += 1
        print("FAIL swap failure should throw")
    } catch {
        check(files.paths.contains(original.path), "failed swap restores original")
        check(!files.removed.contains { $0.contains(".old-ID") }, "failed swap keeps aside until restore")
    }
}

do {
    let root = URL(fileURLWithPath: "/tmp/bundles")
    let original = root.appendingPathComponent("Vault.sparsebundle")
    let staged = root.appendingPathComponent(".new.sparsebundle")
    let files = FakeFiles(paths: [original.path, staged.path])
    files.failRemove = true
    let leftover = try SparseBundleReplacement.replace(original: original, with: staged, files: files, uniqueID: "ID")
    check(files.paths.contains(original.path), "new image is in place even if backup delete fails")
    check(leftover.leftoverBackup != nil, "leftover backup path is reported")
} catch {
    failed += 1
    print("FAIL leftover backup: \(error)")
}

check(StagingName.isPartialArtifact(".ABC.partial.Out.dmg"), "detects partial artifact")
check(!StagingName.isPartialArtifact("Out.dmg"), "normal name is not a partial")

let same = URL(fileURLWithPath: "/tmp/A.dmg")
check(
    OutputPathGuard.rejectSameItem(source: same, output: URL(fileURLWithPath: "/tmp/./A.dmg")) != nil,
    "same path rejected"
)
check(
    OutputPathGuard.rejectSameItem(source: same, output: URL(fileURLWithPath: "/tmp/B.dmg")) == nil,
    "different path allowed"
)
let photosFolder = URL(fileURLWithPath: "/tmp/Photos", isDirectory: true)
check(
    OutputPathGuard.rejectOutputInsideSourceFolder(
        sourceFolder: photosFolder,
        output: URL(fileURLWithPath: "/tmp/Photos/Album.dmg")
    ) != nil,
    "output inside source folder rejected"
)
check(
    OutputPathGuard.rejectOutputInsideSourceFolder(
        sourceFolder: photosFolder,
        output: URL(fileURLWithPath: "/tmp/Album.dmg")
    ) == nil,
    "output beside source folder allowed"
)
let staged = OutputPathGuard.stagingURL(for: URL(fileURLWithPath: "/tmp/Out.dmg"), uniqueID: "ABC")
check(staged.lastPathComponent == ".ABC.partial.Out.dmg", "staging sibling name")
check(staged.deletingLastPathComponent().path == "/tmp", "staging stays next to dest")

check(SizeSpec.bytes(amount: "10", unit: .megabytes) == 10 * 1024 * 1024, "10 MB")
check(SizeSpec.bytes(amount: "2", unit: .gigabytes) == 2 * 1024 * 1024 * 1024, "2 GB")
check(SizeSpec.bytes(amount: "0", unit: .megabytes) == nil, "zero size rejected")
check(SizeSpec.bytes(amount: "nope", unit: .megabytes) == nil, "non-numeric size rejected")

check(ExclusiveLaunch.allow(existingRunning: false) == nil, "idle runner accepts launch")
check(ExclusiveLaunch.allow(existingRunning: true) == .busy, "busy runner rejects launch")
check(JobKind.resize.stronglyDiscourageQuit, "resize discourages quit")
check(JobKind.compact.stronglyDiscourageQuit, "compact discourages quit")
check(JobKind.bands.stronglyDiscourageQuit, "band replace discourages quit")
check(!JobKind.checksum.stronglyDiscourageQuit, "checksum is ordinary confirm")
check(JobKind.convert.interruptionMayCorrupt, "convert interruption is dangerous")
check(!JobKind.inspect.interruptionMayCorrupt, "inspect interruption is not destructive")

if failed == 0 {
    print("All checks passed.")
    exit(0)
} else {
    print("\(failed) check(s) failed.")
    exit(1)
}
