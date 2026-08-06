import SwiftUI
import SwiftData
import CloudKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Room.name) private var rooms: [Room]

    @State private var showingImportPicker = false
    @State private var importResultMessage: String?
    @State private var iCloudStatus: CKAccountStatus?

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    private var syncStatusText: String {
        switch iCloudStatus {
        case .available:         return "On"
        case .noAccount:         return "Signed Out"
        case .restricted:        return "Restricted"
        case .couldNotDetermine: return "Unknown"
        case .temporarilyUnavailable: return "Unavailable"
        case .none:               return "Checking…"
        @unknown default:        return "Unknown"
        }
    }

    private var syncStatusColor: Color {
        iCloudStatus == .available ? .green : .secondary
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Label("iCloud Sync", systemImage: "icloud")
                        Spacer()
                        Text(syncStatusText)
                            .font(.subheadline)
                            .foregroundStyle(syncStatusColor)
                    }
                } header: {
                    Text("Sync")
                } footer: {
                    if iCloudStatus == .noAccount {
                        Text("Sign in to iCloud in Settings to sync your inventory across devices.")
                    } else if iCloudStatus == .available {
                        Text("Your inventory syncs automatically to your other devices signed into this iCloud account.")
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
                    NavigationLink(destination: PrivacyPolicyView()) {
                        Text("Privacy Policy")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                iCloudStatus = try? await CKContainer(identifier: "iCloud.com.allan.OwnedIt").accountStatus()
            }
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
