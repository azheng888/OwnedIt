import SwiftUI
import SwiftData
import CloudKit
import UniformTypeIdentifiers
import UserNotifications

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Room.name) private var rooms: [Room]

    @AppStorage(SettingsKeys.warrantyAlertsEnabled) private var warrantyAlertsEnabled = true
    @AppStorage(SettingsKeys.hasSeenOnboarding) private var hasSeenOnboarding = true

    @State private var showingImportPicker = false
    @State private var importResultMessage: String?
    @State private var iCloudStatus: CKAccountStatus?
    @State private var notificationStatus: UNAuthorizationStatus?

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }

    private var syncStatus: (text: String, color: Color) {
        switch iCloudStatus {
        case .available:              return ("On", Theme.positive)
        case .noAccount:              return ("Signed Out", .secondary)
        case .restricted:             return ("Restricted", .secondary)
        case .temporarilyUnavailable: return ("Unavailable", Theme.warning)
        case .couldNotDetermine:      return ("Unknown", .secondary)
        case .none:                   return ("Checking…", .secondary)
        @unknown default:             return ("Unknown", .secondary)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent {
                        Text(syncStatus.text).foregroundStyle(syncStatus.color)
                    } label: {
                        Label("iCloud Sync", systemImage: "icloud")
                    }
                } header: {
                    Text("Sync")
                } footer: {
                    switch iCloudStatus {
                    case .noAccount:
                        Text("Sign in to iCloud in the Settings app to sync your inventory across devices.")
                    case .available:
                        Text("Your inventory syncs privately to your other devices signed into this iCloud account.")
                    default:
                        EmptyView()
                    }
                }

                Section {
                    LabeledContent {
                        if notificationStatus == .denied {
                            Button("Turn On") { openSystemSettings() }
                        } else {
                            Text(notificationStatus == .authorized ? "On" : "Not Set Up")
                                .foregroundStyle(Theme.secondaryText)
                        }
                    } label: {
                        Label("Notifications", systemImage: "bell")
                    }
                    Toggle(isOn: $warrantyAlertsEnabled) {
                        Label("Warranty Expiry Alerts", systemImage: "checkmark.shield")
                    }
                    .onChange(of: warrantyAlertsEnabled) { _, enabled in
                        if enabled { NotificationManager.shared.requestPermission { _ in refreshNotificationStatus() } }
                    }
                } header: {
                    Text("Alerts")
                } footer: {
                    Text("Get a heads-up \(NotificationManager.warrantyLeadDays) days before a warranty expires, while there's still time to make a claim.")
                }

                Section {
                    Button {
                        showingImportPicker = true
                    } label: {
                        Label("Import from CSV", systemImage: "square.and.arrow.down")
                    }
                } header: {
                    Text("Data")
                } footer: {
                    Text("Use a file exported from OwnedIt, or any spreadsheet with a \"Name\" column. Matching columns like Room, Category and Purchase Price are picked up automatically.")
                }

                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    NavigationLink(destination: PrivacyPolicyView()) {
                        Text("Privacy Policy")
                    }
                    Button("Show Welcome Tour") {
                        dismiss()
                        hasSeenOnboarding = false
                    }
                }
            }
            .listStyle(.insetGrouped)
            .themedList()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                iCloudStatus = try? await CKContainer(identifier: "iCloud.com.allan.OwnedIt").accountStatus()
                refreshNotificationStatus()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { refreshNotificationStatus() }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $showingImportPicker,
                allowedContentTypes: [.commaSeparatedText, .plainText],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }
            .messageAlert("Import", message: $importResultMessage)
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            importResultMessage = error.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else {
                importResultMessage = "Couldn't read \(url.lastPathComponent)."
                return
            }
            let outcome = ExportManager.importItems(from: data, into: modelContext, existingRooms: rooms)
            try? modelContext.save()
            if outcome.imported == 0 {
                importResultMessage = "No items were found. Make sure the file has a header row with a \"Name\" column."
            } else {
                var parts = ["Imported \(outcome.imported.pluralized("item"))"]
                if outcome.roomsCreated > 0 { parts.append("created \(outcome.roomsCreated.pluralized("room"))") }
                if outcome.skipped > 0 { parts.append("skipped \(outcome.skipped) row\(outcome.skipped == 1 ? "" : "s") without a name") }
                importResultMessage = ListFormatter.localizedString(byJoining: parts) + "."
            }
        }
    }

    private func refreshNotificationStatus() {
        Task { notificationStatus = await NotificationManager.shared.authorizationStatus() }
    }

    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
