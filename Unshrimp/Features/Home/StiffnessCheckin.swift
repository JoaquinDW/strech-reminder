import SwiftUI

/// "How much does it bother you?" for one area, 0 (not at all) to 10 (a lot).
struct StiffnessScale: View {
    let area: FocusArea
    @Binding var score: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            HStack {
                Label(area.title, systemImage: area.symbol)
                    .font(.uCallout.weight(.bold))
                    .foregroundStyle(Palette.petrol)
                Spacer()
                Text(score.map { "\($0)/10" } ?? String(localized: "Slide to rate"))
                    .font(.uCaption.weight(.semibold))
                    .foregroundStyle(Palette.petrolSoft)
                    .monospacedDigit()
            }
            Slider(value: Binding(get: { Double(score ?? 0) }, set: { score = Int($0.rounded()) }),
                   in: Double(StiffnessRecord.range.lowerBound)...Double(StiffnessRecord.range.upperBound), step: 1)
                .tint(Palette.coral)
                .opacity(score == nil ? 0.6 : 1)
                .accessibilityLabel(Text("\(area.title) stiffness"))
                .accessibilityValue(Text(score.map { "\($0) of 10" } ?? String(localized: "Not rated")))
            HStack {
                Text("Not at all")
                Spacer()
                Text("A lot")
            }
            .font(.uMicro)
            .foregroundStyle(Palette.petrolSoft)
            .accessibilityHidden(true)
        }
    }
}

/// The weekly check-in on Home: one scale per focus area, save or skip. Shown once a week.
struct StiffnessCheckinCard: View {
    @Environment(AppModel.self) private var model
    let areas: Set<FocusArea>
    @State private var scores: [FocusArea: Int] = [:]

    private var ordered: [FocusArea] { FocusArea.allCases.filter(areas.contains) }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(spacing: Space.s) {
                Image(systemName: "heart.text.square")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Palette.petrol)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Palette.mintSoft))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Weekly check-in").font(.uHeadline).foregroundStyle(Palette.petrol)
                        .accessibilityAddTraits(.isHeader)
                    Text("How stiff do you feel this week? It shows in your weekly recap.")
                        .font(.uCaption).foregroundStyle(Palette.petrolSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            ForEach(ordered) { area in
                StiffnessScale(area: area, score: Binding(get: { scores[area] }, set: { scores[area] = $0 }))
            }
            HStack(spacing: Space.s) {
                Button("Skip this week") {
                    withAnimation(Motion.snappy) { model.skipStiffnessCheckin() }
                }
                .buttonStyle(.chunky(.quiet, compact: true))
                Button("Save") {
                    withAnimation(Motion.snappy) { model.recordStiffness(scores) }
                }
                .buttonStyle(.chunky(.primary, compact: true))
                .disabled(scores.isEmpty)
            }
        }
        .card()
        .transition(.opacity.combined(with: .scale(scale: 0.97)))
    }
}
