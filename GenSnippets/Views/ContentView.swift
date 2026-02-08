import SwiftUI

struct ContentView: View {
    @State private var isQuitting = false
    
    var body: some View {
        ThreeColumnView()
            .frame(minWidth: 780, minHeight: 550)
        // Replace modern alert with custom alert sheet for macOS 11.5 compatibility
        .sheet(isPresented: $isQuitting) {
            VStack(spacing: 20) {
                Text("Quit Application".localized)
                    .font(.headline)
                
                Text("Do you want to quit completely or keep running in the background?".localized)
                    .multilineTextAlignment(.center)
                
                HStack(spacing: 20) {
                    Button("Run in Background".localized) {
                        isQuitting = false
                        // hideDockIcon handles orderOut for all windows
                        NotificationCenter.default.post(name: NSNotification.Name("HideDockIcon"), object: nil)
                    }
                    .buttonStyle(ModernButtonStyle(isPrimary: false))
                    .keyboardShortcut(.escape)
                    
                    Button("Quit".localized) {
                        // Stop monitoring and cleanup
                        TextReplacementService.shared.stopMonitoring()
                        // Set isQuitting to false before posting notification
                        isQuitting = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            // Post notification for actual quit with a slight delay
                            NotificationCenter.default.post(name: NSNotification.Name("ConfirmedQuit"), object: nil)
                        }
                    }
                    .buttonStyle(ModernButtonStyle(isDestructive: true))
                    .keyboardShortcut(.defaultAction)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
            }
            .padding()
            .frame(width: 400, height: 150)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowQuitDialog"))) { _ in
            isQuitting = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("HideDockIcon"))) { _ in
            // Reset quit dialog if entering background via another code path
            isQuitting = false
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
} 