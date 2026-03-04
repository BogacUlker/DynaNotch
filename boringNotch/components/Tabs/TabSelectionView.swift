//
//  TabSelectionView.swift
//  boringNotch
//
//  Created by Hugo Persson on 2024-08-25.
//

import Defaults
import SwiftUI

struct TabModel: Identifiable {
    let id = UUID()
    let label: String
    let icon: String
    let view: NotchViews
}

struct TabSelectionView: View {
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @Default(.enablePomodoro) var enablePomodoro
    @Default(.enableSystemMonitor) var enableSystemMonitor
    @Default(.enableQuickNotes) var enableQuickNotes
    @Namespace var animation

    private var visibleTabs: [TabModel] {
        var result = [
            TabModel(label: "Home", icon: "house.fill", view: .home),
            TabModel(label: "Shelf", icon: "tray.fill", view: .shelf),
        ]
        if enableQuickNotes {
            result.append(TabModel(label: "Notes", icon: "note.text", view: .quickNotes))
        }
        if enablePomodoro {
            result.append(TabModel(label: "Pomodoro", icon: "timer", view: .pomodoro))
        }
        if enableSystemMonitor {
            result.append(TabModel(label: "Monitor", icon: "gauge.with.dots.needle.33percent", view: .systemMonitor))
        }
        return result
    }

    private var tabPadding: CGFloat {
        visibleTabs.count > 4 ? 10 : 15
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(visibleTabs) { tab in
                    TabButton(label: tab.label, icon: tab.icon, horizontalPadding: tabPadding, selected: coordinator.currentView == tab.view) {
                        withAnimation(.smooth) {
                            coordinator.currentView = tab.view
                        }
                    }
                    .frame(height: 26)
                    .foregroundStyle(tab.view == coordinator.currentView ? .white : .gray)
                    .background {
                        if tab.view == coordinator.currentView {
                            Capsule()
                                .fill(coordinator.currentView == tab.view ? Color(nsColor: .secondarySystemFill) : Color.clear)
                                .matchedGeometryEffect(id: "capsule", in: animation)
                        } else {
                            Capsule()
                                .fill(coordinator.currentView == tab.view ? Color(nsColor: .secondarySystemFill) : Color.clear)
                                .matchedGeometryEffect(id: "capsule", in: animation)
                                .hidden()
                        }
                    }
            }
        }
        .clipShape(Capsule())
    }
}

#Preview {
    BoringHeader().environmentObject(BoringViewModel())
}
