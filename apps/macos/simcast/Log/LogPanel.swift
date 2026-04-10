import SwiftUI

private let logBackground = Color(red: 0.933, green: 0.941, blue: 0.949)
private let logToolbarBackground = Color(red: 0.878, green: 0.890, blue: 0.906)

struct LogPanel: View {
    @Environment(AppLogger.self) private var logger
    @Environment(SimulatorService.self) private var simulatorService

    @State private var isExpanded = false
    @State private var panelHeight: CGFloat = 160
    @State private var dragStartHeight: CGFloat = 160
    @State private var selectedCategory: LogCategory?
    @State private var selectedSimulator: String = "all"

    private struct SimulatorOption: Identifiable {
        let udid: String
        let name: String

        var id: String { udid }
    }

    private var filteredEntries: [LogEntry] {
        logger.entries.filter { entry in
            let matchesCategory = selectedCategory == nil || entry.category == selectedCategory
            let matchesSimulator = selectedSimulator == "all" || entry.udid == selectedSimulator
            return matchesCategory && matchesSimulator
        }
    }

    private var simulatorOptions: [SimulatorOption] {
        let knownSimulators = simulatorService.simulators.compactMap { simulator -> SimulatorOption? in
            guard let udid = simulator.udid else { return nil }
            return SimulatorOption(udid: udid, name: simulator.title)
        }

        let loggedUdids = Set(logger.entries.compactMap(\.udid))
        let knownUdids = Set(knownSimulators.map(\.udid))

        let recoveredFromLogs = loggedUdids
            .subtracting(knownUdids)
            .sorted()
            .map { SimulatorOption(udid: $0, name: $0.shortId()) }

        return (knownSimulators + recoveredFromLogs)
            .sorted { lhs, rhs in
                if lhs.name != rhs.name { return lhs.name < rhs.name }
                return lhs.udid < rhs.udid
            }
    }

    private var selectedSimulatorLabel: String {
        guard selectedSimulator != "all" else { return "All Simulators" }
        guard let option = simulatorOptions.first(where: { $0.udid == selectedSimulator }) else {
            return selectedSimulator.shortId()
        }
        return option.name
    }

    var body: some View {
        VStack(spacing: 0) {
            if isExpanded {
                dragHandle
                logContent
                    .frame(height: panelHeight)
            }
            collapsedBar
        }
        .onChange(of: simulatorOptions.map(\.udid)) { _, udids in
            guard selectedSimulator != "all", !udids.contains(selectedSimulator) else { return }
            selectedSimulator = "all"
        }
    }

    // MARK: - Subviews

    private var dragHandle: some View {
        logToolbarBackground
            .frame(height: 8)
            .overlay(
                Capsule()
                    .fill(Color(nsColor: .tertiaryLabelColor))
                    .frame(width: 30, height: 3)
            )
            .onHover { inside in
                if inside { NSCursor.resizeUpDown.push() } else { NSCursor.pop() }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        panelHeight = max(80, min(400, dragStartHeight - value.translation.height))
                    }
                    .onEnded { _ in
                        dragStartHeight = panelHeight
                    }
            )
    }

    private var logContent: some View {
        VStack(spacing: 0) {
            logToolbar
            Divider()
            logScrollView
        }
    }

    private var logToolbar: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Log Console")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Spacer()

                Menu {
                    Button("All Simulators") { selectedSimulator = "all" }
                    if !simulatorOptions.isEmpty {
                        Divider()
                        ForEach(simulatorOptions) { option in
                            Button("\(option.name) (\(option.udid.shortId()))") {
                                selectedSimulator = option.udid
                            }
                        }
                    }
                } label: {
                    Label(
                        selectedSimulatorLabel,
                        systemImage: "iphone"
                    )
                    .font(.caption)
                }
                .menuStyle(.borderlessButton)

                Button("Clear") { logger.clear() }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                categoryChip(title: "All", category: nil)
                ForEach(LogCategory.allCases, id: \.rawValue) { category in
                    categoryChip(title: category.label.trimmingCharacters(in: .whitespaces), category: category)
                }
                Spacer()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(logToolbarBackground)
    }

    private var logScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(filteredEntries) { entry in
                        LogEntryRow(
                            entry: entry,
                            simulatorName: entry.udid.flatMap { udid in
                                simulatorOptions.first(where: { $0.udid == udid })?.name
                            }
                        )
                            .id(entry.id)
                    }
                }
                .padding(6)
            }
            .background(logBackground)
            .onChange(of: filteredEntries.count) { _, _ in
                guard let last = filteredEntries.last else { return }
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    private var collapsedBar: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text("Log")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                if !isExpanded, let last = logger.lastEntry {
                    Text(last.message)
                        .font(.caption)
                        .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                        .lineLimit(1)
                }

                Spacer()

                if logger.errorCount > 0 {
                    Text("\(logger.errorCount) error\(logger.errorCount == 1 ? "" : "s")")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(LogCategory.error.color)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(logToolbarBackground)
        .overlay(alignment: .top) { Divider() }
    }

    private func categoryChip(title: String, category: LogCategory?) -> some View {
        let isSelected = selectedCategory == category

        return Button {
            selectedCategory = category
        } label: {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isSelected ? .white : Color(nsColor: .secondaryLabelColor))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(isSelected ? (category?.color ?? Color.accentColor) : Color.white.opacity(0.7))
                )
        }
        .buttonStyle(.plain)
    }
}

private struct LogEntryRow: View {
    let entry: LogEntry
    let simulatorName: String?

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(Self.timeFormatter.string(from: entry.timestamp))
                .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                .frame(width: 60, alignment: .leading)

            Text("\(entry.category.symbol) \(entry.category.label) ")
                .foregroundStyle(entry.category.color)
                .fontWeight(.medium)

            VStack(alignment: .leading, spacing: 2) {
                if let udid = entry.udid {
                    HStack(spacing: 6) {
                        if let simulatorName {
                            Text(simulatorName)
                                .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                        }
                        Text(udid.shortId())
                            .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                    }
                }

                Text(entry.message)
                    .foregroundStyle(Color(nsColor: .labelColor))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .font(.system(size: 11, design: .monospaced))
        .padding(.vertical, 1)
    }
}
