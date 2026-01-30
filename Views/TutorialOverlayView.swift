import SwiftUI

struct TutorialOverlayView: View {
    let onComplete: () -> Void

    @State private var currentStep = 0

    private let steps: [(icon: String, titleKey: String, bodyKey: String)] = [
        ("sun.max.fill", L10n.tutorialWelcomeTitle, L10n.tutorialWelcomeBody),
        ("map.fill", L10n.tutorialMapTitle, L10n.tutorialMapBody),
        ("bolt.fill", L10n.tutorialCombatTitle, L10n.tutorialCombatBody),
        ("sparkles", L10n.tutorialFateTitle, L10n.tutorialFateBody),
    ]

    var body: some View {
        ZStack {
            AppColors.backgroundSystem.opacity(Opacity.high).ignoresSafeArea()

            VStack(spacing: Spacing.xl) {
                Spacer()

                // Step indicator
                HStack(spacing: Spacing.xs) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentStep ? AppColors.primary : AppColors.secondary.opacity(Opacity.light))
                            .frame(width: Sizes.dotIndicator, height: Sizes.dotIndicator)
                    }
                }

                let step = steps[currentStep]

                Image(systemName: step.icon)
                    .font(.system(size: Sizes.iconXXL))
                    .foregroundColor(AppColors.primary)

                Text(step.titleKey.localized)
                    .font(.title)
                    .fontWeight(.bold)

                Text(step.bodyKey.localized)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)

                Spacer()

                // Buttons
                VStack(spacing: Spacing.sm) {
                    Button(action: {
                        if currentStep < steps.count - 1 {
                            withAnimation(AppAnimation.gentle) { currentStep += 1 }
                        } else {
                            onComplete()
                        }
                    }) {
                        Text(currentStep < steps.count - 1
                             ? L10n.tutorialNext.localized
                             : L10n.tutorialFinish.localized)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppColors.primary)
                            .cornerRadius(CornerRadius.lg)
                    }

                    if currentStep < steps.count - 1 {
                        Button(action: onComplete) {
                            Text(L10n.tutorialSkip.localized)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.xl)
            }
        }
    }
}
