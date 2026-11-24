# Attaché

Attaché is a complete native macOS disk-image workbench, exposing the useful capabilities of Apple’s hdiutil through an approachable graphical interface.

**Version:** 1.4.0 — see [CHANGELOG.md](CHANGELOG.md).

## Features

- **Home** — overview cards for every action, plus the live attached-image list
- **Attach** — mount a `.dmg`, `.iso`, `.asif`, `.sparseimage`, or `.sparsebundle` with read-only, nomount, verify, and mount-point options. `.asif` uses `diskutil image attach`
- **Create** — blank image, image from a folder, or clone a device (UDIF / sparse / sparse bundle / Apple Sparse Image, APFS / HFS+ / ExFAT / FAT). Sparse bundles can set band size (1 MB–8 GB). Blank `.asif` images use APFS, ExFAT, or MS-DOS, and AES-256
- **Convert** — rewrite between UDZO, ULFO, ULMO, UDRW, sparse, ASIF, DVD master, and more. UDSB output can set band size. A source or destination `.asif` uses `diskutil image` (ASIF, RAW, UDRO, UDZO, ULFO, ULMO, UDSB)
- **Inspect** — `imageinfo` tree plus stored-checksum verify
- **Compact** — reclaim unused bands in sparse images
- **Band Size** — read or change a sparse bundle’s band size (`-imagekey` / `-tgtimagekey sparse-band-size`)
- **Resize** — query min/current/max, then grow or shrink
- **Checksum** — SHA-256, SHA-512, SHA-1, MD5, CRC-32, UDIF checksums
- **Hybrid ISO** — HFS+ / ISO9660 / Joliet / UDF via `makehybrid`
- **Console** — shows the exact invocation and live progress. macOS 27 `hdiutil` deprecation warnings are filtered out
- **Passwords** — sent on stdin with `-stdinpass` (or `--stdinpass` for `diskutil image`), never as a process argument. Staged verification and Attach After Create reuse that password
- Drag-and-drop images onto the window; Open With for disk images (does not steal the default handler)

## Requirements

- macOS 13 or later. Apple Sparse Image needs macOS 27
- Swift toolchain (`xcode-select` / Command Line Tools or Xcode). SwiftUI builds use Xcode’s toolchain
- System `hdiutil` at `/usr/bin/hdiutil` and `diskutil` at `/usr/sbin/diskutil`

## Build & run

```bash
cd "$HOME/Apps - macOS Utility/Attache"
chmod +x build-app.sh
./build-app.sh
```

This builds a release binary, packages `Attaché.app`, ad-hoc signs it, and opens it.

Build without launching:

```bash
./build-app.sh --no-launch
```

SwiftPM only:

```bash
swift run AttacheCheck
swift build -c release
```

## Install (optional)

```bash
cp -R "Attaché.app" /Applications/
```

## Usage

| Sidebar        | Command              | What it does                                      |
|----------------|----------------------|---------------------------------------------------|
| Home           | `hdiutil info`       | Overview, action cards, and attached images       |
| Attach         | `hdiutil attach` or `diskutil image attach` | Mount a disk image. `.asif` uses diskutil |
| Create         | `hdiutil create` or `diskutil image create` | Blank, from folder, or from device. `.asif` uses diskutil |
| Convert        | `hdiutil convert` or `diskutil image create` | Change image format. `.asif` source or destination uses diskutil |
| Inspect        | `imageinfo` / `verify` | Metadata and checksum check. `.asif` info uses `diskutil image info`; verify refuses `.asif` |
| Compact        | `hdiutil compact`    | Shrink sparse images. Not available for `.asif`  |
| Band Size      | `convert` + imagekey | Read or change sparse-bundle band size            |
| Resize         | `hdiutil resize` or `diskutil image resize` | Change virtual size. `.asif` has no partition-only |
| Checksum       | `hdiutil checksum`   | Hash the image. Not available for `.asif`         |
| Hybrid ISO     | `hdiutil makehybrid` | Cross-platform ISO. Not available for `.asif`     |

Shortcuts: **⌘O** open image, **⌘R** refresh attached list, **⌘.** cancel, **⌘⇧R** reveal last output.

## Notes

- This is a front end for the system `hdiutil`, plus `diskutil image` for Apple Sparse Image. It does not install a private disk-image stack.
- Creating an image of a physical disk reads every block; prefer an external disk, and use an APFS *container* rather than a single APFS volume. Cloning a device to `.asif` uses `diskutil image` and can fail with “Operation not permitted” on a root-owned disk.
- Verify, compact, checksum, and hybrid do not accept `.asif`. Encryption detection still uses `hdiutil isencrypted`, which answers immediately for that format.
- Burn, `chpass`, and `erasekeys` are not wrapped.

## License

Copyright © 2026. All rights reserved.
