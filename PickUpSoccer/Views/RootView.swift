//
//  RootView.swift
//  PickUpSoccer
//
//  Created by xc j on 6/25/25.
//

import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ContentView()
            .environmentObject(AuthManager(modelContext: modelContext))
    }
}

