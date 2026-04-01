import SwiftUI

@main
struct AdAstraApp: App {
    
    @StateObject private var habitTracker = HabitTracker.shared
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            GameContainerView()
                .environmentObject(habitTracker)
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - Game Container (bridges UIKit/SpriteKit into SwiftUI lifecycle)

struct GameContainerView: View {
    @EnvironmentObject var habitTracker: HabitTracker
    @State private var showHabitSetup = false
    
    var body: some View {
        SpriteKitContainer()
            .ignoresSafeArea()
            .onAppear {
                showHabitSetup = habitTracker.needsDailySetup
            }
            // FIX: Ascolta la notifica proveniente dal MainMenuScene
            .onReceive(NotificationCenter.default.publisher(for: .showHabitSetup)) { _ in
                showHabitSetup = true
            }
            .sheet(isPresented: $showHabitSetup) {
                HabitSetupView(habitTracker: habitTracker) {
                    showHabitSetup = false
                    // FIX: Fai partire il gioco automaticamente dopo aver inserito l'obiettivo!
                    NotificationCenter.default.post(name: Notification.Name("startGameAutomatically"), object: nil)
                }
            }
    }
}

// MARK: - SpriteKit View Wrapper

struct SpriteKitContainer: UIViewRepresentable {
    func makeUIView(context: Context) -> SKView {
        let view = SKView()
        view.preferredFramesPerSecond = 60
        view.ignoresSiblingOrder = true
        #if DEBUG
        view.showsFPS = true
        view.showsNodeCount = true
        #endif
        
        let scene = MainMenuScene(size: CGSize(width: 393, height: 852))
        scene.scaleMode = .aspectFill
        view.presentScene(scene)
        
        return view
    }
    
    func updateUIView(_ uiView: SKView, context: Context) {}
}

import SpriteKit
