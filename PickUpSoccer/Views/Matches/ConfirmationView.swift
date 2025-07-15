import SwiftUI

struct ConfirmationView: View {
    // 通用属性
    var title: String = "请确认" // 提供一个默认标题
    let message: String
    let confirmAction: () -> Void
    var cancelAction: (() -> Void)? = nil // 取消操作变为可选

    // 便利初始化器，用于之前的语音识别场景
    init(
        recognizedText: String,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.title = "识别到的内容"
        self.message = recognizedText
        self.confirmAction = onConfirm
        self.cancelAction = onCancel
    }

    // 主初始化器，用于通用场景
    init(
        title: String,
        message: String,
        confirmAction: @escaping () -> Void,
        cancelAction: (() -> Void)? = nil // 允许多一个取消操作
    ) {
        self.title = title
        self.message = message
        self.confirmAction = confirmAction
        self.cancelAction = cancelAction
    }

    var body: some View {
        VStack(spacing: 20) {
            Text(title)
                .font(.title2).bold()

            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)

            HStack(spacing: 20) {
                // 如果提供了取消操作，就显示取消按钮
                if let cancelAction = cancelAction {
                    Button("取消", role: .destructive, action: cancelAction)
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                }

                Button("确认", role: .none, action: confirmAction)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
        }
        .padding()
    }
} 