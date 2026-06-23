import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    private struct LoadedDropItem {
        let index: Int
        let url: URL?
    }

    @State private var isDropTargeted = false
//    @State private var selectedItemName = NSLocalizedString("No file selected", comment: "No file selected")
    @State private var selectedItemName = ""
    @State private var resolvedBinaryPath = ""
    @State private var architectureSummary = ""
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showsAlert = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("LipoArchs")
                    .font(.largeTitle.bold())

                Text("Drag one or more macOS executables, dynamic libraries, or .app\nbundles into the drop area to display their architectures.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                dropArea

                Divider()

                LabeledContent("") {
                    Text(architectureSummary)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    LabeledContent("Selected Items:") {
                        Text(selectedItemName)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                    .padding(.bottom, 10)

                    Divider()

                    LabeledContent("Resolved Binaries:") {
                        Text(resolvedBinaryPath)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                    .padding(.top, 12)

                }

                Spacer(minLength: 0)
            }
        }
        .padding(24)
        .frame(
            minWidth: 540,
            idealWidth: 540,
            maxWidth: 540,
            minHeight: 512,
            idealHeight: 512,
            maxHeight: 512,
            alignment: .topLeading
        )
        .alert(alertTitle, isPresented: $showsAlert) {
//            Button("OK", role: .cancel) {}
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
        .task(id: showsAlert) {
             guard showsAlert else { return }

             try? await Task.sleep(for: .seconds(5))

             guard showsAlert else { return }
             showsAlert = false
         }

    }

    private var dropArea: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(isDropTargeted ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.08))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.4),
                        style: StrokeStyle(lineWidth: 2, dash: [8])
                    )
            }
            .overlay {
                VStack(spacing: 10) {
                    Image(systemName: "square.and.arrow.down.on.square")
                        .font(.system(size: 34))
                    Text("Drop Files Here")
                        .font(.title3.weight(.semibold))
                    Text(".app bundles are resolved to Contents/MacOS automatically.")
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .frame(
                maxWidth: .infinity,
                minHeight: 170,
                idealHeight: 170,
                maxHeight: 170
            )
            .onDrop(of: [UTType.fileURL], isTargeted: $isDropTargeted, perform: handleDrop)
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        let fileProviders = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }

        guard !fileProviders.isEmpty else {
            presentAlert(
                title: NSLocalizedString("No File Found", comment: "No file found"),
                message: NSLocalizedString("Drop one or more files or .app bundles from Finder.", comment: "Drop hint")
            )
            return false
        }

        let loadedItemsQueue = DispatchQueue(label: "LipoArchs.loaded-items")
        var loadedItems = Array<LoadedDropItem?>(repeating: nil, count: fileProviders.count)
        let group = DispatchGroup()

        for (index, provider) in fileProviders.enumerated() {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let url = Self.fileURL(from: item)
                loadedItemsQueue.sync {
                    loadedItems[index] = LoadedDropItem(index: index, url: url)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            self.inspect(items: loadedItems.compactMap { $0 }.sorted { $0.index < $1.index })
        }

        return true
    }

    private func inspect(items: [LoadedDropItem]) {
        let droppedNames = items.compactMap { $0.url?.lastPathComponent }
        selectedItemName = droppedNames.isEmpty ? "—" : droppedNames.joined(separator: "\n")

        var successfulResults: [InspectionResult] = []
        var failedEntries: [String] = []

        for item in items {
            guard let url = item.url else {
                failedEntries.append(
                    String(
                        format: NSLocalizedString("• %@", comment: "Unreadable dropped item entry"),
                        locale: Locale.current,
                        NSLocalizedString("The dropped item was not a valid file URL.", comment: "Invalid dropped URL")
                    )
                )
                continue
            }

            do {
                successfulResults.append(try ArchitectureInspector.inspect(url: url))
            } catch {
                failedEntries.append(
                    String(
                        format: NSLocalizedString("• %@: %@", comment: "Failed inspection entry"),
                        locale: Locale.current,
                        url.lastPathComponent,
                        error.localizedDescription
                    )
                )
            }
        }

        guard !successfulResults.isEmpty else {
            resolvedBinaryPath = "—"
            architectureSummary = NSLocalizedString("No architecture information available", comment: "No architecture information available")
            presentAlert(
                title: NSLocalizedString("Couldn't Inspect Files", comment: "Couldn't inspect files"),
                message: failedEntries.joined(separator: "\n")
            )
            return
        }

        resolvedBinaryPath = successfulResults
            .map(\.resolvedURL.path)
            .joined(separator: "\n")
        architectureSummary = successfulResults
            .map(\.summaryLine)
            .joined(separator: "\n")

        let successSection = ([NSLocalizedString("Detected architectures:", comment: "Detected architectures header")] + successfulResults.map(\.alertListEntry))
            .joined(separator: "\n")
        let failureSection = failedEntries.isEmpty
            ? nil
            : ([NSLocalizedString("Issues:", comment: "Issues header")] + failedEntries).joined(separator: "\n")

        let alertSections = [successSection, failureSection].compactMap { $0 }
        let alertTitle = failedEntries.isEmpty
            ? NSLocalizedString("Inspection Complete", comment: "Inspection complete")
            : NSLocalizedString("Inspection Completed with Errors", comment: "Inspection completed with errors")

        presentAlert(title: alertTitle, message: alertSections.joined(separator: "\n\n"))
    }

    private func presentAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showsAlert = true
    }

    private nonisolated static func fileURL(from item: NSSecureCoding?) -> URL? {
        switch item {
        case let url as URL:
            return url
        case let data as Data:
            return URL(dataRepresentation: data, relativeTo: nil)
        case let string as String:
            return URL(string: string)
        default:
            return nil
        }
    }
}
