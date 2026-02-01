import SwiftUI
import TwilightEngine

struct CardView: View {
    let card: Card
    var isSelected: Bool = false
    var onTap: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Card header with name and type
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack {
                    Text(card.name)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Spacer()
                    if let cost = card.cost {
                        Text("\(cost)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.faith)
                            .padding(Spacing.xs)
                            .background(Circle().fill(AppColors.backgroundSystem.opacity(Opacity.mediumHigh)))
                    }
                }

                Text(localizedCardType)
                    .font(.caption)
                    .foregroundColor(.white.opacity(Opacity.high))
            }
            .padding(Spacing.md)
            .background(headerColor)

            // Card image area
            ZStack {
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [cardColor.opacity(Opacity.light), cardColor]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                VStack {
                    Image(systemName: cardIcon)
                        .font(.system(size: Sizes.iconRegion))
                        .foregroundColor(.white.opacity(Opacity.almostOpaque))
                }
            }
            .frame(height: Sizes.cardHeightSmall + Spacing.xl)

            // Stats section
            if hasStats {
                HStack(spacing: Spacing.lg) {
                    if let power = card.power {
                        CardStatBadge(icon: "bolt.fill", value: power, color: AppColors.power)
                    }
                    if let defense = card.defense {
                        CardStatBadge(icon: "shield.fill", value: defense, color: AppColors.defense)
                    }
                    if let health = card.health {
                        CardStatBadge(icon: "heart.fill", value: health, color: AppColors.health)
                    }
                    Spacer()
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(AppColors.backgroundSystem.opacity(Opacity.faint))
            }

            // Description
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text(card.description)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    // Abilities
                    ForEach(card.abilities) { ability in
                        VStack(alignment: .leading, spacing: Spacing.xxxs) {
                            Text(ability.name)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.power)
                            Text(ability.description)
                                .font(.caption2)
                                .foregroundColor(AppColors.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.top, Spacing.xxs)
                    }

                    // Traits
                    if !card.traits.isEmpty {
                        HStack {
                            ForEach(card.traits, id: \.self) { trait in
                                Text(trait.localized)
                                    .font(.caption2)
                                    .padding(.horizontal, Spacing.xs)
                                    .padding(.vertical, Spacing.xxxs)
                                    .background(Capsule().fill(AppColors.secondary.opacity(Opacity.light)))
                            }
                        }
                        .padding(.top, Spacing.xxs)
                    }
                }
                .padding(Spacing.md)
            }

            // Rarity indicator
            HStack {
                Spacer()
                Circle()
                    .fill(rarityColor)
                    .frame(width: Spacing.sm, height: Spacing.sm)
                Text(localizedRarity)
                    .font(.caption2)
                    .foregroundColor(AppColors.muted)
            }
            .padding(Spacing.sm)
        }
        .frame(height: Sizes.cardHeightLarge + Sizes.cardHeightMedium)
        .background(AppColors.cardBackground)
        .cornerRadius(CornerRadius.lg)
        .shadow(isSelected ? AppShadows.lg : AppShadows.md)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .stroke(isSelected ? AppColors.primary : .clear, lineWidth: 3)
        )
        .onTapGesture {
            onTap?()
        }
    }

    var hasStats: Bool {
        card.power != nil || card.defense != nil || card.health != nil
    }

    var localizedCardType: String {
        switch card.type {
        case .character: return L10n.cardTypeCharacter.localized
        case .weapon: return L10n.cardTypeWeapon.localized
        case .spell: return L10n.cardTypeSpell.localized
        case .armor: return L10n.cardTypeArmor.localized
        case .item: return L10n.cardTypeItem.localized
        case .ally: return L10n.cardTypeAlly.localized
        case .blessing: return L10n.cardTypeBlessing.localized
        case .monster: return L10n.cardTypeMonster.localized
        case .location: return L10n.cardTypeLocation.localized
        case .scenario: return card.type.rawValue.capitalized
        case .curse: return L10n.tmCardTypeCurse.localized
        case .spirit: return L10n.tmCardTypeSpirit.localized
        case .artifact: return L10n.tmCardTypeArtifact.localized
        case .ritual: return L10n.tmCardTypeRitual.localized
        case .resource: return L10n.cardTypeResource.localized
        case .attack: return L10n.cardTypeAttack.localized
        case .defense: return L10n.cardTypeDefense.localized
        case .special: return L10n.cardTypeSpecial.localized
        }
    }

    var localizedRarity: String {
        switch card.rarity {
        case .common: return L10n.rarityCommon.localized
        case .uncommon: return L10n.rarityUncommon.localized
        case .rare: return L10n.rarityRare.localized
        case .epic: return L10n.rarityEpic.localized
        case .legendary: return L10n.rarityLegendary.localized
        }
    }

    var headerColor: Color {
        switch card.type {
        case .character: return AppColors.dark
        case .weapon: return AppColors.danger
        case .spell: return AppColors.primary
        case .armor: return AppColors.secondary
        case .item: return AppColors.cardTypeItem
        case .ally: return AppColors.success
        case .blessing: return AppColors.light
        case .monster: return AppColors.danger.opacity(Opacity.high)
        case .location: return AppColors.cardTypeLocation
        case .scenario: return AppColors.cardTypeScenario
        case .curse: return AppColors.cardTypeCurse
        case .spirit: return AppColors.cardTypeSpirit
        case .artifact: return AppColors.power
        case .ritual: return AppColors.cardTypeRitual
        case .resource: return AppColors.success
        case .attack: return AppColors.danger
        case .defense: return AppColors.defense
        case .special: return AppColors.dark
        }
    }

    var cardColor: Color {
        headerColor.opacity(Opacity.mediumHigh)
    }

    var cardIcon: String {
        switch card.type {
        case .character: return "person.fill"
        case .weapon: return "bolt.fill"
        case .spell: return "sparkles"
        case .armor: return "shield.fill"
        case .item: return "bag.fill"
        case .ally: return "person.2.fill"
        case .blessing: return "star.fill"
        case .monster: return "flame.fill"
        case .location: return "mappin.and.ellipse"
        case .scenario: return "book.fill"
        case .curse: return "cloud.bolt.fill"
        case .spirit: return "cloud.moon.fill"
        case .artifact: return "crown.fill"
        case .ritual: return "book.closed.fill"
        case .resource: return "leaf.fill"
        case .attack: return "bolt.fill"
        case .defense: return "shield.fill"
        case .special: return "star.circle.fill"
        }
    }

    var rarityColor: Color {
        switch card.rarity {
        case .common: return AppColors.rarityCommon
        case .uncommon: return AppColors.rarityUncommon
        case .rare: return AppColors.rarityRare
        case .epic: return AppColors.rarityEpic
        case .legendary: return AppColors.rarityLegendary
        }
    }
}

struct CardStatBadge: View {
    let icon: String
    let value: Int
    let color: Color

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: icon)
                .font(.caption)
            Text("\(value)")
                .font(.caption)
                .fontWeight(.bold)
        }
        .foregroundColor(color)
    }
}

// Compact card view for character selection
struct CompactCardView: View {
    let card: Card
    var isSelected: Bool = false
    var onTap: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Card header
            Text(card.name)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(headerColor)

            // Card image area
            ZStack {
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [headerColor.opacity(Opacity.light), headerColor.opacity(Opacity.mediumHigh)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                Image(systemName: cardIcon)
                    .font(.system(size: Sizes.iconRegion + Spacing.smd))
                    .foregroundColor(.white.opacity(Opacity.almostOpaque))
            }
            .frame(height: Sizes.cardHeightMedium)

            // Stats
            VStack(spacing: Spacing.sm) {
                Text(localizedCardType)
                    .font(.caption)
                    .foregroundColor(AppColors.muted)

                HStack(spacing: Spacing.xl) {
                    if let health = card.health {
                        VStack(spacing: Spacing.xxxs) {
                            Image(systemName: "heart.fill")
                                .font(.title3)
                                .foregroundColor(AppColors.health)
                            Text("\(health)")
                                .font(.headline)
                                .fontWeight(.bold)
                            Text(L10n.cardStatHealth.localized)
                                .font(.system(size: Sizes.tinyCaption))
                                .foregroundColor(AppColors.muted)
                        }
                    }
                    if let power = card.power {
                        VStack(spacing: Spacing.xxxs) {
                            Image(systemName: "bolt.fill")
                                .font(.title3)
                                .foregroundColor(AppColors.power)
                            Text("\(power)")
                                .font(.headline)
                                .fontWeight(.bold)
                            Text(L10n.cardStatStrength.localized)
                                .font(.system(size: Sizes.tinyCaption))
                                .foregroundColor(AppColors.muted)
                        }
                    }
                    if let defense = card.defense {
                        VStack(spacing: Spacing.xxxs) {
                            Image(systemName: "shield.fill")
                                .font(.title3)
                                .foregroundColor(AppColors.defense)
                            Text("\(defense)")
                                .font(.headline)
                                .fontWeight(.bold)
                            Text(L10n.cardStatDefense.localized)
                                .font(.system(size: Sizes.tinyCaption))
                                .foregroundColor(AppColors.muted)
                        }
                    }
                }

                Circle()
                    .fill(rarityColor)
                    .frame(width: Spacing.xs, height: Spacing.xs)
            }
            .padding(.vertical, Spacing.smd)
            .frame(maxWidth: .infinity)
            .background(AppColors.cardBackground)
        }
        .frame(height: Sizes.cardHeightMedium + Sizes.cardHeightMedium)
        .background(AppColors.backgroundSystem)
        .cornerRadius(CornerRadius.xl)
        .shadow(isSelected ? AppShadows.lg : AppShadows.md)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.xl)
                .stroke(isSelected ? headerColor : Color.clear, lineWidth: 3)
        )
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: AnimationDuration.slow, dampingFraction: 0.7), value: isSelected)
        .onTapGesture {
            onTap?()
        }
    }

    var headerColor: Color {
        switch card.type {
        case .character: return AppColors.dark
        case .weapon: return AppColors.danger
        case .spell: return AppColors.primary
        case .armor: return AppColors.secondary
        case .item: return AppColors.cardTypeItem
        case .ally: return AppColors.success
        case .blessing: return AppColors.light
        case .monster: return AppColors.danger.opacity(Opacity.high)
        case .location: return AppColors.cardTypeLocation
        case .scenario: return AppColors.cardTypeScenario
        case .curse: return AppColors.cardTypeCurse
        case .spirit: return AppColors.cardTypeSpirit
        case .artifact: return AppColors.power
        case .ritual: return AppColors.cardTypeRitual
        case .resource: return AppColors.success
        case .attack: return AppColors.danger
        case .defense: return AppColors.defense
        case .special: return AppColors.dark
        }
    }

    var cardIcon: String {
        switch card.type {
        case .character: return "person.fill"
        case .weapon: return "bolt.fill"
        case .spell: return "sparkles"
        case .armor: return "shield.fill"
        case .item: return "bag.fill"
        case .ally: return "person.2.fill"
        case .blessing: return "star.fill"
        case .monster: return "flame.fill"
        case .location: return "mappin.and.ellipse"
        case .scenario: return "book.fill"
        case .curse: return "cloud.bolt.fill"
        case .spirit: return "cloud.moon.fill"
        case .artifact: return "crown.fill"
        case .ritual: return "book.closed.fill"
        case .resource: return "leaf.fill"
        case .attack: return "bolt.fill"
        case .defense: return "shield.fill"
        case .special: return "star.circle.fill"
        }
    }

    var localizedCardType: String {
        switch card.type {
        case .character: return L10n.cardTypeCharacter.localized
        case .weapon: return L10n.cardTypeWeapon.localized
        case .spell: return L10n.cardTypeSpell.localized
        case .armor: return L10n.cardTypeArmor.localized
        case .item: return L10n.cardTypeItem.localized
        case .ally: return L10n.cardTypeAlly.localized
        case .blessing: return L10n.cardTypeBlessing.localized
        case .monster: return L10n.cardTypeMonster.localized
        case .location: return L10n.cardTypeLocation.localized
        case .scenario: return card.type.rawValue.capitalized
        case .curse: return L10n.tmCardTypeCurse.localized
        case .spirit: return L10n.tmCardTypeSpirit.localized
        case .artifact: return L10n.tmCardTypeArtifact.localized
        case .ritual: return L10n.tmCardTypeRitual.localized
        case .resource: return L10n.cardTypeResource.localized
        case .attack: return L10n.cardTypeAttack.localized
        case .defense: return L10n.cardTypeDefense.localized
        case .special: return L10n.cardTypeSpecial.localized
        }
    }

    var rarityColor: Color {
        switch card.rarity {
        case .common: return AppColors.rarityCommon
        case .uncommon: return AppColors.rarityUncommon
        case .rare: return AppColors.rarityRare
        case .epic: return AppColors.rarityEpic
        case .legendary: return AppColors.rarityLegendary
        }
    }
}

// Very compact card view for player hand
struct HandCardView: View {
    let card: Card
    var isSelected: Bool = false
    var onTap: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Card name
            Text(card.name)
                .font(.system(size: Sizes.smallText))
                .fontWeight(.bold)
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xxxs)
                .padding(.horizontal, Spacing.xxxs)
                .background(headerColor)

            // Card icon
            ZStack {
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [headerColor.opacity(Opacity.light), headerColor.opacity(Opacity.mediumHigh)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                Image(systemName: cardIcon)
                    .font(.system(size: Sizes.iconLarge))
                    .foregroundColor(.white.opacity(Opacity.almostOpaque))
            }
            .frame(height: Sizes.iconHero + 5)

            // Stats in vertical column
            VStack(spacing: Spacing.xxxs) {
                if let cost = card.cost {
                    HStack(spacing: Spacing.xxxs) {
                        Image(systemName: "star.fill")
                            .font(.system(size: Sizes.microText))
                            .foregroundColor(AppColors.faith)
                        Text("\(cost)")
                            .font(.system(size: Sizes.tinyCaption))
                            .fontWeight(.bold)
                    }
                }
                if let power = card.power {
                    HStack(spacing: Spacing.xxxs) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: Sizes.microText))
                            .foregroundColor(AppColors.health)
                        Text("\(power)")
                            .font(.system(size: Sizes.tinyCaption))
                            .fontWeight(.bold)
                    }
                }
                if let defense = card.defense {
                    HStack(spacing: Spacing.xxxs) {
                        Image(systemName: "shield.fill")
                            .font(.system(size: Sizes.microText))
                            .foregroundColor(AppColors.defense)
                        Text("\(defense)")
                            .font(.system(size: Sizes.tinyCaption))
                            .fontWeight(.bold)
                    }
                }
            }
            .padding(.vertical, Spacing.xxxs)
            .frame(maxWidth: .infinity)
            .background(AppColors.cardBackground)
        }
        .frame(width: Sizes.cardWidthSmall + 5, height: Sizes.cardHeightSmall + Spacing.lg - 1)
        .background(AppColors.backgroundSystem)
        .cornerRadius(CornerRadius.md)
        .shadow(isSelected ? AppShadows.md : AppShadows.sm)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .stroke(isSelected ? headerColor : Color.clear, lineWidth: 2)
        )
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.spring(response: AnimationDuration.fast + 0.05, dampingFraction: 0.7), value: isSelected)
        .onTapGesture {
            onTap?()
        }
    }

    var headerColor: Color {
        switch card.type {
        case .character: return AppColors.dark
        case .weapon: return AppColors.danger
        case .spell: return AppColors.primary
        case .armor: return AppColors.secondary
        case .item: return AppColors.cardTypeItem
        case .ally: return AppColors.success
        case .blessing: return AppColors.light
        case .monster: return AppColors.danger.opacity(Opacity.high)
        case .location: return AppColors.cardTypeLocation
        case .scenario: return AppColors.cardTypeScenario
        case .curse: return AppColors.cardTypeCurse
        case .spirit: return AppColors.cardTypeSpirit
        case .artifact: return AppColors.power
        case .ritual: return AppColors.cardTypeRitual
        case .resource: return AppColors.success
        case .attack: return AppColors.danger
        case .defense: return AppColors.defense
        case .special: return AppColors.dark
        }
    }

    var cardIcon: String {
        switch card.type {
        case .character: return "person.fill"
        case .weapon: return "bolt.fill"
        case .spell: return "sparkles"
        case .armor: return "shield.fill"
        case .item: return "bag.fill"
        case .ally: return "person.2.fill"
        case .blessing: return "star.fill"
        case .monster: return "flame.fill"
        case .location: return "mappin.and.ellipse"
        case .scenario: return "book.fill"
        case .curse: return "cloud.bolt.fill"
        case .spirit: return "cloud.moon.fill"
        case .artifact: return "crown.fill"
        case .ritual: return "book.closed.fill"
        case .resource: return "leaf.fill"
        case .attack: return "bolt.fill"
        case .defense: return "shield.fill"
        case .special: return "star.circle.fill"
        }
    }
}
