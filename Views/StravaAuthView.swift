import SwiftUI

struct StravaAuthView: View {
    @EnvironmentObject var stravaService: StravaService
    @Environment(\.openURL) var openURL
    @State private var authCode: String = ""
    @State private var showCodeInput: Bool = false
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "bicycle")
                .font(.system(size: 80))
                .foregroundColor(.orange)
            
            Text("Wattlet")
                .font(.system(size: 48, weight: .bold, design: .rounded))
            
            Text("Connect with Strava to analyze your power data")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Button(action: {
                Task {
                    await openURL(stravaService.getAuthURL())
                }
                showCodeInput = true
            }) {
                HStack {
                    Image(systemName: "link")
                    Text("Connect Strava")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange)
                .cornerRadius(12)
            }
            .padding(.horizontal, 40)
            
            if showCodeInput {
                VStack(spacing: 12) {
                    Text("Paste the code from the URL:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("Authorization code", text: $authCode)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal, 40)
                    
                    Button("Authenticate") {
                        Task {
                            await stravaService.authenticate(code: authCode)
                        }
                    }
                    .disabled(authCode.isEmpty)
                }
            }
        }
        .onOpenURL { url in
            handleOAuthCallback(url: url)
        }
    }
    
    func handleOAuthCallback(url: URL) {
        guard url.scheme == "wattlet",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            return
        }
        
        Task {
            await stravaService.authenticate(code: code)
        }
    }
}
