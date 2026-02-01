import FirebladeECS

/// Base protocol for all EchoEngine systems.
public protocol EchoSystem {
    func update(nexus: Nexus)
}
