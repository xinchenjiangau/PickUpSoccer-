//
//  SeasonListView.swift
//  PickUpSoccer
//
//  Created by xc j on 1/5/26.
//

import SwiftUI
import SwiftData

struct SeasonListView: View {
    @Environment(\.modelContext) private var modelContext
    // 按结束时间倒序排列，最近的赛季在上面
    @Query(sort: \Season.endDate, order: .reverse) private var seasons: [Season]
    
    @State private var showingAddSeason = false
    @State private var newSeasonName = ""
    @State private var newStartDate = Date()
    @State private var newEndDate = Date().addingTimeInterval(86400 * 90) // 默认3个月
    
    var body: some View {
        List {
            ForEach(seasons) { season in
                NavigationLink(destination: SeasonEditView(season: season)) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(season.name)
                                .font(.headline)
                            Text("\(formattedDate(season.startDate)) - \(formattedDate(season.endDate))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if season.isCurrent {
                            Text("当前")
                                .font(.caption)
                                .fontWeight(.bold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(8)
                        }
                    }
                }
            }
            .onDelete(perform: deleteSeasons)
        }
        .navigationTitle("赛季管理")
        .toolbar {
            Button(action: { showingAddSeason = true }) {
                Image(systemName: "plus")
            }
        }
        .sheet(isPresented: $showingAddSeason) {
            NavigationStack {
                Form {
                    Section("新赛季信息") {
                        TextField("赛季名称 (如: 2025春季赛)", text: $newSeasonName)
                        DatePicker("开始时间", selection: $newStartDate, displayedComponents: .date)
                        DatePicker("结束时间", selection: $newEndDate, displayedComponents: .date)
                    }
                    
                    Section {
                        Text("创建后，您可以在详情页添加球员。")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .navigationTitle("新建赛季")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { showingAddSeason = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") {
                            addSeason()
                            showingAddSeason = false
                        }
                        .disabled(newSeasonName.isEmpty)
                    }
                }
            }
        }
    }
    
    private func addSeason() {
        // 如果是第一个赛季，自动设为当前赛季
        let isFirst = seasons.isEmpty
        let newSeason = Season(name: newSeasonName, startDate: newStartDate, endDate: newEndDate, isCurrent: isFirst)
        modelContext.insert(newSeason)
    }
    
    private func deleteSeasons(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(seasons[index])
            }
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: date)
    }
}


