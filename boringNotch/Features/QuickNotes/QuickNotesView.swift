//
//  QuickNotesView.swift
//  boringNotch
//
//  Created by DynaNotch on 2026-03-04.
//  GPL v3 License
//

import SwiftUI

/// Quick Notes tab view for the expanded notch.
struct QuickNotesView: View {
    @ObservedObject var manager = QuickNotesManager.shared
    @EnvironmentObject var vm: BoringViewModel
    @State private var newNoteText: String = ""

    var body: some View {
        VStack(spacing: 8) {
            // Input bar
            HStack(spacing: 8) {
                TextField("Quick note...", text: $newNoteText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.ultraThinMaterial)
                            .opacity(0.6)
                    )
                    .onSubmit {
                        addNote()
                    }

                Button(action: addNote) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.effectiveAccent)
                }
                .buttonStyle(.plain)
                .disabled(newNoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 10)

            // Notes list
            if manager.notes.isEmpty {
                Spacer()
                VStack(spacing: 4) {
                    Image(systemName: "note.text")
                        .font(.system(size: 20))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("No notes yet")
                        .font(.system(size: 11))
                        .foregroundColor(.gray.opacity(0.5))
                }
                Spacer()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 4) {
                        ForEach(manager.notes, id: \.id) { note in
                            noteCard(note)
                        }
                    }
                    .padding(.horizontal, 10)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 6)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .top)),
            removal: .opacity
        ))
    }

    // MARK: - Note Card

    private func noteCard(_ note: QuickNote) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(note.content)
                    .font(.system(size: 11))
                    .foregroundColor(.white)
                    .lineLimit(3)

                Text(relativeTime(note.createdAt))
                    .font(.system(size: 9))
                    .foregroundColor(.gray)
            }

            Spacer(minLength: 0)

            Button(action: {
                withAnimation(.smooth(duration: 0.2)) {
                    manager.deleteNote(note)
                }
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.gray.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
                .opacity(0.6)
        )
    }

    // MARK: - Helpers

    private func addNote() {
        manager.addNote(newNoteText)
        newNoteText = ""
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
