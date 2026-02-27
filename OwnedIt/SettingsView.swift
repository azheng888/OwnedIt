import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Room.name) private var rooms: [Room]

    @State private var showingImportPicker = false
    @State private var importResultMessage: String?

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Sync") {
                    HStack {
                        Label("iCloud Sync", systemImage: "icloud")
                        Spacer()
                        Text("Coming Soon")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Data") {
                    Button {
                        showingImportPicker = true
                    } label: {
                        Label("Import CSV", systemImage: "square.and.arrow.down")
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("\(appVersion) (\(buildNumber))")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $showingImportPicker,
                allowedContentTypes: [.commaSeparatedText],
                allowsMultipleSelection: false
            ) { result in
                guard case .success(let urls) = result, let url = urls.first else { return }
                guard url.startAccessingSecurityScopedResource() else { return }
                defer { url.stopAccessingSecurityScopedResource() }
                guard let data = try? Data(contentsOf: url) else { return }
                let (imported, skipped) = ExportManager.importItems(from: data, into: modelContext, existingRooms: rooms)
                importResultMessage = skipped > 0
                    ? "Imported \(imported) item\(imported == 1 ? "" : "s"), \(skipped) skipped."
                    : "Imported \(imported) item\(imported == 1 ? "" : "s")."
            }
            .alert("Import Complete", isPresented: .constant(importResultMessage != nil)) {
                Button("OK") { importResultMessage = nil }
            } message: {
                Text(importResultMessage ?? "")
            }
        }
    }
}
