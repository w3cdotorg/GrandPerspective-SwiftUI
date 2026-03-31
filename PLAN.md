# GrandPerspective — Migration SwiftUI (macOS 26)

## Vue d'ensemble

Migration de GrandPerspective (Objective-C / AppKit / XIBs) vers une app SwiftUI moderne ciblant macOS 26, Swift 6.

---

## Phase 0 — Fondations ✅

- [x] Créer le dossier `SwiftUI/` avec l'App entry point (`@main`)
- [x] `ContentView` avec écran d'accueil + placeholder `Canvas` pour le treemap
- [x] `ScanCommands` — commandes menu (Scan Folder, ⇧⌘O)
- [x] `PreferencesView` — Settings avec onglets General / Appearance et `@AppStorage`
- [x] Bridging header (imports commentés, prêt pour Phase 1)
- [x] `project.yml` (XcodeGen) — 2 targets : SwiftUI + Legacy
- [x] Entitlements + Info.plist (document types `.gpscan`, UTI export)
- [x] **BUILD SUCCEEDED** avec Xcode 26.4

**Fichiers créés :** `SwiftUI/GrandPerspectiveApp.swift`, `ContentView.swift`, `ScanCommands.swift`, `PreferencesView.swift`, `GrandPerspective-Bridging-Header.h`, `Info.plist`, `GrandPerspective.entitlements`

---

## Phase 1 — Modèle de données (Swift pur) ✅

Réécriture des modèles Obj-C en Swift avec les protocoles modernes.

- [x] `FileNode` — `@Observable` class remplaçant `Item`/`FileItem`/`DirectoryItem`/`PlainFileItem`/`CompoundItem`
  - Kind enum (file/directory/synthetic), Flags OptionSet, parent/children, path, ancestors
- [x] `FileSystemScanner` — actor remplaçant `TreeBuilder` + `ScanTaskExecutor`
  - `async/await`, `AsyncStream<Progress>`, annulation, mesure logique/physique
- [x] `ScanResult` — `@Observable` remplaçant `TreeContext` / `AnnotatedTreeContext`
  - Métadonnées volume, tracking deletions, factory `scan(url:)` async
- [x] `FileFilter` — enum composable remplaçant `Filter`/`NamedFilter`/`FilterTest` + 10 sous-classes
  - Combinateurs: `.and`, `.or`, `.not`, `.filesOnly`, `.directoriesOnly`
  - Tests: `.sizeRange`, `.nameMatches`, `.pathMatches`, `.typeMatches`, `.hasFlags`, `.lacksFlags`
- [x] `ColorMapping` — protocol remplaçant `FileItemMappingScheme` + 5 implémentations
  - `FolderColorMapping`, `ModificationDateColorMapping`, `CreationDateColorMapping`, `AccessDateColorMapping`, `FileTypeColorMapping`
- [x] `TreemapLayout` — algorithme squarified remplaçant `TreeLayoutBuilder` + `TreeBalancer`
- [x] `UTType` (framework système) au lieu de `UniformType`/`UniformTypeInventory`
- [x] ContentView connectée : scan réel, rendu treemap Canvas, sélecteur de color mapping
- [x] **BUILD SUCCEEDED**

**Fichiers créés :** `SwiftUI/Model/FileNode.swift`, `FileSystemScanner.swift`, `ScanResult.swift`, `FileFilter.swift`, `ColorMapping.swift`, `TreemapLayout.swift`

---

## Phase 2 — Moteur de rendu treemap (Canvas SwiftUI) ✅

Le cœur technique. Réécriture du rendu treemap.

- [x] `TreemapCanvasView` — rendu via `Canvas` SwiftUI avec gradient fills (remplace `DirectoryView` + `TreeDrawer` + `GradientRectangleDrawer`)
  - Gradient linéaire par rectangle (lighten top-left → darken bottom-right), intensité configurable
  - Labels (nom + taille) sur les rectangles assez grands, avec ombre pour lisibilité
  - `drawingGroup()` pour rendu Metal optimisé
- [x] Interactions : `.onContinuousHover` (highlight), `.onTapGesture` (click-to-zoom sur dossiers)
  - Hit-testing via cache de `[TreemapRect]`
  - Zoom animé (`withAnimation(.easeInOut)`)
- [x] `BreadcrumbBar` — navigation par fil d'Ariane (remplace `ItemPathDrawer`)
  - Bouton home, breadcrumbs cliquables, affichage taille du nœud zoomé
- [x] `ContentView` rebranchée : BreadcrumbBar + TreemapCanvasView + NodeInfoBar + toolbar (color picker, zoom out)
- [x] Zoom out via parent traversal, retour au scan root

**Fichiers créés :** `SwiftUI/Views/TreemapCanvasView.swift`, `SwiftUI/Views/BreadcrumbBar.swift`
**Fichiers modifiés :** `SwiftUI/ContentView.swift`

---

## Phase 3 — Interface utilisateur ✅

Migration de chaque XIB vers une View SwiftUI.

| XIB legacy | SwiftUI | Status |
|---|---|---|
| `MainMenu.xib` | `@main App` avec `commands { }` | ✅ Phase 0 |
| `DirectoryViewWindow.xib` | `ContentView` (toolbar + treemap + info bar) | ✅ Phase 2 |
| `PreferencesPanel.xib` | `Settings { PreferencesView() }` | ✅ Phase 0 |
| `ProgressPanel.xib` | `ScanProgressView` avec annulation | ✅ |
| `FilterWindow.xib` + `FiltersWindow.xib` | `FilterEditorView` + `FilterListView` | ✅ |
| `FilterSelectionPanel.xib` | `FilterPickerView` (`.sheet`) | ✅ |
| `SaveImageDialog.xib` | `ImageExportView` (PNG/TIFF/JPEG, presets, `NSSavePanel`) | ✅ |
| `UniformTypeRankingWindow.xib` | `TypeRankingView` (Table, tri, visibilité) | ✅ |

- [x] `FilterRepository` — modèle `@Observable` CRUD pour filtres nommés
- [x] `FilterEditorView` — édition composée de tests (nom, path, taille, type, flags) avec combinaison AND/OR
- [x] `FilterTestRow` — modèle éditable avec round-trip `FileFilter` ↔ UI
- [x] `FilterListView` — liste avec add/edit/remove, descriptions auto-générées
- [x] `FilterPickerView` — sélection de filtre à appliquer, création inline
- [x] `ImageExportView` — export treemap en image (PNG/TIFF/JPEG), presets 1080p/4K, preview
- [x] `TypeRankingView` — Table des types UTI avec stats (taille totale, count), tri, visibilité
- [x] `ScanProgressView` — progression temps réel avec animation, annulation
- [x] `ScanCommands` étendu — menu Analysis (Apply Filter, Manage Filters, File Types, Export Image) avec raccourcis
- [x] `ContentView` rebranchée — toolbar étendue (filtres, menu More), sheets pour tous les panneaux

**Fichiers créés :** `SwiftUI/Model/FilterRepository.swift`, `SwiftUI/Views/FilterEditorView.swift`, `SwiftUI/Views/FilterListView.swift`, `SwiftUI/Views/FilterPickerView.swift`, `SwiftUI/Views/ImageExportView.swift`, `SwiftUI/Views/TypeRankingView.swift`, `SwiftUI/Views/ScanProgressView.swift`
**Fichiers modifiés :** `SwiftUI/ContentView.swift`, `SwiftUI/ScanCommands.swift`

---

## Phase 4 — Concurrence et état global ✅

- [x] `@MainActor @Observable class AppState` — état central de l'application
  - `ScanPhase` enum (idle/scanning/completed) remplace les flags éparpillés
  - Possède `ScanResult`, `FilterRepository`, `ColorMapping`, navigation (zoom/hover)
  - Injecté via `@Environment(AppState.self)` depuis `GrandPerspectiveApp`
- [x] Scanning async via `async/await` + `AsyncStream` pour le reporting de progression
  - `startScan(url:)` crée `FileSystemScanner`, écoute `progressStream` en parallèle
  - `cancelScan()` annule la task et revient à `.idle`
  - Progress réel affiché dans `ScanProgressView`
- [x] Filtrage réactif comme transformation sur le modèle
  - `appliedFilter` didSet → `recomputeFilteredTree()` crée une copie filtrée de l'arbre
  - `displayTree` computed: filteredTree ?? scanTree
  - Zoom root invalidé si le nœud n'est plus dans l'arbre filtré
  - Tailles recalculées après filtrage (cohérence parent = Σ children)
- [x] Remplacement complet du framework `TaskExecutor` legacy
  - `Task` + `async/await` + `AsyncStream` remplacent `NSOperation` / `TaskExecutor`
  - Plus de callbacks/notifications pour le lifecycle du scan

**Fichiers créés :** `SwiftUI/Model/AppState.swift`
**Fichiers modifiés :** `SwiftUI/ContentView.swift`, `SwiftUI/GrandPerspectiveApp.swift`

---

## Phase 5 — Polish et fonctionnalités avancées ✅

- [x] Persistance : `CodableNode` / `CodableScanResult` (JSON, ISO 8601) + `ScanDocument` (`FileDocument`)
  - Format v2 : JSON avec `formatVersion`, arbre récursif, métadonnées volume, dates, flags, UTType
  - `AppState.saveScan()` / `openScan()` via `NSSavePanel` / `NSOpenPanel`
  - Compatible `.gpscan` et `.json`
  - Remplace `TreeReader` / `TreeWriter` (ancien format XML)
- [x] Localisation : `String(localized:)` sur tous les textes UI (ContentView, ScanCommands, WelcomeView, NodeInfoBar)
  - Prêt pour extraction via `xcstrings` / String Catalogs
- [x] Export image : déjà fait en Phase 3 (`ImageExportView` avec `ImageRenderer`)
- [x] Drag & drop : `.dropDestination(for: URL.self)` sur ContentView
  - Dossier → lance un scan, fichier `.gpscan` → ouvre le scan sauvegardé
  - Feedback visuel sur WelcomeView (icône scale + texte "Drop folder to scan")
- [x] Menus enrichis : Open Scan (⌘O), Save Scan (⌘S) dans le menu File

**Fichiers créés :** `SwiftUI/Model/ScanDocument.swift`
**Fichiers modifiés :** `SwiftUI/ContentView.swift`, `SwiftUI/ScanCommands.swift`, `SwiftUI/Model/AppState.swift`

---

## Phase 6 — Opérations fichier et actions contextuelles ✅

Features manquantes par rapport au legacy : suppression, reveal, rescan.

- [x] **Suppression de fichiers** (remplace `deleteFile:` de `DirectoryViewControl`)
  - Move to Trash via `FileManager.trashItem(at:resultingItemURL:)`
  - Confirmation dialog avec nom du fichier/dossier/package
  - Warning hard-link ("le fichier est hard-linké, il occupera de l'espace jusqu'à suppression de tous les liens")
  - Warning dossier ("tous les fichiers du dossier, y compris ceux non affichés, seront supprimés")
  - `AppState.requestDelete(_:)` + `performDelete(node:url:)` met à jour `ScanResult.recordDeletion` + retire le nœud de l'arbre
  - Préférence `FileDeletionTargets` : delete nothing / only files / files+folders (`@AppStorage`)
  - Préférence `confirmFileDeletion` / `confirmFolderDeletion` (toggles)
- [x] **Reveal in Finder / Open File** (remplace `revealFileInFinder:` et `openFile:`)
  - `NSWorkspace.shared.activateFileViewerSelecting([url])` pour reveal
  - `NSWorkspace.shared.open(url)` pour ouvrir avec l'app par défaut
  - Accessible via menu contextuel (clic droit) sur le treemap
- [x] **Menu contextuel sur le treemap**
  - Clic droit sur un nœud : Open, Reveal in Finder, Zoom In, Copy Path, Move to Trash
  - Implémenté via `.contextMenu` sur `TreemapCanvasView` (uses hoveredNode)
- [x] Préférences mises à jour : onglet "File Operations" avec les options de suppression
- [x] **15 tests** : 3 suites (FileNode Mutation, AppState File Operations, File Operations Preferences)

**Fichiers modifiés :** `SwiftUI/Model/FileNode.swift`, `SwiftUI/Model/AppState.swift`, `SwiftUI/Views/TreemapCanvasView.swift`, `SwiftUI/ContentView.swift`, `SwiftUI/PreferencesView.swift`, `Tests/Phase6Tests.swift`

---

## Phase 7 — Rescan et fenêtres multiples ✅

- [x] **Rescan** (remplace le système `rescan*:` de `DirectoryViewControl`)
  - `Rescan All` — re-scanne le même dossier racine, remplace le ScanResult
  - `Rescan Visible` — re-scanne uniquement le sous-arbre visible (zoomRoot ou displayTree)
  - Menu View > Rescan (⌘R), Rescan All (⇧⌘R), Rescan Visible
  - Toolbar button "Rescan" avec menu déroulant (all / visible)
  - `AppState.rescan(scope:)` avec enum `RescanScope { all, visible }`
  - `scanURL` stockée dans `AppState` pour permettre le rescan
  - Préférence `defaultRescanAction` : Rescan All / Rescan Visible (`@AppStorage`)
- [x] **Fenêtres multiples** (remplace `duplicateDirectoryView:` / `twinDirectoryView:`)
  - `Duplicate View` (⌘D) — ouvre une nouvelle fenêtre avec le même scan mais état indépendant
  - `Twin View (Filtered)` — ouvre une nouvelle fenêtre avec un filtre pré-appliqué
  - Chaque fenêtre possède son propre `AppState` (zoom, filtre, hover indépendants)
  - `ScanWindow` wrapper crée un `AppState` par fenêtre
  - `WindowTransfer` singleton pour passer les données scan aux nouvelles fenêtres
  - `WindowGroup(id: "scan")` pour les fenêtres secondaires
  - `AppState.loadScanResult(_:url:filter:)` pour initialiser depuis un scan existant
  - `AppState.windowTitle` dynamique (nom du dossier + filtre actif)
- [x] **17 tests** : 5 suites (Rescan, Window Title, LoadScanResult, WindowTransfer, ScanURL)

**Fichiers modifiés :** `SwiftUI/Model/AppState.swift`, `SwiftUI/GrandPerspectiveApp.swift`, `SwiftUI/WindowTransfer.swift` (nouveau), `SwiftUI/ContentView.swift`, `SwiftUI/ScanCommands.swift`, `SwiftUI/PreferencesView.swift`, `Tests/Phase7Tests.swift`

---

## Phase 8 — Filtres par date et persistance des filtres ✅

- [x] **Filtres par date** (remplace `ItemCreationDateTest`, `ItemModificationDateTest`, `ItemAccessDateTest`)
  - Trois cases dédiés : `.creationDateRange(min:max:)`, `.modificationDateRange(min:max:)`, `.accessDateRange(min:max:)`
  - UI : `FilterTestRow.TestType.date` avec `DateField` picker (Creation/Modification/Access) + deux `DatePicker` (min/max)
  - Round-trip `FilterTestRow` ↔ `FileFilter` pour les filtres par date
  - `describeFilter` mis à jour pour afficher les plages de dates
- [x] **Persistance des filtres entre sessions** (remplace la sauvegarde NSUserDefaults legacy)
  - `FilterRepository` sauvegardé en JSON dans `Application Support/GrandPerspective/filters.json`
  - Chargement au démarrage via `loadFromDisk()`, sauvegarde automatique avec debounce 500ms
  - `FileFilter: Codable` — encodage discriminé par type avec `CodingCase` enum
  - `NamedFilter: Codable` — ID stable pour persistance
  - `FilterRepository` accepte un `storageURL` injectable (testable)
- [x] **24 tests** : 5 suites (Date Filters, FileFilter Codable, NamedFilter Codable, FilterRepository Persistence, Date FilterTestRow)

**Fichiers modifiés :** `Sources/Model/FileFilter.swift`, `Sources/Model/FilterRepository.swift`, `Sources/Views/FilterEditorView.swift`, `Sources/Views/FilterListView.swift`, `Sources/GrandPerspectiveApp.swift`, `Tests/Phase8Tests.swift`
---

## Phase 9 — Nettoyage et finalisation ✅

- [x] Supprimer `GrandPerspective-Bridging-Header.h` (fait lors de la création du repo standalone)
- [x] Nettoyer les commentaires "Phase N:" obsolètes dans le code source
- [x] Supprimer le target `GrandPerspectiveLegacy` de `project.yml` (fait lors de la création du repo)
- [x] Corriger les warnings : `let fm` inutilisé, `var result` → `let result`
- [x] **Audit d'accessibilité** : labels VoiceOver ajoutés sur :
  - Treemap Canvas (label, value dynamique, hint)
  - BreadcrumbBar (label par bouton de navigation)
  - NodeInfoBar (combiné avec accessibilityElement)
  - ScanProgressView (label + value dynamique)
- [x] **Optimisations performance** pour gros répertoires :
  - `FileNode.fileCount` mis en cache (lazy, `@ObservationIgnored`)
  - `ByteCountFormatter` réutilisé (singleton `nonisolated(unsafe) static`)
  - `TreemapLayout.squarify` — suppression de l'allocation `(i...j).map` dans la boucle interne
- [x] **Documentation** : README.md complet avec architecture, design decisions, arborescence
- [x] **7 tests** : 3 suites (FileNode Optimizations, TreemapLayout Performance, Cleanup Verification)

**Fichiers modifiés :** `Sources/Model/FileNode.swift`, `Sources/Model/ScanResult.swift`, `Sources/Model/TreemapLayout.swift`, `Sources/Views/TreemapCanvasView.swift`, `Sources/Views/BreadcrumbBar.swift`, `Sources/Views/ScanProgressView.swift`, `Sources/ContentView.swift`, `Sources/PreferencesView.swift`, `README.md`, `Tests/Phase9Tests.swift`

---

## Phase 10 — Scan filtré et rescan sélection ✅

- [x] **Scan filtré** (Cmd+Shift+N) — remplace `filterSelectedScan:` de `DirectoryViewControl`
  - Menu File > "Scan with Filter…" (⇧⌘N) ouvre un FilterPickerView puis un folder picker
  - `AppState.startFilteredScan(url:filter:)` — stocke le filtre en `pendingFilterAfterScan`, appliqué automatiquement après le scan
  - `AppState.selectFolderForFilteredScan(filter:)` — ouvre un NSOpenPanel et lance le scan filtré
- [x] **Rescan Selected** — remplace `rescanSelected:` / `rescanSelectedItem:`
  - `AppState.selectedNode` — nœud sélectionné au clic dans le treemap (distinct du hover)
  - `RescanScope.selected` — nouveau cas, re-scanne le sous-arbre du nœud sélectionné
  - Menu View > "Rescan Selected" + bouton dans le toolbar Rescan menu
  - `TreemapCanvasView.onTapGesture` met à jour `selectedNode`
- [x] **13 tests** : 4 suites (Filtered Scan, Rescan Selected, Selected Node, Scan Commands Notifications)

**Fichiers modifiés :** `Sources/Model/AppState.swift`, `Sources/ScanCommands.swift`, `Sources/ContentView.swift`, `Sources/Views/TreemapCanvasView.swift`, `Tests/Phase10Tests.swift`, `Tests/Phase7Tests.swift`, `Tests/ViewTests.swift`, `Tests/TreemapCanvasViewTests.swift`

---

## Phase 11 — Panneau d'information (Drawer) ✅

Remplace les 3 onglets Drawer du legacy : Display, Info, Focus.

- [x] **InfoPanelView** — panneau latéral via `.inspector()` avec 3 onglets segmentés
  - **Onglet Display** : volume (path, taille, libre, utilisé), scan (dossier, taille, fichiers, misc, date, mesure), deletions
  - **Onglet Info** : nom, chemin, taille, type, UTI, kind, dates (création/modification/accès), attributs (fichiers, enfants, hard-link, package)
  - **Onglet Focus** : nom, chemin, taille, % du parent, % du total, profondeur, nb fichiers
  - ~30 champs d'information au total, text sélectionnable
- [x] Menu View > "Show Inspector" (⌥⌘I) toggle via `AppState.showInspector`
- [x] `AppState.selectedNode` déjà ajouté en Phase 10 (clic dans le treemap)
- [x] **14 tests** : 5 suites (InfoPanel Display, InfoPanel Info, InfoPanel Focus, Inspector Toggle, InfoPanel Tabs)

**Fichiers créés :** `Sources/Views/InfoPanelView.swift`, `Tests/Phase11Tests.swift`
**Fichiers modifiés :** `Sources/Model/AppState.swift`, `Sources/ScanCommands.swift`, `Sources/ContentView.swift`

---

## Phase 12 — Affichage volume et paquets ✅

- [x] **Show Package Contents** toggle (remplace `showPackageContents` de `DirectoryViewControl`)
  - `AppState.showPackageContents: Bool` (défaut true), `collapsePackages(_:)` transforme les packages en fichiers opaques
  - Pipeline display : filter → package collapse → volume wrap, via `recomputeDisplayTree()`
  - Menu View > "Show Package Contents"
- [x] **Show Entire Volume** toggle (remplace `openSelectedVolume:`)
  - `AppState.showEntireVolume: Bool` (défaut false), `wrapInVolume()` crée un nœud racine volume
  - Nœuds synthétiques : Free space + Misc. used space ajoutés au volume root
  - Menu View > "Show Entire Volume"
- [x] Refactoring : `CommandNotificationHandler` ViewModifier pour éviter type-checker timeout
- [x] **14 tests** : 3 suites (Package Contents Toggle, Entire Volume Toggle, Package + Volume Combined)

**Fichiers créés :** `Tests/Phase12Tests.swift`
**Fichiers modifiés :** `Sources/Model/AppState.swift`, `Sources/ScanCommands.swift`, `Sources/ContentView.swift`

---

## Phase 13 — Masque et préférences de taille ✅

- [x] **Mask** (remplace `maskFilter` / `toggleMask:` de `DirectoryViewControl`)
  - `AppState.FilterMode` enum (`.filter` supprime, `.mask` grise) avec `maskedNodeIDs: Set<UUID>`
  - `TreemapCanvasView` dessine les nœuds masqués en gris plat (opacity 0.3, sans gradient)
  - Menu View > "Toggle Mask" (⌥⌘M)
  - `collectMaskedIDs(_:filter:into:)` pour identifier les nœuds qui échouent au filtre
- [x] **File Size Measure** — préférence exposée dans l'UI
  - `@AppStorage("fileSizeMeasure")` — logical / physical
  - `PreferencesView` > General > picker, `AppState.preferredSizeMeasure` computed property
  - `selectAndScan()` utilise la préférence
- [x] **File Size Unit System** — préférence
  - `@AppStorage("fileSizeUnitSystem")` — decimal / binary
  - `FileNode.useBinaryUnits` static flag, deux formatters (decimal + binary)
  - `PreferencesView` > General > picker avec `.onChange` sync
  - Chargé au démarrage dans `ScanWindow.onAppear`
- [x] **14 tests** : 3 suites (Filter Mask Mode, File Size Measure, File Size Units)

**Fichiers créés :** `Tests/Phase13Tests.swift`
**Fichiers modifiés :** `Sources/Model/AppState.swift`, `Sources/Model/FileNode.swift`, `Sources/Views/TreemapCanvasView.swift`, `Sources/ScanCommands.swift`, `Sources/ContentView.swift`, `Sources/PreferencesView.swift`, `Sources/GrandPerspectiveApp.swift`

---

## Phase 14 — Commentaires de scan ✅

- [x] **Scan Comments** — UI éditable (remplace `editComments:` de `DirectoryViewControl`)
  - `ScanCommentsView` — sheet avec TextEditor, boutons Cancel/Save
  - Menu Edit > "Edit Scan Comments…"
  - `ScanResult.comments` déjà en place, `CodableScanResult` déjà sérialisé (JSON round-trip)
- [x] **8 tests** : 3 suites (Scan Comments, Scan Comments Persistence, Scan Comments Notification)

**Fichiers créés :** `Sources/Views/ScanCommentsView.swift`, `Tests/Phase14Tests.swift`
**Fichiers modifiés :** `Sources/ScanCommands.swift`, `Sources/ContentView.swift`

---

## Couleurs — Palettes & Mappings ✅

- [x] **18 palettes de couleurs** portées depuis `ColorListCreator.m` (CoffeeBeans, Pastel Papageno, Blue Sky Tulips, Monaco, Warm Fall, Moss and Lichen, Matbord, Bujumbura, Autumn, Olive Sunset, Rainbow, Origami Mice, Green Eggs, Feng Shui, Daytona, Flying Geese, Lagoon Nebula, Autumn Blush)
- [x] **Couleurs ajustées** pour lisibilité du texte blanc (contrast ratio ≥ 2:1 WCAG contre blanc, vérifié par test)
- [x] **`Color(hex:)` extension** avec calcul de luminance relative et ratio de contraste
- [x] **4 nouveaux color mappings** : Top Folder, Extension, Level, Nothing (Uniform)
- [x] **File Type (UTI)** couleurs remplacées par des hex medium-saturation lisibles
- [x] **Sélecteur de palette** dans Préférences > Appearance (avec aperçu swatches)
- [x] **Slider d'intensité du gradient** (0%–100%) dans Préférences > Appearance
- [x] **Palette persistée** via `@AppStorage("selectedPaletteName")`
- [x] **9 mappings** dans le registre (Files & Folders, Top Folder, Extension, Level, Nothing, Modification Date, Creation Date, Access Date, File Type)
- [x] **26 tests** couvrant palettes, hex parsing, readability, et nouveaux mappings

**Fichiers modifiés :** `Sources/Model/ColorMapping.swift`, `Sources/Model/AppState.swift`, `Sources/PreferencesView.swift`, `Sources/ContentView.swift`, `Sources/GrandPerspectiveApp.swift`, `Sources/Views/TreemapCanvasView.swift`
**Fichiers créés :** `Tests/ColorPaletteTests.swift`

---

## Notes techniques

- **Deployment target :** macOS 26
- **Swift :** 6.0 (strict concurrency)
- **Xcode :** 26.4
- **XcodeGen :** `/opt/homebrew/bin/xcodegen` (v2.45.3)
- **Génération projet :** `xcodegen generate` depuis `~/Sites/grandperspectiv-code/`
- **Build :** `xcodebuild -scheme GrandPerspectiveSwiftUI -destination 'platform=macOS' build`
- **Tests :** `xcodebuild -scheme GrandPerspectiveSwiftUI -destination 'platform=macOS,arch=arm64' test`
- **Code legacy :** intact dans `GrandPerspective/trunk/code/`, sert de référence

---

## Tests — 292 tests, 60 suites ✅

| Suite | Tests | Couverture |
|---|---|---|
| FileNode | 10 | Kind, flags, parent/child, path, ancestors, fileCount, replaceChild, formatting |
| FileFilter | 19 | Size range, name/type matching, flags, AND/OR/NOT, filesOnly/directoriesOnly, defaults |
| TreemapLayout | 11 | Basic layout, depth, area proportions, edge cases (empty, zero, single), non-overlapping, 100 children |
| FileSystemScanner | 6 | Tree building, sizes, parent refs, dates, empty dirs, cancellation |
| ScanResult | 7 | usedSpace, miscUsedSpace, deletion tracking (file, dir, synthetic), formatting, filters |
| ColorMapping | 14 | Folder/date/type mappings, registry, legend, gray fallback for missing dates |
| SwiftUI Views | 4 | Layout integration, color mapping integration, ImageRenderer snapshot, end-to-end scan→render |
| TreemapCanvasView | 7 | Gradient rendering, zoom subtree, zoom full area, hit-test correct/outside, all mappings render, labels |
| BreadcrumbBar | 3 | Path display, ancestors from zoom root, nil zoom root |
| FilterRepository | 6 | Defaults, add/sort, remove, replace, isNameTaken, lookup by name |
| FilterTestRow | 6 | Name/size/type/inverted/filesOnly round-trip, empty row returns nil |
| FilterEditorView | 3 | Decompose AND/OR/single filters into editable rows |
| FilterDescription | 4 | Describe name/size/NOT/AND filters as human-readable text |
| TypeRanking | 1 | Stats computation and render without crash |
| ScanProgressView | 2 | Render with/without progress data |
| ImageExportView | 1 | Image format properties (extension, UTType) |
| AppState | 14 | Initial state, zoom in/out/navigate, filtering (apply/clear/reset zoom/display tree/size consistency), color mapping, cancel scan, filter repository |
| CodableNode | 7 | Round-trip tree/files/flags/nesting/parent refs/synthetic nodes, JSON encode/decode |
| CodableScanResult | 3 | Round-trip with all metadata, format version, physical size measure |
| ScanDocument | 3 | End-to-end JSON round-trip, readable/writable content types |
| UTType Extension | 1 | .gpscan UTType identifier |
| AppState DragDrop | 2 | Empty URLs, nonexistent path |
| Filtered Scan | 4 | Pending filter, start filtered scan, regular scan no pending, clear selected on scan |
| Rescan Selected | 4 | Requires selected node, directory rescan, selected node set, scope enum cases |
| Selected Node | 3 | Initially nil, cleared on load, filtered scan sets pending+URL |
| Scan Commands Notifications | 2 | scanWithFilter + rescanSelected notification names |
| InfoPanel Display | 3 | Volume info, scan info, deletion tracking |
| InfoPanel Info | 3 | File fields (dates, UTI, flags), directory children, package type |
| InfoPanel Focus | 3 | % of parent, % of total, depth calculation |
| Inspector Toggle | 3 | Initial state, toggle, notification name |
| InfoPanel Tabs | 2 | All tabs covered, raw values |
| Package Contents Toggle | 5 | Default true, visible by default, collapsed when off, toggle back, non-package unaffected |
| Entire Volume Toggle | 7 | Default false, normal display, volume wrap, free space, misc space, toggle off, total size |
| Package + Volume Combined | 2 | Both toggles together, notification names |
| Filter Mask Mode | 8 | Default filter, enum cases, filter removes, mask keeps all, mask tracks IDs, switch recomputes, clear clears mask, notification |
| File Size Measure | 3 | Default logical, preference mapping, invalid fallback |
| File Size Units | 3 | Decimal formatting, binary formatting, switching changes output |
| Scan Comments | 4 | Default empty, set, init with value, clear |
| Scan Comments Persistence | 3 | Round-trip JSON with emoji/newlines, empty round-trip, JSON field present |
| Scan Comments Notification | 1 | editScanComments notification name |

**Commandes :**
```bash
# Générer le projet et lancer les tests
/opt/homebrew/bin/xcodegen generate
xcodebuild -scheme GrandPerspective -destination 'platform=macOS,arch=arm64' test
```
