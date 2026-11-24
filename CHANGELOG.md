# Changelog

All notable changes to **Attaché** are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project aims to follow [Semantic Versioning](https://semver.org/).

## [1.4.0] - 2026-11-23

### Added

- Apple Sparse Image (`.asif`) attach, inspect, create, convert, and resize go through `diskutil image`. Detach of an attached `.asif` uses `diskutil eject`. Other formats stay on `hdiutil`
- Blank ASIF images can use APFS, ExFAT, or MS-DOS, with AES-256 encryption. Convert can write ASIF, RAW, UDRO, UDZO, ULFO, ULMO, and UDSB. UDRW is written as RAW
- The app claims the `.asif` extension

### Fixed

- Staged-image verification passes the job password into `imageinfo` (or `diskutil image info` for `.asif`), so an encrypted image no longer waits on SecurityAgent
- Attach After Create passes the create password into the attach
- Checksum results still parse when `hdiutil -puppetstrings` prints progress lines ahead of the plist
- macOS 27 `hdiutil` deprecation warnings are omitted from the console and from failure text
- ASIF resize limits, which `diskutil` reports in bytes, are converted to 512-byte sectors before the min / current / max check

### Changed

- Verify, compact, checksum, and hybrid refuse an Apple Sparse Image, because those `hdiutil` verbs do not read the format
- ASIF attach ignores skip-verify and Finder auto-open. ASIF resize has no partition-only mode. Band size is not set when converting an `.asif` source

## [1.3.1] - 2026-08-13

### Fixed

- Attach After Create now attaches the committed destination, not the staging file
- Staging `.partial.` files are deleted after failure, cancellation, or a failed commit; leftover paths are logged if deletion fails
- Leftover partials from a previous session are swept on launch
- Resize limits are bound to the standardized source path and cleared when the source changes or a resize completes
- A destination that appears only after the job starts is not overwritten; both files are kept
- Failure to delete the hidden previous copy after a successful swap is reported with its full path

### Changed

- Removed redundant Overwrite toggles; confirmation is based on whether the destination exists

## [1.3.0] - 2026-08-13

### Fixed

- User jobs (create, convert, compact, resize, checksum, …) use an exclusive process runner. Background `info` / `isencrypted` / `diskutil` probes use a separate runner and cannot terminate a job
- `launch()` no longer kills an existing process; a second exclusive launch is rejected as busy
- Polling of attached images is skipped while a user job is running
- Cancel Operation stops only the active user job
- Quitting or closing the last window while a job runs asks for confirmation. Resize, compact, and bundle replacement use stronger wording

### Added

- Source and destination paths are standardized and rejected if they collide; folder imaging cannot write inside the source folder
- Create, convert, hybrid, and band-size writes go to a temporary sibling and replace the destination only after success
- Overwriting an existing destination requires confirmation
- Resize requires a successful Limits query, refuses sizes outside min/max, labels grow vs shrink, confirms shrinking, and warns on Image Only / Partition Only

### Changed

- Password copy now says Attaché does not retain passwords after a job — not that memory was securely erased

## [1.2.1] - 2026-08-13

### Fixed

- Iconset Retina files now use Apple’s `icon_*@2x.png` names instead of example.com aliases; leftover bogus names are deleted on regenerate
- Band-size rewrite no longer treats a source password as “encrypt the destination with AES-256.” Source unlock and destination encryption are separate
- Destination encryption reuses the source password when the source is encrypted. A new destination password is asked only if the source is unencrypted. Two different passphrases cannot be sent through −stdinpass; Attaché no longer pretends they can

### Added

- Confirmation before Force Detach and before replacing an original sparse bundle
- Passwords are cleared when a job finishes (success, failure, or cancel)
- Image Only and Partition Only are mutually exclusive in the Resize UI and in argv
- Tests for convert credentials, job cancel/failure classification, and destructive bundle replacement (including restore-on-failure)

## [1.2.0] - 2026-08-13

### Changed

- Renamed the app from HDIUtil to **Attaché**
- Bundle identifier is now `com.attache.app`; the executable is `Attache`

## [1.1.1] - 2026-08-13

### Changed

- Home is now an overview: action cards for every hdiutil verb, then the attached-image list
- Sidebar stays open, starts at Home, and shows a one-line description under each item
- Replaced the empty zebra-striped table that hid Attach / Create / Convert
- Command console is pinned to the bottom of the window so it cannot be pushed off-screen

## [1.1.0] - 2026-08-13

### Added

- Sparse-bundle **band size** on Create (blank / folder / device when the type is SPARSEBUNDLE or UDSB)
- Band size when Convert’s target format is UDSB (`-tgtimagekey sparse-band-size`)
- **Band Size** sidebar: read the current size from `Info.plist`, pick a new size (1 MB–8 GB or custom), write a new bundle or replace the original
- Inspect and Compact show the current band size for `.sparsebundle` images

## [1.0.0] - 2026-08-13

### Added

- Native macOS GUI for `/usr/bin/hdiutil`
- Attached-image list with detach, force detach, Open, and Reveal
- Attach with read-only, nomount, skip-verify, auto-open, custom mount point, and encryption
- Create blank images, images from a folder, or images from a device
- Convert between UDZO, ULFO, ULMO, UDRO, UDRW, UDSP, UDSB, UDTO, UDCO, UFBI
- Inspect (`imageinfo`) and verify stored checksums
- Compact sparse images and sparse bundles
- Resize with limits query
- Checksum (SHA-256, SHA-512, SHA-1, MD5, CRC-32, UDIF)
- Hybrid ISO via `makehybrid` (HFS+, ISO9660, Joliet, UDF)
- Activity console with the exact command line (password redacted) and live progress
- Passwords passed with `-stdinpass` only
- Drag-and-drop and Open With for disk images
- Help window and command-builder unit tests
