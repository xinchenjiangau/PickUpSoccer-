//
//  AddPlayerView.swift
//  PickUpSoccer
//
//  Created by xc j on 6/24/25.
//

import SwiftUI

struct AddPlayerView: View {
    @Environment(\.dismiss) private var dismiss
    
    let onSave: (String, Bool) -> Void

    @State private var playerName = ""
    @State private var isHomeTeam = true

    var body: some View {
        NavigationStack {
            Form {
                TextField("球员姓名", text: $playerName)
                Toggle(isHomeTeam ? "主队" : "客队", isOn: $isHomeTeam)
            }
            .navigationTitle("添加新球员")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(playerName, isHomeTeam)
                        dismiss()
                    }.disabled(playerName.isEmpty)
                }
            }
        }
    }
}

