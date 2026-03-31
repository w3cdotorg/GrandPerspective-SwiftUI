# GrandPerspective (SwiftUI)

A pure SwiftUI rewrite of [GrandPerspective](https://grandperspectiv.sourceforge.net/), the macOS disk-usage visualizer. This version targets **macOS 26** with **Swift 6** and replaces the original Objective-C/AppKit codebase entirely.

## Features

- **Squarified treemap** rendered on a Metal-backed `Canvas` with gradient fills, hover highlights, and labels
- **Live filesystem scanning** with async/await and real-time progress
- **Zoom & navigation** — click to zoom into directories, breadcrumb bar for navigation
- **Filters** — composable filter system (size, name, extension, type, directories-only, files-only, NOT, AND, OR) with editor UI
- **Color mappings** — by folder depth, file type (UTI), creation/modification/access date
- **File operations** — Reveal in Finder, Open, Copy Path, Move to Trash (with confirmation and hard-link warnings)
- **Context menu** — right-click on any node in the treemap
- **Rescan** — rescan all or just the visible subtree
- **Multiple windows** — Duplicate View and Twin View (with filter) for side-by-side comparison
- **Persistence** — save/load scans as `.gpscan` (JSON), drag & drop folders or scan files
- **Image export** — export treemap as PNG
- **File type ranking** — view disk usage breakdown by file type
- **Preferences** — color mapping, rescan behavior, file deletion policy, confirmations

## Requirements

- macOS 26+
- Xcode 26+
- Swift 6

## Building

This project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the Xcode project:

```bash
brew install xcodegen
xcodegen generate
open GrandPerspective.xcodeproj
```

Then build and run the **GrandPerspective** scheme.

## Running Tests

```bash
xcodebuild test -scheme GrandPerspective -destination "platform=macOS"
```

169 tests across 30 suites covering model, layout, filters, views, persistence, file operations, rescan, and multi-window.

## Project Structure

```
Sources/          Swift source code
  Model/          FileNode, ScanResult, AppState, FileFilter, ColorMapping, ...
  Views/          TreemapCanvasView, BreadcrumbBar, FilterEditorView, ...
Tests/            Unit tests (Swift Testing framework)
Resources/        App icons, images, localizations
project.yml       XcodeGen project definition
PLAN.md           Migration plan and phase tracking
```

## License

GrandPerspective is released under the GNU General Public License v2.
