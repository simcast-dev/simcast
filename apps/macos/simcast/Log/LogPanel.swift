import SwiftUI

private let logBackground = Color(red: 0.933, green: 0.941, blue: 0.949)
private let logToolbarBackground = Color(red: 0.878, green: 0.890, blue: 0.906)

struct LogPanel: View {
    @Environment(AppLogger.self) private var logger

    @State private var isExpanded = false
    @State private var panelHeight: CGFloat = 160
    @State private var dragStartHeight: CGFloat = 160

    var body: some View {
        VStack(spacing: 0) {
            if isExpanded {
                dragHandle
                logContent
                    .frame(height: panelHeight)
            }
            collapsedBar
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
        HStack {
            Text("Log")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Clear") { logger.clear() }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(logToolbarBackground)
    }

    private var logScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(logger.entries) { entry in
                        LogEntryRow(entry: entry)
                            .id(entry.id)
                    }
                }
                .padding(6)
            }
            .background(logBackground)
            .onChange(of: logger.entries.count) { _, _ in
                guard let last = logger.entries.last else { return }
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
}

private struct LogEntryRow: View {
    let entry: LogEntry

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

            Text(entry.message)
                .foregroundStyle(Color(nsColor: .labelColor))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(size: 11, design: .monospaced))
        .padding(.vertical, 1)
    }
}
