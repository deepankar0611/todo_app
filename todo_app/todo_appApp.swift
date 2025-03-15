import SwiftUI
import Firebase  // ✅ Ensure this is correctly imported

@main
struct todo_appApp: App {
    init() {
        FirebaseApp.configure()  // ✅ Firebase should be initialized here
    }

    var body: some Scene {
        WindowGroup {
            LoginView()
        }
    }
}
