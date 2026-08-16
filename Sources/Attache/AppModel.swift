import AppKit
import Combine
import Foundation
import AttacheCore
import UniformTypeIdentifiers

enum JobState: Equatable {
    case idle
    case running(verb: String, percent: Double?, kind: JobKind)
    case succeeded(String)
    case failed(String)
    case cancelled

    var isRunning: Bool {
        if case .running = self { return true }
        return false
    }

    var kind: JobKind? {
        if case .running(_, _, let kind) = self { return kind }
        return nil
    }
}

struct AttachForm {
    var source: URL?
    var readOnly = false
    var noMount = false
    var skipVerify = false
    var autoOpen = false
    var useCustomMount = false
    var mountPoint: URL?
    var password = ""
    var encrypted: Bool?
}

struct CreateForm {
    var mode: CreateMode = .blank
    var sizeAmount = "1"
    var sizeUnit: SizeUnit = .gigabytes
    var type: BlankImageType = .udif
    var filesystem: DiskFilesystem = .apfs
    var overrideFilesystem = false
    var volumeName = "Untitled"
    var folder: URL?
    var folderFormat: ImageFormat = .udzo
    var deviceBSD = ""
    var deviceFormat: ImageFormat = .udzo
    var output: URL?
    var encryption: EncryptionChoice = .none
    var password = ""
    var confirm = ""
    var attachAfter = false
    var bandPreset: BandSizePreset = .systemDefault
    var bandCustomMB = "8"

    var wantsBandSize: Bool {
        switch mode {
        case .blank: return type == .sparsebundle
        case .folder: return folderFormat == .udsb
        case .device: return deviceFormat == .udsb
        }
    }
}

struct ConvertForm {
    var source: URL?
    var format: ImageFormat = .udzo
    var output: URL?
    var encryption: EncryptionChoice = .none
    var password = ""
    var bandPreset: BandSizePreset = .systemDefault
    var bandCustomMB = "8"
    var sourceBandBytes: Int64?
}

struct InspectForm {
    var source: URL?
    var password = ""
    var encrypted: Bool?
    var rows: [InfoRow] = []
    var summary: [String: String] = [:]
}

struct CompactForm {
    var source: URL?
    var batteryAllowed = true
    var password = ""
}

struct BandForm {
    var source: URL?
    var currentBytes: Int64?
    var virtualSizeBytes: Int64?
    var preset: BandSizePreset = .mb8
    var customMB = "8"
    var output: URL?
    var sourcePassword = ""
    var sourceEncrypted: Bool?
    var destEncryption: EncryptionChoice = .none
    var destPassword = ""
    var destConfirm = ""
    var replaceOriginal = false
}

struct ResizeForm {
    var source: URL?
    var amount = ""
    var unit: SizeUnit = .gigabytes
    var imageOnly = false
    var partitionOnly = false
    var password = ""
    var snapshot: ResizeLimitsSnapshot?

    var limits: ResizeLimits? { snapshot?.limits }
}

struct ChecksumForm {
    var source: URL?
    var type: ChecksumType = .sha256
    var password = ""
    var result: String?
}

struct HybridForm {
    var source: URL?
    var output: URL?
    var hfs = true
    var iso = true
    var joliet = true
    var udf = false
    var volumeName = "Untitled"
}

@MainActor
final class AppModel: ObservableObject {
    @Published var selection: SidebarItem = .attached
    @Published var attached: [AttachedImage] = []
    @Published var selectedAttachedID: String?
    @Published var isRefreshing = false
    @Published var frameworkVersion: String?
    @Published var devices: [DiskDevice] = []

    @Published var attachForm = AttachForm()
    @Published var createForm = CreateForm()
    @Published var convertForm = ConvertForm()
    @Published var inspectForm = InspectForm()
    @Published var compactForm = CompactForm()
    @Published var bandForm = BandForm()
    @Published var resizeForm = ResizeForm()
    @Published var checksumForm = ChecksumForm()
    @Published var hybridForm = HybridForm()

    @Published var job: JobState = .idle
    @Published var log = ""
    @Published var recents: [URL] = []
    @Published var lastRevealURL: URL?
    @Published var showHelp = false
    @Published var confirmForceDetach = false
    @Published var confirmReplaceBundle = false
    @Published var confirmOverwrite = false
    @Published var overwritePath = ""
    @Published var confirmShrink = false
    @Published var confirmAdvancedResize = false
    @Published var resizeDirectionNote = ""

    let service = AttacheService()
    private var refreshTask: Task<Void, Never>?
    private var jobTask: Task<Void, Never>?
    private let recentsKey = "Attache.recentImages"

    init() {
        loadRecents()
    }

    var selectedAttached: AttachedImage? {
        attached.first(where: { $0.id == selectedAttachedID }) ?? attached.first
    }

    var canRun: Bool { !job.isRunning }

    func start() {
        sweepPartialArtifacts()
        Task { await refreshAttached() }
        Task { devices = await service.listDevices() }
        startPolling()
    }

    func stop() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    func startPolling() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                guard let self, !self.job.isRunning else { continue }
                await self.refreshAttached(quiet: true)
            }
        }
    }

    func refreshAttached(quiet: Bool = false) async {
        if quiet && job.isRunning { return }
        if !quiet { isRefreshing = true }
        defer { if !quiet { isRefreshing = false } }
        do {
            let result = try await service.runProbe(CommandBuilder.info())
            if result.status == 0 {
                attached = (try? PlistParsing.parseAttached(from: result.stdout)) ?? []
                if frameworkVersion == nil {
                    frameworkVersion = PlistParsing.parseFrameworkVersion(from: result.stdout)
                }
                if let selectedAttachedID, !attached.contains(where: { $0.id == selectedAttachedID }) {
                    self.selectedAttachedID = attached.first?.id
                } else if selectedAttachedID == nil {
                    selectedAttachedID = attached.first?.id
                }
            }
        } catch {
            if !quiet {
                appendLog("info failed: \(error.localizedDescription)")
            }
        }
    }

    func openImage(_ url: URL, preferring item: SidebarItem? = nil) {
        remember(url)
        if DiskImagePath.isDiskImage(url) {
            attachForm.source = url
            convertForm.source = url
            inspectForm.source = url
            compactForm.source = url
            setResizeSource(url)
            checksumForm.source = url
            if SparseBundleInfo.isSparseBundle(url) {
                loadBandInfo(from: url)
                convertForm.sourceBandBytes = bandForm.currentBytes
            }
            selection = item ?? .attach
            Task { await detectEncryption(url) }
        } else if url.hasDirectoryPath {
            createForm.folder = url
            createForm.mode = .folder
            hybridForm.source = url
            selection = item ?? .create
        } else {
            attachForm.source = url
            selection = item ?? .attach
        }
    }

    func chooseImage(for item: SidebarItem) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = "Choose a Disk Image"
        panel.message = "Select a disk image or a folder."
        panel.allowedContentTypes = Self.imageTypes + [.folder]
        if panel.runModal() == .OK, let url = panel.url {
            openImage(url, preferring: item)
        }
    }

    func copyLastCommand() {
        guard !log.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(log, forType: .string)
    }

    func cancelJob() {
        service.cancelJob()
        jobTask?.cancel()
    }

    func requestForceDetach() {
        guard selectedAttached?.detachTarget != nil else { return }
        confirmForceDetach = true
    }

    func detachSelected(force: Bool) {
        guard let target = selectedAttached?.detachTarget else { return }
        run(CommandBuilder.detach(target: target, force: force), kind: .detach, reveal: nil, onFinish: { [weak self] _ in
            await self?.refreshAttached()
        })
    }

    func openSelectedMount() {
        guard let mount = selectedAttached?.primaryMount else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: mount))
    }

    func revealSelectedImage() {
        guard let path = selectedAttached?.imagePath else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    func revealLastOutput() {
        guard let lastRevealURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([lastRevealURL])
    }

    func runAttach() {
        guard let source = attachForm.source else {
            fail("Choose a disk image to attach.")
            return
        }
        remember(source)
        let request = CommandBuilder.attach(
            image: source.path,
            readOnly: attachForm.readOnly,
            noMount: attachForm.noMount,
            skipVerify: attachForm.skipVerify,
            autoOpen: attachForm.autoOpen,
            mountPoint: attachForm.useCustomMount ? attachForm.mountPoint?.path : nil,
            password: attachForm.password
        )
        run(request, kind: .attach, reveal: nil, onSuccess: { [weak self] _ in
            await self?.refreshAttached()
            self?.selection = .attached
        })
    }

    func runCreate() {
        if let error = validateCreate() {
            fail(error)
            return
        }
        let form = createForm
        let bandSectors: Int64?
        if form.wantsBandSize {
            let resolved = SparseBandSize.resolve(preset: form.bandPreset, customMegabytes: form.bandCustomMB)
            if let message = resolved.error {
                fail(message)
                return
            }
            bandSectors = resolved.sectors
        } else {
            bandSectors = nil
        }
        guard let output = resolvedCreateOutput() else {
            fail("Choose where to save the new image.")
            return
        }
        createForm.output = output
        if form.mode == .folder, let folder = form.folder {
            if let message = OutputPathGuard.rejectSameItem(source: folder, output: output)
                ?? OutputPathGuard.rejectOutputInsideSourceFolder(sourceFolder: folder, output: output) {
                fail(message)
                return
            }
        }
        remember(output)
        writeStaged(to: output, kind: .create) { [self] staging in
            switch form.mode {
            case .blank:
                return CommandBuilder.createBlank(
                    sizeSpec: form.sizeUnit.spec(self.sanitizedAmount(form.sizeAmount)),
                    output: staging.path,
                    type: form.type,
                    filesystem: form.filesystem,
                    volumeName: form.volumeName,
                    encryption: form.encryption,
                    password: form.password,
                    overwrite: false,
                    attachAfter: false,
                    bandSizeSectors: bandSectors
                )
            case .folder:
                return CommandBuilder.createFromFolder(
                    folder: form.folder!.path,
                    output: staging.path,
                    format: form.folderFormat,
                    filesystem: form.overrideFilesystem ? form.filesystem : nil,
                    volumeName: form.volumeName,
                    encryption: form.encryption,
                    password: form.password,
                    overwrite: false,
                    attachAfter: false,
                    bandSizeSectors: bandSectors
                )
            case .device:
                let device = form.deviceBSD.trimmingCharacters(in: .whitespacesAndNewlines)
                return CommandBuilder.createFromDevice(
                    device: device.hasPrefix("/dev/") ? device : "/dev/\(device)",
                    output: staging.path,
                    format: form.deviceFormat,
                    encryption: form.encryption,
                    password: form.password,
                    overwrite: false,
                    bandSizeSectors: bandSectors
                )
            }
        } onSuccess: { [weak self] committed in
            guard let self else { return }
            if form.attachAfter {
                await self.attachCommittedImage(committed)
            }
            await self.refreshAttached()
        }
    }

    func runConvert() {
        guard let source = convertForm.source else {
            fail("Choose an image to convert.")
            return
        }
        guard let output = resolvedConvertOutput() else {
            fail("Choose where to save the converted image.")
            return
        }
        convertForm.output = output
        if let message = OutputPathGuard.rejectSameItem(source: source, output: output) {
            fail(message)
            return
        }
        remember(source)
        remember(output)
        let bandSectors: Int64?
        if convertForm.format == .udsb {
            let resolved = SparseBandSize.resolve(preset: convertForm.bandPreset, customMegabytes: convertForm.bandCustomMB)
            if let message = resolved.error {
                fail(message)
                return
            }
            bandSectors = resolved.sectors
        } else {
            bandSectors = nil
        }
        writeStaged(to: output, kind: .convert) { staging in
            CommandBuilder.convert(
                image: source.path,
                output: staging.path,
                format: self.convertForm.format,
                encryption: self.convertForm.encryption,
                password: self.convertForm.password,
                overwrite: false,
                bandSizeSectors: bandSectors
            )
        }
    }

    func runInspect() {
        guard let source = inspectForm.source else {
            fail("Choose an image to inspect.")
            return
        }
        remember(source)
        run(CommandBuilder.imageInfo(image: source.path, password: inspectForm.password), kind: .inspect, reveal: nil, onSuccess: { [weak self] result in
            guard let self else { return }
            if let root = try? PlistParsing.plistRoot(result.stdout) {
                self.inspectForm.rows = PlistParsing.flatten(root)
                if let dict = root as? [String: Any] {
                    var summary: [String: String] = [:]
                    summary["Format"] = PlistParsing.stringValue(in: dict, keys: ["Format", "format", "Class Name"])
                    summary["Checksum"] = PlistParsing.stringValue(in: dict, keys: ["Checksum Type", "Checksum"])
                    if let size = dict["Size Information"] as? [String: Any] {
                        summary["Total Bytes"] = PlistParsing.stringValue(in: size, keys: ["Total Bytes", "Compressed Bytes"])
                    }
                    if SparseBundleInfo.isSparseBundle(source),
                       let bandBytes = SparseBundleInfo.readBandSizeBytes(at: source) {
                        summary["Band Size"] = SparseBandSize.display(bytes: bandBytes)
                    }
                    self.inspectForm.summary = summary.compactMapValues { $0 }
                }
            }
            await self.detectEncryption(source)
        })
    }

    func runVerify() {
        guard let source = inspectForm.source else {
            fail("Choose an image to verify.")
            return
        }
        run(CommandBuilder.verify(image: source.path, password: inspectForm.password), kind: .inspect, reveal: nil)
    }

    func runCompact() {
        guard let source = compactForm.source else {
            fail("Choose a sparse image to compact.")
            return
        }
        remember(source)
        run(
            CommandBuilder.compact(
                image: source.path,
                batteryAllowed: compactForm.batteryAllowed,
                password: compactForm.password
            ),
            kind: .compact,
            reveal: source
        )
    }

    func queryResizeLimits() {
        guard let source = resizeForm.source else {
            fail("Choose an image to resize.")
            return
        }
        run(CommandBuilder.resizeLimits(image: source.path, password: resizeForm.password), kind: .inspect, reveal: nil, onSuccess: { [weak self] result in
            if let limits = try? PlistParsing.parseResizeLimits(from: result.stdout) {
                self?.resizeForm.snapshot = ResizeLimitsSnapshot(
                    sourcePath: OutputPathGuard.standardized(source).path,
                    limits: limits
                )
            }
        })
    }

    func runResize() {
        guard let source = resizeForm.source else {
            fail("Choose an image to resize.")
            return
        }
        let sourcePath = OutputPathGuard.standardized(source).path
        guard let snapshot = resizeForm.snapshot, snapshot.sourcePath == sourcePath else {
            fail("Query Limits for the currently selected image first.")
            return
        }
        let limits = snapshot.limits
        let amount = sanitizedAmount(resizeForm.amount)
        guard let requested = SizeSpec.bytes(amount: amount, unit: resizeForm.unit) else {
            fail("Enter a numeric size.")
            return
        }
        if requested < limits.minBytes || requested > limits.maxBytes {
            fail("Requested size is outside the reported minimum and maximum.")
            return
        }
        if requested < limits.currentBytes {
            resizeDirectionNote = "This will shrink the image from \(Self.bytesLabel(limits.currentBytes)) to \(Self.bytesLabel(requested)). Shrinking can make the volume unreadable if the filesystem does not fit."
            confirmShrink = true
            return
        }
        if resizeForm.imageOnly || resizeForm.partitionOnly {
            requestAdvancedResizeConfirm(growNote: requested > limits.currentBytes)
            return
        }
        performResize()
    }

    func continueAfterShrinkConfirm() {
        if resizeForm.imageOnly || resizeForm.partitionOnly {
            requestAdvancedResizeConfirm(growNote: false)
        } else {
            performResize()
        }
    }

    private func requestAdvancedResizeConfirm(growNote: Bool) {
        let mode = resizeForm.imageOnly ? "Image Only (−imageonly)" : "Partition Only (−partitiononly)"
        let direction = growNote ? "grow" : "shrink"
        resizeDirectionNote =
            "\(mode) changes only part of the container. A failed \(direction) can leave the image or its partition unusable. Attaché is not a backup — keep a copy of important images."
        confirmAdvancedResize = true
    }

    func performResize() {
        guard let source = resizeForm.source else { return }
        let amount = sanitizedAmount(resizeForm.amount)
        remember(source)
        run(
            CommandBuilder.resize(
                image: source.path,
                sizeSpec: resizeForm.unit.spec(amount),
                imageOnly: resizeForm.imageOnly && !resizeForm.partitionOnly,
                partitionOnly: resizeForm.partitionOnly && !resizeForm.imageOnly,
                password: resizeForm.password
            ),
            kind: .resize,
            reveal: source,
            onFinish: { [weak self] _ in
                self?.resizeForm.snapshot = nil
            }
        )
    }

    func setResizeSource(_ url: URL?) {
        if let url {
            let path = OutputPathGuard.standardized(url).path
            if resizeForm.snapshot?.sourcePath != path {
                resizeForm.snapshot = nil
            }
            resizeForm.source = url
        } else {
            resizeForm.source = nil
            resizeForm.snapshot = nil
        }
    }

    func runChecksum() {
        guard let source = checksumForm.source else {
            fail("Choose an image to checksum.")
            return
        }
        remember(source)
        checksumForm.result = nil
        run(
            CommandBuilder.checksum(image: source.path, type: checksumForm.type, password: checksumForm.password),
            kind: .checksum,
            reveal: nil,
            onSuccess: { [weak self] result in
                self?.checksumForm.result = PlistParsing.parseChecksum(from: result.stdout)
                    ?? self?.lastNonEmptyLogLine()
            }
        )
    }

    func loadBandInfo(from url: URL) {
        bandForm.source = url
        bandForm.currentBytes = SparseBundleInfo.readBandSizeBytes(at: url)
        bandForm.virtualSizeBytes = SparseBundleInfo.readVirtualSizeBytes(at: url)
        if let current = bandForm.currentBytes {
            let match = SparseBandSize.matchingPreset(bytes: current)
            bandForm.preset = match == .systemDefault ? .mb8 : match
            let mb = SparseBandSize.megabytes(bytes: current)
            if mb > 0 { bandForm.customMB = String(mb) }
        }
        convertForm.sourceBandBytes = bandForm.currentBytes
        bandForm.sourceEncrypted = nil
        Task { await detectBandEncryption(url) }
    }

    private func detectBandEncryption(_ url: URL) async {
        do {
            let result = try await service.runProbe(CommandBuilder.isEncrypted(image: url.path))
            if result.status == 0 {
                bandForm.sourceEncrypted = PlistParsing.parseEncrypted(from: result.stdout)
            }
        } catch {
            bandForm.sourceEncrypted = nil
        }
    }

    func requestChangeBandSize() {
        if let message = validateBandChange() {
            fail(message)
            return
        }
        if bandForm.replaceOriginal {
            confirmReplaceBundle = true
        } else if let output = bandForm.output ?? resolvedBandOutput() {
            bandForm.output = output
            if let source = bandForm.source,
               let message = OutputPathGuard.rejectSameItem(source: source, output: output) {
                fail(message)
                return
            }
            runChangeBandSize()
        } else {
            fail("Choose where to save the rewritten sparse bundle.")
        }
    }

    func runChangeBandSize() {
        if let message = validateBandChange() {
            fail(message)
            return
        }
        guard let source = bandForm.source else { return }
        let resolved = SparseBandSize.resolve(preset: bandForm.preset, customMegabytes: bandForm.customMB)
        guard let sectors = resolved.sectors else { return }

        remember(source)
        if bandForm.replaceOriginal {
            let staging = OutputPathGuard.stagingURL(for: source, uniqueID: UUID().uuidString)
            let request = CommandBuilder.convert(
                image: source.path,
                output: staging.path,
                format: .udsb,
                sourcePassword: bandForm.sourcePassword,
                destEncryption: bandForm.destEncryption,
                destPassword: bandForm.destPassword,
                overwrite: false,
                bandSizeSectors: sectors
            )
            registerStaging(staging)
            run(request, kind: .bands, reveal: source, onFinish: { [weak self] finish in
                guard let self else { return }
                switch finish {
                case .succeeded:
                    do {
                        let outcome = try SparseBundleReplacement.replace(
                            original: source,
                            with: staging,
                            files: FileManager.default,
                            uniqueID: UUID().uuidString
                        )
                        self.forgetStaging(staging)
                        self.loadBandInfo(from: source)
                        self.lastRevealURL = source
                        self.appendLog("Replaced original bundle with \(SparseBandSize.displaySectors(sectors)) bands.")
                        if let leftover = outcome.leftoverBackup {
                            self.appendLog("Could not delete the previous copy at \(leftover.path). The new image is in place; remove the old copy yourself.")
                        }
                    } catch {
                        self.job = .failed(error.localizedDescription)
                        self.appendLog(error.localizedDescription)
                        self.removeStaging(staging, context: "after a failed replacement")
                    }
                case .cancelled, .failed(_):
                    self.removeStaging(staging, context: "after unsuccessful band rewrite")
                }
            })
            return
        }

        guard let output = bandForm.output ?? resolvedBandOutput() else {
            fail("Choose where to save the rewritten sparse bundle.")
            return
        }
        if let message = OutputPathGuard.rejectSameItem(source: source, output: output) {
            fail(message)
            return
        }
        bandForm.output = output
        writeStaged(to: output, kind: .bands) { staging in
            CommandBuilder.convert(
                image: source.path,
                output: staging.path,
                format: .udsb,
                sourcePassword: self.bandForm.sourcePassword,
                destEncryption: self.bandForm.destEncryption,
                destPassword: self.bandForm.destPassword,
                overwrite: false,
                bandSizeSectors: sectors
            )
        } onSuccess: { [weak self] committed in
            self?.loadBandInfo(from: committed)
        }
    }

    private func validateBandChange() -> String? {
        guard let source = bandForm.source else {
            return "Choose a sparse bundle."
        }
        guard SparseBundleInfo.isSparseBundle(source) else {
            return "Band size only applies to .sparsebundle images."
        }
        if attached.contains(where: { $0.imagePath == source.path }) {
            return "Detach the sparse bundle before changing its band size."
        }
        let resolved = SparseBandSize.resolve(preset: bandForm.preset, customMegabytes: bandForm.customMB)
        if let message = resolved.error { return message }
        guard let sectors = resolved.sectors else {
            return "Choose a new band size."
        }
        if let current = bandForm.currentBytes,
           current == sectors * SparseBandSize.bytesPerSector {
            return "The bundle already uses \(SparseBandSize.display(bytes: current)) bands."
        }
        return ConvertCredentials.validate(
            destEncryption: bandForm.destEncryption,
            destPassword: bandForm.destPassword,
            destConfirm: bandForm.destConfirm,
            sourcePassword: bandForm.sourcePassword
        )
    }

    func resolvedBandOutput() -> URL? {
        if let output = bandForm.output { return output }
        let base = bandForm.source?.deletingPathExtension().lastPathComponent ?? "Bundle"
        let resolved = SparseBandSize.resolve(preset: bandForm.preset, customMegabytes: bandForm.customMB)
        let label = resolved.sectors.map { SparseBandSize.displaySectors($0).replacingOccurrences(of: " ", with: "") } ?? "bands"
        return pickSaveURL(defaultName: "\(base)-\(label)", ext: "sparsebundle")
    }

    func runHybrid() {
        guard let source = hybridForm.source else {
            fail("Choose a folder or image to make a hybrid from.")
            return
        }
        guard hybridForm.hfs || hybridForm.iso || hybridForm.joliet || hybridForm.udf else {
            fail("Select at least one filesystem (HFS+, ISO, Joliet, or UDF).")
            return
        }
        guard let output = resolvedHybridOutput() else {
            fail("Choose where to save the hybrid image.")
            return
        }
        hybridForm.output = output
        if let message = OutputPathGuard.rejectSameItem(source: source, output: output) {
            fail(message)
            return
        }
        if source.hasDirectoryPath,
           let message = OutputPathGuard.rejectOutputInsideSourceFolder(sourceFolder: source, output: output) {
            fail(message)
            return
        }
        remember(output)
        writeStaged(to: output, kind: .hybrid) { staging in
            CommandBuilder.makeHybrid(
                source: source.path,
                output: staging.path,
                hfs: self.hybridForm.hfs,
                iso: self.hybridForm.iso,
                joliet: self.hybridForm.joliet,
                udf: self.hybridForm.udf,
                volumeName: self.hybridForm.volumeName,
                overwrite: false
            )
        }
    }

    func detectEncryption(_ url: URL) async {
        do {
            let result = try await service.runProbe(CommandBuilder.isEncrypted(image: url.path))
            let flag = PlistParsing.parseEncrypted(from: result.stdout)
            attachForm.encrypted = flag
            inspectForm.encrypted = flag
        } catch {
            attachForm.encrypted = nil
        }
    }

    func pickSaveURL(defaultName: String, ext: String) -> URL? {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = DiskImagePath.suggestedName(base: defaultName, ext: ext)
        panel.title = "Save Disk Image"
        panel.allowedContentTypes = [UTType(filenameExtension: ext) ?? .data]
        return panel.runModal() == .OK ? panel.url : nil
    }

    func pickFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = "Choose Folder"
        return panel.runModal() == .OK ? panel.url : nil
    }

    func pickMountPoint() -> URL? {
        pickFolder()
    }

    func clearLog() {
        log = ""
        if !job.isRunning { job = .idle }
    }

    func clearPasswords() {
        attachForm.password = ""
        createForm.password = ""
        createForm.confirm = ""
        convertForm.password = ""
        inspectForm.password = ""
        compactForm.password = ""
        bandForm.sourcePassword = ""
        bandForm.destPassword = ""
        bandForm.destConfirm = ""
        resizeForm.password = ""
        checksumForm.password = ""
    }

    private var pendingWrite: (() -> Void)?

    func confirmPendingOverwrite() {
        let action = pendingWrite
        pendingWrite = nil
        action?()
    }

    func cancelPendingOverwrite() {
        pendingWrite = nil
    }

    /// Returns true if the app may quit.
    func confirmQuitIfNeeded() -> Bool {
        guard job.isRunning else { return true }
        let kind = job.kind
        let alert = NSAlert()
        alert.messageText = "A disk-image operation is still running."
        if kind?.stronglyDiscourageQuit == true {
            alert.informativeText =
                "This operation is changing an existing image (resize, compact, or bundle replacement). Quitting now can leave that image incomplete or unusable. Keep Attaché open until it finishes."
        } else {
            alert.informativeText =
                "Quitting now may leave an incomplete image."
        }
        alert.addButton(withTitle: "Keep Running")
        alert.addButton(withTitle: "Quit Anyway")
        if #available(macOS 11.0, *) {
            alert.buttons.last?.hasDestructiveAction = true
        }
        return alert.runModal() != .alertFirstButtonReturn
    }

    private let stagingRegistryKey = "Attache.stagingArtifacts"

    private func writeStaged(
        to final: URL,
        kind: JobKind,
        build: @escaping (URL) -> HDIRequest,
        onSuccess: ((URL) async -> Void)? = nil
    ) {
        let dest = OutputPathGuard.standardized(final)
        let existedAtStart = FileManager.default.fileExists(atPath: dest.path)
        let overwriteConfirmed = existedAtStart
        let start: () -> Void = { [weak self] in
            guard let self else { return }
            let staging = OutputPathGuard.stagingURL(for: dest, uniqueID: UUID().uuidString)
            self.registerStaging(staging)
            self.run(build(staging), kind: kind, reveal: dest, onFinish: { [weak self] finish in
                guard let self else { return }
                switch finish {
                case .succeeded:
                    await self.commitStaged(
                        staging: staging,
                        dest: dest,
                        overwriteConfirmed: overwriteConfirmed,
                        onSuccess: onSuccess
                    )
                case .cancelled, .failed(_):
                    self.removeStaging(staging, context: "after unsuccessful \(kind.rawValue)")
                }
            })
        }
        if existedAtStart {
            overwritePath = dest.path
            pendingWrite = start
            confirmOverwrite = true
        } else {
            start()
        }
    }

    private func commitStaged(
        staging: URL,
        dest: URL,
        overwriteConfirmed: Bool,
        onSuccess: ((URL) async -> Void)?
    ) async {
        let destExistsNow = FileManager.default.fileExists(atPath: dest.path)
        if destExistsNow && !overwriteConfirmed {
            self.job = .failed("A file appeared at the destination while the operation ran. It was not overwritten.")
            self.appendLog("Left the new image at \(staging.path) and preserved \(dest.path).")
            return
        }

        if let verifyError = await verifyStagedImage(staging) {
            self.job = .failed(verifyError)
            self.appendLog("Staged image left at \(staging.path)")
            return
        }

        do {
            if destExistsNow {
                let outcome = try SparseBundleReplacement.replace(
                    original: dest,
                    with: staging,
                    files: FileManager.default,
                    uniqueID: UUID().uuidString
                )
                if let leftover = outcome.leftoverBackup {
                    self.appendLog("Could not delete the previous copy at \(leftover.path). The new image is in place; remove the old copy yourself.")
                }
            } else {
                try FileManager.default.moveItem(at: staging, to: dest)
            }
            forgetStaging(staging)
            self.lastRevealURL = dest
            await onSuccess?(dest)
        } catch {
            self.job = .failed(error.localizedDescription)
            self.appendLog(error.localizedDescription)
            self.removeStaging(staging, context: "after a failed commit")
        }
    }

    private func verifyStagedImage(_ staging: URL) async -> String? {
        do {
            let result = try await service.runProbe(CommandBuilder.imageInfo(image: staging.path, password: nil))
            if result.status != 0 {
                return "The staged image could not be read with hdiutil imageinfo (exit \(result.status)). The destination was not replaced. Staging file: \(staging.path)"
            }
            return nil
        } catch {
            return "Could not verify the staged image: \(error.localizedDescription). Staging file: \(staging.path)"
        }
    }

    private func attachCommittedImage(_ url: URL) async {
        let request = CommandBuilder.attach(
            image: url.path,
            readOnly: false,
            noMount: false,
            skipVerify: false,
            autoOpen: false,
            mountPoint: nil,
            password: nil
        )
        appendCommand(request.displayCommand)
        do {
            let result = try await service.runJob(request, onProgress: { _ in }, onLog: { [weak self] line in
                self?.appendLog(line)
            })
            if result.status == 0 {
                appendLog("Attached \(url.path)")
            } else {
                appendLog("Created the image but attach failed (exit \(result.status)).")
            }
        } catch {
            appendLog("Created the image but attach failed: \(error.localizedDescription)")
        }
    }

    private func removeStaging(_ url: URL, context: String) {
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            forgetStaging(url)
        } catch {
            appendLog("Could not delete the partial image \(context): \(url.path) (\(error.localizedDescription))")
        }
    }

    private func registerStaging(_ url: URL) {
        var items = UserDefaults.standard.stringArray(forKey: stagingRegistryKey) ?? []
        if !items.contains(url.path) {
            items.append(url.path)
            UserDefaults.standard.set(items, forKey: stagingRegistryKey)
        }
    }

    private func forgetStaging(_ url: URL) {
        var items = UserDefaults.standard.stringArray(forKey: stagingRegistryKey) ?? []
        items.removeAll { $0 == url.path }
        UserDefaults.standard.set(items, forKey: stagingRegistryKey)
    }

    private func sweepPartialArtifacts() {
        var paths = Set(UserDefaults.standard.stringArray(forKey: stagingRegistryKey) ?? [])
        var directories = Set(recents.map { $0.deletingLastPathComponent().path })
        directories.insert(NSHomeDirectory() + "/Desktop")
        directories.insert(NSTemporaryDirectory())
        let fm = FileManager.default
        for dir in directories {
            if let names = try? fm.contentsOfDirectory(atPath: dir) {
                for name in names where StagingName.isPartialArtifact(name) {
                    paths.insert((dir as NSString).appendingPathComponent(name))
                }
            }
        }
        for path in paths {
            let url = URL(fileURLWithPath: path)
            if fm.fileExists(atPath: path) {
                do {
                    try fm.removeItem(at: url)
                    appendLog("Removed leftover partial image \(path)")
                } catch {
                    appendLog("Could not delete leftover partial image \(path): \(error.localizedDescription)")
                }
            }
        }
        UserDefaults.standard.set([] as [String], forKey: stagingRegistryKey)
    }

    private func run(
        _ request: HDIRequest,
        kind: JobKind,
        reveal: URL?,
        onSuccess: ((HDIResult) async -> Void)? = nil,
        onFinish: ((JobFinish) async -> Void)? = nil
    ) {
        guard canRun else { return }
        jobTask?.cancel()
        lastRevealURL = reveal
        appendCommand(request.displayCommand)
        job = .running(verb: request.verb, percent: nil, kind: kind)
        jobTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await self.service.runJob(
                    request,
                    onProgress: { [weak self] value in
                        self?.job = .running(verb: request.verb, percent: value, kind: kind)
                    },
                    onLog: { [weak self] line in
                        self?.appendLog(line)
                    }
                )
                let finish = JobFinish.classify(status: result.status, taskCancelled: Task.isCancelled)
                switch finish {
                case .cancelled:
                    self.job = .cancelled
                    self.appendLog("Cancelled.")
                case .succeeded:
                    let summary = "hdiutil \(request.verb) finished."
                    self.job = .succeeded(summary)
                    self.appendLog(summary)
                    if let reveal {
                        self.lastRevealURL = reveal
                    }
                    await onSuccess?(result)
                case .failed(let status):
                    let message = Self.failureMessage(verb: request.verb, status: status, log: result.log)
                    self.job = .failed(message)
                    self.appendLog(message)
                }
                await onFinish?(finish)
            } catch is CancellationError {
                self.job = .cancelled
                self.appendLog("Cancelled.")
                await onFinish?(.cancelled)
            } catch {
                self.job = .failed(error.localizedDescription)
                self.appendLog(error.localizedDescription)
                await onFinish?(.failed(status: -1))
            }
            self.clearPasswords()
        }
    }

    private func validateCreate() -> String? {
        if createForm.mode == .blank {
            let amount = sanitizedAmount(createForm.sizeAmount)
            if amount.isEmpty || Double(amount) == nil {
                return "Enter a numeric size for the blank image."
            }
        }
        if createForm.mode == .folder && createForm.folder == nil {
            return "Choose a source folder."
        }
        if createForm.mode == .device && createForm.deviceBSD.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Choose a source device."
        }
        return CommandBuilder.validatePassword(
            encryption: createForm.encryption,
            password: createForm.password,
            confirm: createForm.confirm
        )
    }

    func resolvedCreateOutput() -> URL? {
        if let output = createForm.output { return output }
        let ext: String
        switch createForm.mode {
        case .blank: ext = createForm.type.fileExtension
        case .folder: ext = createForm.folderFormat.fileExtension
        case .device: ext = createForm.deviceFormat.fileExtension
        }
        let base: String
        switch createForm.mode {
        case .blank:
            base = createForm.volumeName.isEmpty ? "Untitled" : createForm.volumeName
        case .folder:
            base = createForm.folder?.lastPathComponent ?? "Folder"
        case .device:
            base = createForm.deviceBSD.isEmpty ? "Device" : createForm.deviceBSD.replacingOccurrences(of: "/dev/", with: "")
        }
        return pickSaveURL(defaultName: base, ext: ext)
    }

    func resolvedConvertOutput() -> URL? {
        if let output = convertForm.output { return output }
        let base = convertForm.source?.deletingPathExtension().lastPathComponent ?? "Converted"
        return pickSaveURL(defaultName: base, ext: convertForm.format.fileExtension)
    }

    func resolvedHybridOutput() -> URL? {
        if let output = hybridForm.output { return output }
        let base = hybridForm.source?.lastPathComponent ?? "Hybrid"
        return pickSaveURL(defaultName: base, ext: "iso")
    }

    private func sanitizedAmount(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
    }

    private func fail(_ message: String) {
        job = .failed(message)
        appendLog(message)
    }

    private func appendCommand(_ command: String) {
        if !log.isEmpty { log.append("\n") }
        log.append("$ \(command)\n")
    }

    func appendLog(_ line: String) {
        if !log.isEmpty && !log.hasSuffix("\n") { log.append("\n") }
        log.append(line)
        if !line.hasSuffix("\n") { log.append("\n") }
    }

    private func lastNonEmptyLogLine() -> String? {
        log.split(whereSeparator: \.isNewline)
            .map { String($0) }
            .last(where: { !$0.hasPrefix("$") && !$0.hasPrefix("hdiutil") && !$0.isEmpty })
    }

    private func remember(_ url: URL) {
        recents.removeAll { $0.path == url.path }
        recents.insert(url, at: 0)
        if recents.count > 12 { recents = Array(recents.prefix(12)) }
        saveRecents()
    }

    private func loadRecents() {
        let paths = UserDefaults.standard.stringArray(forKey: recentsKey) ?? []
        recents = paths.map { URL(fileURLWithPath: $0) }.filter {
            FileManager.default.fileExists(atPath: $0.path)
        }
    }

    private func saveRecents() {
        UserDefaults.standard.set(recents.map(\.path), forKey: recentsKey)
    }

    private static func failureMessage(verb: String, status: Int32, log: String) -> String {
        let lines = log.split(whereSeparator: \.isNewline).map { String($0) }
        let useful = lines.reversed().first(where: { line in
            let lower = line.lowercased()
            return !line.isEmpty
                && !lower.hasPrefix("percent")
                && !lower.hasPrefix("$")
        })
        if let useful, useful.count < 400 {
            return useful
        }
        return "hdiutil \(verb) failed (exit \(status))."
    }

    private static func bytesLabel(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    static let imageTypes: [UTType] = {
        let tags = ["dmg", "iso", "img", "cdr", "sparseimage", "sparsebundle", "toast", "shadow"]
        return tags.compactMap { UTType(filenameExtension: $0) } + [
            UTType(filenameExtension: "dmg") ?? .data
        ]
    }()
}
