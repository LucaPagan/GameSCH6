import SwiftUI
import SpriteKit

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

// MARK: - Game Container

struct GameContainerView: View {
    @EnvironmentObject var habitTracker: HabitTracker
    @State private var showHabitSetup = false
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            SpriteKitContainer()
                .ignoresSafeArea()
                .navigationDestination(for: String.self) { destination in
                    switch destination {
                    case "profile":
                        ProfileView()
                    case "settings":
                        SettingsView()
                    default:
                        EmptyView()
                    }
                }
        }
        .onAppear {
            showHabitSetup = habitTracker.needsDailySetup
        }
        .onReceive(NotificationCenter.default.publisher(for: .showHabitSetup)) { _ in
            showHabitSetup = true
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("showProfile"))) { _ in
            navigationPath.append("profile")
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("showSettings"))) { _ in
            navigationPath.append("settings")
        }
        .sheet(isPresented: $showHabitSetup) {
            HabitSetupView(habitTracker: habitTracker) {
                showHabitSetup = false
                NotificationCenter.default.post(
                    name: Notification.Name("startGameAutomatically"), object: nil)
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
