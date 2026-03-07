import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Group {
                    PolicySection(title: "Overview",
                        content: "OwnedIt is designed to keep your data private and on your device. The app does not collect, sell, or share your personal information with third parties.")

                    PolicySection(title: "Data Storage",
                        content: "All inventory data — including items, rooms, photos, receipts, and reminders — is stored locally on your device using Apple's SwiftData framework. This data never leaves your device except as described below.")

                    PolicySection(title: "iCloud Sync",
                        content: "When iCloud sync is enabled, your data is synced to your personal iCloud account using Apple's CloudKit framework. This data is governed by Apple's Privacy Policy and is not accessible to the developers of OwnedIt.")

                    PolicySection(title: "Barcode Lookup",
                        content: "When you scan a barcode, the barcode number is sent to UPCitemdb (upcitemdb.com) to look up product information such as name and brand. No personal information is transmitted as part of this request. You can review UPCitemdb's privacy policy at upcitemdb.com.")

                    PolicySection(title: "Photos and Documents",
                        content: "Photos and documents you attach to items are stored locally on your device. They are not uploaded to any server operated by OwnedIt.")

                    PolicySection(title: "Notifications",
                        content: "Maintenance reminders are scheduled locally on your device using Apple's UserNotifications framework. No data is transmitted to any server to deliver these notifications.")

                    PolicySection(title: "Analytics and Advertising",
                        content: "OwnedIt does not use any analytics frameworks, crash reporting services, or advertising SDKs. No usage data is collected or transmitted.")

                    PolicySection(title: "Children's Privacy",
                        content: "OwnedIt does not knowingly collect any information from children under the age of 13.")

                    PolicySection(title: "Changes to This Policy",
                        content: "This privacy policy may be updated from time to time. Continued use of the app after changes constitutes acceptance of the updated policy.")

                    PolicySection(title: "Contact",
                        content: "If you have questions about this privacy policy, please open an issue on the OwnedIt GitHub repository.")
                }

                Text("Last updated: March 2026")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.large)
    }
}

private struct PolicySection: View {
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(content)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
