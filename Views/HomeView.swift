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
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Wattlet")
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
            Text("Current FTP")
                .font(.headline)
                .foregroundColor(.secondary)
            
            HStack(alignment: .firstTextBaseline) {
                Text("\(ftp)")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                Text("watts")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.gray.opacity(0.1))
        .cornerRadius(16)
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
        .padding()
        .background(.gray.opacity(0.1))
        .cornerRadius(16)
    }
}

struct FusedZonesView: View {
    @EnvironmentObject var zonesManager: ZonesManager
    
    var fusedItems: [(type: String, name: String, watts: Int, color: Color, description: String)] {
        var items: [(type: String, name: String, watts: Int, color: Color, description: String)] = []
        
        // Add zones from selected systems
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
        
        // Add thresholds
        if zonesManager.showVentilatoryThresholds {
            items.append((type: "threshold", name: "VT1/LT1", watts: zonesManager.vt1Watts, color: .blue, description: "\(zonesManager.vt1Watts)W"))
            items.append((type: "threshold", name: "VT2/LT2", watts: zonesManager.vt2Watts, color: .red, description: "\(zonesManager.vt2Watts)W"))
        }
        items.append((type: "threshold", name: "FTP", watts: zonesManager.ftp, color: .orange, description: "\(zonesManager.ftp)W"))
        
        // Sort by watts
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
