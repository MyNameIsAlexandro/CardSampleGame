import SwiftUI
import TwilightEngine

struct PhaseBanner: View {
    let phase: EncounterPhase
    let round: Int

    @State private var isVisible = true

    var body: some View {
        Group {
            if isVisible {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: phaseIcon)
                    Text(phaseText)
                }
                .font(.subheadline.bold())
                .foregroundColor(.white)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
                .background(phaseColor)
                .cornerRadius(CornerRadius.lg)
                .shadow(color: phaseColor.opacity(Opacity.light), radius: 4)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        withAnimation {
                            isVisible = false
                        }
                    }
                }
            }
        }
        .id(phase)
    }

    private var phaseIcon: String {
        switch phase {
        case .intent:
            return "eye.fill"
        case .playerAction:
            return "hand.raised.fill"
        case .enemyResolution:
            return "burst.fill"
        case .roundEnd:
            return "arrow.clockwise"
        }
    }

    private var phaseText: String {
        switch phase {
        case .intent:
            return "Enemy Intent"
        case .playerAction:
            return "Your Turn"
        case .enemyResolution:
            return "Enemy Acts"
        case .roundEnd:
            return "Round \(round + 1)"
        }
    }

    private var phaseColor: Color {
        switch phase {
        case .intent:
            return AppColors.warning
        case .playerAction:
            return AppColors.success
        case .enemyResolution:
            return AppColors.danger
        case .roundEnd:
            return AppColors.muted
        }
    }
}

#Preview {
    VStack(spacing: Spacing.xl) {
        PhaseBanner(phase: .intent, round: 0)
        PhaseBanner(phase: .playerAction, round: 0)
        PhaseBanner(phase: .enemyResolution, round: 0)
        PhaseBanner(phase: .roundEnd, round: 0)
    }
    .padding()
    .background(AppColors.backgroundSystem)
}
