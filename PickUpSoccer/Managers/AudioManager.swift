import Foundation
import AVFoundation
import Speech

class AudioManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recognizedText = ""
    @Published var permissionGranted = false
    @Published var showPermissionAlert = false
    @Published var permissionError: String?
    
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    
    var recordingCallback: ((String) -> Void)?
    
    override init() {
        super.init()
        checkPermissions()
    }
    
    func checkPermissions() {
        // 检查语音识别权限
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    print("语音识别已授权")
                    self?.checkMicrophonePermission()
                case .denied:
                    self?.handlePermissionError("语音识别权限被拒绝")
                case .restricted:
                    self?.handlePermissionError("语音识别功能受限")
                case .notDetermined:
                    self?.handlePermissionError("请在设置中授权语音识别")
                @unknown default:
                    self?.handlePermissionError("未知错误")
                }
            }
        }
    }
    
    private func checkMicrophonePermission() {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            self.permissionGranted = true
        case .denied:
            handlePermissionError("麦克风权限被拒绝")
        case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.permissionGranted = true
                    } else {
                        self?.handlePermissionError("麦克风权限被拒绝")
                    }
                }
            }
        @unknown default:
            handlePermissionError("未知错误")
        }
    }
    
    private func handlePermissionError(_ message: String) {
        permissionError = message
        showPermissionAlert = true
        permissionGranted = false
    }
    
    func startRecording() throws {
        // 检查权限
        guard permissionGranted else {
            handlePermissionError("请先授予必要的权限")
            return
        }
        
        // 重置之前的任务
        resetAudio()
        
        // 配置音频会话
        try AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement, options: .duckOthers)
        try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        
        // 创建音频引擎和输入节点
        audioEngine = AVAudioEngine()
        guard let inputNode = audioEngine?.inputNode else { return }
        
        // 创建识别请求
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true
        
        // 开始识别任务
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                self.recognizedText = result.bestTranscription.formattedString
                if result.isFinal {
                    self.recordingCallback?(self.recognizedText)
                }
            }
            
            if error != nil {
                self.stopRecording()
            }
        }
        
        // 安装音频tap
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        // 启动音频引擎
        try audioEngine?.start()
        isRecording = true
    }
    
    func stopRecording() {
        audioEngine?.stop()
        recognitionRequest?.endAudio()
        isRecording = false
        
        // 处理最终识别的文本
        if !recognizedText.isEmpty {
            recordingCallback?(recognizedText)
        }
        
        resetAudio()
    }
    
    private func resetAudio() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
    }
} 