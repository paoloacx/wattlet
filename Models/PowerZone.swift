import Foundation
import SwiftUI
import Combine

enum ZoneSystem: String, CaseIterable {
    case coggan7 = "Coggan 7 Zones"
    case friel5 = "Friel 5 Zones"
    case polarized3 = "Polarized 3 Zones"
}

struct PowerZone: Identifiable {
    let id: Int
    let name: String
    let minWatts: Int
    let maxWatts: Int
    let color: Color
    let description: String
}

struct ThresholdMarker: Identifiable {
    let id = UUID()
    let name: String
    let watts: Int
    let color: Color
}

class ZonesManager: ObservableObject {
    @Published var ftp: Int = 250
    @Published var zones: [PowerZone] = []
    @Published var selectedSystems: Set<ZoneSystem> = [.coggan7]
    @Published var showVentilatoryThresholds: Bool = false
    @Published var vt1Watts: Int = 180
    @Published var vt2Watts: Int = 230
    
    init() {
        calculateZones()
    }
    
    func calculateZones() {
        zones = getCoggan7Zones()
    }
    
    func getCoggan7Zones() -> [PowerZone] {
        [
            PowerZone(id: 1, name: "Z1", minWatts: 0, maxWatts: Int(Double(ftp) * 0.55), color: .gray, description: "Recovery"),
            PowerZone(id: 2, name: "Z2", minWatts: Int(Double(ftp) * 0.56), maxWatts: Int(Double(ftp) * 0.75), color: .blue, description: "Endurance"),
            PowerZone(id: 3, name: "Z3", minWatts: Int(Double(ftp) * 0.76), maxWatts: Int(Double(ftp) * 0.90), color: .green, description: "Tempo"),
            PowerZone(id: 4, name: "Z4", minWatts: Int(Double(ftp) * 0.91), maxWatts: Int(Double(ftp) * 1.05), color: .yellow, description: "Threshold"),
            PowerZone(id: 5, name: "Z5", minWatts: Int(Double(ftp) * 1.06), maxWatts: Int(Double(ftp) * 1.20), color: .orange, description: "VO2max"),
            PowerZone(id: 6, name: "Z6", minWatts: Int(Double(ftp) * 1.21), maxWatts: Int(Double(ftp) * 1.50), color: .red, description: "Anaerobic"),
            PowerZone(id: 7, name: "Z7", minWatts: Int(Double(ftp) * 1.51), maxWatts: 9999, color: .purple, description: "Neuromuscular")
        ]
    }
    
    func getFriel5Zones() -> [PowerZone] {
        [
            PowerZone(id: 1, name: "Z1", minWatts: 0, maxWatts: Int(Double(ftp) * 0.55), color: .gray, description: "Recovery"),
            PowerZone(id: 2, name: "Z2", minWatts: Int(Double(ftp) * 0.56), maxWatts: Int(Double(ftp) * 0.74), color: .blue, description: "Endurance"),
            PowerZone(id: 3, name: "Z3", minWatts: Int(Double(ftp) * 0.75), maxWatts: Int(Double(ftp) * 0.89), color: .green, description: "Tempo"),
            PowerZone(id: 4, name: "Z4", minWatts: Int(Double(ftp) * 0.90), maxWatts: Int(Double(ftp) * 1.04), color: .yellow, description: "Threshold"),
            PowerZone(id: 5, name: "Z5", minWatts: Int(Double(ftp) * 1.05), maxWatts: 9999, color: .red, description: "VO2max+")
        ]
    }
    
    func getPolarized3Zones() -> [PowerZone] {
        [
            PowerZone(id: 1, name: "Z1", minWatts: 0, maxWatts: vt1Watts, color: .green, description: "Low Intensity"),
            PowerZone(id: 2, name: "Z2", minWatts: vt1Watts + 1, maxWatts: vt2Watts, color: .yellow, description: "Moderate"),
            PowerZone(id: 3, name: "Z3", minWatts: vt2Watts + 1, maxWatts: 9999, color: .red, description: "High Intensity")
        ]
    }
    
    func getThresholdMarkers() -> [ThresholdMarker] {
        var markers: [ThresholdMarker] = []
        if showVentilatoryThresholds {
            markers.append(ThresholdMarker(name: "VT1/LT1", watts: vt1Watts, color: .blue))
            markers.append(ThresholdMarker(name: "VT2/LT2", watts: vt2Watts, color: .red))
        }
        markers.append(ThresholdMarker(name: "FTP", watts: ftp, color: .orange))
        return markers
    }
    
    func updateFTP(_ newFTP: Int) {
        ftp = newFTP
        UserDefaults.standard.set(newFTP, forKey: "user_ftp")
        calculateZones()
    }
    
    func loadSavedFTP() {
            if let savedFTP = UserDefaults.standard.value(forKey: "user_ftp") as? Int {
                ftp = savedFTP
                calculateZones()
            }
        }
        
        func updateThresholds(vt1: Int, vt2: Int) {
            vt1Watts = vt1
            vt2Watts = vt2
            calculateZones()
        }
    }

