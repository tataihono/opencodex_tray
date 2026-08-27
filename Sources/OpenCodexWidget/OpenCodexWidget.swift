import Darwin
import PauseWorkerCore
import SwiftUI
import WidgetKit

private let widgetKind = "local.opencodex.quota-tray.widget"

private struct SendableCompletion<Value>: @unchecked Sendable {
    let call: (Value) -> Void
}

private struct QuotaWidgetEntry: TimelineEntry {
    let date: Date
    let summary: QuotaSummary?
    let errorMessage: String?

    static let placeholder = QuotaWidgetEntry(
        date: Date(),
        summary: QuotaSummary(
            trayPercentage: 291,
            rows: [
                AccountAllowance(accountId: "personal", label: "personal", remainingPercent: 91, totalPercent: 100, resetAt: Date().addingTimeInterval(6 * 86_400)),
                AccountAllowance(accountId: "tandem", label: "tandem", remainingPercent: 100, totalPercent: 100, resetAt: Date().addingTimeInterval(6 * 86_400)),
                AccountAllowance(accountId: "jesusfilm", label: "jesusfilm", remainingPercent: 100, totalPercent: 100, resetAt: Date().addingTimeInterval(7 * 86_400)),
            ]
        ),
        errorMessage: nil
    )
}

private struct QuotaWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuotaWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (QuotaWidgetEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }
        let completion = SendableCompletion(call: completion)
        Task { completion.call(await loadEntry()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuotaWidgetEntry>) -> Void) {
        let completion = SendableCompletion(call: completion)
        Task {
            let entry = await loadEntry()
            completion.call(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(15 * 60))))
        }
    }

    private func loadEntry() async -> QuotaWidgetEntry {
        do {
            var environment = ProcessInfo.processInfo.environment
            environment["HOME"] = currentUserHomeDirectory()
            environment.removeValue(forKey: "OPENCODEX_HOME")
            environment.removeValue(forKey: "OPENCODEX_BASE_URL")
            let configuration = try WorkerConfiguration.resolve(environment: environment)
            let token = try AdminTokenReader.read(path: configuration.adminTokenPath)
            let client = OpenCodexClient(
                baseURL: configuration.baseURL,
                adminToken: token,
                timeout: configuration.requestTimeout
            )
            let accounts = try await client.fetchAccounts()
            return QuotaWidgetEntry(
                date: Date(),
                summary: QuotaCalculator.summarize(accounts: accounts),
                errorMessage: nil
            )
        } catch {
            return QuotaWidgetEntry(
                date: Date(),
                summary: nil,
                errorMessage: error.localizedDescription
            )
        }
    }

    private func currentUserHomeDirectory() -> String {
        guard let record = getpwuid(getuid()), let home = record.pointee.pw_dir else {
            return FileManager.default.homeDirectoryForCurrentUser.path
        }
        return String(cString: home)
    }
}

private struct QuotaWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    let entry: QuotaWidgetEntry

    var body: some View {
        Group {
            if let summary = entry.summary {
                switch family {
                case .systemMedium, .systemLarge, .systemExtraLarge:
                    mediumContent(summary)
                default:
                    smallContent(summary)
                }
            } else {
                unavailableContent
            }
        }
        .foregroundStyle(primaryColor)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color(red: 0.09, green: 0.10, blue: 0.12), Color(red: 0.13, green: 0.15, blue: 0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func smallContent(_ summary: QuotaSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            Spacer(minLength: 0)
            quotaText(summary)
        }
        .padding(2)
    }

    private func mediumContent(_ summary: QuotaSummary) -> some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                header
                Spacer(minLength: 0)
                quotaText(summary)
            }
            Divider().overlay(secondaryColor.opacity(0.35))
            VStack(spacing: 8) {
                ForEach(summary.rows.prefix(4)) { row in
                    accountRow(row)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(2)
    }

    private var header: some View {
        Label("OpenCodex", systemImage: "circle.hexagongrid.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(secondaryColor)
    }

    private func quotaText(_ summary: QuotaSummary) -> some View {
        let parts = splitResetSuffix(DisplayFormatter.trayTitle(summary, now: entry.date))
        return HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(parts.primary)
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .monospacedDigit()
            if let reset = parts.reset {
                Text(reset)
                    .font(.headline)
                    .monospacedDigit()
                    .foregroundStyle(secondaryColor)
            }
        }
        .minimumScaleFactor(0.7)
    }

    private func accountRow(_ row: AccountAllowance) -> some View {
        let parts = splitResetSuffix(DisplayFormatter.row(row, now: entry.date))
        return HStack(spacing: 4) {
            Text(parts.primary)
                .lineLimit(1)
            Spacer(minLength: 4)
            if let reset = parts.reset {
                Text(reset)
                    .foregroundStyle(secondaryColor)
            }
        }
        .font(.caption.monospacedDigit())
    }

    private var unavailableContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            Spacer()
            Text("OpenCodex unavailable")
                .font(.headline)
            Text("Open the tray app and check that the local OpenCodex service is running.")
                .font(.caption)
                .foregroundStyle(secondaryColor)
                .lineLimit(3)
        }
        .padding(2)
        .accessibilityLabel(entry.errorMessage ?? "OpenCodex unavailable")
    }

    private func splitResetSuffix(_ value: String) -> (primary: String, reset: String?) {
        guard let space = value.lastIndex(of: " ") else { return (value, nil) }
        let suffix = String(value[value.index(after: space)...])
        guard suffix.hasSuffix("d"), Int(suffix.dropLast()) != nil else { return (value, nil) }
        return (String(value[..<space]), suffix)
    }

    private var primaryColor: Color {
        renderingMode == .fullColor ? .white : .primary
    }

    private var secondaryColor: Color {
        renderingMode == .fullColor ? .white.opacity(0.62) : .secondary
    }
}

@main
struct OpenCodexWidgets: WidgetBundle {
    var body: some Widget {
        OpenCodexQuotaWidget()
    }
}

private struct OpenCodexQuotaWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: widgetKind, provider: QuotaWidgetProvider()) { entry in
            QuotaWidgetView(entry: entry)
        }
        .configurationDisplayName("OpenCodex Usage")
        .description("Shows remaining usage across your local OpenCodex accounts.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
