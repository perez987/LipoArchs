# LipoArchs Logic Basics

This document summarizes the core logic that powers the app.

## 1) UI flow

- `ContentView` defines a fixed-size SwiftUI window with:
  - A drag-and-drop area.
  - Output fields for selected item, resolved binary path, and architecture summary.
  - Auto-dismissing alerts.
- When a file is dropped, `handleDrop` extracts a file URL from `NSItemProvider`.
- The view calls `inspect(url:)`, which delegates all parsing work to `ArchitectureInspector`.

## 2) Input normalization and resolution

- `DroppedBinaryResolver.resolve(url:)` standardizes and validates the dropped URL.
- If the URL is a file, it is used directly.
- If it is a directory:
  - Only `.app` bundles are accepted.
  - `resolveAppBundle(url:)` tries to find the executable:
    1. Read `Contents/Info.plist` and use `CFBundleExecutable`.
    2. Fallback: if `Contents/MacOS` has exactly one non-directory file, use it.
  - Otherwise, an error is thrown.

## 3) Binary format detection

- `ArchitectureInspector.architectures(for:)` loads file bytes and calls `BinaryFormat.detect(in:)`.
- `BinaryFormat.detect` reads the first 4 bytes (Mach-O magic) and classifies:
  - Thin binary (32/64, little or big endian).
  - FAT binary (32-bit or 64-bit headers, little or big endian).
- Unsupported magic or too-small files return explicit errors.

## 4) Architecture extraction

- Thin binary:
  - Reads `cpuType` and `cpuSubtype` from fixed header offsets.
  - Maps values to names (`x86_64`, `arm64`, `arm64e`, etc.).
- FAT binary:
  - Reads architecture count from header.
  - Iterates FAT entries and reads `cpuType`/`cpuSubtype` for each one.
  - Deduplicates names while preserving discovery order.

## 5) Architecture mapping

- `architectureName(cpuType:cpuSubtype:)` converts Mach-O CPU constants to readable names.
- Known mappings include:
  - Intel: `i386`, `x86_64`, `x86_64h`
  - ARM: `arm`, `armv6`, `armv7`, `armv7s`, `arm64`, `arm64e`
  - PowerPC: `ppc`, `ppc64`
- Unknown values are returned as `cpu(<type>, subtype: <subtype>)`.

## 6) Result and error model

- `InspectionResult` contains:
  - Original dropped URL.
  - Resolved executable URL.
  - Final architecture list.
- It also builds:
  - `labelText` for inline UI display.
  - A localized `alertMessage` for completion feedback.
- `ArchitectureInspectionError` centralizes user-facing failures:
  - Missing file.
  - Unsupported container.
  - Missing bundle executable.
  - Unsupported format.
  - File too small.

## 7) Why this approach

- The app avoids shelling out to `lipo`.
- It reads Mach-O metadata directly, so:
  - It works without command invocation.
  - It can handle dropped `.app` bundles in one step.
  - It keeps logic deterministic and self-contained in Swift.
