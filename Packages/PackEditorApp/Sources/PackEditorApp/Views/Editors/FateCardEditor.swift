/// Файл: Packages/PackEditorApp/Sources/PackEditorApp/Views/Editors/FateCardEditor.swift
/// Назначение: Содержит реализацию файла FateCardEditor.swift.
/// Зона ответственности: Изолирован своей предметной ответственностью в рамках модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import SwiftUI
import TwilightEngine
import PackEditorKit

struct FateCardEditor: View {
    @Binding var card: FateCard

    var body: some View {
        Form {
            Section("Identity") {
                LabeledContent("ID", value: card.id)
                TextField("Name", text: $card.name)
                    .validated(card.name.isEmpty ? .error("Name is required") : nil)
                TextField("Name Key", text: optionalString(\.nameKey))
                TextField("Suit (rawValue)", text: optionalRawValue(\.suit, parse: FateCardSuit.init(rawValue:)))
                Picker("Keyword", selection: optionalCaseIterable(\.keyword)) {
                    Text("None").tag(nil as FateKeyword?)
                    ForEach(FateKeyword.allCases, id: \.self) { kw in
                        Text(kw.rawValue).tag(kw as FateKeyword?)
                    }
                }
                TextField("Card Type (rawValue)", text: rawValue(\.cardType, parse: FateCardType.init(rawValue:)))
            }

            Section("Values") {
                IntField(label: "Base Value", value: $card.baseValue)
                Toggle("Critical", isOn: $card.isCritical)
                Toggle("Sticky", isOn: $card.isSticky)
            }

            Section {
                ForEach(Array(card.resonanceRules.enumerated()), id: \.offset) { index, _ in
                    HStack {
                        VStack {
                            Picker("Zone", selection: resonanceZoneBinding(at: index)) {
                                ForEach(ResonanceZone.allCases, id: \.self) { zone in
                                    Text(zone.rawValue).tag(zone)
                                }
                            }
                            IntField(label: "Modify Value", value: resonanceModifyValueBinding(at: index))
                            TextField("Visual Effect", text: optionalString(forResonanceRuleAt: index))
                        }
                        Button(role: .destructive) {
                            guard index < card.resonanceRules.count else { return }
                            card.resonanceRules.remove(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                        }.buttonStyle(.plain).foregroundStyle(.red)
                    }
                }
                Button {
                    card.resonanceRules.append(FateResonanceRule(zone: .yav, modifyValue: 0))
                } label: {
                    Label("Add Resonance Rule", systemImage: "plus.circle.fill")
                }
            } header: {
                Text("Resonance Rules (\(card.resonanceRules.count))")
            }

            Section {
                ForEach(Array(card.onDrawEffects.enumerated()), id: \.offset) { index, _ in
                    HStack {
                        VStack {
                            Picker("Type", selection: drawEffectTypeBinding(at: index)) {
                                Text("shiftResonance").tag(FateEffectType.shiftResonance)
                                Text("shiftTension").tag(FateEffectType.shiftTension)
                            }
                            IntField(label: "Value", value: drawEffectValueBinding(at: index))
                        }
                        Button(role: .destructive) {
                            guard index < card.onDrawEffects.count else { return }
                            card.onDrawEffects.remove(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                        }.buttonStyle(.plain).foregroundStyle(.red)
                    }
                }
                Button {
                    card.onDrawEffects.append(FateDrawEffect(type: .shiftResonance, value: 0))
                } label: {
                    Label("Add Draw Effect", systemImage: "plus.circle.fill")
                }
            } header: {
                Text("On Draw Effects (\(card.onDrawEffects.count))")
            }

            Section {
                Toggle("Has Choice Options", isOn: hasChoiceOptions)
                if let choices = card.choiceOptions {
                    ForEach(Array(choices.enumerated()), id: \.offset) { index, _ in
                        HStack {
                            VStack {
                                TextField("Label", text: choiceLabel(at: index))
                                TextField("Effect", text: choiceEffect(at: index))
                            }
                            Button(role: .destructive) {
                                guard let count = card.choiceOptions?.count, index < count else { return }
                                card.choiceOptions?.remove(at: index)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                            }.buttonStyle(.plain).foregroundStyle(.red)
                        }
                    }
                    Button {
                        card.choiceOptions?.append(FateChoiceOption(label: "", effect: ""))
                    } label: {
                        Label("Add Choice Option", systemImage: "plus.circle.fill")
                    }
                }
            } header: {
                Text("Choice Options (\(card.choiceOptions?.count ?? 0))")
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Binding Helpers

    /// Binding for an optional String field — empty string maps to nil.
    private func optionalString(_ keyPath: WritableKeyPath<FateCard, String?>) -> Binding<String> {
        Binding<String>(
            get: { card[keyPath: keyPath] ?? "" },
            set: { card[keyPath: keyPath] = $0.isEmpty ? nil : $0 }
        )
    }

    /// Binding for an optional RawRepresentable enum — empty string maps to nil.
    private func optionalRawValue<E: RawRepresentable>(
        _ keyPath: WritableKeyPath<FateCard, E?>,
        parse: @escaping (String) -> E?
    ) -> Binding<String> where E.RawValue == String {
        Binding<String>(
            get: { card[keyPath: keyPath]?.rawValue ?? "" },
            set: { card[keyPath: keyPath] = $0.isEmpty ? nil : parse($0) }
        )
    }

    /// Binding for a required RawRepresentable enum — invalid input is ignored.
    private func rawValue<E: RawRepresentable>(
        _ keyPath: WritableKeyPath<FateCard, E>,
        parse: @escaping (String) -> E?
    ) -> Binding<String> where E.RawValue == String {
        Binding<String>(
            get: { card[keyPath: keyPath].rawValue },
            set: { newValue in
                if let parsed = parse(newValue) {
                    card[keyPath: keyPath] = parsed
                }
            }
        )
    }

    /// Binding for an optional CaseIterable enum used with Picker.
    private func optionalCaseIterable<E: Hashable>(
        _ keyPath: WritableKeyPath<FateCard, E?>
    ) -> Binding<E?> {
        Binding<E?>(
            get: { card[keyPath: keyPath] },
            set: { card[keyPath: keyPath] = $0 }
        )
    }

    /// Binding for a resonance rule's optional visualEffect at a given index.
    private func optionalString(forResonanceRuleAt index: Int) -> Binding<String> {
        Binding<String>(
            get: {
                guard index < card.resonanceRules.count else { return "" }
                return card.resonanceRules[index].visualEffect ?? ""
            },
            set: {
                guard index < card.resonanceRules.count else { return }
                card.resonanceRules[index].visualEffect = $0.isEmpty ? nil : $0
            }
        )
    }

    /// Toggle binding for choiceOptions nil ↔ empty array.
    private var hasChoiceOptions: Binding<Bool> {
        Binding<Bool>(
            get: { card.choiceOptions != nil },
            set: { card.choiceOptions = $0 ? [] : nil }
        )
    }

    /// Binding for a choice option's label at a given index.
    private func choiceLabel(at index: Int) -> Binding<String> {
        Binding<String>(
            get: {
                guard let choices = card.choiceOptions, index < choices.count else { return "" }
                return choices[index].label
            },
            set: {
                guard card.choiceOptions != nil, index < (card.choiceOptions?.count ?? 0) else { return }
                card.choiceOptions?[index].label = $0
            }
        )
    }

    /// Binding for a choice option's effect at a given index.
    private func choiceEffect(at index: Int) -> Binding<String> {
        Binding<String>(
            get: {
                guard let choices = card.choiceOptions, index < choices.count else { return "" }
                return choices[index].effect
            },
            set: {
                guard card.choiceOptions != nil, index < (card.choiceOptions?.count ?? 0) else { return }
                card.choiceOptions?[index].effect = $0
            }
        )
    }

    // MARK: - Safe Resonance Rule Bindings

    private func resonanceZoneBinding(at index: Int) -> Binding<ResonanceZone> {
        Binding(
            get: {
                guard index < card.resonanceRules.count else { return .yav }
                return card.resonanceRules[index].zone
            },
            set: { newValue in
                guard index < card.resonanceRules.count else { return }
                card.resonanceRules[index].zone = newValue
            }
        )
    }

    private func resonanceModifyValueBinding(at index: Int) -> Binding<Int> {
        Binding(
            get: {
                guard index < card.resonanceRules.count else { return 0 }
                return card.resonanceRules[index].modifyValue
            },
            set: { newValue in
                guard index < card.resonanceRules.count else { return }
                card.resonanceRules[index].modifyValue = newValue
            }
        )
    }

    // MARK: - Safe Draw Effect Bindings

    private func drawEffectTypeBinding(at index: Int) -> Binding<FateEffectType> {
        Binding(
            get: {
                guard index < card.onDrawEffects.count else { return .shiftResonance }
                return card.onDrawEffects[index].type
            },
            set: { newValue in
                guard index < card.onDrawEffects.count else { return }
                card.onDrawEffects[index].type = newValue
            }
        )
    }

    private func drawEffectValueBinding(at index: Int) -> Binding<Int> {
        Binding(
            get: {
                guard index < card.onDrawEffects.count else { return 0 }
                return card.onDrawEffects[index].value
            },
            set: { newValue in
                guard index < card.onDrawEffects.count else { return }
                card.onDrawEffects[index].value = newValue
            }
        )
    }
}
