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
                    wardrobe
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

    // MARK: Wardrobe

    private var wardrobe: some View {
        let growth = model.growth
        return VStack(alignment: .leading, spacing: Space.m) {
            HStack(alignment: .firstTextBaseline) {
                Text("Wardrobe").font(.uTitle2).foregroundStyle(Palette.petrol).accessibilityAddTraits(.isHeader)
                Spacer()
                Text(growth.title).font(.uCaption).foregroundStyle(Palette.coralDeep)
            }
            Text(growth.nextHint.map { String(localized: "Every break uncurls \(Brand.mascotName) a little. \($0).") }
                 ?? String(localized: "\(Brand.mascotName) is fully uncurled. Tap to change outfits."))
                .font(.uCaption.weight(.medium))
                .foregroundStyle(Palette.petrolSoft)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Space.s), count: 3), spacing: Space.s) {
                wearTile(nil)
                ForEach(Wearable.allCases) { wearTile($0) }
            }
        }
    }

    private func wearTile(_ wearable: Wearable?) -> some View {
        let owned = wearable.map { model.ownedWearables.contains($0) } ?? true
        let worn = model.data.outfit == wearable
        let stage = wearable.map(KipGrowth.stageWearable) ?? 0
        return Button {
            withAnimation(Motion.snappy) { model.wear(wearable) }
        } label: {
            VStack(spacing: 4) {
                ShrimpView(state: .inviting)
                    .environment(\.kipLook, KipLook(uncurl: model.look.uncurl, wearable: wearable))
                    .frame(height: 64)
                    .grayscale(owned ? 0 : 1)
                    .opacity(owned ? 1 : 0.3)
                    .overlay {
                        if !owned { Image(systemName: "lock.fill").font(.uHeadline).foregroundStyle(Palette.petrolSoft) }
                    }
                    .allowsHitTesting(false)
                Text(wearable?.title ?? String(localized: "Just \(Brand.mascotName)"))
                    .font(.uCaption).foregroundStyle(Palette.petrol)
                    .lineLimit(2).multilineTextAlignment(.center).minimumScaleFactor(0.8)
                Text(owned ? (worn ? String(localized: "Wearing") : String(localized: "Tap to wear"))
                           : wearable?.streakMilestone.map { String(localized: "\($0)-day streak") }
                             ?? String(localized: "At \(KipGrowth.title(stage).lowercased())"))
                    .font(.uMicro)
                    .foregroundStyle(worn ? Palette.mintDeep : Palette.petrolSoft)
                    .lineLimit(2).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 128)
            .padding(Space.s)
            .background(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous).fill(worn ? Palette.mintSoft : Palette.paper))
            .overlay(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous).strokeBorder(worn ? Palette.petrol : Palette.line, lineWidth: worn ? 2 : 1.5))
        }
        .buttonStyle(PressableStyle())
        .disabled(!owned)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(worn ? .isSelected : [])
    }

    // MARK: Desk

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
