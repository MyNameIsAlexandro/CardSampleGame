/// Файл: Views/MarketView.swift
/// Назначение: Содержит реализацию файла MarketView.swift.
/// Зона ответственности: Ограничен задачами слоя представления и пользовательского интерфейса.
/// Контекст: Используется в приложении CardSampleGame и связанных потоках выполнения.

import SwiftUI
import TwilightEngine

struct MarketView: View {
    @ObservedObject var vm: GameEngineObservable
    let onAutoSave: (() -> Void)?
    let onDismiss: () -> Void

    @State private var showingActionError = false
    @State private var actionErrorMessage = ""

    private var cards: [Card] { vm.engine.publishedMarketCards }

    init(
        vm: GameEngineObservable,
        onAutoSave: (() -> Void)? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.vm = vm
        self.onAutoSave = onAutoSave
        self.onDismiss = onDismiss
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                HeroPanel(vm: vm)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xxs)

                HStack(spacing: Spacing.md) {
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundColor(AppColors.faith)
                        Text("\(L10n.combatFaithLabel.localized): \(vm.engine.player.faith)")
                            .font(.caption)
                            .foregroundColor(AppColors.muted)
                    }

                    Spacer()
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)

                ScrollView {
                    LazyVStack(spacing: Spacing.md) {
                        if cards.isEmpty {
                            Text(L10n.marketEmpty.localized)
                                .font(.callout)
                                .foregroundColor(AppColors.muted)
                                .padding(.top, Spacing.xl)
                        } else {
                            ForEach(cards) { card in
                                let cost = card.adjustedFaithCost(playerBalance: vm.engine.player.balance)
                                MarketCardRow(
                                    card: card,
                                    localizedTypeName: localizedTypeName(for: card.type),
                                    cost: cost,
                                    canAfford: vm.engine.player.faith >= cost,
                                    onBuy: { buy(cardId: card.id) }
                                )
                            }
                        }
                    }
                    .padding()
                }
            }
            .background(AppColors.backgroundSystem.ignoresSafeArea())
            .navigationTitle(L10n.marketTitle.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(AppColors.backgroundSystem, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .tint(AppColors.primary)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.uiClose.localized) {
                        onDismiss()
                    }
                }
            }
            .alert(L10n.actionImpossible.localized, isPresented: $showingActionError) {
                Button(L10n.buttonUnderstood.localized, role: .cancel) { }
            } message: {
                Text(actionErrorMessage)
            }
        }
    }

    private func buy(cardId: String) {
        let result = vm.engine.performAction(.marketBuy(cardId: cardId))
        guard !result.success else {
            onAutoSave?()
            return
        }

        actionErrorMessage = errorMessage(for: result.error)
        showingActionError = true
    }

    private func errorMessage(for error: ActionError?) -> String {
        guard let error else { return L10n.errorUnknown.localized }
        switch error {
        case .insufficientResources:
            return L10n.combatFaithInsufficient.localized
        default:
            return error.localizedDescription
        }
    }

    private func localizedTypeName(for type: CardType) -> String {
        switch type {
        case .character: return L10n.cardTypeCharacter.localized
        case .weapon: return L10n.cardTypeWeapon.localized
        case .spell: return L10n.cardTypeSpell.localized
        case .armor: return L10n.cardTypeArmor.localized
        case .item: return L10n.cardTypeItem.localized
        case .ally: return L10n.cardTypeAlly.localized
        case .blessing: return L10n.cardTypeBlessing.localized
        case .monster: return L10n.cardTypeMonster.localized
        case .location: return L10n.cardTypeLocation.localized
        case .scenario: return type.rawValue.capitalized
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
}

private struct MarketCardRow: View {
    let card: Card
    let localizedTypeName: String
    let cost: Int
    let canAfford: Bool
    let onBuy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .top, spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xxxs) {
                    Text(card.name)
                        .font(.headline)
                        .foregroundColor(.white)

                    Text(localizedTypeName)
                        .font(.caption)
                        .foregroundColor(AppColors.muted)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: Spacing.xxs) {
                    Text(L10n.combatFaithCost.localized(with: cost))
                        .font(.caption)
                        .foregroundColor(AppColors.faith)

                    Button(action: onBuy) {
                        Text(L10n.marketBuy.localized)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.xxs)
                            .background(canAfford ? AppColors.warning : AppColors.secondary)
                            .cornerRadius(CornerRadius.md)
                    }
                    .disabled(!canAfford)

                    if !canAfford {
                        Text(L10n.combatFaithInsufficient.localized)
                            .font(.caption2)
                            .foregroundColor(AppColors.secondary)
                    }
                }
            }

            if !card.description.isEmpty {
                Text(card.description)
                    .font(.caption)
                    .foregroundColor(AppColors.muted)
                    .lineLimit(3)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .fill(AppColors.cardBackground)
        )
    }
}
