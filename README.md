# LipoArchs

![Platform](https://img.shields.io/badge/macOS-13.5+-orange.svg)
![Swift](https://img.shields.io/badge/Swift-5-blue.svg)
![Xcode](https://img.shields.io/badge/Xcode-15-lavender.svg)

Minimal macOS SwiftUI app for displaying the architecture(s) of a dropped executable, dynamic library, or `.app` bundle in a graphical way.

![Main window](Images/Window-1.png)

![Task processed](Images/Window-2.png)

## Requirements

- macOS 13+
- Xcode 15+

## Behavior

- Drag one or more Mach-O executables, `.dylib` files, or `.app` bundles onto the window
- `.app` bundles are resolved to `Contents/MacOS/<CFBundleExecutable>`
- The window keeps the detected architectures visible in the interface
- A single alert groups the results of all dropped items and reports any failures
- There is language support with automatic system language detection (English and Spanish for now).

## Motivation

In macOS there is a command called `lipo` which, followed by the argument `-archs`, shows the architecture(s) of an executable or library (e.g., `x86_64` is Apple Intel, `arm64` is Apple Silicon).

While using this command is simple, it requires displaying the contents of an application, since the executable located in Contents/MacOS needs to be passed to `lipo`.

LipoArchs offers an even simpler way to do this. Simply drag the application or library onto the LipoArchs window to obtain information about its embedded architecture(s). LipoArchs requires no special permissions, takes up very little space (2.2 MB), and has no configuration options.

Despite its name, LipoArchs doesn't use `lipo`. It searches for data such as CPU type and subtype and finds the architecture(s) of that CPU.
