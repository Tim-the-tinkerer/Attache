import SwiftUI
import AttacheCore
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow
    @State private var isDropTargeted = false
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
                .navigationSplitViewColumnWidth(min: 208, ideal: 228, max: 280)
        } detail: {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    JobConsoleView(model: model)
                }
        }
        .navigationSplitViewStyle(.balanced)
        .navigationTitle(model.selection.title)
        .navigationSubtitle(model.selection.summary)
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(minWidth: 960, minHeight: 620)
        .onAppear {
            columnVisibility = .all
            HelpWindowOpener.shared.openWindow = { id in
                openWindow(id: id)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted, perform: handleDrop)
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Theme.accent, lineWidth: 3)
                    .padding(6)
                    .allowsHitTesting(false)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openAttacheHelp)) { _ in
            openWindow(id: HelpPresenter.windowID)
        }
        .alert("Force Detach?", isPresented: $model.confirmForceDetach) {
            Button("Cancel", role: .cancel) {}
            Button("Force Detach", role: .destructive) {
                model.detachSelected(force: true)
            }
        } message: {
            Text("Open files on the volume will be ignored. Unsaved work on that volume may be lost.")
        }
        .alert("Replace original bundle?", isPresented: $model.confirmReplaceBundle) {
            Button("Cancel", role: .cancel) {}
            Button("Replace", role: .destructive) {
                model.runChangeBandSize()
            }
        } message: {
            Text("After the new sparse bundle is written, the original will be replaced. Detach it first. Attaché cannot undo this.")
        }
        .alert("Overwrite existing file?", isPresented: $model.confirmOverwrite) {
            Button("Cancel", role: .cancel) { model.cancelPendingOverwrite() }
            Button("Overwrite", role: .destructive) {
                model.confirmPendingOverwrite()
            }
        } message: {
            Text("\(model.overwritePath)\n\nAttaché will write a temporary sibling first and replace this file only after success. If the swap fails, the original is restored. Attaché is not a backup.")
        }
        .alert("Shrink this image?", isPresented: $model.confirmShrink) {
            Button("Cancel", role: .cancel) {}
            Button("Shrink", role: .destructive) {
                model.continueAfterShrinkConfirm()
            }
        } message: {
            Text(model.resizeDirectionNote + "\n\nAttaché is not a backup.")
        }
        .alert("Advanced resize?", isPresented: $model.confirmAdvancedResize) {
            Button("Cancel", role: .cancel) {}
            Button("Resize Anyway", role: .destructive) {
                model.performResize()
            }
        } message: {
            Text(model.resizeDirectionNote)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if model.selection == .attached {
                    Button {
                        Task { await model.refreshAttached() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .help("Refresh attached images")
                    .disabled(model.isRefreshing)

                    Button {
                        model.selection = .attach
                        model.chooseImage(for: .attach)
                    } label: {
                        Label("Attach…", systemImage: "externaldrive.badge.plus")
                    }
                    .help("Choose a disk image to attach")
                }

                Button {
                    HelpWindowOpener.shared.open()
                } label: {
                    Label("Help", systemImage: "questionmark.circle")
                }
            }
        }
    }

    private var sidebar: some View {
        ScrollViewReader { proxy in
            List(selection: $model.selection) {
                ForEach(SidebarSection.allCases) { section in
                    Section(section.rawValue) {
                        ForEach(section.items) { item in
                            sidebarRow(item)
                                .tag(item)
                                .id(item)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .onAppear {
                proxy.scrollTo(SidebarItem.attached, anchor: .top)
            }
            .onChange(of: model.selection) { item in
                withAnimation(.easeInOut(duration: 0.15)) {
                    proxy.scrollTo(item, anchor: .center)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                if let version = model.frameworkVersion {
                    Text("DiskImages \(version)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
                Text("Attaché \(AppVersion.short)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private func sidebarRow(_ item: SidebarItem) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                Text(item.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } icon: {
            Image(systemName: item.systemImage)
                .symbolRenderingMode(.hierarchical)
        }
        .padding(.vertical, 2)
        .help(item.subtitle)
    }

    @ViewBuilder
    private var detail: some View {
        switch model.selection {
        case .attached:
            AttachedView(model: model)
        case .attach:
            AttachView(model: model)
        case .create:
            CreateView(model: model)
        case .convert:
            ConvertView(model: model)
        case .inspect:
            InspectView(model: model)
        case .compact:
            CompactView(model: model)
        case .bands:
            BandSizeView(model: model)
        case .resize:
            ResizeView(model: model)
        case .checksum:
            ChecksumView(model: model)
        case .hybrid:
            HybridView(model: model)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var claimed = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                claimed = true
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    let url: URL? = {
                        if let url = item as? URL { return url }
                        if let data = item as? Data {
                            return URL(dataRepresentation: data, relativeTo: nil)
                        }
                        return nil
                    }()
                    guard let url else { return }
                    DispatchQueue.main.async {
                        model.openImage(url)
                    }
                }
            }
        }
        return claimed
    }
}
