import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(AppRouter.self) private var router
    @AppStorage(SettingsKeys.hasSeenOnboarding) private var hasSeenOnboarding = false
    @Query(filter: #Predicate<Reminder> { $0.isActive }) private var activeReminders: [Reminder]

    private var overdueCount: Int {
        activeReminders.filter(\.isDue).count
    }

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            NavigationStack {
                ItemsView()
            }
            .tabItem {
                Label("Items", systemImage: "archivebox.fill")
            }
            .tag(AppRouter.Tab.items)

            NavigationStack {
                RoomsView()
            }
            .tabItem {
                Label("Rooms", systemImage: "house.fill")
            }
            .tag(AppRouter.Tab.rooms)

            NavigationStack {
                MaintenanceView()
            }
            .tabItem {
                Label("Maintenance", systemImage: "wrench.and.screwdriver.fill")
            }
            .badge(overdueCount)
            .tag(AppRouter.Tab.maintenance)

            NavigationStack {
                SummaryView()
            }
            .tabItem {
                Label("Summary", systemImage: "chart.bar.fill")
            }
            .tag(AppRouter.Tab.summary)
        }
        .fullScreenCover(isPresented: Binding(
            get: { !hasSeenOnboarding },
            set: { if !$0 { hasSeenOnboarding = true } }
        )) {
            OnboardingView { hasSeenOnboarding = true }
        }
    }
}
