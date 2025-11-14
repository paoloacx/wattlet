import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var userProfile: UserProfile
    @EnvironmentObject var zonesManager: ZonesManager
    @EnvironmentObject var stravaService: StravaService
    @Environment(\.dismiss) var dismiss
    
    @State private var ftpText: String = ""
    @State private var maxHRText: String = ""
    @State private var restingHRText: String = ""
    @State private var vt1PowerText: String = ""
    @State private var vt2PowerText: String = ""
    @State private var vt1HRText: String = ""
    @State private var vt2HRText: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Power")) {
                    HStack {
                        Text("FTP")
                        Spacer()
                        TextField("watts", text: $ftpText)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("W")
                    }
                }
                
                Section(header: Text("Heart Rate")) {
                    HStack {
                        Text("Max HR")
                        Spacer()
                        TextField("bpm", text: $maxHRText)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("bpm")
                    }
                    HStack {
                        Text("Resting HR")
                        Spacer()
                        TextField("bpm", text: $restingHRText)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("bpm")
                    }
                }
                
                Section(header: Text("Ventilatory Thresholds")) {
                    HStack {
                        Text("VT1 Power")
                        Spacer()
                        TextField("watts", text: $vt1PowerText)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("W")
                    }
                    HStack {
                        Text("VT1 HR")
                        Spacer()
                        TextField("bpm", text: $vt1HRText)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("bpm")
                    }
                    HStack {
                        Text("VT2 Power")
                        Spacer()
                        TextField("watts", text: $vt2PowerText)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("W")
                    }
                    HStack {
                        Text("VT2 HR")
                        Spacer()
                        TextField("bpm", text: $vt2HRText)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("bpm")
                    }
                }
                
                Section {
                    Button("Disconnect Strava", role: .destructive) {
                        UserDefaults.standard.removeObject(forKey: "strava_token")
                        UserDefaults.standard.removeObject(forKey: "power_curve_cache")
                        stravaService.isAuthenticated = false
                        stravaService.accessToken = nil
                        dismiss()
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveSettings() }
                }
            }
            .onAppear {
                ftpText = "\(userProfile.ftp)"
                maxHRText = "\(userProfile.maxHR)"
                restingHRText = "\(userProfile.restingHR)"
                vt1PowerText = "\(userProfile.vt1Power)"
                vt2PowerText = "\(userProfile.vt2Power)"
                vt1HRText = "\(userProfile.vt1HR)"
                vt2HRText = "\(userProfile.vt2HR)"
            }
        }
    }
    
    func saveSettings() {
        if let ftp = Int(ftpText) {
            userProfile.ftp = ftp
            zonesManager.updateFTP(ftp)
        }
        if let maxHR = Int(maxHRText) { userProfile.maxHR = maxHR }
        if let restingHR = Int(restingHRText) { userProfile.restingHR = restingHR }
        if let vt1Power = Int(vt1PowerText) { userProfile.vt1Power = vt1Power }
        if let vt2Power = Int(vt2PowerText) { userProfile.vt2Power = vt2Power }
        if let vt1HR = Int(vt1HRText) { userProfile.vt1HR = vt1HR }
        if let vt2HR = Int(vt2HRText) { userProfile.vt2HR = vt2HR }
        
        userProfile.saveProfile()
        dismiss()
    }
}
