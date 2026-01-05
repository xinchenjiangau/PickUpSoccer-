//
//  SeasonEditView.swift
//  PickUpSoccer
//
//  Created by xc j on 1/5/26.
//

import SwiftUI
import SwiftData

struct SeasonEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var season: Season
    @Query private var allSeasons: [Season] // 用于处理互斥的"当前赛季"逻辑
    
    var body: some View {
        Form {
            Section("基本信息") {
                TextField("赛季名称", text: $season.name)
                DatePicker("开始时间", selection: $season.startDate, displayedComponents: .date)
                DatePicker("结束时间", selection: $season.endDate, displayedComponents: .date)
                
                Toggle("设为当前赛季", isOn: $season.isCurrent)
                    .onChange(of: season.isCurrent) { oldValue, newValue in
                        if newValue {
                            // 如果设为当前，取消其他赛季的当前状态
                            for s in allSeasons where s.id != season.id {
                                s.isCurrent = false
                            }
                        }
                    }
            }
            
            // 跳转到成员管理页面的入口
            Section("成员管理") {
                NavigationLink(destination: SeasonPlayerManagementView(season: season)) {
                    HStack {
                        Text("管理参赛球员")
                        Spacer()
                        Text("\(season.players?.count ?? 0) 人")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Section("数据统计") {
                LabeledContent("关联比赛场次", value: "\(season.matches?.count ?? 0)")
            }
        }
        .navigationTitle("编辑赛季")
        .navigationBarTitleDisplayMode(.inline)
    }
}
