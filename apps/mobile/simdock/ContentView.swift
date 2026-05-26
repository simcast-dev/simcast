//
//  ContentView.swift
//  simdock
//
//  Created by Ioan-Florin Matincă on 25.05.2026.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        SimDockScreen()
    }
}

#Preview("Narrow iPad Window") {
    ContentView()
        .frame(width: 430, height: 900)
}

#Preview("Wide iPad Window") {
    ContentView()
        .frame(width: 760, height: 900)
}
