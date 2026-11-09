# OwnedIt

A home inventory app for iOS. Track what you own, where it lives, what it's worth, and when warranties expire.

Built with SwiftUI and SwiftData. Requires iOS 17.0+.

## What it does

**Items** — Photos (camera or library, reorderable, with a cover photo), purchase info, serial number, condition, current value, warranty, notes, and attached receipts/documents. Scan a barcode to auto-fill the name, brand, model and a product photo, or scan a paper receipt straight to PDF.

**Rooms** — Organize items by where they live, with per-room totals.

**Maintenance** — Recurring reminders (filters, servicing, batteries) with local notifications, pause/resume, and completion history.

**Summary** — Total value, a *claim readiness* score showing which items are missing photos, values or receipts, warranty and maintenance alerts, and breakdowns by category and room.

**Export & import** — PDF inventory report (grouped by room) and per-item PDF records for insurance; CSV export/import that round-trips across devices and accepts most spreadsheets with a "Name" column.

**Sync** — iCloud (CloudKit) sync across your devices. Notifications are derived from the synced data, so reminders created on one device alert on all of them.

## Design

A warm, editorial look: paper-toned background, white cards with hairline borders, a single emerald accent, New York serif headings and large monospaced-digit numbers. Motion is short and purposeful (critically damped springs, subtle press feedback, staggered entrances) and respects Reduce Motion. Shared tokens and components live in `Theme.swift`.

## Tech

- SwiftUI + SwiftData (CloudKit-backed, with local fallback)
- VisionKit for barcode and document scanning
- PhotosUI and the camera for photos (downscaled to 2048 px, with cached thumbnails)
- UserNotifications for reminders and warranty alerts
- UIGraphicsPDFRenderer for reports

## Running it

Open `OwnedIt.xcodeproj` in Xcode 16+ and run. No external dependencies.

For demo data in a Debug build, launch with `-seedSampleData YES` (only seeds an empty store). `-initialTab summary|items|rooms|maintenance` opens a specific tab — handy for screenshots.

## License

MIT
