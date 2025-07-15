//
//  WaitingForMatchView.swift
//  PickUpSoccer
//
//  Created by xc j on 6/24/25.
//

import SwiftUI

struct WaitingForMatchView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "applewatch.radiowaves.left.and.right")
                .font(.largeTitle)
                .foregroundStyle(.green)
            
            Text("等待比赛")
                .font(.headline)
            
            Text("请在iPhone上开始一场新比赛。")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
    }
}

