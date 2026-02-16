/// Файл: Views/Combat/DragDropController.swift
/// Назначение: Контроллер drag-drop жестов для карт ритуального боя.
/// Зона ответственности: Gesture state machine → canonical combat commands.
/// Контекст: Phase 3 Ritual Combat (R3). Без импорта Engine — чистый input layer.

import Foundation

// MARK: - Drag State

/// State machine for card drag gesture.
enum DragState: Equatable {
    case idle
    case pressing(cardId: String)
    case dragging(cardId: String, offset: CGSize)
    case released
}

// MARK: - Drag Command

/// Canonical command produced by drag-drop interaction.
/// Scene translates these into CombatSimulation API calls.
enum DragCommand: Equatable {
    case selectCard(cardId: String)
    case burnForEffort(cardId: String)
    case showTooltip(cardId: String)
    case cancelDrag
}

// MARK: - Drag Drop Controller

/// Processes touch/drag input and produces canonical combat commands.
/// Does not import TwilightEngine or access ECS directly.
@MainActor
final class DragDropController {

    /// Current drag state
    private(set) var state: DragState = .idle

    /// Drag threshold in points (below = long press, above = drag)
    let dragThreshold: CGFloat = 5.0

    /// Long press duration in seconds
    let longPressDuration: TimeInterval = 0.4

    /// Command output handler
    var onCommand: ((DragCommand) -> Void)?

    /// Long-press timer for tooltip
    private var longPressWorkItem: DispatchWorkItem?

    /// Begin tracking a potential drag on a card.
    func beginTouch(cardId: String) {
        state = .pressing(cardId: cardId)
        startLongPressTimer(cardId: cardId)
    }

    /// Whether long-press is blocked (drag already started or no active touch).
    var isLongPressBlocked: Bool {
        switch state {
        case .pressing: return false
        case .idle, .dragging, .released: return true
        }
    }

    /// Update drag position. Produces dragging state if threshold crossed.
    func updateDrag(offset: CGSize) {
        switch state {
        case .pressing(let cardId):
            let distance = sqrt(offset.width * offset.width + offset.height * offset.height)
            if distance > dragThreshold {
                cancelLongPressTimer()
                state = .dragging(cardId: cardId, offset: offset)
            }
        case .dragging(let cardId, _):
            state = .dragging(cardId: cardId, offset: offset)
        case .idle, .released:
            break
        }
    }

    /// End touch. Produces appropriate command based on final state.
    func endTouch() {
        switch state {
        case .pressing(let cardId):
            onCommand?(.selectCard(cardId: cardId))
        case .dragging(let cardId, _):
            onCommand?(.burnForEffort(cardId: cardId))
        case .idle, .released:
            break
        }
        state = .idle
    }

    /// Reset state without firing command. Used when scene handles zone routing.
    func reset() {
        state = .idle
    }

    /// Cancel current interaction.
    func cancel() {
        cancelLongPressTimer()
        state = .idle
        onCommand?(.cancelDrag)
    }

    // MARK: - Long Press Timer

    private func startLongPressTimer(cardId: String) {
        cancelLongPressTimer()
        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.isLongPressBlocked else { return }
            self.onCommand?(.showTooltip(cardId: cardId))
        }
        longPressWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + longPressDuration, execute: work)
    }

    func cancelLongPressTimer() {
        longPressWorkItem?.cancel()
        longPressWorkItem = nil
    }
}
