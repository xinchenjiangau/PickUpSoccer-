//
//  MatchActionsView.swift
//  PickUpSoccer
//
//  Created by xc j on 6/24/25.
//

import SwiftUI

struct MatchActionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var session: WatchMatchSession
    @State private var showAddPlayerSheet = false
    
    var body: some View {
        VStack(spacing: 15) {
            Text("比赛管理")
                .font(.headline)
            
            Text("球员管理请在手机端操作")
                .font(.footnote)
                .foregroundColor(.gray)

            // End Match Button
            Button(role: .destructive) {
                endMatch()
            } label: {
                Label("结束比赛", systemImage: "xmark.circle.fill")
            }
        }
    }


    
    private func endMatch() {
        WatchConnectivityManager.shared.endMatchFromWatch()
    }
}

