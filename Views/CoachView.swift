import SwiftUI

struct CoachView: View {
    @EnvironmentObject var stravaService: StravaService
    @EnvironmentObject var zonesManager: ZonesManager
    @EnvironmentObject var userProfile: UserProfile
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // FTP Status Card
                    FTPStatusCard()
                        .environmentObject(zonesManager)
                    
                    // Training Focus Card
                    TrainingFocusCard()
                        .environmentObject(zonesManager)
                        .environmentObject(stravaService)
                    
                    // Thresholds Check Card
                    ThresholdsCheckCard()
                        .environmentObject(userProfile)
                        .environmentObject(zonesManager)
                                        
                    // Recent Best Efforts Card
                                        RecentEffortsCard()
                                            .environmentObject(stravaService)
                                        
                                        // HR by Duration Card
                                        HRByDurationCard()
                                            .environmentObject(stravaService)
                    
                    Spacer()
                }
                .padding()
            }
            .background(GrainBackground())
            .navigationTitle("Wattlet Coach")
        }
    }
}

struct FTPStatusCard: View {
    @EnvironmentObject var zonesManager: ZonesManager
    @State private var ftpTrend: String = "stable"
    
    var trendIcon: String {
        switch ftpTrend {
        case "up": return "arrow.up.circle.fill"
        case "down": return "arrow.down.circle.fill"
        default: return "equal.circle.fill"
        }
    }
    
    var trendColor: Color {
        switch ftpTrend {
        case "up": return .green
        case "down": return .red
        default: return .yellow
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("FTP Status")
                    .font(.headline)
                Spacer()
                Image(systemName: trendIcon)
                    .foregroundColor(trendColor)
                    .font(.title2)
            }
            
            HStack(alignment: .firstTextBaseline) {
                Text("\(zonesManager.ftp)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                Text("watts")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Text("Your FTP has been stable for the last 4 weeks. Consider an FTP test if you've been training consistently.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .cardStyle()
    }
}

struct TrainingFocusCard: View {
    @EnvironmentObject var zonesManager: ZonesManager
    @EnvironmentObject var stravaService: StravaService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Training Focus")
                    .font(.headline)
                Spacer()
                HelpButton(
                    title: "Training Focus",
                    explanation: "Based on your power curve analysis, these are the areas where you can improve the most."
                )
            }
            
            VStack(alignment: .leading, spacing: 10) {
                FocusRow(
                    icon: "flame.fill",
                    color: .red,
                    title: "Sprint Power (5-15s)",
                    status: "Needs work",
                    suggestion: "Add 2x weekly sprint intervals"
                )
                
                FocusRow(
                    icon: "bolt.fill",
                    color: .orange,
                    title: "Anaerobic (1-5min)",
                    status: "Average",
                    suggestion: "VO2max intervals recommended"
                )
                
                FocusRow(
                    icon: "heart.fill",
                    color: .green,
                    title: "Endurance (20min+)",
                    status: "Strong",
                    suggestion: "Maintain with long rides"
                )
            }
        }
        .cardStyle()
    }
}

struct FocusRow: View {
    let icon: String
    let color: Color
    let title: String
    let status: String
    let suggestion: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    Text(status)
                        .font(.caption)
                        .foregroundColor(color)
                }
                Text(suggestion)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct ThresholdsCheckCard: View {
    @EnvironmentObject var userProfile: UserProfile
    @EnvironmentObject var zonesManager: ZonesManager
    
    var vt1Status: Bool {
        userProfile.vt1Power > 0
    }
    
    var vt2Status: Bool {
        userProfile.vt2Power > 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Ventilatory Thresholds")
                    .font(.headline)
                Spacer()
                HelpButton(
                    title: "VT1 & VT2",
                    explanation: "VT1 (aerobic threshold) and VT2 (anaerobic threshold) help define your training zones more precisely than FTP alone."
                )
            }
            
            VStack(spacing: 8) {
                ThresholdRow(
                    name: "VT1 / LT1",
                    configured: vt1Status,
                    value: vt1Status ? "\(userProfile.vt1Power)W" : "Not set"
                )
                
                ThresholdRow(
                    name: "VT2 / LT2",
                    configured: vt2Status,
                    value: vt2Status ? "\(userProfile.vt2Power)W" : "Not set"
                )
            }
            
            if !vt1Status || !vt2Status {
                Text("Configure your thresholds in Profile for more accurate zone training.")
                    .font(.caption)
                    .foregroundColor(.orange)
            } else {
                Text("Your thresholds are configured. Review them every 6-8 weeks.")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .cardStyle()
    }
}

struct ThresholdRow: View {
    let name: String
    let configured: Bool
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: configured ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundColor(configured ? .green : .orange)
            
            Text(name)
                .font(.subheadline)
            
            Spacer()
            
            Text(value)
                .font(.system(.subheadline, design: .monospaced))
                .foregroundColor(configured ? .primary : .secondary)
        }
    }
}
struct RecentEffortsCard: View {
    @EnvironmentObject var stravaService: StravaService
    @State private var isLoading = false
    @State private var loadingMessage = ""
    @State private var showYearView = false
    
    var topEfforts: [BestEffort] {
        if showYearView {
            // Show best from year history
            guard let history = UserDefaults.standard.array(forKey: "year_history_cache") as? [[String: Any]] else {
                return []
            }
            
            var bestByDuration: [Int: BestEffort] = [:]
            let labels: [Int: String] = [
                5: "5s", 10: "10s", 30: "30s", 60: "1m", 120: "2m", 300: "5m",
                600: "10m", 1200: "20m", 1800: "30m", 3600: "1h"
            ]
            
            for effort in history {
                let duration = effort["duration"] as? Int ?? 0
                let watts = effort["watts"] as? Int ?? 0
                let name = effort["name"] as? String ?? "Unknown"
                let timestamp = effort["date"] as? Double ?? 0
                let date = Date(timeIntervalSince1970: timestamp)
                
                if bestByDuration[duration] == nil || watts > bestByDuration[duration]!.watts {
                    let hrForDuration = effort["hrForDuration"] as? Int ?? 0
                    bestByDuration[duration] = BestEffort(
                        duration: duration,
                        label: labels[duration]!,
                        watts: watts,
                        hr: hrForDuration,
                        date: date,
                        activityName: name
                    )
                }
            }
            
            return bestByDuration.values
                .sorted { $0.duration < $1.duration }
                .prefix(5)
                .map { $0 }
        } else {
            // Show recent 12 weeks
            return stravaService.bestEfforts
                .filter { $0.watts > 0 }
                .sorted { $0.date > $1.date }
                .prefix(5)
                .map { $0 }
        }
    }
    
    var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(showYearView ? "Best Efforts (Year)" : "Recent Best Efforts")
                    .font(.headline)
                
                Spacer()
                
                Toggle("", isOn: $showYearView)
                    .labelsHidden()
                    .scaleEffect(0.7)
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Menu {
                        Button("Refresh (12 weeks)") {
                            Task {
                                isLoading = true
                                loadingMessage = "Fetching activities..."
                                UserDefaults.standard.removeObject(forKey: "power_curve_cache")
                                UserDefaults.standard.removeObject(forKey: "best_efforts_cache")
                                let _ = await stravaService.fetchPowerCurve()
                                isLoading = false
                                loadingMessage = ""
                            }
                        }
                        
                        Button("Load Full Year History") {
                            Task {
                                isLoading = true
                                UserDefaults.standard.removeObject(forKey: "year_history_cache")
                                let _ = await stravaService.fetchFullYearHistory { message in
                                    Task { @MainActor in
                                        loadingMessage = message
                                    }
                                }
                                isLoading = false
                                loadingMessage = ""
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.orange)
                    }
                }
            }
            
            if isLoading {
                VStack(spacing: 8) {
                    ProgressView()
                    Text(loadingMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else if topEfforts.isEmpty {
                Text("No power data available yet. Sync with Strava to see your best efforts.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(topEfforts, id: \.duration) { effort in
                        EffortRow(
                            duration: effort.label,
                            durationSeconds: effort.duration,
                            watts: effort.watts,
                            date: dateFormatter.string(from: effort.date),
                            activity: effort.activityName,
                            stravaService: stravaService
                        )
                    }
                }
            }
            
            Text(showYearView ? "Best from last 365 days" : "Data from your last 12 weeks")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .cardStyle()
    }
}

struct EffortRow: View {
    let duration: String
    let durationSeconds: Int
    let watts: Int
    let date: String
    let activity: String
    let stravaService: StravaService
    
    var rankInfo: (rank: Int, improvement: Double)? {
        stravaService.getHistoricalRank(for: durationSeconds, currentWatts: watts)
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(duration)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    if let rank = rankInfo {
                        if rank.rank == 1 {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.yellow)
                        } else {
                            Text("#\(rank.rank)")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                Text(activity)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(watts)W")
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.bold)
                
                if let rank = rankInfo, rank.rank == 1, rank.improvement > 0 {
                    Text("+\(String(format: "%.1f", rank.improvement))%")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                } else {
                    Text(date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
    struct HRRecordsCard: View {
        @EnvironmentObject var stravaService: StravaService
        
        var hrRecords: [(name: String, maxHR: Int, avgHR: Int, date: Date)] {
            guard let history = UserDefaults.standard.array(forKey: "year_history_cache") as? [[String: Any]] else {
                return []
            }
            
            // Group by activity name and date to get unique activities
            var uniqueActivities: [String: (name: String, maxHR: Int, avgHR: Int, date: Date)] = [:]
            
            for effort in history {
                let name = effort["name"] as? String ?? "Unknown"
                let maxHR = effort["maxHR"] as? Int ?? 0
                let avgHR = effort["avgHR"] as? Int ?? 0
                let timestamp = effort["date"] as? Double ?? 0
                let date = Date(timeIntervalSince1970: timestamp)
                let key = "\(name)_\(timestamp)"
                
                if maxHR > 0 && uniqueActivities[key] == nil {
                    uniqueActivities[key] = (name, maxHR, avgHR, date)
                }
            }
            
            return uniqueActivities.values
                .sorted { $0.maxHR > $1.maxHR }
                .prefix(5)
                .map { $0 }
        }
        
        var dateFormatter: DateFormatter {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter
        }
        
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("Max Heart Rate by Activity")
                    .font(.headline)
                
                if hrRecords.isEmpty {
                    Text("No heart rate data available. Load full year history to see records.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    VStack(spacing: 8) {
                        ForEach(Array(hrRecords.enumerated()), id: \.offset) { index, record in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 4) {
                                        if index == 0 {
                                            Image(systemName: "crown.fill")
                                                .font(.system(size: 10))
                                                .foregroundColor(.yellow)
                                        } else {
                                            Text("#\(index + 1)")
                                                .font(.system(size: 10))
                                                .foregroundColor(.secondary)
                                        }
                                        Text(record.name)
                                            .font(.caption)
                                            .lineLimit(1)
                                    }
                                    Text(dateFormatter.string(from: record.date))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 2) {
                                    HStack(spacing: 2) {
                                        Image(systemName: "heart.fill")
                                            .font(.system(size: 10))
                                            .foregroundColor(.red)
                                        Text("\(record.maxHR)")
                                            .font(.system(.subheadline, design: .monospaced))
                                            .fontWeight(.bold)
                                    }
                                    Text("avg \(record.avgHR)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .cardStyle()
        }
    }
struct HRByDurationCard: View {
    @EnvironmentObject var stravaService: StravaService
    @State private var showYearView = true
    
    var hrByDuration: [(duration: String, durationSeconds: Int, hr: Int, activityName: String, date: Date)] {
        guard let history = UserDefaults.standard.array(forKey: "year_history_cache") as? [[String: Any]] else {
            return []
        }
        
        let targetDurations: [Int: String] = [
            5: "5s", 60: "1m", 300: "5m", 600: "10m", 1200: "20m", 3600: "1h"
        ]
        
        var bestByDuration: [Int: (hr: Int, name: String, date: Date)] = [:]
        
        for effort in history {
            let duration = effort["duration"] as? Int ?? 0
            let hrForDuration = effort["hrForDuration"] as? Int ?? 0
            let name = effort["name"] as? String ?? "Unknown"
            let timestamp = effort["date"] as? Double ?? 0
            let date = Date(timeIntervalSince1970: timestamp)
            
            if hrForDuration > 0 && targetDurations[duration] != nil {
                if bestByDuration[duration] == nil || hrForDuration > bestByDuration[duration]!.hr {
                    bestByDuration[duration] = (hrForDuration, name, date)
                }
            }
        }
        
        return bestByDuration
            .sorted { $0.key < $1.key }
            .map { (targetDurations[$0.key]!, $0.key, $0.value.hr, $0.value.name, $0.value.date) }
    }
    
    var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }
    
    func rankIcon(for durationSeconds: Int, hr: Int) -> (icon: String, color: Color)? {
        guard let history = UserDefaults.standard.array(forKey: "year_history_cache") as? [[String: Any]] else {
            return nil
        }
        
        let allHRForDuration = history
            .filter { $0["duration"] as? Int == durationSeconds }
            .compactMap { $0["hrForDuration"] as? Int }
            .filter { $0 > 0 }
            .sorted(by: >)
        
        guard let rank = allHRForDuration.firstIndex(where: { hr >= $0 }) else { return nil }
        
        switch rank {
        case 0: return ("crown.fill", .yellow)
        case 1: return ("medal.fill", .gray)
        case 2: return ("medal.fill", .orange)
        default: return nil
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(showYearView ? "Best Avg HR (Year)" : "Best Avg HR (12 weeks)")
                    .font(.headline)
                
                Spacer()
                
                Toggle("", isOn: $showYearView)
                    .labelsHidden()
                    .scaleEffect(0.7)
            }
            
            if hrByDuration.isEmpty {
                Text("No HR duration data available. Load full year history to see records.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(hrByDuration.enumerated()), id: \.offset) { index, record in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text(record.duration)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    
                                    if let rankInfo = rankIcon(for: record.durationSeconds, hr: record.hr) {
                                        Image(systemName: rankInfo.icon)
                                            .font(.system(size: 10))
                                            .foregroundColor(rankInfo.color)
                                    }
                                }
                                Text(record.activityName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                HStack(spacing: 2) {
                                    Image(systemName: "heart.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(.red)
                                    Text("\(record.hr) bpm")
                                        .font(.system(.subheadline, design: .monospaced))
                                        .fontWeight(.bold)
                                }
                                Text(dateFormatter.string(from: record.date))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                            }
                            
                            Text(showYearView ? "Best from last 365 days" : "Data from your last 12 weeks")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .cardStyle()
                    }
                }
