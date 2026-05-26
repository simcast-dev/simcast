//
//  ControlPanel.swift
//  simdock
//

import SwiftUI

struct ControlPanel: View {
    @Binding var selectedMode: ControlMode
    @Binding var isRecording: Bool
    @Binding var typedText: String
    @Binding var linkText: String
    var addCommand: CommandHandler

    var body: some View {
        VStack(spacing: 12) {
            Picker("Command mode", selection: $selectedMode) {
                ForEach(ControlMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            modeContent
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    @ViewBuilder
    private var modeContent: some View {
        switch selectedMode {
        case .tap:
            TapControls(isRecording: $isRecording, addCommand: addCommand)
        case .type:
            TypeControls(text: $typedText, addCommand: addCommand)
        case .push:
            PushControls(addCommand: addCommand)
        case .link:
            LinkControls(linkText: $linkText, addCommand: addCommand)
        }
    }
}
