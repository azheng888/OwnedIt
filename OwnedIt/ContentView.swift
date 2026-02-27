import SwiftUI

struct ContentView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

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
