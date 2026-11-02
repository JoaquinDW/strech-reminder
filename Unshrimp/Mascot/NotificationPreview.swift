import SwiftUI

/// Illustrated phone showing what a reminder looks like, with Kip peeking in.
struct NotificationPreview: View {
    var minutes: Int
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(Palette.mintSoft)
                .overlay(RoundedRectangle(cornerRadius: 36, style: .continuous).strokeBorder(Palette.petrol, lineWidth: 3))
                .overlay(alignment: .top) {
                    VStack(spacing: Space.m) {
                        Capsule().fill(Palette.petrol).frame(width: 64, height: 10).padding(.top, 14)
                        Text(Date().formatted(date: .omitted, time: .shortened))
                            .font(.system(size: 34, weight: .heavy, design: .rounded))
                            .foregroundStyle(Palette.petrol.opacity(0.85))
                        banner
                            .padding(.horizontal, Space.m)
                            .offset(y: shown ? 0 : -30)
                            .opacity(shown ? 1 : 0)
                    }
                }
                .padding(.horizontal, 36)
                .padding(.bottom, 40)

            ShrimpView(state: .inviting)
                .frame(width: 130, height: 130)
                .offset(x: 92, y: 18)
                .accessibilityHidden(true)
        }
        .onAppear {
            if reduceMotion { shown = true } else {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.4)) { shown = true }
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text("Example reminder: \(Brand.mascotName) looked up from the laptop. A \(minutes)-minute break is ready when you are."))
    }

    private var banner: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Palette.butterSoft)
                .frame(width: 38, height: 38)
                .overlay(ShrimpView(state: .working).padding(2))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Palette.petrol, lineWidth: 1.5))
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(Brand.appName.uppercased()).font(.uMicro).foregroundStyle(Palette.petrolSoft)
                    Spacer()
                    Text("now").font(.uMicro).foregroundStyle(Palette.petrolSoft)
                }
                Text("\(Brand.mascotName) looked up from the laptop")
                    .font(.uCaption).foregroundStyle(Palette.petrol)
                Text("A \(minutes)-minute break is ready when you are.")
                    .font(.uCaption.weight(.medium)).foregroundStyle(Palette.petrolSoft)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.paper))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Palette.petrol, lineWidth: 2))
    }
}
