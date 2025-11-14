import SwiftUI

struct PowerCurveView: View {
    @EnvironmentObject var stravaService: StravaService
    @EnvironmentObject var zonesManager: ZonesManager
    @State private var powerData: [PowerPoint] = []
    @State private var isLoading = false
    @State private var errorMessage: String = ""
    @State private var showList = false
    @State private var selectedPoint: PowerPoint? = nil
    @State private var zoomLevel: Int = 0
    @State private var showYLabels: Bool = true
    
    var zoomRanges: [(min: Int, max: Int, label: String)] {
        [
            (5, 21600, "5s - 6h"),
            (30, 3600, "30s - 1h"),
            (60, 1200, "1m - 20m")
        ]
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Power Curve")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                HStack(spacing: 4) {
                    Text("12 weeks")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HelpButton(
                        title: "Time Range",
                        explanation: "Your power curve is calculated from activities in the last 12 weeks to reflect your current fitness level."
                    )
                }
            }
            
            if isLoading {
                ProgressView("Loading activities...")
                    .frame(height: 200)
            } else if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                
                Button("Reload") {
                    Task {
                        await loadPowerCurve()
                    }
                }
            } else if powerData.isEmpty || powerData.allSatisfy({ $0.watts == 0 }) {
                Text("No power data available")
                    .foregroundColor(.secondary)
                    .frame(height: 200)
            } else {
                PowerCurveGraph(
                    data: powerData,
                    ftp: zonesManager.ftp,
                    selectedPoint: $selectedPoint,
                    zonesManager: zonesManager,
                    minDuration: zoomRanges[zoomLevel].min,
                    maxDuration: zoomRanges[zoomLevel].max,
                    showYLabels: showYLabels
                )
                .frame(height: 200)
                
                HStack {
                    Button(action: { if zoomLevel > 0 { zoomLevel -= 1 } }) {
                        Image(systemName: "minus.magnifyingglass")
                            .foregroundColor(zoomLevel > 0 ? .primary : .secondary)
                    }
                    .disabled(zoomLevel == 0)
                    
                    Spacer()
                    
                    Text(zoomRanges[zoomLevel].label)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button(action: { if zoomLevel < 2 { zoomLevel += 1 } }) {
                        Image(systemName: "plus.magnifyingglass")
                            .foregroundColor(zoomLevel < 2 ? .primary : .secondary)
                    }
                    .disabled(zoomLevel == 2)
                }
                .padding(.top, 24)
                
                Button(action: { showList.toggle() }) {
                    HStack {
                        Text("Details")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: showList ? "chevron.up" : "chevron.down")
                            .foregroundColor(.secondary)
                    }
                }
                
                if showList {
                    PowerCurveList(data: powerData)
                }
            }
        }
        .cardStyle()
        .task {
            await loadPowerCurve()
        }
    }
    
    func loadPowerCurve() async {
        isLoading = true
        errorMessage = ""
        if let data = await stravaService.fetchPowerCurve() {
            powerData = data
            if data.allSatisfy({ $0.watts == 0 }) {
                errorMessage = "No activities with power meter found"
            }
        } else {
            errorMessage = "Failed to fetch data from Strava"
        }
        isLoading = false
    }
}

struct PowerPoint: Identifiable {
    let id = UUID()
    let duration: Int
    let label: String
    let watts: Int
}

struct PowerCurveGraph: View {
    let data: [PowerPoint]
    let ftp: Int
    @Binding var selectedPoint: PowerPoint?
    let zonesManager: ZonesManager
    let minDuration: Int
    let maxDuration: Int
    let showYLabels: Bool
    
    var filteredData: [PowerPoint] {
        data.filter { $0.duration >= minDuration && $0.duration <= maxDuration && $0.watts > 0 }
    }
    
    var maxWatts: CGFloat {
        let actualMax = CGFloat(filteredData.map { $0.watts }.max() ?? 1)
        let idealMax = CGFloat(calculateIdealPower(duration: minDuration, ftp: ftp))
        return max(actualMax, idealMax) * 1.05
    }
    
    var minWatts: CGFloat {
        let actualMin = CGFloat(filteredData.map { $0.watts }.min() ?? 0)
        let idealMin = CGFloat(calculateIdealPower(duration: maxDuration, ftp: ftp))
        return min(actualMin, idealMin) * 0.95
    }
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let padding: CGFloat = 10
            let graphWidth = width - padding
            let graphHeight = height - 10
            
            ZStack {
                // Zone backgrounds (Friel 5 zones)
                ForEach(zonesManager.getFriel5Zones().reversed()) { zone in
                    let zoneMaxY = graphHeight - ((CGFloat(zone.maxWatts == 9999 ? Int(maxWatts) : zone.maxWatts) - minWatts) / (maxWatts - minWatts) * graphHeight)
                    let zoneMinY = graphHeight - ((CGFloat(zone.minWatts) - minWatts) / (maxWatts - minWatts) * graphHeight)
                    
                    Rectangle()
                        .fill(zone.color.opacity(0.15))
                        .frame(width: graphWidth, height: max(0, zoneMinY - zoneMaxY))
                        .position(x: padding + graphWidth / 2, y: zoneMaxY + (zoneMinY - zoneMaxY) / 2)
                }
                
                // Grid lines
                ForEach(0..<5) { i in
                    let y = graphHeight - (CGFloat(i) / 4.0 * graphHeight)
                    Path { path in
                        path.move(to: CGPoint(x: padding, y: y))
                        path.addLine(to: CGPoint(x: width, y: y))
                    }
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                }
                
                // Ideal curve (black) - extended to full range
                Path { path in
                    let steps = 50
                    for i in 0...steps {
                        let t = Double(minDuration) * pow(Double(maxDuration) / Double(minDuration), Double(i) / Double(steps))
                        let duration = Int(t)
                        let idealWatts = calculateIdealPower(duration: duration, ftp: ftp)
                        let x = padding + logPosition(duration: duration) * graphWidth
                        let normalizedWatts = (CGFloat(idealWatts) - minWatts) / (maxWatts - minWatts)
                        let y = graphHeight - (normalizedWatts * graphHeight)
                        
                        if i == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(Color.black.opacity(0.5), lineWidth: 2)
                
                // Actual curve (orange)
                Path { path in
                    guard filteredData.count > 1 else { return }
                    
                    for (index, point) in filteredData.enumerated() {
                        let x = padding + logPosition(duration: point.duration) * graphWidth
                        let normalizedWatts = (CGFloat(point.watts) - minWatts) / (maxWatts - minWatts)
                        let y = graphHeight - (normalizedWatts * graphHeight)
                        
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(Color.orange, lineWidth: 3)
                
                // Data points (tappable)
                ForEach(filteredData) { point in
                    let x = padding + logPosition(duration: point.duration) * graphWidth
                    let normalizedWatts = (CGFloat(point.watts) - minWatts) / (maxWatts - minWatts)
                    let y = graphHeight - (normalizedWatts * graphHeight)
                    
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 10, height: 10)
                        .position(x: x, y: y)
                        .onTapGesture {
                            selectedPoint = point
                        }
                    
                    if selectedPoint?.id == point.id {
                        let idealWatts = calculateIdealPower(duration: point.duration, ftp: ftp)
                        let isAboveIdeal = point.watts >= idealWatts
                        
                        VStack(spacing: 2) {
                            Text("\(point.label): \(point.watts)W")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(isAboveIdeal ? .green : .red)
                            
                            if !isAboveIdeal {
                                Text("Needs improvement")
                                    .font(.system(size: 8))
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(4)
                        .background(Color.white)
                        .cornerRadius(4)
                        .shadow(radius: 2)
                        .position(x: x, y: y - 25)
                    }
                }
            }
            .onTapGesture {
                selectedPoint = nil
            }
        }
    }
    
    func logPosition(duration: Int) -> CGFloat {
        let minLog = log10(Double(minDuration))
        let maxLog = log10(Double(maxDuration))
        let durationLog = log10(Double(duration))
        return CGFloat((durationLog - minLog) / (maxLog - minLog))
    }
    
    func calculateIdealPower(duration: Int, ftp: Int) -> Int {
        let t = Double(duration)
        let ftpDouble = Double(ftp)
        let ratio = ftpDouble / 250.0
        
        // Datos de referencia para FTP 250
        let points: [(Double, Double)] = [
            (1, 900), (2, 877), (3, 856), (5, 819), (10, 742),
            (15, 683), (20, 637), (30, 569), (45, 498), (60, 459),
            (90, 403), (120, 371), (180, 334), (300, 301), (900, 265),
            (1200, 260), (1800, 255), (2700, 251), (3600, 250), (21600, 220)
        ]
        
        // Encontrar el segmento correcto e interpolar
        for i in 0..<(points.count - 1) {
            if t <= points[i + 1].0 {
                let t1 = points[i].0
                let t2 = points[i + 1].0
                let p1 = points[i].1
                let p2 = points[i + 1].1
                
                let power = p1 + (p2 - p1) * (t - t1) / (t2 - t1)
                return Int(power * ratio)
            }
        }
        
        return Int(220 * ratio)
    }
}

struct PowerCurveList: View {
    let data: [PowerPoint]
    
    var allPoints: [PowerPoint] {
        var points = data
        if points.count % 2 != 0 {
            points.append(PowerPoint(duration: 99999, label: "∞", watts: 0))
        }
        return points
    }
    
    var body: some View {
        VStack(spacing: 8) {
            let halfCount = allPoints.count / 2
            ForEach(0..<halfCount, id: \.self) { i in
                HStack {
                    HStack {
                        Text(allPoints[i].label)
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(.secondary)
                        Spacer()
                        if allPoints[i].watts > 0 {
                            Text("\(allPoints[i].watts)W")
                                .font(.system(.caption, design: .monospaced))
                                .fontWeight(.semibold)
                        } else {
                            Text("-")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    HStack {
                        Text(allPoints[i + halfCount].label)
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(.secondary)
                        Spacer()
                        if allPoints[i + halfCount].watts > 0 {
                            Text("\(allPoints[i + halfCount].watts)W")
                                .font(.system(.caption, design: .monospaced))
                                .fontWeight(.semibold)
                        } else {
                            Text("-")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

struct HelpButton: View {
    let title: String
    let explanation: String
    @State private var showHelp = false
    
    var body: some View {
        Button(action: { showHelp.toggle() }) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .alert(title, isPresented: $showHelp) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(explanation)
        }
    }
}
