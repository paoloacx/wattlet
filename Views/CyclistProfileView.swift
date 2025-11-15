import SwiftUI

struct CyclistProfileView: View {
    @EnvironmentObject var userProfile: UserProfile
    @EnvironmentObject var zonesManager: ZonesManager
    @EnvironmentObject var stravaService: StravaService
    @State private var showImagePicker = false
    @State private var profileImage: Image? = nil
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    ProfilePhotoCard(profileImage: $profileImage, showImagePicker: $showImagePicker)
                    
                    CoreMetricsCard()
                        .environmentObject(userProfile)
                        .environmentObject(zonesManager)
                        .environmentObject(stravaService)
                    
                    CyclistTypeCard()
                        .environmentObject(zonesManager)
                    
                    StrengthsCard()
                        .environmentObject(zonesManager)
                    
                    TrainingPlanCard()
                        .environmentObject(zonesManager)
                    
                    StravaConnectionCard()
                        .environmentObject(stravaService)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Cyclist Profile")
        }
    }
}

struct ProfilePhotoCard: View {
    @Binding var profileImage: Image?
    @Binding var showImagePicker: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            if let image = profileImage {
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.gray)
            }
            
            Button("Change Photo") {
                showImagePicker = true
            }
            .font(.caption)
            .foregroundColor(.orange)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.gray.opacity(0.1))
        .cornerRadius(16)
    }
}

struct CoreMetricsCard: View {
    @EnvironmentObject var userProfile: UserProfile
    @EnvironmentObject var zonesManager: ZonesManager
    @EnvironmentObject var stravaService: StravaService
    @State private var isEditing = false
    @State private var dismissedSuggestions = false
    
    @State private var ftpText = ""
    @State private var maxHRText = ""
    @State private var restingHRText = ""
    @State private var vt1PowerText = ""
    @State private var vt2PowerText = ""
    @State private var vt1HRText = ""
    @State private var vt2HRText = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Core Metrics")
                    .font(.headline)
                Spacer()
                Button(isEditing ? "Save" : "Edit") {
                    if isEditing {
                        saveMetrics()
                    }
                    isEditing.toggle()
                }
                .font(.caption)
                .foregroundColor(.orange)
            }
            
            if isEditing {
                VStack(spacing: 8) {
                    MetricInputRow(label: "FTP", value: $ftpText, unit: "W")
                    MetricInputRow(label: "Max HR", value: $maxHRText, unit: "bpm")
                    MetricInputRow(label: "Resting HR", value: $restingHRText, unit: "bpm")
                    MetricInputRow(label: "VT1 Power", value: $vt1PowerText, unit: "W")
                    MetricInputRow(label: "VT1 HR", value: $vt1HRText, unit: "bpm")
                    MetricInputRow(label: "VT2 Power", value: $vt2PowerText, unit: "W")
                    MetricInputRow(label: "VT2 HR", value: $vt2HRText, unit: "bpm")
                }
            } else {
                VStack(spacing: 6) {
                    MetricDisplayRow(label: "FTP", value: "\(zonesManager.ftp) W")
                    MetricDisplayRow(label: "Max HR", value: "\(userProfile.maxHR) bpm")
                    MetricDisplayRow(label: "Resting HR", value: "\(userProfile.restingHR) bpm")
                    MetricDisplayRow(label: "VT1", value: "\(userProfile.vt1Power) W / \(userProfile.vt1HR) bpm")
                    MetricDisplayRow(label: "VT2", value: "\(userProfile.vt2Power) W / \(userProfile.vt2HR) bpm")
                }
                
                if let estimates = stravaService.estimateThresholds(), !dismissedSuggestions {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Auto-Estimated Values")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Spacer()
                            Button("Dismiss") {
                                dismissedSuggestions = true
                            }
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        }
                        
                        if abs(estimates.ftp - zonesManager.ftp) > zonesManager.ftp / 20 {
                            SuggestionRow(
                                label: "FTP",
                                current: "\(zonesManager.ftp) W",
                                suggested: "\(estimates.ftp) W",
                                onAccept: {
                                    zonesManager.updateFTP(estimates.ftp)
                                    userProfile.ftp = estimates.ftp
                                    userProfile.saveProfile()
                                }
                            )
                        }
                        
                        if abs(estimates.vt1Power - userProfile.vt1Power) > userProfile.vt1Power / 20 || userProfile.vt1Power == 0 {
                            SuggestionRow(
                                label: "VT1",
                                current: userProfile.vt1Power > 0 ? "\(userProfile.vt1Power) W" : "Not set",
                                suggested: "\(estimates.vt1Power) W / \(estimates.vt1HR) bpm",
                                onAccept: {
                                    userProfile.vt1Power = estimates.vt1Power
                                    userProfile.vt1HR = estimates.vt1HR
                                    userProfile.saveProfile()
                                }
                            )
                        }
                        
                        if abs(estimates.vt2Power - userProfile.vt2Power) > userProfile.vt2Power / 20 || userProfile.vt2Power == 0 {
                            SuggestionRow(
                                label: "VT2",
                                current: userProfile.vt2Power > 0 ? "\(userProfile.vt2Power) W" : "Not set",
                                suggested: "\(estimates.vt2Power) W / \(estimates.vt2HR) bpm",
                                onAccept: {
                                    userProfile.vt2Power = estimates.vt2Power
                                    userProfile.vt2HR = estimates.vt2HR
                                    userProfile.saveProfile()
                                }
                            )
                        }
                    }
                }
            }
        }
        .padding()
        .background(.gray.opacity(0.1))
        .cornerRadius(16)
        .onAppear {
            loadMetrics()
        }
    }
    
    func loadMetrics() {
        ftpText = "\(zonesManager.ftp)"
        maxHRText = "\(userProfile.maxHR)"
        restingHRText = "\(userProfile.restingHR)"
        vt1PowerText = "\(userProfile.vt1Power)"
        vt2PowerText = "\(userProfile.vt2Power)"
        vt1HRText = "\(userProfile.vt1HR)"
        vt2HRText = "\(userProfile.vt2HR)"
    }
    
    func saveMetrics() {
        if let ftp = Int(ftpText) {
            zonesManager.updateFTP(ftp)
            userProfile.ftp = ftp
        }
        if let maxHR = Int(maxHRText) { userProfile.maxHR = maxHR }
        if let restingHR = Int(restingHRText) { userProfile.restingHR = restingHR }
        if let vt1Power = Int(vt1PowerText) { userProfile.vt1Power = vt1Power }
        if let vt2Power = Int(vt2PowerText) { userProfile.vt2Power = vt2Power }
        if let vt1HR = Int(vt1HRText) { userProfile.vt1HR = vt1HR }
        if let vt2HR = Int(vt2HRText) { userProfile.vt2HR = vt2HR }
        userProfile.saveProfile()
    }
}

struct MetricInputRow: View {
    let label: String
    @Binding var value: String
    let unit: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            TextField("", text: $value)
                .multilineTextAlignment(.trailing)
                .frame(width: 60)
                .font(.system(.caption, design: .monospaced))
            Text(unit)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct MetricDisplayRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.semibold)
        }
    }
}

struct CyclistTypeCard: View {
    @EnvironmentObject var zonesManager: ZonesManager
    
    var cyclistType: String {
        "All-Rounder"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cyclist Type")
                .font(.headline)
            
            HStack {
                Image(systemName: "figure.outdoor.cycle")
                    .font(.title)
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading) {
                    Text(cyclistType)
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("Based on your power curve analysis")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.gray.opacity(0.1))
        .cornerRadius(16)
    }
}

struct StrengthsCard: View {
    @EnvironmentObject var zonesManager: ZonesManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Strengths & Weaknesses")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundColor(.green)
                    Text("Strong: 5-min power")
                        .font(.caption)
                }
                
                HStack {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(.red)
                    Text("Needs work: Sprint power")
                        .font(.caption)
                }
                
                HStack {
                    Image(systemName: "equal.circle.fill")
                        .foregroundColor(.yellow)
                    Text("Average: Endurance")
                        .font(.caption)
                }
            }
            
            Text("Feed your power curve to get personalized insights")
                .font(.caption2)
                .foregroundColor(.secondary)
                .italic()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.gray.opacity(0.1))
        .cornerRadius(16)
    }
}

struct TrainingPlanCard: View {
    @EnvironmentObject var zonesManager: ZonesManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FTP Goal")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Current FTP:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(zonesManager.ftp) W")
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.bold)
                }
                
                HStack {
                    Text("Suggested focus:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Maintain & Build")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                }
            }
            
            Text("Complete more activities to refine recommendations")
                .font(.caption2)
                .foregroundColor(.secondary)
                .italic()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.gray.opacity(0.1))
        .cornerRadius(16)
    }
}

struct StravaConnectionCard: View {
    @EnvironmentObject var stravaService: StravaService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Strava Connection")
                .font(.headline)
            
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Connected")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            
            Button("Disconnect Strava") {
                UserDefaults.standard.removeObject(forKey: "strava_token")
                UserDefaults.standard.removeObject(forKey: "power_curve_cache")
                stravaService.isAuthenticated = false
                stravaService.accessToken = nil
            }
            .font(.caption)
            .foregroundColor(.red)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.gray.opacity(0.1))
        .cornerRadius(16)
    }
}

struct SuggestionRow: View {
    let label: String
    let current: String
    let suggested: String
    let onAccept: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
                Button("Accept") {
                    onAccept()
                }
                .font(.caption)
                .foregroundColor(.orange)
            }
            
            HStack {
                            Text("Current: \(current)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("→ \(suggested)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
        }
    }
}
