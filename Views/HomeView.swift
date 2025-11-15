import SwiftUI

struct HomeView: View {
    @EnvironmentObject var zonesManager: ZonesManager
    @EnvironmentObject var stravaService: StravaService
    @EnvironmentObject var userProfile: UserProfile
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    FTPCard(ftp: zonesManager.ftp)
                    
                    PowerCurveView()
                        .environmentObject(stravaService)
                        .environmentObject(zonesManager)
                    
                    ZonesConfigurableCard()
                        .environmentObject(zonesManager)
                                        
                        FatOxidationCard()
                          .environmentObject(zonesManager)
                          .environmentObject(userProfile)
                                        
                        Spacer()
                }
                .padding()
            }
            .background(GrainBackground())
            .navigationTitle("Power & HR Zones")
            .task {
                if UserDefaults.standard.value(forKey: "user_ftp") == nil {
                    if let stravaFTP = await stravaService.fetchAthleteProfile() {
                        zonesManager.updateFTP(stravaFTP)
                        userProfile.ftp = stravaFTP
                        userProfile.saveProfile()
                    }
                }
            }
        }
    }
}

struct FTPCard: View {
    let ftp: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 4) {
                Text("Current FTP")
                    .font(.headline)
                    .foregroundColor(.secondary)
                HelpButton(
                    title: "Functional Threshold Power",
                    explanation: "The maximum power you can sustain for approximately one hour. It's a key metric for training zones and performance tracking."
                )
            }
            
            HStack(alignment: .firstTextBaseline) {
                Text("\(ftp)")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                Text("watts")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

struct ZonesConfigurableCard: View {
    @EnvironmentObject var zonesManager: ZonesManager
    @State private var showConfig = false
    @State private var fusedView = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Power Zones")
                    .font(.headline)
                Spacer()
                Button(action: { showConfig.toggle() }) {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 8)
            
            if showConfig {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Zone Systems")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(ZoneSystem.allCases, id: \.self) { system in
                        Toggle(system.rawValue, isOn: Binding(
                            get: { zonesManager.selectedSystems.contains(system) },
                            set: { isOn in
                                if isOn {
                                    zonesManager.selectedSystems.insert(system)
                                } else {
                                    zonesManager.selectedSystems.remove(system)
                                }
                            }
                        ))
                        .font(.subheadline)
                    }
                    
                    Toggle("Show VT1/VT2 Thresholds", isOn: $zonesManager.showVentilatoryThresholds)
                        .font(.subheadline)
                    
                    Toggle("Fused View", isOn: $fusedView)
                        .font(.subheadline)
                    
                    Divider()
                }
            }
            
            if fusedView {
                FusedZonesView()
                    .environmentObject(zonesManager)
            } else {
                SeparateZonesView()
                    .environmentObject(zonesManager)
            }
        }
        .cardStyle()
    }
}

struct FusedZonesView: View {
    @EnvironmentObject var zonesManager: ZonesManager
    
    var fusedItems: [(type: String, name: String, watts: Int, color: Color, description: String)] {
        var items: [(type: String, name: String, watts: Int, color: Color, description: String)] = []
        
        for system in zonesManager.selectedSystems {
            let zones: [PowerZone]
            let prefix: String
            switch system {
            case .coggan7:
                zones = zonesManager.getCoggan7Zones()
                prefix = "C"
            case .friel5:
                zones = zonesManager.getFriel5Zones()
                prefix = "F"
            case .polarized3:
                zones = zonesManager.getPolarized3Zones()
                prefix = "P"
            }
            
            for zone in zones {
                items.append((
                    type: "zone",
                    name: "\(prefix)-\(zone.name)",
                    watts: zone.minWatts,
                    color: zone.color,
                    description: "\(zone.minWatts)-\(zone.maxWatts == 9999 ? "∞" : "\(zone.maxWatts)")W"
                ))
            }
        }
        
        if zonesManager.showVentilatoryThresholds {
            items.append((type: "threshold", name: "VT1/LT1", watts: zonesManager.vt1Watts, color: .blue, description: "\(zonesManager.vt1Watts)W"))
            items.append((type: "threshold", name: "VT2/LT2", watts: zonesManager.vt2Watts, color: .red, description: "\(zonesManager.vt2Watts)W"))
        }
        items.append((type: "threshold", name: "FTP", watts: zonesManager.ftp, color: .orange, description: "\(zonesManager.ftp)W"))
        
        return items.sorted { $0.watts < $1.watts }
    }
    
    var body: some View {
        VStack(spacing: 4) {
            ForEach(Array(fusedItems.enumerated()), id: \.offset) { index, item in
                HStack {
                    if item.type == "zone" {
                        Circle()
                            .fill(item.color)
                            .frame(width: 10, height: 10)
                    } else {
                        Rectangle()
                            .fill(item.color)
                            .frame(width: 3, height: 16)
                    }
                    
                    Text(item.name)
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(item.type == "threshold" ? .bold : .semibold)
                    
                    Spacer()
                    
                    Text(item.description)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 2)
            }
        }
    }
}

struct SeparateZonesView: View {
    @EnvironmentObject var zonesManager: ZonesManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(zonesManager.selectedSystems).sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { system in
                VStack(alignment: .leading, spacing: 8) {
                    Text(system.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                    
                    let zones = getZonesForSystem(system)
                    ForEach(zones) { zone in
                        ZoneRow(zone: zone, thresholds: zonesManager.getThresholdMarkers())
                    }
                }
            }
            
            if zonesManager.showVentilatoryThresholds {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Thresholds")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                    
                    ForEach(zonesManager.getThresholdMarkers()) { marker in
                        HStack {
                            Rectangle()
                                .fill(marker.color)
                                .frame(width: 3, height: 20)
                            
                            Text(marker.name)
                                .font(.system(.body, design: .rounded))
                                .fontWeight(.semibold)
                            
                            Spacer()
                            
                            Text("\(marker.watts)W")
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
    
    func getZonesForSystem(_ system: ZoneSystem) -> [PowerZone] {
        switch system {
        case .coggan7:
            return zonesManager.getCoggan7Zones()
        case .friel5:
            return zonesManager.getFriel5Zones()
        case .polarized3:
            return zonesManager.getPolarized3Zones()
        }
    }
}

struct ZoneRow: View {
    let zone: PowerZone
    let thresholds: [ThresholdMarker]
    
    var body: some View {
        HStack {
            Circle()
                .fill(zone.color)
                .frame(width: 12, height: 12)
            
            Text(zone.name)
                .font(.system(.body, design: .rounded))
                .fontWeight(.semibold)
            
            Text(zone.description)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text("\(zone.minWatts)-\(zone.maxWatts == 9999 ? "∞" : "\(zone.maxWatts)")W")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}
struct FatOxidationCard: View {
    @EnvironmentObject var zonesManager: ZonesManager
    @EnvironmentObject var userProfile: UserProfile
    
    var fatMaxWatts: Int {
        // FatMax typically around 60-65% of FTP, close to VT1
        let vt1 = zonesManager.vt1Watts > 0 ? zonesManager.vt1Watts : Int(Double(zonesManager.ftp) * 0.75)
        return Int(Double(vt1) * 0.85) // Slightly below VT1
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Fat Oxidation Curve")
                    .font(.headline)
                Spacer()
                HelpButton(
                    title: "Fat Oxidation",
                    explanation: "Shows how your body uses fat vs carbohydrates at different intensities. FatMax is the intensity where you burn the most fat per minute. Training at FatMax improves metabolic efficiency."
                )
            }
            
            // Fat Oxidation Graph
            GeometryReader { geometry in
                let width = geometry.size.width
                let height: CGFloat = 120
                
                ZStack(alignment: .bottomLeading) {
                    // Background grid
                    Path { path in
                        for i in 0...4 {
                            let y = height * CGFloat(i) / 4
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: width, y: y))
                        }
                    }
                    .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                    
                    // Fat curve (bell curve peaking around 60% intensity)
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: height * 0.7))
                        path.addCurve(
                            to: CGPoint(x: width * 0.35, y: height * 0.15),
                            control1: CGPoint(x: width * 0.15, y: height * 0.5),
                            control2: CGPoint(x: width * 0.25, y: height * 0.2)
                        )
                        path.addCurve(
                            to: CGPoint(x: width * 0.85, y: height * 0.95),
                            control1: CGPoint(x: width * 0.5, y: height * 0.1),
                            control2: CGPoint(x: width * 0.7, y: height * 0.8)
                        )
                        path.addLine(to: CGPoint(x: width, y: height))
                    }
                    .fill(
                        LinearGradient(
                            colors: [.yellow.opacity(0.6), .yellow.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    // Fat curve line
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: height * 0.7))
                        path.addCurve(
                            to: CGPoint(x: width * 0.35, y: height * 0.15),
                            control1: CGPoint(x: width * 0.15, y: height * 0.5),
                            control2: CGPoint(x: width * 0.25, y: height * 0.2)
                        )
                        path.addCurve(
                            to: CGPoint(x: width * 0.85, y: height * 0.95),
                            control1: CGPoint(x: width * 0.5, y: height * 0.1),
                            control2: CGPoint(x: width * 0.7, y: height * 0.8)
                        )
                    }
                    .stroke(Color.yellow, lineWidth: 2)
                    
                    // Carb curve (increasing line)
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: height * 0.95))
                        path.addCurve(
                            to: CGPoint(x: width, y: height * 0.1),
                            control1: CGPoint(x: width * 0.3, y: height * 0.85),
                            control2: CGPoint(x: width * 0.6, y: height * 0.3)
                        )
                    }
                    .stroke(Color.blue, lineWidth: 2)
                    
                    // FatMax marker
                    Rectangle()
                        .fill(Color.orange)
                        .frame(width: 2, height: height)
                        .position(x: width * 0.35, y: height / 2)
                    
                    // VT1 marker if available
                    if zonesManager.showVentilatoryThresholds {
                        Rectangle()
                            .fill(Color.blue.opacity(0.5))
                            .frame(width: 1, height: height)
                            .position(x: width * 0.45, y: height / 2)
                    }
                }
            }
            .frame(height: 120)
            
            // Labels
            HStack {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.yellow)
                        .frame(width: 8, height: 8)
                    Text("Fat")
                        .font(.caption2)
                }
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                    Text("Carbs")
                        .font(.caption2)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 2)
                    Text("FatMax")
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
            }
            
            // FatMax value
            HStack {
                Text("FatMax Zone:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(fatMaxWatts)W")
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
            }
            
            Text("Optimal fat burning intensity")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .cardStyle()
    }
}
