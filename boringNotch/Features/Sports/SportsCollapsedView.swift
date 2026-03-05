//
//  SportsCollapsedView.swift
//  boringNotch
//
//  Created by DynaNotch on 2026-03-04.
//  GPL v3 License
//

import SwiftUI

/// Compact collapsed chip for the carousel system.
/// Shows the first live event's collapsed text (e.g. "FB 2-1 GS 67'").
struct SportsCollapsedChip: View {
    @ObservedObject var manager = SportsManager.shared

    var body: some View {
        if let text = manager.currentCollapsedText {
            HStack(spacing: 3) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 4, height: 4)
                Text(text)
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                    .fixedSize()
                    .lineLimit(1)
            }
        }
    }
}
