# OwnedIt

A home inventory app for iOS. Track what you own, where it lives, what it's worth, and when warranties expire.

Built with SwiftUI and SwiftData. Requires iOS 17.0+.

## What it does

**Items** — Add anything to your inventory: furniture, electronics, appliances, tools, etc. Each item can have photos, purchase info, a serial number, condition rating, current value estimate, warranty date, and notes. You can scan a barcode to auto-fill product details instead of typing everything by hand.

**Rooms** — Organize items by location. Rooms have a name, an icon, and a color. The app tracks the total value of everything in each room.

**Summary** — A dashboard showing your full inventory value, a breakdown by category and room, recently added items, and warranty alerts for anything expiring in the next 90 days.

You can export your inventory as a CSV (for spreadsheets) or a PDF (for insurance claims, moving, etc.).

## Screenshots

_Coming soon._

## Tech

- SwiftUI + SwiftData
- VisionKit for barcode scanning (iOS 16.1+)
- CloudKit for iCloud sync (configured, entitlement needed to enable)
- PhotosUI for photo picking
- PDFKit / UIGraphicsPDFRenderer for export

## Running it

Clone the repo and open `OwnedIt.xcodeproj` in Xcode 16+. Select your device or simulator and hit run. No external dependencies, no package manager needed.

To enable iCloud sync, add the CloudKit capability in Xcode and set your container identifier in `OwnedItApp.swift`.

## License

MIT
