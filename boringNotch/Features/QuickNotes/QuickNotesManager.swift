//
//  QuickNotesManager.swift
//  boringNotch
//
//  Created by DynaNotch on 2026-03-04.
//  GPL v3 License
//

import Combine
import Defaults
import Foundation
import os

/// Centralized Quick Notes manager with persistence via Defaults.
class QuickNotesManager: ObservableObject {

    static let shared = QuickNotesManager()

    private let logger = Logger(subsystem: "com.dynanotch", category: "QuickNotes")

    // MARK: - Published State

    @Published var notes: [QuickNote] = []

    // MARK: - Computed

    var isActive: Bool { Defaults[.enableQuickNotes] }

    var mostRecentPreview: String {
        guard let first = notes.first else { return "No notes" }
        if first.content.count > 25 {
            return String(first.content.prefix(25)) + "..."
        }
        return first.content
    }

    // MARK: - Private

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    private init() {
        notes = Defaults[.quickNotes]

        Defaults.publisher(.enableQuickNotes)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    // MARK: - Public API

    func addNote(_ content: String) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let note = QuickNote(content: trimmed)
        notes.insert(note, at: 0)
        persist()
        logger.info("[QUICKNOTES] added note id=\(note.id.uuidString.prefix(8))")
    }

    func deleteNote(_ note: QuickNote) {
        notes.removeAll { $0.id == note.id }
        persist()
        logger.info("[QUICKNOTES] deleted note id=\(note.id.uuidString.prefix(8))")
    }

    func deleteNote(at offsets: IndexSet) {
        notes.remove(atOffsets: offsets)
        persist()
    }

    // MARK: - Persistence

    private func persist() {
        Defaults[.quickNotes] = notes
    }
}
