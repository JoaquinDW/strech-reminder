import SwiftUI

/// The week's recap with a card that can be shared as an image.
struct WeeklyRecapView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.kipLook) private var look
    let summary: WeeklySummary

    @State private var image: Image?

    var body: some View {
        VStack(spacing: Space.l) {
            HStack {
                Text("Your week").font(.uTitle2).foregroundStyle(Palette.petrol).accessibilityAddTraits(.isHeader)
                Spacer()
                CircleIconButton(systemName: "xmark", label: "Close") { dismiss() }
            }
            .padding(.top, Space.l)

            GeometryReader { geo in
                let scale = min(geo.size.width / WeekShareCard.size.width, geo.size.height / WeekShareCard.size.height)
                WeekShareCard(summary: summary, look: look)
                    .scaleEffect(scale)
                    .frame(width: geo.size.width, height: geo.size.height)
            }

            if let image {
                ShareLink(item: image,
                          message: Text("This week I moved \(summary.minutes) minutes with \(Brand.mascotName) in \(Brand.appName)."),
                          preview: SharePreview(Text("My week with \(Brand.mascotName)"), image: image)) {
                    Label("Share my week", systemImage: "square.and.arrow.up")
                        .font(.system(.title3, design: .rounded, weight: .heavy))
                }
                .buttonStyle(.chunky)
                .simultaneousGesture(TapGesture().onEnded {
                    Analytics.capture("weekly_recap_share_tapped", properties: ["minutes": summary.minutes, "breaks": summary.breaks])
                })
            } else {
                ProgressView().frame(minHeight: 60)
            }
        }
        .padding(.horizontal, Space.page)
        .padding(.bottom, Space.l)
        .background(Palette.ivory.ignoresSafeArea())
        .task {
            image = WeekShareCard.render(summary: summary, look: look)
            Analytics.capture("weekly_recap_viewed", properties: ["minutes": summary.minutes, "breaks": summary.breaks,
                                                                  "is_current_week": summary.isCurrent])
        }
    }
}

/// A fixed-size 4:5 card, laid out the same on screen and in the shared image.
struct WeekShareCard: View {
    static let size = CGSize(width: 360, height: 450)

    let summary: WeeklySummary
    let look: KipLook

    @MainActor
    static func render(summary: WeeklySummary, look: KipLook) -> Image? {
        let renderer = ImageRenderer(content: WeekShareCard(summary: summary, look: look))
        renderer.scale = 3
        guard let ui = renderer.uiImage else { return nil }
        return Image(uiImage: ui)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(Brand.appName)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(Palette.coralDeep)
                Spacer()
                Text(summary.rangeText)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.petrolSoft)
            }

            ZStack(alignment: .topLeading) {
                kip
                    .frame(width: 190, height: 170)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                VStack(alignment: .leading, spacing: 0) {
                    Text(summary.title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.petrolSoft)
                    Text("\(summary.minutes)")
                        .font(.system(size: 84, weight: .heavy, design: .rounded))
                        .foregroundStyle(Palette.petrol)
                        .monospacedDigit()
                        .padding(.top, -6)
                    Text(summary.minutes == 1 ? String(localized: "minute moved") : String(localized: "minutes moved"))
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(Palette.petrol)
                        .padding(.top, -10)
                }
                .padding(.top, 18)
            }
            .frame(height: 176)

            bars.padding(.top, 10)

            HStack(spacing: 8) {
                stat("\(summary.breaks)", summary.breaks == 1 ? String(localized: "break") : String(localized: "breaks"))
                stat("\(summary.activeDays)", summary.activeDays == 1 ? String(localized: "active day") : String(localized: "active days"))
                stat(summary.topArea?.title ?? "–", String(localized: "top focus"))
            }
            .padding(.top, 14)

            Spacer(minLength: 0)

            Text("“\(summary.kipLine)”")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.petrol)
                .fixedSize(horizontal: false, vertical: true)
            Text("— \(Brand.mascotName), desk shrimp")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.petrolSoft)
                .padding(.top, 2)
        }
        .padding(22)
        .frame(width: Self.size.width, height: Self.size.height)
        .background(Palette.butterSoft)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(Palette.petrol, lineWidth: 3))
        .environment(\.dynamicTypeSize, .large)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(summary.title): \(summary.minutes) minutes moved, \(summary.breaks) breaks on \(summary.activeDays) days."))
    }

    /// A still Kip, dressed as in the app. Canvas without a timeline so ImageRenderer captures it.
    private var kip: some View {
        Canvas { ctx, size in
            ctx.fill(Geo.circle(CGPoint(x: size.width * 0.55, y: size.height * 0.52), size.height * 0.44), with: .color(Palette.mintSoft))
            let pose = ShrimpMotion.pose(.celebrating, t: 0, animated: false, growth: look.uncurl)
            var still = look
            still.revealAt = nil
            ShrimpRenderer.draw(pose, in: ctx, rect: CGRect(origin: .zero, size: size), look: still)
        }
    }

    private var bars: some View {
        let peak = max(summary.days.map(\.minutes).max() ?? 0, 1)
        return HStack(alignment: .bottom, spacing: 8) {
            ForEach(summary.days) { day in
                VStack(spacing: 5) {
                    ZStack(alignment: .bottom) {
                        Capsule().fill(Palette.petrolFaint).frame(height: 54)
                        if day.minutes > 0 {
                            Capsule()
                                .fill(Palette.coral)
                                .overlay(Capsule().strokeBorder(Palette.petrol, lineWidth: 2))
                                .frame(height: max(14, 54 * CGFloat(day.minutes) / CGFloat(peak)))
                        }
                    }
                    Text(day.date.formatted(.dateTime.weekday(.narrow)))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(day.isFuture ? Palette.petrolSoft.opacity(0.5) : Palette.petrolSoft)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(Palette.petrol)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.petrolSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.paper))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.petrol, lineWidth: 2))
    }
}
