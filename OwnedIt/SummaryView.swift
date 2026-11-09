import SwiftUI
import SwiftData

struct SummaryView: View {
    @Query private var items: [Item]
    @Query(sort: \Room.name) private var rooms: [Room]
    @Query(filter: #Predicate<Reminder> { $0.isActive }) private var activeReminders: [Reminder]

    @State private var exportFile: ShareableFile?
    @State private var showingSettings = false
    @State private var isExporting = false
    @State private var exportError: String?

    // MARK: Derived data

    private var totalValue: Double { items.compactMap(\.displayValue).reduce(0, +) }

    private var totalPaid: Double {
        items.compactMap { item in item.purchasePrice.map { $0 * Double(item.quantity) } }.reduce(0, +)
    }

    private var totalUnits: Int { items.reduce(0) { $0 + $1.quantity } }

    private var readiness: (score: Double, noPhoto: Int, noValue: Int, noReceipt: Int) {
        guard !items.isEmpty else { return (0, 0, 0, 0) }
        let noPhoto = items.filter { !$0.hasPhotos }.count
        let noValue = items.filter { $0.unitValue == nil }.count
        let noReceipt = items.filter { !$0.hasReceipts }.count
        // Photo and value matter most for a claim; receipts are a bonus.
        let total = Double(items.count)
        let photoScore: Double = (total - Double(noPhoto)) * 0.4
        let valueScore: Double = (total - Double(noValue)) * 0.4
        let receiptScore: Double = (total - Double(noReceipt)) * 0.2
        return ((photoScore + valueScore + receiptScore) / total, noPhoto, noValue, noReceipt)
    }

    private var categoryBreakdown: [(category: ItemCategory, count: Int, value: Double)] {
        let groups: [ItemCategory: [Item]] = Dictionary(grouping: items) { $0.category ?? .other }
        var result: [(category: ItemCategory, count: Int, value: Double)] = []
        for (category, members) in groups {
            let value: Double = members.compactMap(\.displayValue).reduce(0, +)
            result.append((category: category, count: members.count, value: value))
        }
        return result.sorted { $0.value == $1.value ? $0.count > $1.count : $0.value > $1.value }
    }

    private var roomBreakdown: [(room: Room, count: Int, value: Double)] {
        rooms.compactMap { room in
            let roomItems = room.items ?? []
            guard !roomItems.isEmpty else { return nil }
            return (room, roomItems.count, roomItems.compactMap(\.displayValue).reduce(0, +))
        }
        .sorted { $0.value == $1.value ? $0.count > $1.count : $0.value > $1.value }
    }

    private var recentItems: [Item] {
        Array(items.sorted { ($0.dateAdded ?? .distantPast) > ($1.dateAdded ?? .distantPast) }.prefix(8))
    }

    private var dueReminders: [Reminder] {
        let horizon = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
        return activeReminders.filter { $0.item != nil && $0.nextDueDate <= horizon }
            .sorted { $0.nextDueDate < $1.nextDueDate }
    }

    private var warrantyAlerts: [Item] {
        let now = Calendar.current.startOfDay(for: Date())
        let horizon = Calendar.current.date(byAdding: .day, value: 90, to: now) ?? now
        let recentlyExpired = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
        return items.filter {
            guard let exp = $0.warrantyExpiration else { return false }
            return exp >= recentlyExpired && exp <= horizon
        }
        .sorted { ($0.warrantyExpiration ?? .distantFuture) < ($1.warrantyExpiration ?? .distantFuture) }
    }

    // MARK: Body

    var body: some View {
        Group {
            if items.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        heroCard.appearEffect(index: 0)
                        readinessCard.appearEffect(index: 1)
                        if !dueReminders.isEmpty || !warrantyAlerts.isEmpty {
                            alertsCard.appearEffect(index: 2)
                        }
                        categoriesCard.appearEffect(index: 3)
                        if !roomBreakdown.isEmpty {
                            roomsCard.appearEffect(index: 4)
                        }
                        recentCard.appearEffect(index: 5)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
        }
        .themedScreen()
        .navigationTitle("Summary")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingSettings = true } label: { Image(systemName: "gearshape") }
                    .accessibilityLabel("Settings")
            }
            if !items.isEmpty {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button(action: exportPDF) {
                            Label("PDF Report", systemImage: "doc.richtext")
                        }
                        Button(action: exportCSV) {
                            Label("Spreadsheet (CSV)", systemImage: "tablecells")
                        }
                    } label: {
                        if isExporting { ProgressView() } else { Image(systemName: "square.and.arrow.up") }
                    }
                    .accessibilityLabel("Export")
                }
            }
        }
        .sheet(item: $exportFile) { file in
            ShareSheet(url: file.url)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .messageAlert("Export Failed", message: $exportError)
    }

    // MARK: Cards

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Total value")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
            Text(totalValue, format: AppFormat.wholeCurrency)
                .font(.hero(40))
                .foregroundStyle(Theme.ink)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .contentTransition(.numericText(value: totalValue))
                .animation(Motion.snappy, value: totalValue)
            HStack(spacing: 6) {
                Text(totalUnits.pluralized("item"))
                Text("·")
                Text(rooms.count.pluralized("room"))
                if totalPaid > 0, abs(totalValue - totalPaid) > 0.5 {
                    Text("·")
                    let delta = totalValue - totalPaid
                    Text("\(delta >= 0 ? "+" : "−")\(abs(delta).wholeCurrencyString) vs. paid")
                }
            }
            .font(.subheadline)
            .foregroundStyle(Theme.secondaryText)
            .monospacedDigit()
        }
        .card(padding: 18)
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
    }

    private var readinessCard: some View {
        let r = readiness
        return VStack(alignment: .leading, spacing: 8) {
            CardHeader("Claim readiness")
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 16) {
                    ProgressRing(progress: r.score, color: r.score < 0.5 ? Theme.warning : Theme.ink)
                        .frame(width: 56, height: 56)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(r.score >= 0.999 ? "Fully documented" : r.score >= 0.8 ? "Well documented" : r.score >= 0.5 ? "Getting there" : "Needs attention")
                            .font(.body.weight(.medium))
                            .foregroundStyle(Theme.ink)
                        Text("Photos, values and receipts make claims fast.")
                            .font(.footnote)
                            .foregroundStyle(Theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(14)

                gapRow("Missing photos", count: r.noPhoto) { !$0.hasPhotos }
                gapRow("Missing value", count: r.noValue) { $0.unitValue == nil }
                gapRow("Missing receipt", count: r.noReceipt) { !$0.hasReceipts }
            }
            .card(padding: 0)
        }
    }

    @ViewBuilder
    private func gapRow(_ title: String, count: Int, filter: @escaping (Item) -> Bool) -> some View {
        if count > 0 {
            Divider().overlay(Theme.divider)
            NavigationLink {
                FilteredItemsView(title: title, filter: filter)
            } label: {
                HStack(spacing: 12) {
                    Text(title).foregroundStyle(Theme.ink)
                    Spacer()
                    Text("\(count)")
                        .monospacedDigit()
                        .foregroundStyle(Theme.secondaryText)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.tertiaryText)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.pressable)
        }
    }

    private var alertsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            CardHeader("Needs attention")
            VStack(spacing: 0) {
                ForEach(Array(dueReminders.enumerated()), id: \.element.persistentModelID) { index, reminder in
                    if let item = reminder.item {
                        if index > 0 { Divider().overlay(Theme.divider) }
                        NavigationLink(destination: ItemDetailView(item: item)) {
                            alertRow(icon: "wrench.and.screwdriver", color: reminder.isDue ? Theme.warning : Theme.secondaryText,
                                     title: reminder.title, subtitle: item.displayName,
                                     trailing: AppFormat.shortDate(reminder.nextDueDate))
                        }
                        .buttonStyle(.pressable)
                    }
                }
                ForEach(Array(warrantyAlerts.enumerated()), id: \.element.persistentModelID) { index, item in
                    if index > 0 || !dueReminders.isEmpty { Divider().overlay(Theme.divider) }
                    NavigationLink(destination: ItemDetailView(item: item)) {
                        alertRow(icon: "checkmark.shield",
                                 color: item.isWarrantyExpired ? Theme.critical : Theme.warning,
                                 title: item.isWarrantyExpired ? "Warranty expired" : "Warranty ending",
                                 subtitle: item.displayName,
                                 trailing: item.warrantyExpiration.map(AppFormat.shortDate) ?? "")
                    }
                    .buttonStyle(.pressable)
                }
            }
            .card(padding: 0)
        }
    }

    private func alertRow(icon: String, color: Color, title: String, subtitle: String, trailing: String) -> some View {
        HStack(spacing: 12) {
            IconTile(systemName: icon, color: color, size: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).foregroundStyle(Theme.ink)
                Text(subtitle).font(.footnote).foregroundStyle(Theme.secondaryText).lineLimit(1)
            }
            Spacer()
            Text(trailing).font(.footnote).monospacedDigit().foregroundStyle(color)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private var categoriesCard: some View {
        let breakdown = categoryBreakdown
        let useValue = totalValue > 0
        let maxMetric = breakdown.map { useValue ? $0.value : Double($0.count) }.max() ?? 1
        return VStack(alignment: .leading, spacing: 8) {
            CardHeader("By category")
            VStack(spacing: 14) {
                ForEach(breakdown, id: \.category) { entry in
                    NavigationLink {
                        FilteredItemsView(title: entry.category.rawValue) { ($0.category ?? .other) == entry.category }
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(entry.category.rawValue).foregroundStyle(Theme.ink)
                                Spacer()
                                Text(useValue ? entry.value.wholeCurrencyString : "\(entry.count)")
                                    .monospacedDigit()
                                    .foregroundStyle(Theme.secondaryText)
                            }
                            BarView(fraction: (useValue ? entry.value : Double(entry.count)) / max(maxMetric, 1))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.pressable)
                }
            }
            .card(padding: 14)
        }
    }

    private var roomsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            CardHeader("By room")
            VStack(spacing: 0) {
                ForEach(Array(roomBreakdown.enumerated()), id: \.element.room.persistentModelID) { index, entry in
                    if index > 0 { Divider().overlay(Theme.divider) }
                    NavigationLink(destination: RoomDetailView(room: entry.room)) {
                        HStack(spacing: 12) {
                            IconTile(systemName: entry.room.icon, size: 32)
                            Text(entry.room.name).foregroundStyle(Theme.ink)
                            Spacer()
                            Text(entry.value > 0 ? entry.value.wholeCurrencyString : entry.count.pluralized("item"))
                                .monospacedDigit()
                                .foregroundStyle(Theme.secondaryText)
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Theme.tertiaryText)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.pressable)
                }
            }
            .card(padding: 0)
        }
    }

    private var recentCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            CardHeader("Recently added")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(recentItems) { item in
                        NavigationLink(destination: ItemDetailView(item: item)) {
                            VStack(alignment: .leading, spacing: 6) {
                                ItemThumbnailView(item: item, size: 104)
                                Text(item.displayName)
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(Theme.ink)
                                    .lineLimit(1)
                                if let value = item.displayValue {
                                    Text(value.currencyString)
                                        .font(.caption)
                                        .monospacedDigit()
                                        .foregroundStyle(Theme.secondaryText)
                                }
                            }
                            .frame(width: 104, alignment: .leading)
                        }
                        .buttonStyle(.pressable)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Your Summary Lives Here", systemImage: "chart.bar")
        } description: {
            Text("Add a few items to see their total value, what's missing for insurance, and what needs attention.")
        }
    }

    // MARK: Export

    private func exportCSV() {
        let data = ExportManager.csvData(from: items)
        guard let url = TempFile.write(data, preferredName: "OwnedIt Inventory", ext: "csv") else {
            exportError = "The file couldn't be created."
            return
        }
        exportFile = ShareableFile(url: url)
    }

    private func exportPDF() {
        isExporting = true
        // Let the spinner render before the (synchronous) render.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            let data = ExportManager.pdfData(from: items, rooms: rooms)
            isExporting = false
            guard let url = TempFile.write(data, preferredName: "OwnedIt Inventory Report", ext: "pdf") else {
                exportError = "The report couldn't be created."
                return
            }
            exportFile = ShareableFile(url: url)
        }
    }
}

// MARK: - Components

struct ProgressRing: View {
    let progress: Double
    var color: Color = Theme.accent
    @State private var shown: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle().stroke(Theme.surfaceMuted, lineWidth: 6)
            Circle()
                .trim(from: 0, to: shown)
                .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(progress, format: .percent.precision(.fractionLength(0)))
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
        }
        .onAppear { animate(to: progress) }
        .onChange(of: progress) { _, new in animate(to: new) }
        .accessibilityElement()
        .accessibilityLabel("Claim readiness")
        .accessibilityValue(progress.formatted(.percent.precision(.fractionLength(0))))
    }

    private func animate(to value: Double) {
        withAnimation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 1)) { shown = value }
    }
}

private struct BarView: View {
    let fraction: Double
    @State private var shown: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.surfaceMuted)
                Capsule().fill(Theme.accent)
                    .frame(width: max(3, geo.size.width * shown))
            }
        }
        .frame(height: 4)
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 1)) { shown = fraction }
        }
        .onChange(of: fraction) { _, new in withAnimation(Motion.snappy) { shown = new } }
        .accessibilityHidden(true)
    }
}

/// A simple list of items matching an in-memory filter (used for drill-downs).
struct FilteredItemsView: View {
    let title: String
    let filter: (Item) -> Bool
    @Query(sort: \Item.name) private var items: [Item]

    private var matches: [Item] { items.filter(filter) }

    var body: some View {
        List {
            ForEach(matches) { item in
                NavigationLink(destination: ItemDetailView(item: item)) {
                    ItemRowView(item: item)
                }
            }
        }
        .listStyle(.insetGrouped)
        .themedList()
        .overlay {
            if matches.isEmpty {
                ContentUnavailableView("All Set", systemImage: "checkmark.circle",
                                       description: Text("No items here right now."))
            }
        }
        .navigationTitle(title)
    }
}
