//
//  ScrollCommandSubmenu.swift
//  simdock
//

import SwiftUI

struct ScrollCommandSubmenu: View {
    var addCommand: CommandHandler

    var body: some View {
        VStack(spacing: 8) {
            VStack(spacing: 5) {
                CommandPanelTitle(title: "Scroll")

                gestureGrid(
                    top: .scrollUp,
                    left: .scrollLeft,
                    right: .scrollRight,
                    bottom: .scrollDown
                )
            }

            CommandPanelDivider()

            VStack(spacing: 5) {
                CommandPanelTitle(title: "Edge")

                gestureGrid(
                    top: .swipeFromTopEdge,
                    left: .swipeFromLeftEdge,
                    right: .swipeFromRightEdge,
                    bottom: .swipeFromBottomEdge
                )
            }
        }
    }

    private func gestureGrid(
        top: SimulatorGesture,
        left: SimulatorGesture,
        right: SimulatorGesture,
        bottom: SimulatorGesture
    ) -> some View {
        Grid(horizontalSpacing: 4, verticalSpacing: 4) {
            GridRow {
                Color.clear.frame(width: 30, height: 30)
                GesturePadButton(gesture: top, action: { send(top) })
                Color.clear.frame(width: 30, height: 30)
            }

            GridRow {
                GesturePadButton(gesture: left, action: { send(left) })
                Color.clear.frame(width: 30, height: 30)
                GesturePadButton(gesture: right, action: { send(right) })
            }

            GridRow {
                Color.clear.frame(width: 30, height: 30)
                GesturePadButton(gesture: bottom, action: { send(bottom) })
                Color.clear.frame(width: 30, height: 30)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func send(_ gesture: SimulatorGesture) {
        addCommand("gesture", gesture.rawValue)
    }
}
