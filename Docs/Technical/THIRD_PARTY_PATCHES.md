# Third-Party Patch Registry

This document tracks local overrides for external dependencies that are required
to keep architecture and quality gates enforceable.

## FirebladeECS (local override)

- Dependency: `FirebladeECS`
- Upstream: `https://github.com/fireblade-engine/ecs.git` (`0.17.7`, revision `ae23509c4a5b8a1631e31fe697279d0cde40c45a`)
- Local package path: `Packages/ThirdParty/FirebladeECS`
- Integration point: `Packages/EchoEngine/Package.swift` (path dependency)
- Owner: Engine platform / architecture audit track

### Why this override exists

The upstream package failed strict-concurrency app builds due to protocol
conformance mismatch in `TopLevelEncoder` / `TopLevelDecoder` (`JSONEncoder` and
`JSONDecoder` `userInfo` type under Swift 6 concurrency checks).

### Local patch set

1. `CodingStrategy` now conforms to `Sendable`.
2. `TopLevelEncoder.userInfo` changed to `[CodingUserInfoKey: any Sendable]`.
3. `TopLevelDecoder.userInfo` changed to `[CodingUserInfoKey: any Sendable]`.
4. Removed `swift-docc-plugin` dependency from local `Package.swift` to keep the
   vendored package self-contained for CI/package resolution.

### Removal criteria

1. Upstream releases a Swift 6 strict-concurrency compatible version.
2. Project passes app strict-concurrency gate with upstream dependency.
3. CI and local strict build are green without this local override.

### Rollback plan

1. Switch `Packages/EchoEngine/Package.swift` back to remote `ecs.git`.
2. Remove `Packages/ThirdParty/FirebladeECS`.
3. Resolve packages and run strict app build gate.
