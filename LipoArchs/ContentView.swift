import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var isDropTargeted = false
//    @State private var selectedItemName = NSLocalizedString("No file selected", comment: "No file selected")
    @State private var selectedItemName = "—"
    @State private var resolvedBinaryPath = "—"
    @State private var architectureSummary = "—"
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showsAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("LipoArchs")
                .font(.largeTitle.bold())

            Text("Drag a macOS executable, dynamic library, or .app\nbundle into the drop area to display its architecture.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            dropArea

            Divider()

            LabeledContent("Architecture:") {
                Text(architectureSummary)
                    .font(.headline)
                    .textSelection(.enabled)
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                LabeledContent("Selected Item:") {
                    Text(selectedItemName)
                        .textSelection(.enabled)
                }
                .padding(.bottom, 10)

                Divider()

                LabeledContent("Resolved Binary:") {
                    Text(resolvedBinaryPath)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
                .padding(.top, 12)

            }

            Spacer(minLength: 0)
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

             try? await Task.sleep(for: .seconds(3))

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
                    Text("Drop File Here")
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
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            presentAlert(
                title: NSLocalizedString("No File Found", comment: "No file found"),
                message: NSLocalizedString("Drop a single file or .app bundle from Finder.", comment: "Drop hint")
            )
            return false
        }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            let url = Self.fileURL(from: item)
            DispatchQueue.main.async {
                guard let url else {
                    presentAlert(
                        title: NSLocalizedString("Couldn't Read Drop", comment: "Couldn't read drop"),
                        message: NSLocalizedString("The dropped item was not a valid file URL.", comment: "Invalid dropped URL")
                    )
                    return
                }
                inspect(url: url)
            }
        }

        return true
    }

    private func inspect(url: URL) {
        selectedItemName = url.lastPathComponent

        do {
            let result = try ArchitectureInspector.inspect(url: url)
            resolvedBinaryPath = result.resolvedURL.path
            architectureSummary = result.labelText
            presentAlert(title: (NSLocalizedString("Inspection Complete", comment: "Inspection complete")), message: result.alertMessage)
        } catch {
            resolvedBinaryPath = "—"
            architectureSummary = NSLocalizedString("No architecture information available", comment: "No architecture information available")
            presentAlert(title: NSLocalizedString("Couldn't Inspect File", comment: "Couldn't Inspect File"), message: error.localizedDescription)
        }
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
