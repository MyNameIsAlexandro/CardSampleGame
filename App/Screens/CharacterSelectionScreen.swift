/// Файл: App/Screens/CharacterSelectionScreen.swift
/// Назначение: Содержит реализацию файла CharacterSelectionScreen.swift.
/// Зона ответственности: Изолирован логикой уровня инициализации и навигации приложения.
/// Контекст: Используется в приложении CardSampleGame и связанных потоках выполнения.

import SwiftUI
import TwilightEngine

/// Экран выбора героя и входных действий кампании.
/// Отвечает только за UI главного меню и не содержит мутаций состояния движка.
struct CharacterSelectionScreen: View {
    let availableHeroes: [HeroDefinition]
    let registry: ContentRegistry
    @Binding var selectedHeroId: String?

    let isSaveManagerLoaded: Bool
    let hasSaves: Bool

    let onOpenContentManager: () -> Void
    let onOpenSettings: () -> Void
    let onOpenBestiary: () -> Void
    let onOpenAchievements: () -> Void
    let onOpenStatistics: () -> Void
    let onOpenRules: () -> Void

    let onContinueGame: () -> Void
    let onStartAdventure: () -> Void
    let onQuickBattle: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: Spacing.xl) {
                        HStack(spacing: Spacing.sm) {
                            VStack(alignment: .leading, spacing: Spacing.xxxs) {
                                Text(L10n.tmGameTitle.localized)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .minimumScaleFactor(0.6)
                                    .lineLimit(2)
                                Text(L10n.tmGameSubtitle.localized)
                                    .font(.caption2)
                                    .foregroundColor(AppColors.muted)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            #if DEBUG
                            Button(action: onOpenContentManager) {
                                Image(systemName: "shippingbox.fill")
                                    .font(.title3)
                                    .padding(Spacing.sm)
                                    .background(AppColors.dark.opacity(Opacity.faint))
                                    .foregroundColor(AppColors.dark)
                                    .cornerRadius(CornerRadius.md)
                            }
                            #endif

                            Button(action: onOpenSettings) {
                                Image(systemName: "gearshape.fill")
                                    .font(.title3)
                                    .padding(Spacing.sm)
                                    .background(AppColors.secondary.opacity(Opacity.faint))
                                    .foregroundColor(AppColors.secondary)
                                    .cornerRadius(CornerRadius.md)
                            }
                            Button(action: onOpenBestiary) {
                                Image(systemName: "pawprint.fill")
                                    .font(.title3)
                                    .padding(Spacing.sm)
                                    .background(AppColors.success.opacity(Opacity.faint))
                                    .foregroundColor(AppColors.success)
                                    .cornerRadius(CornerRadius.md)
                            }
                            Button(action: onOpenAchievements) {
                                Image(systemName: "trophy.fill")
                                    .font(.title3)
                                    .padding(Spacing.sm)
                                    .background(AppColors.warning.opacity(Opacity.faint))
                                    .foregroundColor(AppColors.warning)
                                    .cornerRadius(CornerRadius.md)
                            }
                            Button(action: onOpenStatistics) {
                                Image(systemName: "chart.bar.fill")
                                    .font(.title3)
                                    .padding(Spacing.sm)
                                    .background(AppColors.info.opacity(Opacity.faint))
                                    .foregroundColor(AppColors.info)
                                    .cornerRadius(CornerRadius.md)
                            }
                            Button(action: onOpenRules) {
                                Image(systemName: "book.fill")
                                    .font(.title3)
                                    .padding(Spacing.sm)
                                    .background(AppColors.info.opacity(Opacity.faint))
                                    .foregroundColor(AppColors.info)
                                    .cornerRadius(CornerRadius.md)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, Spacing.sm)

                        Text(L10n.characterSelectTitle.localized)
                            .font(.title2)
                            .foregroundColor(AppColors.muted)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Spacing.xl) {
                                ForEach(availableHeroes, id: \.id) { hero in
                                    HeroSelectionCard(
                                        hero: hero,
                                        isSelected: selectedHeroId == hero.id,
                                        onTap: {
                                            selectedHeroId = hero.id
                                        }
                                    )
                                    .frame(width: min(geometry.size.width * 0.65, 240), height: 280)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, Spacing.md)
                        }
                        .frame(height: Sizes.heroCarouselHeight)

                        if let heroId = selectedHeroId,
                           let hero = registry.heroRegistry.hero(id: heroId) {
                            VStack(alignment: .leading, spacing: Spacing.lg) {
                                Text(L10n.characterStats.localized)
                                    .font(.headline)

                                Text(hero.description.localized)
                                    .font(.body)
                                    .foregroundColor(AppColors.muted)
                                    .fixedSize(horizontal: false, vertical: true)

                                HStack(spacing: Spacing.xxl) {
                                    StatDisplay(icon: "heart.fill", label: L10n.statHealth.localized, value: hero.baseStats.health, color: AppColors.health)
                                    StatDisplay(icon: "bolt.fill", label: L10n.statPower.localized, value: hero.baseStats.strength, color: AppColors.power)
                                    StatDisplay(icon: "shield.fill", label: L10n.statDefense.localized, value: hero.baseStats.constitution, color: AppColors.defense)
                                }

                                Divider()
                                Text(L10n.characterAbilities.localized)
                                    .font(.headline)

                                VStack(alignment: .leading, spacing: Spacing.xxs) {
                                    HStack {
                                        Image(systemName: hero.specialAbility.icon)
                                        Text(hero.specialAbility.name.localized)
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                            .foregroundColor(AppColors.power)
                                    }
                                    Text(hero.specialAbility.description.localized)
                                        .font(.caption)
                                        .foregroundColor(AppColors.muted)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(.vertical, Spacing.xxs)
                            }
                            .padding()
                            .background(AppColors.cardBackground)
                            .cornerRadius(CornerRadius.lg)
                            .padding(.horizontal)
                        }

                        Color.clear.frame(height: Sizes.menuBottomSpacer)
                    }
                    .padding(.bottom, Spacing.xl)
                }

                VStack(spacing: 0) {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.clear, AppColors.backgroundSystem]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: Sizes.menuGradientFadeHeight)

                    VStack(spacing: Spacing.md) {
                        if !isSaveManagerLoaded {
                            Button(action: {}) {
                                HStack {
                                    ProgressView()
                                        .tint(.white)
                                    Text(L10n.uiContinue.localized)
                                }
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(AppColors.success.opacity(Opacity.medium))
                                .cornerRadius(CornerRadius.lg)
                            }
                            .disabled(true)
                        } else if hasSaves {
                            Button(action: onContinueGame) {
                                HStack {
                                    Image(systemName: "play.fill")
                                    Text(L10n.uiContinue.localized)
                                }
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(AppColors.success)
                                .cornerRadius(CornerRadius.lg)
                            }
                        }

                        Button(action: onStartAdventure) {
                            HStack {
                                Image(systemName: hasSaves ? "plus.circle.fill" : "play.fill")
                                Text(selectedHeroId == nil
                                    ? L10n.buttonSelectHeroFirst.localized
                                    : L10n.buttonStartAdventure.localized)
                            }
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(selectedHeroId == nil ? AppColors.secondary : AppColors.primary)
                            .cornerRadius(CornerRadius.lg)
                        }
                        .disabled(selectedHeroId == nil)

                        Button(action: onQuickBattle) {
                            HStack {
                                Image(systemName: "flame.fill")
                                Text(L10n.arenaTitle.localized)
                            }
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppColors.danger.opacity(Opacity.high))
                            .cornerRadius(CornerRadius.lg)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, Spacing.md)
                    .background(AppColors.backgroundSystem)
                }
            }
        }
        .background(AppColors.backgroundSystem)
        .navigationBarHidden(true)
    }
}
