import SwiftUI
import SwiftData

@main
struct OwnedItApp: App {
    @State private var router = AppRouter()

    let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            Room.self,
            Photo.self,
            Receipt.self,
            Reminder.self,
        ])

        // Try CloudKit-backed store first; fall back to local if not provisioned
        let cloud = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .automatic)
        let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)

        do {
            return try ModelContainer(for: schema, configurations: [cloud])
        } catch {
            print("OwnedIt: CloudKit store unavailable (\(error)); using local store.")
            do {
                return try ModelContainer(for: schema, configurations: [fallback])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    init() {
        NotificationManager.shared.activate()
        Theme.applyAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(Theme.accent)
                .environment(router)
                .keepsNotificationsInSync()
                .task { DataMaintenance.run(in: sharedModelContainer.mainContext) }
                .onAppear {
                    NotificationManager.shared.onOpenNotification = { kind in
                        router.selectedTab = kind == .warranty ? .summary : .maintenance
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}

@Observable
final class AppRouter {
    enum Tab: String, Hashable { case items, rooms, maintenance, summary }
    var selectedTab: Tab = .items

    init() {
        #if DEBUG
        // e.g. `-initialTab summary` for screenshots/testing.
        if let raw = UserDefaults.standard.string(forKey: "initialTab"), let tab = Tab(rawValue: raw) {
            selectedTab = tab
        }
        #endif
    }
}

/// Small, idempotent data upgrades run at launch.
enum DataMaintenance {
    private static let photoOrderMigrationKey = "migration.photoSortIndex.v1"

    @MainActor
    static func run(in context: ModelContext) {
        #if DEBUG
        SampleData.seedIfRequested(in: context)
        #endif
        backfillThumbnails(in: context)
        fixInvalidRoomIcons(in: context)
        if !UserDefaults.standard.bool(forKey: photoOrderMigrationKey) {
            assignPhotoOrder(in: context)
            UserDefaults.standard.set(true, forKey: photoOrderMigrationKey)
        }
        try? context.save()
    }

    /// Photos created before thumbnails existed (or synced from an older build) get one now.
    @MainActor
    private static func backfillThumbnails(in context: ModelContext) {
        let descriptor = FetchDescriptor<Photo>(predicate: #Predicate { $0.thumbnailData == nil })
        guard let photos = try? context.fetch(descriptor) else { return }
        for photo in photos {
            guard let data = photo.imageData else { continue }
            photo.thumbnailData = ImageProcessing.thumbnailData(from: data)
        }
    }

    /// Older builds offered "garage", which isn't a valid SF Symbol (rendered blank).
    @MainActor
    private static func fixInvalidRoomIcons(in context: ModelContext) {
        let descriptor = FetchDescriptor<Room>(predicate: #Predicate { $0.icon == "garage" })
        for room in (try? context.fetch(descriptor)) ?? [] { room.icon = "door.garage.closed" }
    }

    /// Older builds didn't persist photo order; freeze whatever order we have now.
    @MainActor
    private static func assignPhotoOrder(in context: ModelContext) {
        guard let items = try? context.fetch(FetchDescriptor<Item>()) else { return }
        for item in items {
            let photos = item.photos ?? []
            guard photos.count > 1, Set(photos.map(\.sortIndex)).count < photos.count else { continue }
            for (index, photo) in photos.enumerated() { photo.sortIndex = index }
        }
    }
}
