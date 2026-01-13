import SwiftUI

struct CardView: View {
    let card: Card
    var isSelected: Bool = false
    var onTap: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Card header with name and type
            VStack(alignment: .leading, spacing: 4) {
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
                            .foregroundColor(.yellow)
                            .padding(6)
                            .background(Circle().fill(Color.black.opacity(0.6)))
                    }
                }

                Text(localizedCardType)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(12)
            .background(headerColor)

            // Card image area
            ZStack {
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [cardColor.opacity(0.3), cardColor]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                VStack {
                    Image(systemName: cardIcon)
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            .frame(height: 120)

            // Stats section
            if hasStats {
                HStack(spacing: 16) {
                    if let power = card.power {
                        StatBadge(icon: "sword.fill", value: power, color: .red)
                    }
                    if let defense = card.defense {
                        StatBadge(icon: "shield.fill", value: defense, color: .blue)
                    }
                    if let health = card.health {
                        StatBadge(icon: "heart.fill", value: health, color: .green)
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.2))
            }

            // Description
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text(card.description)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    // Abilities
                    ForEach(card.abilities) { ability in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ability.name)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                            Text(ability.description)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.top, 4)
                    }

                    // Traits
                    if !card.traits.isEmpty {
                        HStack {
                            ForEach(card.traits, id: \.self) { trait in
                                Text(trait.localized)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.gray.opacity(0.3)))
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(12)
            }

            // Rarity indicator
            HStack {
                Spacer()
                Circle()
                    .fill(rarityColor)
                    .frame(width: 8, height: 8)
                Text(localizedRarity)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(8)
        }
        .frame(height: 320)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: isSelected ? .blue.opacity(0.5) : .black.opacity(0.2), radius: isSelected ? 8 : 4)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
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
        case .character: return Color.purple
        case .weapon: return Color.red
        case .spell: return Color.blue
        case .armor: return Color.gray
        case .item: return Color.brown
        case .ally: return Color.green
        case .blessing: return Color.yellow
        case .monster: return Color.red.opacity(0.8)
        case .location: return Color.teal
        case .scenario: return Color.indigo
        case .curse: return Color.black
        case .spirit: return Color.cyan
        case .artifact: return Color.orange
        case .ritual: return Color.indigo
        }
    }

    var cardColor: Color {
        headerColor.opacity(0.6)
    }

    var cardIcon: String {
        switch card.type {
        case .character: return "person.fill"
        case .weapon: return "sword.fill"
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
        }
    }

    var rarityColor: Color {
        switch card.rarity {
        case .common: return .gray
        case .uncommon: return .green
        case .rare: return .blue
        case .epic: return .purple
        case .legendary: return .orange
        }
    }
}

struct StatBadge: View {
    let icon: String
    let value: Int
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
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
                .padding(.vertical, 12)
                .background(headerColor)

            // Card image area
            ZStack {
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [headerColor.opacity(0.3), headerColor.opacity(0.6)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                Image(systemName: cardIcon)
                    .font(.system(size: 70))
                    .foregroundColor(.white.opacity(0.9))
            }
            .frame(height: 140)

            // Stats
            VStack(spacing: 12) {
                Text(localizedCardType)
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 16) {
                    if let health = card.health {
                        VStack(spacing: 2) {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                            Text("\(health)")
                                .font(.headline)
                                .fontWeight(.bold)
                        }
                    }
                    if let power = card.power {
                        VStack(spacing: 2) {
                            Image(systemName: "sword.fill")
                                .foregroundColor(.orange)
                            Text("\(power)")
                                .font(.headline)
                                .fontWeight(.bold)
                        }
                    }
                    if let defense = card.defense {
                        VStack(spacing: 2) {
                            Image(systemName: "shield.fill")
                                .foregroundColor(.blue)
                            Text("\(defense)")
                                .font(.headline)
                                .fontWeight(.bold)
                        }
                    }
                }

                Circle()
                    .fill(rarityColor)
                    .frame(width: 6, height: 6)
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color(UIColor.secondarySystemBackground))
        }
        .frame(height: 280)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: isSelected ? headerColor.opacity(0.5) : .black.opacity(0.2), radius: isSelected ? 10 : 5)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? headerColor : Color.clear, lineWidth: 3)
        )
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .onTapGesture {
            onTap?()
        }
    }

    var headerColor: Color {
        switch card.type {
        case .character: return Color.purple
        case .weapon: return Color.red
        case .spell: return Color.blue
        case .armor: return Color.gray
        case .item: return Color.brown
        case .ally: return Color.green
        case .blessing: return Color.yellow
        case .monster: return Color.red.opacity(0.8)
        case .location: return Color.teal
        case .scenario: return Color.indigo
        case .curse: return Color.black
        case .spirit: return Color.cyan
        case .artifact: return Color.orange
        case .ritual: return Color.indigo
        }
    }

    var cardIcon: String {
        switch card.type {
        case .character: return "person.fill"
        case .weapon: return "sword.fill"
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
        }
    }

    var rarityColor: Color {
        switch card.rarity {
        case .common: return .gray
        case .uncommon: return .green
        case .rare: return .blue
        case .epic: return .purple
        case .legendary: return .orange
        }
    }
}
