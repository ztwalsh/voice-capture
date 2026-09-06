// swift-tools-version: 5.9
import PackageDescription

// Three throwaway spikes for Phase 0 of ../PLAN.md. Nothing here survives into
// the app — the point is to buy certainty before committing to an architecture.
let package = Package(
    name: "HarpsSpikes",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "SpikeAFocus",      path: "Sources/SpikeAFocus"),
        .executableTarget(name: "SpikeBInsert",     path: "Sources/SpikeBInsert"),
        .executableTarget(name: "SpikeCTranscribe", path: "Sources/SpikeCTranscribe"),
    ]
)
