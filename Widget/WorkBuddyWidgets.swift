import WidgetKit
import SwiftUI

struct CreditEntry: TimelineEntry { let date: Date; let payload: CreditPayload }
struct CreditProvider: TimelineProvider {
    func placeholder(in context: Context) -> CreditEntry { CreditEntry(date: .now, payload: .empty) }
    func getSnapshot(in context: Context, completion: @escaping (CreditEntry) -> Void) {
        // Real snapshots never fall back to a fabricated credit balance.
        completion(CreditEntry(date: .now, payload: PayloadCache.read() ?? .empty))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<CreditEntry>) -> Void) {
        Task {
            var payload = PayloadCache.read() ?? .empty
            var request = URLRequest(url: URL(string: "http://127.0.0.1:38348/v1/credits")!)
            request.timeoutInterval = 2
            request.cachePolicy = .reloadIgnoringLocalCacheData
            if let (data, response) = try? await URLSession.shared.data(for: request),
               (response as? HTTPURLResponse)?.statusCode == 200,
               let fresh = try? JSONDecoder().decode(CreditPayload.self, from: data) {
                payload = fresh
                try? PayloadCache.save(fresh)
            } else { payload.message = "打开积分监测应用以继续同步" }
            completion(Timeline(entries: [CreditEntry(date: .now, payload: payload)], policy: .after(Date().addingTimeInterval(300))))
        }
    }
}
struct CreditWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CreditEntry
    let paper: Bool
    var body: some View {
        CreditCardContent(payload: entry.payload, paper: paper, compact: family == .systemSmall)
            .containerBackground(for: .widget) { CreditCardBackground(paper: paper) }
            .widgetURL(URL(string: "workbuddycredits://dashboard"))
    }
}
struct DarkCredits: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WorkBuddyCreditsDark", provider: CreditProvider()) { CreditWidgetView(entry: $0, paper: false) }
            .configurationDisplayName("WorkBuddy 积分 · 深色")
            .description("实时积分余额、套餐和已用积分。请保持积分监测应用运行。")
            .supportedFamilies([.systemSmall, .systemMedium]).contentMarginsDisabled()
    }
}
struct PaperCredits: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WorkBuddyCreditsPaper", provider: CreditProvider()) { CreditWidgetView(entry: $0, paper: true) }
            .configurationDisplayName("WorkBuddy 积分 · 浅色")
            .description("纸张风格的 WorkBuddy 积分额度卡片。")
            .supportedFamilies([.systemSmall, .systemMedium]).contentMarginsDisabled()
    }
}
@main struct WorkBuddyCreditWidgets: WidgetBundle {
    var body: some Widget { DarkCredits(); PaperCredits() }
}
