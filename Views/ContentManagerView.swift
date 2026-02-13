/// Файл: Views/ContentManagerView.swift
/// Назначение: Содержит реализацию файла ContentManagerView.swift.
/// Зона ответственности: Ограничен задачами слоя представления и пользовательского интерфейса.
/// Контекст: Используется в приложении CardSampleGame и связанных потоках выполнения.

import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif
import TwilightEngine

/// Content Manager View - shows all packs with status and reload options
struct ContentManagerView: View {
    @StateObject private var viewModel: ContentManagerVM
    @State private var showingPackDetail = false
    @Environment(\.dismiss) private var dismiss

    private let bundledPackURLs: [URL]

    /// Bundled pack URLs (passed from app)
    init(contentManager: ContentManager, registry: ContentRegistry, bundledPackURLs: [URL]) {
        self.bundledPackURLs = bundledPackURLs
        _viewModel = StateObject(wrappedValue: ContentManagerVM(contentManager: contentManager, registry: registry))
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    // Error banner
                    if let error = viewModel.lastError {
                        errorBanner(error)
                    }

                    // Loaded packs section
                    packSection(
                        title: L10n.contentManagerLoadedPacks.localized,
                        count: viewModel.loadedCount,
                        packs: viewModel.loadedPacks,
                        showReloadAll: false
                    )

                    // Bundled packs section
                    if !viewModel.bundledPacks.isEmpty {
                        packSection(
                            title: L10n.contentManagerBundledPacks.localized,
                            count: viewModel.bundledPacks.count,
                            packs: viewModel.bundledPacks.filter { $0.state != .loaded },
                            showReloadAll: false
                        )
                    }

                    // External packs section
                    externalPacksSection

                    // Instructions
                    instructionsCard
                }
                .padding()
            }
            .navigationTitle(L10n.contentManagerTitle.localized)
            .background(AppColors.backgroundSystem)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(AppColors.backgroundSystem, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .tint(AppColors.primary)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.back.localized) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await viewModel.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isScanning)
                }
            }
            .sheet(isPresented: $showingPackDetail) {
                if let pack = viewModel.selectedPack {
                    PackDetailView(pack: pack, viewModel: viewModel)
                }
            }
            .task {
                viewModel.setBundledPackURLs(bundledPackURLs)
                await viewModel.refresh()
            }
        }
    }

    // MARK: - Pack Section

    private func packSection(title: String, count: Int, packs: [ManagedPack], showReloadAll: Bool) -> some View {
        Group {
            if !packs.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    HStack {
                        Text("\(title) (\(count))")
                            .font(.headline)
                            .foregroundColor(AppColors.muted)
                        Spacer()
                        if showReloadAll {
                            Button(L10n.contentManagerReloadAll.localized) {
                                Task { await viewModel.reloadAllExternal() }
                            }
                            .font(.caption)
                        }
                    }

                    ForEach(packs) { pack in
                        PackRowView(pack: pack, viewModel: viewModel) {
                            viewModel.selectPack(pack.id)
                            showingPackDetail = true
                        }
                    }
                }
            }
        }
    }

    // MARK: - External Packs Section

    private var externalPacksSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text(L10n.contentManagerExternalPacks.localized)
                    .font(.headline)
                    .foregroundColor(AppColors.muted)
                Spacer()
                if !viewModel.externalPacks.isEmpty {
                    Button(L10n.contentManagerReloadAll.localized) {
                        Task { await viewModel.reloadAllExternal() }
                    }
                    .font(.caption)
                }
            }

            if viewModel.externalPacks.isEmpty {
                Text(L10n.contentManagerNoExternal.localized)
                    .font(.subheadline)
                    .foregroundColor(AppColors.muted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(viewModel.externalPacks) { pack in
                    PackRowView(pack: pack, viewModel: viewModel) {
                        viewModel.selectPack(pack.id)
                        showingPackDetail = true
                    }
                }
            }
        }
    }

    // MARK: - Instructions Card

    private var instructionsCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Image(systemName: "lightbulb")
                    .foregroundColor(AppColors.warning)
                Text(L10n.contentManagerHowToAdd.localized)
                    .font(.headline)
            }

            Text(L10n.contentManagerPlaceFiles.localized)
                .font(.subheadline)
                .foregroundColor(AppColors.muted)

            HStack {
                Text(viewModel.externalPacksPath)
                    .font(.caption)
                    .foregroundColor(AppColors.muted)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                Button {
                    copyExternalPacksPathToClipboard()
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }

                #if os(iOS)
                Button {
                    openExternalPacksFolder()
                } label: {
                    Text(L10n.contentManagerOpen.localized)
                        .font(.caption)
                }
                #endif
            }
        }
        .padding()
        .background(AppColors.backgroundTertiary)
        .cornerRadius(CornerRadius.lg)
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(AppColors.danger)
            Text(message)
                .font(.caption)
                .foregroundColor(AppColors.danger)
            Spacer()
            Button {
                viewModel.lastError = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
            }
        }
        .padding()
        .background(AppColors.danger.opacity(Opacity.faint))
        .cornerRadius(CornerRadius.md)
    }

    private func copyExternalPacksPathToClipboard() {
        #if os(iOS)
        UIPasteboard.general.string = viewModel.externalPacksPath
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(viewModel.externalPacksPath, forType: .string)
        #endif
    }

    #if os(iOS)
    private func openExternalPacksFolder() {
        let url = URL(fileURLWithPath: viewModel.externalPacksPath)
        guard let filesURL = URL(string: "shareddocuments://\(url.path)") else { return }
        UIApplication.shared.open(filesURL)
    }
    #endif
}
