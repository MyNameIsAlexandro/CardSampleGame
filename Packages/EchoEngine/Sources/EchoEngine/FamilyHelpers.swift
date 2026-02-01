import FirebladeECS

/// Helper to get the first element from a Family iterator (LazySequence).
/// FirebladeECS Family conforms to LazySequenceProtocol, not RandomAccessCollection,
/// so `.first` doesn't work as expected. This provides a safe accessor.
extension Sequence {
    func firstElement() -> Element? {
        var iterator = makeIterator()
        return iterator.next()
    }
}

/// Helper to get the first Entity from a Family's entity iterator.
extension Family {
    var firstEntity: Entity? {
        entities.firstElement()
    }
}
