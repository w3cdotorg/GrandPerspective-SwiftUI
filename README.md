# GrandPerspective (SwiftUI)

A pure SwiftUI rewrite of [GrandPerspective](https://grandperspectiv.sourceforge.net/), the macOS disk-usage visualizer. This version targets **macOS 26** with **Swift 6** and replaces the original Objective-C/AppKit codebase entirely.

## Features

- **Squarified treemap** rendered on a Metal-backed `Canvas` with gradient fills, hover highlights, and labels
- **Live filesystem scanning** with async/await and real-time progress
- **Zoom & navigation** — click to zoom into directories, breadcrumb bar for navigation
- **Filters** — composable filter system (size, name, path, type, date, flags, directories-only, files-only, NOT, AND, OR) with full editor UI
- **Date filters** — filter by creation, modification, or access date ranges
- **Color mappings** — by folder depth, file type (UTI), creation/modification/access date
- **File operations** — Reveal in Finder, Open, Copy Path, Move to Trash (with confirmation and hard-link warnings)
- **Context menu** — right-click on any node in the treemap
- **Rescan** — rescan all or just the visible subtree, configurable default
- **Multiple windows** — Duplicate View and Twin View (with filter) for side-by-side comparison
- **Persistence** — save/load scans as `.gpscan` (JSON), drag & drop folders or scan files
- **Filter persistence** — saved to `~/Library/Application Support/GrandPerspective/filters.json`, auto-loaded on launch
- **Image export** — export treemap as PNG
- **File type ranking** — view disk usage breakdown by file type
- **Preferences** — color mapping, rescan behavior, file deletion policy, confirmations
- **Accessibility** — VoiceOver labels on treemap, breadcrumbs, info bar, and progress view

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

193 tests across 35 suites covering model, layout, filters, views, persistence, file operations, rescan, multi-window, date filters, and filter persistence.

## Architecture

```
Sources/
  GrandPerspectiveApp.swift    @main, WindowGroup, ScanWindow wrapper
  ContentView.swift            Main window: welcome, scanning, treemap display
  ScanCommands.swift           Menu bar commands (File, View, Analysis)
  PreferencesView.swift        Settings tabs (General, Appearance, File Operations)
  WindowTransfer.swift         Data transfer for multi-window support

  Model/
    FileNode.swift             Tree node (@Observable, cached fileCount)
    FileSystemScanner.swift    Async scanner with progress stream
    ScanResult.swift           Scan metadata + deletion tracking
    AppState.swift             Central state (@MainActor @Observable)
    FileFilter.swift           Composable filter enum (Codable)
    FilterRepository.swift     Named filter CRUD + JSON persistence
    ColorMapping.swift         Color schemes (depth, type, date)
    TreemapLayout.swift        Squarified treemap algorithm
    ScanDocument.swift         .gpscan file format (JSON, FileDocument)

  Views/
    TreemapCanvasView.swift    Canvas renderer + context menu
    BreadcrumbBar.swift        Navigation breadcrumbs
    FilterEditorView.swift     Filter builder with test rows
    FilterListView.swift       Filter management
    FilterPickerView.swift     Filter selection sheet
    ImageExportView.swift      PNG export with ImageRenderer
    ScanProgressView.swift     Real-time progress display
    TypeRankingView.swift      File type breakdown

Tests/                         193 tests, 35 suites (Swift Testing)
Resources/                     App icons, images, localizations
project.yml                    XcodeGen project definition
PLAN.md                        Migration plan (Phases 0–9)
```

### Key Design Decisions

| Concern | Approach |
|---|---|
| State management | `@MainActor @Observable class AppState` injected via `.environment()` |
| Concurrency | Swift 6 strict concurrency, `actor`-based scanner, `AsyncStream` for progress |
| Rendering | SwiftUI `Canvas` with `.drawingGroup()` (Metal), squarified layout algorithm |
| Filters | `enum FileFilter` with recursive cases, `Codable` for persistence |
| Persistence | JSON-based `.gpscan` format, `FileDocument` conformance |
| Multi-window | Per-window `AppState`, `WindowTransfer` singleton for data handoff |
| Testing | Swift Testing framework (`@Test`, `@Suite`, `#expect`) |

## License

GrandPerspective is released under the GNU General Public License v2.
