//
//  TeamSwitchTab.swift
//  PickUpSoccer
//
//  Created by xc j on 6/24/25.
//

import SwiftUI

struct TeamSwitchTab: View {
    @Binding var isHomeTeam: Bool

    var body: some View {
        Toggle("主队/客队", isOn: $isHomeTeam)
    }
}

