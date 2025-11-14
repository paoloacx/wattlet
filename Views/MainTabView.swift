import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var stravaService: StravaService
    @EnvironmentObject var zonesManager: ZonesManager
    @EnvironmentObject var userProfile: UserProfile
    
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Image(systemName: "bolt.fill")
                    Text("Power")
                }
            
            TTEView()
                .tabItem {
                    Image(systemName: "timer")
                    Text("TTE")
                }
            
            CyclistProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Profile")
                }
        }
        .accentColor(.orange)
    }
}
