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

## Phase 8 — Filtres par date et persistance des filtres

- [ ] **Filtres par date** (remplace `ItemCreationDateTest`, `ItemModificationDateTest`, `ItemAccessDateTest`)
  - Nouveau case `FileFilter.dateRange(keyPath:min:max:)` pour creation/modification/access
  - Ou trois cases dédiés : `.creationDateRange`, `.modificationDateRange`, `.accessDateRange`
  - UI : `FilterTestRow.TestType.date` avec deux `DatePicker` (min/max) + sélecteur de champ
  - Round-trip `FilterTestRow` ↔ `FileFilter` pour les filtres par date
- [ ] **Persistance des filtres entre sessions** (remplace la sauvegarde NSUserDefaults legacy)
  - `FilterRepository` sauvegardé en JSON dans `Application Support/GrandPerspective/filters.json`
  - Chargement au démarrage, sauvegarde automatique à chaque modification
  - `NamedFilter` rendu `Codable` (nécessite `FileFilter: Codable`)
---

## Phase 9 — Nettoyage et finalisation

- [ ] Supprimer `GrandPerspective-Bridging-Header.h` (plus utilisé)
- [ ] Nettoyer les commentaires "Phase 1+" dans `project.yml`
- [ ] Supprimer le target `GrandPerspectiveLegacy` de `project.yml` (optionnel, le code reste dans `GrandPerspective/trunk/code/`)
- [ ] Audit d'accessibilité : labels VoiceOver sur les éléments interactifs
- [ ] Profiling avec gros répertoires (100k+ fichiers) — optimiser si nécessaire
- [ ] Documentation : README.md avec instructions de build et architecture

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

## Tests — 169 tests, 30 suites ✅

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

**Commandes :**
```bash
# Générer le projet et lancer les tests
/opt/homebrew/bin/xcodegen generate
xcodebuild -scheme GrandPerspectiveSwiftUI -destination 'platform=macOS,arch=arm64' test
```
