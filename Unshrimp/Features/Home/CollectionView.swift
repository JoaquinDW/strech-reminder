import SwiftUI

/// All desk decor, unlocked and upcoming. Earned items are never taken away.
struct CollectionView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Space.l) {
                    DeskSceneView(state: .resting, unlocked: model.unlocked, ghost: model.nextItem)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.petrol, lineWidth: 2.5))
                    HStack {
                        Label("\(model.data.energy) energy earned", systemImage: "bolt.heart.fill")
                            .font(.uHeadline)
                            .foregroundStyle(Palette.petrol)
                        Spacer()
                    }
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: Space.m), GridItem(.flexible(), spacing: Space.m)], spacing: Space.m) {
                        ForEach(DeskItem.allCases) { item in
                            tile(item)
                        }
                    }
                    Text("Every break adds energy. Energy never runs out or goes away, so take your time.")
                        .font(.uCaption.weight(.medium))
                        .foregroundStyle(Palette.petrolSoft)
                        .multilineTextAlignment(.center)
                }
                .padding(Space.page)
            }
            .background(Palette.ivory.ignoresSafeArea())
            .navigationTitle("\(Brand.mascotName)'s desk")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.font(.uHeadline).tint(Palette.petrol)
                }
            }
        }
    }

    private func tile(_ item: DeskItem) -> some View {
        let owned = model.unlocked.contains(item)
        return VStack(spacing: Space.s) {
            DeskItemIcon(item: item, locked: !owned)
                .frame(height: 70)
            Text(item.title).font(.uHeadline).foregroundStyle(Palette.petrol)
            Text(owned ? String(localized: "On the desk") : String(localized: "\(item.cost) energy"))
                .font(.uCaption)
                .foregroundStyle(owned ? Palette.mintDeep : Palette.petrolSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(Space.m)
        .background(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous).fill(owned ? Palette.mintSoft : Palette.paper))
        .overlay(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous).strokeBorder(owned ? Palette.petrol : Palette.line, lineWidth: owned ? 2 : 1.5))
        .accessibilityElement(children: .combine)
    }
}
