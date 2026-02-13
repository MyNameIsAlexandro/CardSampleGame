/// Файл: Views/ContentManagerComponents.swift
/// Назначение: Содержит реализацию файла ContentManagerComponents.swift.
/// Зона ответственности: Ограничен задачами слоя представления и пользовательского интерфейса.
/// Контекст: Используется в приложении CardSampleGame и связанных потоках выполнения.

import SwiftUI
import TwilightEngine

struct PackRowView: View {
    let pack: ManagedPack
    @ObservedObject var viewModel: ContentManagerVM
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.md) {
                statusIcon
                    .frame(width: Sizes.iconSmall)

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    HStack {
                        Text(pack.displayName)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("v\(pack.versionString)")
                            .font(.caption)
                            .foregroundColor(AppColors.muted)
                    }

                    Text(viewModel.contentSummary(for: pack))
                        .font(.caption)
                        .foregroundColor(AppColors.muted)

                    HStack(spacing: Spacing.sm) {
                        Text(pack.localizedSourceName)
                            .font(.caption2)
                            .foregroundColor(AppColors.muted)

                        if let loadedAt = pack.formattedLoadedAt {
                            Text(String(format: L10n.contentManagerLoadedTime.localized, loadedAt))
                                .font(.caption2)
                                .foregroundColor(AppColors.muted)
                        } else {
                            Text(pack.formattedFileSize)
                                .font(.caption2)
                                .foregroundColor(AppColors.muted)
                        }
                    }
                }

                Spacer()
                actionButtons
            }
            .padding()
            .background(AppColors.cardBackground)
            .cornerRadius(CornerRadius.lg)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch pack.state {
        case .discovered:
            Image(systemName: "circle")
                .foregroundColor(AppColors.secondary)
        case .validating, .loading:
            ProgressView()
                .scaleEffect(0.7)
        case .validated(let summary):
            if summary.errorCount > 0 {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(AppColors.danger)
            } else if summary.warningCount > 0 {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(AppColors.warning)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(AppColors.success)
            }
        case .loaded:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(AppColors.success)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(AppColors.danger)
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: Spacing.sm) {
            if pack.canValidate && pack.state == .discovered {
                Button(L10n.contentManagerValidate.localized) {
                    Task { await viewModel.validatePack(pack.id) }
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }

            if pack.canLoad {
                Button(L10n.contentManagerLoad.localized) {
                    Task { await viewModel.loadPack(pack.id) }
                }
                .font(.caption)
                .buttonStyle(.borderedProminent)
            }

            if pack.canReload && pack.state == .loaded {
                Button(L10n.contentManagerReload.localized) {
                    Task { await viewModel.reloadPack(pack.id) }
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
        }
    }
}

struct PackDetailView: View {
    let pack: ManagedPack
    @ObservedObject var viewModel: ContentManagerVM
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    headerSection
                    statusSection

                    if pack.state == .loaded {
                        contentSection
                    }

                    if let validation = pack.lastValidation {
                        validationSection(validation)
                    }

                    actionsSection
                }
                .padding()
            }
            .navigationTitle(pack.displayName)
            .background(AppColors.backgroundSystem)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(AppColors.backgroundSystem, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .tint(AppColors.primary)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.contentManagerDone.localized) {
                        dismiss()
                    }
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: Spacing.sm) {
            Text(pack.displayName)
                .font(.title)
                .fontWeight(.bold)
            Text("v\(pack.versionString)")
                .font(.subheadline)
                .foregroundColor(AppColors.muted)
            Text(pack.localizedPackType)
                .font(.caption)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xxs)
                .background(AppColors.primary.opacity(Opacity.faint))
                .foregroundColor(AppColors.primary)
                .cornerRadius(CornerRadius.sm)
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(L10n.contentManagerStatus.localized)
                .font(.headline)

            HStack {
                Image(systemName: pack.state.statusIcon)
                    .foregroundColor(statusColor)
                Text(localizedStatusText)
                    .foregroundColor(statusColor)
                Spacer()
            }

            HStack {
                Label(pack.localizedSourceName, systemImage: pack.source.isReloadable ? "arrow.triangle.2.circlepath" : "lock.fill")
                    .font(.caption)
                    .foregroundColor(AppColors.muted)
                Spacer()
                Text(pack.formattedFileSize)
                    .font(.caption)
                    .foregroundColor(AppColors.muted)
            }

            if let loadedAt = pack.formattedLoadedAt {
                Text(String(format: L10n.contentManagerLoadedAt.localized, loadedAt))
                    .font(.caption)
                    .foregroundColor(AppColors.muted)
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .cornerRadius(CornerRadius.lg)
    }

    private var statusColor: Color {
        switch pack.state {
        case .loaded: return AppColors.success
        case .failed: return AppColors.danger
        case .validated(let summary) where summary.errorCount > 0: return AppColors.danger
        case .validated(let summary) where summary.warningCount > 0: return AppColors.warning
        case .validated: return AppColors.success
        default: return AppColors.muted
        }
    }

    private var localizedStatusText: String {
        switch pack.state {
        case .discovered: return L10n.contentManagerStatusDiscovered.localized
        case .validating: return L10n.contentManagerStatusValidating.localized
        case .validated(let summary):
            if summary.errorCount > 0 {
                return String(format: L10n.contentManagerStatusErrors.localized, summary.errorCount)
            }
            if summary.warningCount > 0 {
                return String(format: L10n.contentManagerStatusWarnings.localized, summary.warningCount)
            }
            return L10n.contentManagerStatusValid.localized
        case .loading: return L10n.contentManagerStatusLoading.localized
        case .loaded: return L10n.contentManagerStatusLoaded.localized
        case .failed(let error): return String(format: L10n.contentManagerStatusFailed.localized, error)
        }
    }

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(L10n.contentManagerContent.localized)
                .font(.headline)

            if let loadedPack = viewModel.loadedPack(for: pack.id) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.sm) {
                    contentItem(L10n.contentManagerRegions.localized, count: loadedPack.regions.count, icon: "map")
                    contentItem(L10n.contentManagerEvents.localized, count: loadedPack.events.count, icon: "sparkles")
                    contentItem(L10n.contentManagerQuests.localized, count: loadedPack.quests.count, icon: "scroll")
                    contentItem(L10n.contentManagerHeroes.localized, count: loadedPack.heroes.count, icon: "person.fill")
                    contentItem(L10n.contentManagerCards.localized, count: loadedPack.cards.count, icon: "rectangle.portrait.on.rectangle.portrait")
                    contentItem(L10n.contentManagerEnemies.localized, count: loadedPack.enemies.count, icon: "flame")
                }
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .cornerRadius(CornerRadius.lg)
    }

    private func contentItem(_ title: String, count: Int, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(AppColors.muted)
                .frame(width: Sizes.iconSmall)
            Text(title)
                .font(.caption)
            Spacer()
            Text("\(count)")
                .font(.caption)
                .fontWeight(.semibold)
        }
        .padding(.vertical, Spacing.xs)
    }

    private func validationSection(_ validation: ValidationSummary) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(L10n.contentManagerValidation.localized)
                    .font(.headline)
                Spacer()
                Text(String(format: "%.2fs", validation.duration))
                    .font(.caption)
                    .foregroundColor(AppColors.muted)
            }

            HStack(spacing: Spacing.md) {
                Label("\(validation.errorCount)", systemImage: "xmark.circle.fill")
                    .foregroundColor(validation.errorCount > 0 ? AppColors.danger : AppColors.secondary)
                Label("\(validation.warningCount)", systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(validation.warningCount > 0 ? AppColors.warning : AppColors.secondary)
                Label("\(validation.infoCount)", systemImage: "info.circle.fill")
                    .foregroundColor(AppColors.muted)
            }
            .font(.caption)

            if !validation.errors.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(L10n.contentManagerValidationErrors.localized)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.danger)
                    ForEach(validation.errors, id: \.self) { error in
                        Text("• \(error)")
                            .font(.caption2)
                            .foregroundColor(AppColors.danger)
                    }
                }
            }

            if !validation.warnings.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(L10n.contentManagerValidationWarnings.localized)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.warning)
                    ForEach(validation.warnings, id: \.self) { warning in
                        Text("• \(warning)")
                            .font(.caption2)
                            .foregroundColor(AppColors.warning)
                    }
                }
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .cornerRadius(CornerRadius.lg)
    }

    private var actionsSection: some View {
        HStack(spacing: Spacing.md) {
            if pack.canValidate {
                Button {
                    Task { await viewModel.validatePack(pack.id) }
                } label: {
                    Label(L10n.contentManagerValidate.localized, systemImage: "checkmark.shield")
                }
                .buttonStyle(.bordered)
            }

            if pack.canLoad {
                Button {
                    Task { await viewModel.loadPack(pack.id) }
                } label: {
                    Label(L10n.contentManagerLoad.localized, systemImage: "arrow.down.circle")
                }
                .buttonStyle(.borderedProminent)
            }

            if pack.canReload {
                Button {
                    Task { await viewModel.reloadPack(pack.id) }
                } label: {
                    Label(L10n.contentManagerReload.localized, systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

extension L10n {
    static let contentManagerTitle = "content.manager.title"
    static let contentManagerLoadedPacks = "content.manager.loaded.packs"
    static let contentManagerBundledPacks = "content.manager.bundled.packs"
    static let contentManagerExternalPacks = "content.manager.external.packs"
    static let contentManagerNoExternal = "content.manager.no.external"
    static let contentManagerHowToAdd = "content.manager.how.to.add"
    static let contentManagerPlaceFiles = "content.manager.place.files"
    static let contentManagerOpen = "content.manager.open"
    static let contentManagerReloadAll = "content.manager.reload.all"
    static let contentManagerValidate = "content.manager.validate"
    static let contentManagerLoad = "content.manager.load"
    static let contentManagerReload = "content.manager.reload"
    static let contentManagerDone = "content.manager.done"

    static let contentManagerStatus = "content.manager.status"
    static let contentManagerStatusDiscovered = "content.manager.status.discovered"
    static let contentManagerStatusValidating = "content.manager.status.validating"
    static let contentManagerStatusValid = "content.manager.status.valid"
    static let contentManagerStatusErrors = "content.manager.status.errors"
    static let contentManagerStatusWarnings = "content.manager.status.warnings"
    static let contentManagerStatusLoading = "content.manager.status.loading"
    static let contentManagerStatusLoaded = "content.manager.status.loaded"
    static let contentManagerStatusFailed = "content.manager.status.failed"
    static let contentManagerLoadedAt = "content.manager.loaded.at"
    static let contentManagerLoadedTime = "content.manager.loaded.time"

    static let contentManagerContent = "content.manager.content"
    static let contentManagerRegions = "content.manager.regions"
    static let contentManagerEvents = "content.manager.events"
    static let contentManagerQuests = "content.manager.quests"
    static let contentManagerHeroes = "content.manager.heroes"
    static let contentManagerCards = "content.manager.cards"
    static let contentManagerEnemies = "content.manager.enemies"

    static let contentManagerValidation = "content.manager.validation"
    static let contentManagerValidationErrors = "content.manager.validation.errors"
    static let contentManagerValidationWarnings = "content.manager.validation.warnings"

    static let contentManagerSourceBundled = "content.manager.source.bundled"
    static let contentManagerSourceExternal = "content.manager.source.external"

    static let contentManagerPackTypeCharacter = "content.manager.pack.type.character"
    static let contentManagerPackTypeCampaign = "content.manager.pack.type.campaign"
    static let contentManagerPackTypeBalance = "content.manager.pack.type.balance"
    static let contentManagerPackTypeRulesExtension = "content.manager.pack.type.rules.extension"
    static let contentManagerPackTypeFull = "content.manager.pack.type.full"
    static let contentManagerPackTypeUnknown = "content.manager.pack.type.unknown"

    static let back = "back"
}

extension ManagedPack {
    var localizedSourceName: String {
        switch source {
        case .bundled:
            return L10n.contentManagerSourceBundled.localized
        case .external:
            return L10n.contentManagerSourceExternal.localized
        }
    }

    var localizedPackType: String {
        guard let manifest = manifest else {
            return L10n.contentManagerPackTypeUnknown.localized
        }
        switch manifest.packType {
        case .character:
            return L10n.contentManagerPackTypeCharacter.localized
        case .campaign:
            return L10n.contentManagerPackTypeCampaign.localized
        case .balance:
            return L10n.contentManagerPackTypeBalance.localized
        case .rulesExtension:
            return L10n.contentManagerPackTypeRulesExtension.localized
        case .full:
            return L10n.contentManagerPackTypeFull.localized
        }
    }
}
