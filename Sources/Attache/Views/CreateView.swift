import SwiftUI
import AttacheCore

struct CreateView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        FormCard {
            OperationHeader(
                title: "Create",
                systemImage: "plus.rectangle.on.folder",
                blurb: "Create a blank image, image a folder, or clone a device. Wraps hdiutil create, or diskutil image create for Apple Sparse Image."
            )

            Picker("Source", selection: $model.createForm.mode) {
                ForEach(CreateMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch model.createForm.mode {
            case .blank:
                blankFields
            case .folder:
                folderFields
            case .device:
                deviceFields
            }

            GroupBox("Output") {
                VStack(alignment: .leading, spacing: 10) {
                    PathWell(
                        title: "Save as",
                        placeholder: "Choose a destination…",
                        url: model.createForm.output,
                        onChoose: {
                            model.createForm.output = model.resolvedCreateOutput()
                        },
                        onClear: { model.createForm.output = nil }
                    )
                    if model.createForm.mode != .device {
                        Toggle("Attach after create", isOn: $model.createForm.attachAfter)
                    }
                    Text("If the destination already exists, Attaché will ask before replacing it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .toggleStyle(.checkbox)
            }

            GroupBox("Encryption") {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Encryption", selection: $model.createForm.encryption) {
                        ForEach(encryptionChoices) { choice in
                            Text(choice.title).tag(choice)
                        }
                    }
                    .labelsHidden()
                    if model.createForm.createsASIF {
                        Text("Apple Sparse Image encryption is AES-256.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if model.createForm.encryption != .none {
                        PasswordFields(
                            prompt: "New image password",
                            password: $model.createForm.password,
                            confirm: $model.createForm.confirm
                        )
                    }
                }
            }

            ActionBar {
                Button {
                    model.runCreate()
                } label: {
                    Label("Create Image", systemImage: "plus.rectangle.on.folder")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.canRun)
            } secondary: {
                Text(outputHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: model.createForm.mode) { _ in model.normalizeASIFForm() }
        .onChange(of: model.createForm.type) { _ in model.normalizeASIFForm() }
        .onChange(of: model.createForm.folderFormat) { _ in model.normalizeASIFForm() }
        .onChange(of: model.createForm.deviceFormat) { _ in model.normalizeASIFForm() }
    }

    private var blankFields: some View {
        GroupBox("Blank image") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Size")
                        .frame(width: 110, alignment: .leading)
                    TextField("Size", text: $model.createForm.sizeAmount)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 90)
                    Picker("Unit", selection: $model.createForm.sizeUnit) {
                        ForEach(SizeUnit.allCases) { unit in
                            Text(unit.title).tag(unit)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 80)
                }
                HStack {
                    Text("Type")
                        .frame(width: 110, alignment: .leading)
                    Picker("Type", selection: $model.createForm.type) {
                        ForEach(BlankImageType.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 320)
                }
                filesystemPicker
                if model.createForm.type == .asif {
                    Text("Apple Sparse Image uses diskutil image. The filesystem can be APFS, ExFAT, or MS-DOS.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                volumeNameField
                if model.createForm.type == .sparsebundle {
                    Divider()
                    BandSizePicker(
                        preset: $model.createForm.bandPreset,
                        customMegabytes: $model.createForm.bandCustomMB
                    )
                }
            }
        }
    }

    private var folderFields: some View {
        GroupBox("Folder") {
            VStack(alignment: .leading, spacing: 10) {
                PathWell(
                    title: "Source folder",
                    placeholder: "Choose a folder to image",
                    url: model.createForm.folder,
                    recents: model.recents.filter(\.hasDirectoryPath),
                    onChoose: { model.createForm.folder = model.pickFolder() },
                    onClear: { model.createForm.folder = nil },
                    onPickRecent: { model.createForm.folder = $0 }
                )
                HStack {
                    Text("Format")
                        .frame(width: 110, alignment: .leading)
                    Picker("Format", selection: $model.createForm.folderFormat) {
                        ForEach(ImageFormat.folderCreateCases) { format in
                            Text("\(format.rawValue) — \(format.title)").tag(format)
                        }
                    }
                    .labelsHidden()
                }
                Text(model.createForm.folderFormat.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if model.createForm.folderFormat == .asif {
                    Text("An Apple Sparse Image from a folder keeps the source layout. diskutil image does not take a filesystem override.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Toggle("Override filesystem", isOn: $model.createForm.overrideFilesystem)
                        .toggleStyle(.checkbox)
                    if model.createForm.overrideFilesystem {
                        filesystemPicker
                    }
                }
                volumeNameField
                if model.createForm.folderFormat == .udsb {
                    Divider()
                    BandSizePicker(
                        preset: $model.createForm.bandPreset,
                        customMegabytes: $model.createForm.bandCustomMB
                    )
                }
            }
        }
    }

    private var deviceFields: some View {
        GroupBox("Device") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Device")
                        .frame(width: 110, alignment: .leading)
                    Picker("Device", selection: $model.createForm.deviceBSD) {
                        Text("Choose…").tag("")
                        ForEach(model.devices) { device in
                            Text("\(device.bsdName) — \(device.name) (\(device.sizeLabel))")
                                .tag(device.bsdName)
                        }
                    }
                    .labelsHidden()
                    Button("Reload") {
                        Task { model.devices = await model.service.listDevices() }
                    }
                    .controlSize(.small)
                }
                TextField("or enter /dev/diskN", text: $model.createForm.deviceBSD)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Text("Format")
                        .frame(width: 110, alignment: .leading)
                    Picker("Format", selection: $model.createForm.deviceFormat) {
                        ForEach(ImageFormat.folderCreateCases) { format in
                            Text("\(format.rawValue) — \(format.title)").tag(format)
                        }
                    }
                    .labelsHidden()
                }
                Text(deviceCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if model.createForm.deviceFormat == .udsb {
                    Divider()
                    BandSizePicker(
                        preset: $model.createForm.bandPreset,
                        customMegabytes: $model.createForm.bandCustomMB
                    )
                }
            }
        }
    }

    private var filesystemPicker: some View {
        HStack {
            Text("Filesystem")
                .frame(width: 110, alignment: .leading)
            Picker("Filesystem", selection: $model.createForm.filesystem) {
                ForEach(filesystemCases) { fs in
                    Text(fs.title).tag(fs)
                }
            }
            .labelsHidden()
            .frame(maxWidth: 360)
        }
    }

    private var volumeNameField: some View {
        HStack {
            Text("Volume name")
                .frame(width: 110, alignment: .leading)
            TextField("Volume name", text: $model.createForm.volumeName)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 280)
        }
    }

    private var encryptionChoices: [EncryptionChoice] {
        model.createForm.createsASIF ? [.none, .aes256] : EncryptionChoice.allCases
    }

    private var filesystemCases: [DiskFilesystem] {
        model.createForm.createsASIF ? DiskFilesystem.asifCases : DiskFilesystem.allCases
    }

    private var deviceCaption: String {
        if model.createForm.deviceFormat == .asif {
            return "Cloning a device to Apple Sparse Image uses diskutil image. A root-owned disk can fail with Operation not permitted. Other formats still use hdiutil create −srcdevice. Prefer an external disk, and use an APFS container rather than a single volume."
        }
        return "Imaging a physical disk reads every block. Prefer an external disk. APFS sources must be a container, not a single volume."
    }

    private var outputHint: String {
        switch model.createForm.mode {
        case .blank:
            return ".\(model.createForm.type.fileExtension) · \(model.createForm.sizeAmount)\(model.createForm.sizeUnit.rawValue)"
        case .folder:
            return ".\(model.createForm.folderFormat.fileExtension) · \(model.createForm.folderFormat.rawValue)"
        case .device:
            return ".\(model.createForm.deviceFormat.fileExtension) · \(model.createForm.deviceFormat.rawValue)"
        }
    }
}
