import SwiftUI

struct TTEView: View {
    @EnvironmentObject var zonesManager: ZonesManager
    @EnvironmentObject var userProfile: UserProfile
    
    var tteData: [TTERow] {
        let ftp = Double(zonesManager.ftp)
        let maxHR = Double(userProfile.maxHR)
        
        return [
            TTERow(zone: 1, ftpPercent: "<45", watts: "<\(Int(ftp * 0.45))", trainable: "∞", maxDuration: "∞", hr: "<\(Int(maxHR * 0.60))"),
            TTERow(zone: 2, ftpPercent: "45-50", watts: "\(Int(ftp * 0.45))-\(Int(ftp * 0.50))", trainable: "8h", maxDuration: "10h+", hr: "\(Int(maxHR * 0.60))"),
            TTERow(zone: 3, ftpPercent: "50-55", watts: "\(Int(ftp * 0.50))-\(Int(ftp * 0.55))", trainable: "6-8h", maxDuration: "9h", hr: "\(Int(maxHR * 0.62))-\(Int(maxHR * 0.64))"),
            TTERow(zone: 4, ftpPercent: "55-60", watts: "\(Int(ftp * 0.55))-\(Int(ftp * 0.60))", trainable: "4-6h", maxDuration: "7h", hr: "\(Int(maxHR * 0.65))"),
            TTERow(zone: 5, ftpPercent: "60-65", watts: "\(Int(ftp * 0.60))-\(Int(ftp * 0.65))", trainable: "3-5h", maxDuration: "6h", hr: "\(Int(maxHR * 0.68))"),
            TTERow(zone: 6, ftpPercent: "65-70", watts: "\(Int(ftp * 0.65))-\(Int(ftp * 0.70))", trainable: "2-3h", maxDuration: "4-5h", hr: "\(Int(maxHR * 0.70))-\(Int(maxHR * 0.72))"),
            TTERow(zone: 7, ftpPercent: "70-75", watts: "\(Int(ftp * 0.70))-\(Int(ftp * 0.75))", trainable: "90-120m", maxDuration: "150m", hr: "\(Int(maxHR * 0.74))-\(Int(maxHR * 0.76))"),
            TTERow(zone: 8, ftpPercent: "75-80", watts: "\(Int(ftp * 0.75))-\(Int(ftp * 0.80))", trainable: "60-90m", maxDuration: "120m", hr: "\(Int(maxHR * 0.78))-\(Int(maxHR * 0.80))"),
            TTERow(zone: 9, ftpPercent: "80-85", watts: "\(Int(ftp * 0.80))-\(Int(ftp * 0.85))", trainable: "45-60m", maxDuration: "75m", hr: "\(Int(maxHR * 0.82))-\(Int(maxHR * 0.84))"),
            TTERow(zone: 10, ftpPercent: "85-90", watts: "\(Int(ftp * 0.85))-\(Int(ftp * 0.90))", trainable: "35-50m", maxDuration: "60m", hr: "\(Int(maxHR * 0.86))-\(Int(maxHR * 0.88))"),
            TTERow(zone: 11, ftpPercent: "90-95", watts: "\(Int(ftp * 0.90))-\(Int(ftp * 0.95))", trainable: "30-45m", maxDuration: "55m", hr: "\(Int(maxHR * 0.89))-\(Int(maxHR * 0.90))"),
            TTERow(zone: 12, ftpPercent: "95-100", watts: "\(Int(ftp * 0.95))-\(Int(ftp * 1.00))", trainable: "25-40m", maxDuration: "60m", hr: "\(Int(maxHR * 0.91))-\(Int(maxHR * 0.92))"),
            TTERow(zone: 13, ftpPercent: "100-105", watts: "\(Int(ftp * 1.00))-\(Int(ftp * 1.05))", trainable: "20-30m", maxDuration: "35m", hr: "\(Int(maxHR * 0.93))"),
            TTERow(zone: 14, ftpPercent: "105-110", watts: "\(Int(ftp * 1.05))-\(Int(ftp * 1.10))", trainable: "12-20m", maxDuration: "25m", hr: "\(Int(maxHR * 0.94))"),
            TTERow(zone: 15, ftpPercent: "110-115", watts: "\(Int(ftp * 1.10))-\(Int(ftp * 1.15))", trainable: "8-12m", maxDuration: "15m", hr: "\(Int(maxHR * 0.95))"),
            TTERow(zone: 16, ftpPercent: "115-120", watts: "\(Int(ftp * 1.15))-\(Int(ftp * 1.20))", trainable: "5-8m", maxDuration: "10m", hr: "\(Int(maxHR * 0.96))"),
            TTERow(zone: 17, ftpPercent: "120-130", watts: "\(Int(ftp * 1.20))-\(Int(ftp * 1.30))", trainable: "3-5m", maxDuration: "6-7m", hr: "\(Int(maxHR * 0.97))"),
            TTERow(zone: 18, ftpPercent: "130-150", watts: "\(Int(ftp * 1.30))-\(Int(ftp * 1.50))", trainable: "1-2m", maxDuration: "3m", hr: "\(Int(maxHR * 0.98))"),
            TTERow(zone: 19, ftpPercent: "150-200", watts: "\(Int(ftp * 1.50))-\(Int(ftp * 2.00))", trainable: "15-45s", maxDuration: "60s", hr: "\(Int(maxHR * 0.99))"),
            TTERow(zone: 20, ftpPercent: ">200", watts: ">\(Int(ftp * 2.00))", trainable: "5-20s", maxDuration: "30s", hr: "\(Int(maxHR * 1.00))")
        ]
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    TTEHeaderRow()
                        .padding(.horizontal)
                        .padding(.top)
                    
                    // Data rows
                    ForEach(tteData) { row in
                        TTEDataRow(row: row)
                            .padding(.horizontal)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.gray.opacity(0.1))
                        .padding()
                )
            }
            .navigationTitle("Time to Exhaustion")
        }
    }
}

struct TTERow: Identifiable {
    let id = UUID()
    let zone: Int
    let ftpPercent: String
    let watts: String
    let trainable: String
    let maxDuration: String
    let hr: String
}

struct TTEHeaderRow: View {
    var body: some View {
        HStack(spacing: 4) {
            Text("#")
                .frame(width: 25, alignment: .center)
            Text("%FTP")
                .frame(width: 50, alignment: .center)
            Text("Watts")
                .frame(maxWidth: .infinity, alignment: .center)
            Text("Train")
                .frame(width: 55, alignment: .center)
            Text("Max")
                .frame(width: 45, alignment: .center)
            Text("HR")
                .frame(width: 50, alignment: .center)
        }
        .font(.system(size: 10, weight: .bold))
        .foregroundColor(.secondary)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.2))
        .cornerRadius(8)
    }
}

struct TTEDataRow: View {
    let row: TTERow
    
    var rowColor: Color {
        if row.zone <= 6 {
            return .green.opacity(0.1)
        } else if row.zone <= 12 {
            return .yellow.opacity(0.1)
        } else if row.zone <= 16 {
            return .orange.opacity(0.1)
        } else {
            return .red.opacity(0.1)
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Text("\(row.zone)")
                .frame(width: 25, alignment: .center)
                .fontWeight(.bold)
            Text(row.ftpPercent)
                .frame(width: 50, alignment: .center)
            Text(row.watts)
                .frame(maxWidth: .infinity, alignment: .center)
            Text(row.trainable)
                .frame(width: 55, alignment: .center)
            Text(row.maxDuration)
                .frame(width: 45, alignment: .center)
            Text(row.hr)
                .frame(width: 50, alignment: .center)
        }
        .font(.system(size: 9, design: .monospaced))
        .padding(.vertical, 6)
        .background(rowColor)
        .cornerRadius(4)
        .padding(.vertical, 1)
    }
}
