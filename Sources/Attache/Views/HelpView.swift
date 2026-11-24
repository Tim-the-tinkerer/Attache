import SwiftUI

struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Label("Attaché", systemImage: "internaldrive")
                    .font(.title2.weight(.semibold))

                Text("A native macOS front end for Apple’s hdiutil, and for Apple Sparse Image (.asif) the diskutil image commands. Every action runs the real command; the console at the bottom shows the exact invocation (passwords are never included).")
                    .foregroundStyle(.secondary)

                section("Home") {
                    numbered(1, "Home is the overview. Action cards jump to each operation.")
                    numbered(2, "Attached images appear under the cards. Detach unmounts. An Apple Sparse Image uses diskutil eject; other images use hdiutil detach. Force adds the force flag.")
                    numbered(3, "Open reveals the mount point in Finder; Reveal selects the image file.")
                }

                section("Attach / Create / Convert") {
                    bullet("Attach mounts a .dmg, .iso, .asif, sparse image, or sparse bundle. Skip verify and Finder auto-open do not apply to .asif.")
                    bullet("Create a blank image, an image from a folder, or a clone of a device. Sparse bundles can pick a band size (1 MB–8 GB). Apple Sparse Image blanks use APFS, ExFAT, or MS-DOS, and AES-256 only.")
                    bullet("Convert rewrites an image into another format (UDZO, ULFO, ULMO, UDRW, sparse, ASIF, …). Converting to UDSB can set the band size, except when the source is .asif. diskutil image can write ASIF, RAW, UDRO, UDZO, ULFO, ULMO, and UDSB. UDRW becomes RAW.")
                    bullet("Drop a file onto the window to fill the current form.")
                }

                section("Inspect & maintain") {
                    bullet("Inspect runs imageinfo, or diskutil image info for .asif. Verify, compact, checksum, and hybrid are hdiutil-only and refuse an Apple Sparse Image.")
                    bullet("Compact reclaims unused space in sparse images and sparse bundles.")
                    bullet("Band Size reads Info.plist and rewrites a sparse bundle with a new band size via convert −tgtimagekey sparse-band-size. Detach first; this cannot be done in place.")
                    bullet("The source password unlocks an encrypted bundle. Destination encryption is a separate choice (None / AES-128 / AES-256). If the source is encrypted, that same password is reused; a different destination password would need a later chpass step, which Attaché does not wrap.")
                    bullet("Force Detach and Replace original ask for confirmation. Passwords are cleared when a job finishes.")
                    bullet("Resize changes the virtual size. Query Limits first to see min / current / max. An Apple Sparse Image cannot use partition-only resize. diskutil reports limits in bytes; Attaché shows them as 512-byte sectors.")
                    bullet("Checksum computes SHA-256 and other hashes over the image file.")
                    bullet("Hybrid ISO builds a cross-platform HFS+ / ISO / Joliet / UDF image.")
                }

                section("Passwords") {
                    bullet("Encrypted images use AES-128 or AES-256. Apple Sparse Image encryption is AES-256 only.")
                    bullet("The passphrase is written to the command’s stdin (−stdinpass, or a newline-terminated --stdinpass for diskutil image). It never appears in ps output or in the console command line. Attaché does not retain passwords after a job ends; that is not a claim of secure memory erasure.")
                    bullet("Create, convert, hybrid, and band-size writes go to a temporary sibling and replace the destination only after image info succeeds. That check receives the job password, including for an encrypted Apple Sparse Image. Attach After Create mounts the final path with the same password, not the staging file.")
                    bullet("Failed or cancelled writes delete the hidden .partial. file. If deletion fails, the exact path is logged.")
                    bullet("Background attached-image refresh cannot interrupt a user job. Cancel applies only to that job.")
                    bullet("Quitting while a job is running requires confirmation. Resize, compact, and bundle replacement strongly discourage quitting.")
                }

                section("Tips") {
                    bullet("⌘O opens an image. ⌘R refreshes the attached list. ⌘. cancels a running job.")
                    bullet("Copy in the console copies the log, including the command you can paste into Terminal. macOS 27 deprecation warnings from hdiutil are left out of the log.")
                    bullet("hdiutil appends the right extension if you omit it. Apple Sparse Image files use .asif.")
                    bullet("This app does not wrap burn, chpass, or erasekeys.")
                }

                section("Requirements") {
                    bullet("macOS 13 or later. Apple Sparse Image needs macOS 27, where diskutil image supports it.")
                    bullet("The system hdiutil at /usr/bin/hdiutil and diskutil at /usr/sbin/diskutil")
                }

                Text("Attaché \(AppVersion.display)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 8)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content()
        }
    }

    private func numbered(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(n).")
                .font(.body.monospacedDigit().weight(.semibold))
                .frame(width: 20, alignment: .trailing)
            Text(text)
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundStyle(.secondary)
            Text(text)
        }
    }
}
