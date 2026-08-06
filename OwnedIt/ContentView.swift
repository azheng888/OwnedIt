import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @Query private var reminders: [Reminder]

    private var overdueCount: Int {
        reminders.filter { $0.isActive && $0.isDue }.count
    }

    var body: some View {
        TabView {
            NavigationStack {
                ItemsView()
            }
            .tabItem {
                Label("Items", systemImage: "archivebox.fill")
            }

            NavigationStack {
                RoomsView()
            }
            .tabItem {
                Label("Rooms", systemImage: "house.fill")
            }

            NavigationStack {
                MaintenanceView()
            }
            .tabItem {
                Label("Maintenance", systemImage: "wrench.and.screwdriver.fill")
            }
            .badge(overdueCount)

            NavigationStack {
                SummaryView()
            }
            .tabItem {
                Label("Summary", systemImage: "chart.bar.fill")
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { !hasSeenOnboarding },
            set: { _ in }
        )) {
            OnboardingView { hasSeenOnboarding = true }
        }
    }
}
