import SwiftUI

struct CreditCard: View {
    let payload: CreditPayload
    var paper = false
    var compact = false
    var body: some View {
        CreditCardContent(payload: payload, paper: paper, compact: compact)
            .background { CreditCardBackground(paper: paper) }
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke((paper ? Color.black : Color.white).opacity(0.10), lineWidth: 0.7))
    }
}

/// WidgetKit must be able to remove the background independently of the content
/// when macOS switches desktop widgets to vibrant/monochrome rendering.
struct CreditCardBackground: View {
    var paper: Bool
    var body: some View {
        if paper {
            LinearGradient(colors: [Color(red: 0.96, green: 0.94, blue: 0.87), Color(red: 0.90, green: 0.86, blue: 0.76)], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else {
            LinearGradient(colors: [Color(red: 0.22, green: 0.24, blue: 0.23), Color(red: 0.12, green: 0.14, blue: 0.14)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

struct CreditCardContent: View {
    let payload: CreditPayload
    var paper = false
    var compact = false
    private var snapshot: CreditSnapshot? { payload.snapshot }
    private var ink: Color { paper ? Color(red: 0.16, green: 0.17, blue: 0.14) : .white }
    private var muted: Color { ink.opacity(0.57) }
    private var accent: Color { paper ? ink : Color(red: 0.43, green: 0.91, blue: 0.70) }
    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : paper ? 5 : 10) {
            HStack(spacing: 7) {
                Image(systemName: "sparkle").font(.system(size: 15, weight: .bold)).foregroundStyle(accent)
                Text(paper ? "WorkBuddy 积分" : "WorkBuddy").font(.system(size: 13, weight: .semibold, design: paper ? .serif : .default))
                Spacer(minLength: 2)
                Circle().fill(payload.message != nil || snapshot?.isStale != false ? Color.orange : Color.green).frame(width: 6, height: 6)
            }
            if paper { Rectangle().fill(ink.opacity(0.2)).frame(height: 0.5) }
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(paper ? snapshot.map { $0.unlimited ? "∞" : "\(Int(($0.fraction * 100).rounded()))%" } ?? "—" : CreditFormat.remaining(snapshot))
                        .font(.system(size: compact ? 35 : paper ? 49 : 42, weight: paper ? .regular : .bold, design: paper ? .serif : .rounded))
                        .foregroundStyle(accent).lineLimit(1).minimumScaleFactor(0.45)
                    Text(paper && snapshot != nil ? "\(CreditFormat.remaining(snapshot)) 积分剩余" : "剩余积分").font(.system(size: 11)).foregroundStyle(muted).lineLimit(1).minimumScaleFactor(0.7)
                }.frame(maxWidth: .infinity, alignment: .leading)
                if !compact {
                    VStack(alignment: .leading, spacing: 8) {
                        stat("套餐", snapshot?.plan ?? "未连接")
                        stat("已用", snapshot.map { CreditFormat.number($0.used) } ?? "—")
                        stat("总量", snapshot.map { $0.unlimited ? "不限量" : CreditFormat.number($0.total) } ?? "—")
                    }.frame(width: 115)
                }
            }
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(snapshot == nil ? "等待连接" : "可用比例")
                    Spacer()
                    Text(snapshot.map { $0.unlimited ? "不限量" : "\(Int(($0.fraction * 100).rounded()))%" } ?? "—")
                }.font(.system(size: 10)).foregroundStyle(muted)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(ink.opacity(0.12))
                        Capsule().fill(accent).frame(width: geo.size.width * (snapshot?.fraction ?? 0))
                    }
                }.frame(height: paper ? 7 : 5)
                Text(status).font(.system(size: 9)).foregroundStyle(muted).lineLimit(1)
            }
        }
        .padding(compact || paper ? 14 : 16)
        .foregroundStyle(ink)
    }
    private var status: String {
        if let message = payload.message { return message }
        guard let snapshot else { return "打开应用，登录后自动同步" }
        return "\(snapshot.isStale ? "数据待更新 · " : "已同步 · ")\(snapshot.updatedAt.formatted(date: .omitted, time: .shortened))"
    }
    private func stat(_ label: String, _ value: String) -> some View {
        HStack { Text(label).foregroundStyle(muted); Spacer(minLength: 4); Text(value).lineLimit(1).minimumScaleFactor(0.65) }
            .font(.system(size: 11, weight: .medium))
    }
}
