<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/images/hero-dark.png">
  <img alt="OwnedIt: everything you own, accounted for." src="docs/images/hero-light.png">
</picture>

<p align="center">
  <img alt="iOS 17+" src="https://img.shields.io/badge/iOS-17%2B-1F1D19?style=flat-square&logo=apple&logoColor=F5F2EB">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-SwiftUI%20%2B%20SwiftData-1F1D19?style=flat-square&logo=swift&logoColor=F5F2EB">
  <img alt="iCloud sync" src="https://img.shields.io/badge/Sync-iCloud-1F1D19?style=flat-square&logo=icloud&logoColor=F5F2EB">
  <img alt="No dependencies" src="https://img.shields.io/badge/dependencies-none-1F1D19?style=flat-square">
  <img alt="MIT license" src="https://img.shields.io/badge/license-MIT-1F1D19?style=flat-square">
</p>

<p align="center">
  A home inventory app for iPhone. Track what you own, where it lives, what it's worth,<br>
  and when warranties expire, so an insurance claim takes minutes, not weekends.
</p>

<br>

<p align="center">
  <img src="docs/images/light-onboarding.png" width="24%" alt="Onboarding">
  <img src="docs/images/light-items.png" width="24%" alt="Items, grouped by room">
  <img src="docs/images/light-summary.png" width="24%" alt="Summary with total value and claim readiness">
  <img src="docs/images/light-maintenance.png" width="24%" alt="Maintenance reminders">
</p>

## What it does

| | |
|---|---|
| 📦 **Items** | Photos (camera or library, reorderable, with a cover photo), purchase info, serial number, condition, current value, warranty, notes, and attached receipts and documents. Scan a **barcode** to fill in the name, brand, model and a product photo, or **scan a paper receipt** straight to PDF. |
| 🏠 **Rooms** | Organize items by where they live, with per-room totals. |
| 🔧 **Maintenance** | Recurring reminders (filters, servicing, batteries) with local notifications, pause/resume and completion history. |
| 📊 **Summary** | Total value, a **claim readiness** score that shows which items are missing photos, values or receipts, plus warranty and maintenance alerts and breakdowns by category and room. |
| 📄 **Export & import** | A PDF inventory report grouped by room, and per-item PDF records for insurance. CSV export and import that round-trips across devices and accepts most spreadsheets with a "Name" column. |
| ☁️ **Sync** | iCloud (CloudKit) sync across your devices. Notifications are derived from the synced data, so a reminder created on one device alerts on all of them. |

## Light and dark

<p align="center">
  <img src="docs/images/light-rooms.png" width="24%" alt="Rooms, light">
  <img src="docs/images/dark-rooms.png" width="24%" alt="Rooms, dark">
  <img src="docs/images/dark-items.png" width="24%" alt="Items, dark">
  <img src="docs/images/dark-summary.png" width="24%" alt="Summary, dark">
</p>

## Design

The look is calm and editorial, like a well-kept paper ledger:

- **Warm paper** background, with cards that have hairline borders instead of shadows.
- **Ink is the only accent.** Amber and red appear only as warnings.
- **One typeface:** SF Pro everywhere, with tabular digits for money. Size and weight set the hierarchy.
- **One icon style:** neutral rounded tiles, or the item's own photo.
- **Motion** is short and purposeful (critically damped springs, subtle press feedback) and respects Reduce Motion.

Shared tokens and components live in [`Theme.swift`](OwnedIt/Theme.swift).

## Tech

- **SwiftUI + SwiftData**, backed by CloudKit with a local-only fallback
- **VisionKit** for barcode and document scanning
- **PhotosUI** and the camera for photos (downscaled to 2048 px, with cached thumbnails)
- **UserNotifications** for reminders and warranty alerts
- **UIGraphicsPDFRenderer** for reports

## Running it

Open `OwnedIt.xcodeproj` in Xcode 16+ and run. There are no external dependencies.

Debug builds accept a few launch arguments:

| Argument | Effect |
|---|---|
| `-seedSampleData YES` | Fills an empty store with demo items, rooms and reminders |
| `-initialTab items\|rooms\|maintenance\|summary` | Opens straight to that tab |
| `-hasSeenOnboarding YES` | Skips onboarding |

The README images are generated: [`Tools/make_readme_art.py`](Tools/make_readme_art.py) frames simulator screenshots and draws the banner, and [`Tools/make_app_icon.py`](Tools/make_app_icon.py) draws the app icon.

## License

MIT
