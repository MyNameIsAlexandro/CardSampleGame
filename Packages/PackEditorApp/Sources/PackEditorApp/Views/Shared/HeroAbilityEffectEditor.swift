import SwiftUI
import TwilightEngine

/// Editor for [HeroAbilityEffect] array
struct HeroAbilityEffectEditor: View {
    let label: String
    @Binding var effects: [HeroAbilityEffect]

    var body: some View {
        DisclosureGroup("\(label) (\(effects.count))") {
            ForEach(Array(effects.enumerated()), id: \.offset) { index, _ in
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Effect \(index + 1)")
                                .font(.headline)
                            Spacer()
                            Button(role: .destructive) {
                                guard index < effects.count else { return }
                                effects.remove(at: index)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.red)
                        }

                        Picker("Type", selection: effectTypeBinding(at: index)) {
                            ForEach(HeroAbilityEffectType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }

                        IntField(label: "Value", value: effectValueBinding(at: index))

                        TextField("Description (optional)", text: effectDescBinding(at: index))
                    }
                }
                .id("\(label)-effect-\(index)")
            }

            Button {
                effects.append(HeroAbilityEffect(type: .bonusDamage, value: 1))
            } label: {
                Label("Add Effect", systemImage: "plus.circle")
            }
        }
    }

    private func effectTypeBinding(at index: Int) -> Binding<HeroAbilityEffectType> {
        Binding(
            get: {
                guard index < effects.count else { return .bonusDamage }
                return effects[index].type
            },
            set: {
                guard index < effects.count else { return }
                effects[index].type = $0
            }
        )
    }

    private func effectValueBinding(at index: Int) -> Binding<Int> {
        Binding(
            get: {
                guard index < effects.count else { return 0 }
                return effects[index].value
            },
            set: {
                guard index < effects.count else { return }
                effects[index].value = $0
            }
        )
    }

    private func effectDescBinding(at index: Int) -> Binding<String> {
        Binding(
            get: {
                guard index < effects.count else { return "" }
                return effects[index].description ?? ""
            },
            set: {
                guard index < effects.count else { return }
                effects[index].description = $0.isEmpty ? nil : $0
            }
        )
    }
}
