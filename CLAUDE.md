# CLAUDE.md

## Session quick start
- Project type: macOS SwiftUI app (`LipoArchs.xcodeproj`).
- Main UI file: `/tmp/workspace/perez987/Lipo-archs/LipoArchs/ContentView.swift`.
- Binary parsing logic: `/tmp/workspace/perez987/Lipo-archs/LipoArchs/ArchitectureInspector.swift`.
- Localizations:  
  - English: `/tmp/workspace/perez987/Lipo-archs/LipoArchs/en.lproj/Localizable.strings`  
  - Spanish: `/tmp/workspace/perez987/Lipo-archs/LipoArchs/es.lproj/Localizable.strings`

## Working agreements for this repository
- Keep changes minimal and focused.
- For user-facing text, add/update entries in both `en.lproj` and `es.lproj`.
- For formatted localized messages, use stable keys (for example with `%@`) and build strings with `String(format:locale:...)`.
- Avoid interpolated literals inside `NSLocalizedString(...)`.

## Validation
- Build locally in a macOS/Xcode environment, for example:  
  `xcodebuild -project LipoArchs.xcodeproj -scheme LipoArchs -configuration Debug build`
- There is currently no test target configured in the project.
