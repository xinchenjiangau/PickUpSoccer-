import SwiftUI
import SwiftData
import AVFoundation
import Speech
import WatchConnectivity

struct MatchRecordView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var coordinator: NavigationCoordinator
    @Bindable var match: Match
    @State private var showingEventSelection = false
    @State private var selectedTeamIsHome = true // Used to identify whether the home team or away team is selected
    // @State private var shouldNavigateToMatches = false  // Used to control navigation back to MatchesView
    @State private var currentTime = Date()
    @StateObject private var audioManager = AudioManager()
    @State private var showingConfirmation = false
    @State private var recognizedCommand = ""
    @State private var currentEvent: MatchEvent?
    @State private var showingAddPlayer = false
    @State private var showEndConfirmation = false
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var redTeamPlayers: [Player] {
        match.playerStats.filter { $0.isHomeTeam }.compactMap { $0.player }
    }
    
    var blueTeamPlayers: [Player] {
        match.playerStats.filter { !$0.isHomeTeam }.compactMap { $0.player }
    }
    
    var matchDuration: String {
        let duration = currentTime.timeIntervalSince(match.matchDate)
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // Calculate red team average score
    var redTeamAverageScore: Double {
        let redTeamStats = match.playerStats.filter { $0.isHomeTeam }
        guard !redTeamStats.isEmpty else { return 0 }
        return redTeamStats.reduce(0.0) { $0 + $1.score } / Double(redTeamStats.count)
    }
    
    // Calculate blue team average score
    var blueTeamAverageScore: Double {
        let blueTeamStats = match.playerStats.filter { !$0.isHomeTeam }
        guard !blueTeamStats.isEmpty else { return 0 }
        return blueTeamStats.reduce(0.0) { $0 + $1.score } / Double(blueTeamStats.count)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Score Area
            VStack(spacing: 20) {
                // Match time display
                Text(matchDuration)
                    .font(.custom("DingTalk JinBuTi", size: 20))
                    .foregroundColor(.black)
                    .padding(.top, 10)
                    .onReceive(timer) { _ in
                        // Only update time if match is in progress
                        if match.status == .inProgress {
                            currentTime = Date()
                        }
                    }
                
                // Add average score display
                HStack(spacing: 140) {
                    Text(String(format: "%.1f", redTeamAverageScore))
                        .font(.caption)
                        .foregroundColor(.red)
                    Text(String(format: "%.1f", blueTeamAverageScore))
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                
                // Team names
                HStack(spacing: 140) {
                    Text("Red Team")
                        .font(.custom("PingFang MO", size: 16))
                        .fontWeight(.medium)
                        .foregroundColor(.black)
                    
                    Text("Blue Team")
                        .font(.custom("PingFang MO", size: 16))
                        .fontWeight(.medium)
                        .foregroundColor(Color(red: 0.26, green: 0.56, blue: 0.81))
                }
                .padding(.horizontal, 40)
                
                // Score display
                HStack(spacing: 30) {
                    // Red team button
                    Button(action: {
                        selectedTeamIsHome = true
                        showingEventSelection = true
                    }) {
                        Text("\(match.homeScore)")
                            .font(.custom("Poppins", size: 60))
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                            .frame(width: 100, height: 100)
                            .background(
                                Circle()
                                    .fill(Color.red.opacity(0.5))
                            )
                    }
                    
                    Text("-")
                        .font(.custom("Poppins", size: 60))
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                    
                    // Blue team button
                    Button(action: {
                        selectedTeamIsHome = false
                        showingEventSelection = true
                    }) {
                        Text("\(match.awayScore)")
                            .font(.custom("Poppins", size: 60))
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                            .frame(width: 100, height: 100)
                            .background(
                                Circle()
                                    .fill(Color.blue.opacity(0.5))
                            )
                    }
                }
            }
            .padding(.vertical, 20)
            .background(Color.white)
            
            
            // Timeline Title
            Text("Timeline")
                .font(.custom("PingFang MO", size: 24))
                .fontWeight(.medium)
                .foregroundColor(Color(red: 0.15, green: 0.50, blue: 0.27))
                .padding(.vertical, 20)
            
            // Timeline View
            TimelineView(match: match)
                .frame(maxHeight: .infinity)
            
            // Add recording button
            VStack {
                Button(action: handleRecordingButton) {
                    Image(systemName: audioManager.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(audioManager.isRecording ? .red : .blue)
                }
                .padding()
                
                if !audioManager.recognizedText.isEmpty {
                    Text(audioManager.recognizedText)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(.bottom)
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Back") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        showingAddPlayer = true
                    }) {
                        Label("Add Player", systemImage: "person.badge.plus")
                    }
                    
                    Button("End Match") {
                        showEndConfirmation = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        // .navigationDestination(isPresented: $shouldNavigateToMatches) {
        //     MatchesView()
        // }
        .sheet(isPresented: $showingEventSelection) {
            EventSelectionView(match: match, isHomeTeam: selectedTeamIsHome)
        }
        .sheet(isPresented: $showingConfirmation) {
            if let event = currentEvent {
                ConfirmationView(
                    recognizedText: recognizedCommand,
                    onConfirm: {
                        handleConfirmedEvent(event)
                        showingConfirmation = false
                    },
                    onCancel: {
                        showingConfirmation = false
                    }
                )
            }
        }
        .sheet(isPresented: $showingAddPlayer) {
            AddMatchPlayerView(match: match)
        }
        .sheet(isPresented: $showEndConfirmation) {
            ConfirmationView(
                title: "End Match",
                message: "Are you sure you want to end this match? Data cannot be modified after ending.",
                confirmAction: {
                    showEndConfirmation = false
                    // Delay execution to ensure sheet closes first
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        endMatch()
                    }
                },
                cancelAction: {
                    showEndConfirmation = false
                }
            )
        }
        .alert("Permissions Required", isPresented: $audioManager.showPermissionAlert) {
            Button("Go to Settings", role: .cancel) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .destructive) {
                audioManager.showPermissionAlert = false
            }
        } message: {
            Text(audioManager.permissionError ?? "Please grant necessary permissions in settings")
        }
        .onAppear {
            setupAudioManager()
            // Trigger a view refresh to ensure toolbar rendering
            _ = match.id
            WatchConnectivityManager.shared.sendStartMatchToWatch(match: match)
        }
        .onChange(of: match.status) { oldStatus, newStatus in
            if newStatus == .finished {
                coordinator.shouldDismissParticipationSheet = true
                dismiss()
            }
        }
    }
    
    private func setupAudioManager() {
        audioManager.recordingCallback = { text in
            recognizedCommand = text
            if let event = VoiceCommandParser.parseCommand(text, match: match) {
                currentEvent = event
                showingConfirmation = true
            }
        }
    }
    
    private func handleRecordingButton() {
        if audioManager.isRecording {
            audioManager.stopRecording()
        } else {
            if audioManager.permissionGranted {
                do {
                    try audioManager.startRecording()
                } catch {
                    print("Recording failed to start: \(error)")
                }
            } else {
                audioManager.checkPermissions()
            }
        }
    }
    
    private func handleConfirmedEvent(_ event: MatchEvent) {
        // Update score
        if event.eventType == .goal {
            if event.isHomeTeam {
                match.homeScore += 1
            } else {
                match.awayScore += 1
            }
            
            // Update player stats
            if let stats = match.playerStats.first(where: { $0.player?.id == event.scorer?.id }) {
                stats.goals += 1
            }
        } else if event.eventType == .save {
            // Update player stats
            // Ensure event.goalkeeper is used if available and correctly set in EventSelectionView
            if let stats = match.playerStats.first(where: { $0.player?.id == event.goalkeeper?.id }) { // Changed to event.goalkeeper
                stats.saves += 1
            }
        }
        
        modelContext.insert(event)
        match.events.append(event) // Removed: SwiftData handles inverse relationships automatically
        do {
            try modelContext.save()
            // [新增] 在语音事件保存成功后，调用同步函数
            WatchConnectivityManager.shared.sendEventToWatch(event, matchId: match.id)
        } catch {
            print("保存语音确认的事件失败: \(error)")
        }
    }
    
    private func endMatch() {
        // Update match status
        match.status = .finished
        
        // MARK: - 根本问题修复
        // 在保存比赛之前，调用函数来计算并更新所有的最终统计数据。
        match.updateMatchStats()
        
        // Per your request, this is commented out.
        // WatchConnectivityManager.shared.sendFullMatchEndToWatch(match: match)

        // Notify MatchesView to close sheet
        coordinator.shouldDismissParticipationSheet = true

        // Save the updated match object with correct stats and then dismiss.
        try? modelContext.save()
        dismiss()
    }
}

struct TimelineEventView: View {
    let event: MatchEvent
    let isLastEvent: Bool
    
    var eventTimeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: event.timestamp)
    }
    
    var eventDescription: String {
        switch event.eventType {
        case .goal:
            if let assistant = event.assistant {
                return "\(event.scorer?.name ?? "") Goal!\nAssist: \(assistant.name)"
            } else {
                return "\(event.scorer?.name ?? "") Goal!"
            }
        
        case .foul:
            return "\(event.scorer?.name ?? "") Foul"
        case .save:
            return "\(event.goalkeeper?.name ?? "") Save" // Changed to event.goalkeeper
        case .yellowCard:
            return "\(event.scorer?.name ?? "") Yellow Card"
        case .redCard:
            return "\(event.scorer?.name ?? "") Red Card"
        }
    }
    
    var eventColor: Color {
        switch event.eventType {
        case .goal:
            return .yellow
        
        case .foul:
            return .orange
        case .save:
            return .blue
        case .yellowCard:
            return .yellow
        case .redCard:
            return .red
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            // Time display
            Text(eventTimeString)
                .font(.custom("DingTalk JinBuTi", size: 14))
                .foregroundColor(.black)
            
            // Timeline
            VStack(spacing: 0) {
                Circle()
                    .fill(eventColor)
                    .frame(width: 12, height: 12)
                
                if !isLastEvent {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 2)
                        .frame(height: 40)
                }
            }
            
            // Event content
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: event.eventType == .goal ? "soccerball" : "hand.raised.fill")
                        .foregroundColor(eventColor)
                    Text(event.eventType.rawValue)
                        .font(.custom("PingFang MO", size: 16))
                        .foregroundColor(eventColor)
                }
                
                Text(eventDescription)
                    .font(.custom("PingFang MO", size: 14))
                    .foregroundColor(.black)
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
        }
        .padding(.horizontal)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Match.self, configurations: config)
    
    let newMatch = Match(
        id: UUID(),
        status: .notStarted,
        homeTeamName: "Red Team",
        awayTeamName: "Blue Team"
    )
    return MatchRecordView(match: newMatch)
        .modelContainer(container)
}
