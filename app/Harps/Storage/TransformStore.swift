import Foundation

/// PLAN.md Phase 6. One user-defined (or built-in) post-processing step,
/// run on every capture between transcription and insertion.
struct Transform: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var instructions: String
    var isEnabled: Bool
    /// Built-in transforms (General Clean-up) can be toggled off but never
    /// edited or deleted — same "honest, informational" posture as
    /// Settings' one-implementation rows, just per-row instead of per-page.
    let isBuiltIn: Bool
}

/// Persisted as a JSON file, not `UserDefaults` — consistent with this
/// app's "the file is the source of truth" posture elsewhere (transcripts
/// are files, not a database), and it means a transform's exact wording
/// survives being inspected or hand-edited the same way a day file does.
/// Order in the array is execution order; reordering is a plausible v2, not
/// required for v1 (PLAN.md Phase 6 open questions).
@MainActor
final class TransformStore: ObservableObject {
    static let shared = TransformStore()

    @Published private(set) var transforms: [Transform] = []

    private let fileURL: URL

    private static let generalCleanupID = "general-cleanup"
    private static let generalCleanupInstructions = """
    Remove filler words like "um" and "uh", collapse repeated or restarted \
    words, and tighten up out-loud thinking. Never change the meaning, \
    facts, or tone of what was actually said.
    """

    private init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.fileURL = support.appendingPathComponent("Harps/transforms.json")
        }
        load()
    }

    var enabledTransforms: [Transform] {
        transforms.filter(\.isEnabled)
    }

    func add(name: String, instructions: String) {
        transforms.append(Transform(
            id: UUID().uuidString, name: name, instructions: instructions,
            isEnabled: true, isBuiltIn: false
        ))
        save()
    }

    func update(id: String, name: String, instructions: String) {
        guard let index = transforms.firstIndex(where: { $0.id == id }), !transforms[index].isBuiltIn else { return }
        transforms[index].name = name
        transforms[index].instructions = instructions
        save()
    }

    func toggle(id: String) {
        guard let index = transforms.firstIndex(where: { $0.id == id }) else { return }
        transforms[index].isEnabled.toggle()
        save()
    }

    func delete(id: String) {
        guard let transform = transforms.first(where: { $0.id == id }), !transform.isBuiltIn else { return }
        transforms.removeAll { $0.id == id }
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([Transform].self, from: data)
        else {
            // First run (or a corrupt/missing file): seed with the one
            // built-in default rather than starting empty.
            transforms = [Transform(
                id: Self.generalCleanupID, name: "General Clean-up",
                instructions: Self.generalCleanupInstructions,
                isEnabled: true, isBuiltIn: true
            )]
            save()
            return
        }
        transforms = decoded
    }

    private func save() {
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        guard let data = try? JSONEncoder().encode(transforms) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
