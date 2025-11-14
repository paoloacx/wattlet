import SwiftUI

@main
struct WattletApp: App {
    @StateObject private var stravaService = StravaService()
    @StateObject private var zonesManager = ZonesManager()
    @StateObject private var userProfile = UserProfile()
    
    var body: some Scene {
        WindowGroup {
            if stravaService.isAuthenticated {
                HomeView()
                    .environmentObject(stravaService)
                    .environmentObject(zonesManager)
                    .environmentObject(userProfile)
                    .onAppear {
                        zonesManager.loadSavedFTP()
                    }
            } else {
                StravaAuthView()
                    .environmentObject(stravaService)
                    .onAppear {
                        stravaService.loadSavedToken()
                    }
            }
        }
    }
}
