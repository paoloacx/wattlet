import Foundation
import Combine

struct BestEffort: Codable {
    let duration: Int
    let label: String
    let watts: Int
    let hr: Int
    let date: Date
    let activityName: String
}

class StravaService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var accessToken: String?
    @Published var bestEfforts: [BestEffort] = []
    
    private let clientID = "185327"
    private let clientSecret = "a28a7fc2956047fc681d5a3f4ef78c9a7486c37f"
    private let redirectURI = "http://wattlet/callback"
    
    func authenticate(code: String) async {
        let tokenURL = URL(string: "https://www.strava.com/oauth/token")!
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        
        let params = [
            "client_id": clientID,
            "client_secret": clientSecret,
            "code": code,
            "grant_type": "authorization_code"
        ]
        
        request.httpBody = params.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let token = json["access_token"] as? String {
                await MainActor.run {
                    self.accessToken = token
                    self.isAuthenticated = true
                    UserDefaults.standard.set(token, forKey: "strava_token")
                }
            }
        } catch {
            print("Auth error: \(error)")
        }
    }
    
    func getAuthURL() -> URL {
        var components = URLComponents(string: "https://www.strava.com/oauth/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "activity:read_all,profile:read_all")
        ]
        return components.url!
    }
    
    func loadSavedToken() {
        if let token = UserDefaults.standard.string(forKey: "strava_token") {
            accessToken = token
            isAuthenticated = true
        }
        loadCachedBestEfforts()
    }
    
    func fetchAthleteProfile() async -> Int? {
        guard let token = accessToken else { return nil }
        
        let url = URL(string: "https://www.strava.com/api/v3/athlete")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let ftp = json["ftp"] as? Int {
                return ftp
            }
        } catch {
            print("Fetch athlete error: \(error)")
        }
        return nil
    }
    
    func fetchPowerCurve() async -> [PowerPoint]? {
        if let cached = loadCachedPowerCurve() {
            let cacheAge = Date().timeIntervalSince(cached.date)
            if cacheAge < 604800 {
                return cached.data
            }
            if accessToken == nil {
                return cached.data
            }
        }
        
        guard let token = accessToken else { return nil }
        
        let calendar = Calendar.current
        let now = Date()
        let twelveWeeksAgo = calendar.date(byAdding: .weekOfYear, value: -12, to: now)!
        let after = Int(twelveWeeksAgo.timeIntervalSince1970)
        
        let activitiesURL = URL(string: "https://www.strava.com/api/v3/athlete/activities?after=\(after)&per_page=100")!
        var activitiesRequest = URLRequest(url: activitiesURL)
        activitiesRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        var bestPowers: [Int: (watts: Int, hr: Int, date: Date, name: String)] = [
            5: (0, 0, Date(), ""), 10: (0, 0, Date(), ""), 30: (0, 0, Date(), ""),
            60: (0, 0, Date(), ""), 120: (0, 0, Date(), ""), 300: (0, 0, Date(), ""),
            600: (0, 0, Date(), ""), 1200: (0, 0, Date(), ""), 1800: (0, 0, Date(), ""),
            3600: (0, 0, Date(), ""), 7200: (0, 0, Date(), ""), 10800: (0, 0, Date(), ""),
            14400: (0, 0, Date(), ""), 18000: (0, 0, Date(), ""), 21600: (0, 0, Date(), "")
        ]
        
        do {
            let (data, _) = try await URLSession.shared.data(for: activitiesRequest)
            guard let activities = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                return nil
            }
            
            for activity in activities {
                guard let activityId = activity["id"] as? Int,
                      activity["device_watts"] as? Bool == true else {
                    continue
                }
                
                let activityName = activity["name"] as? String ?? "Unknown"
                let activityDateString = activity["start_date"] as? String ?? ""
                let activityDate = ISO8601DateFormatter().date(from: activityDateString) ?? Date()
                
                if let streams = await fetchActivityStream(activityId: activityId) {
                    let activityBests = calculateBestPowers(from: streams.watts)
                    let hrBests = calculateBestHR(from: streams.heartrate)
                    
                    for (duration, watts) in activityBests {
                        if watts > bestPowers[duration]!.watts {
                            let hr = hrBests[duration] ?? 0
                            bestPowers[duration] = (watts, hr, activityDate, activityName)
                        }
                    }
                }
            }
        } catch {
            print("Fetch activities error: \(error)")
            return nil
        }
        
        let labels = [
            5: "5s", 10: "10s", 30: "30s", 60: "1m", 120: "2m", 300: "5m",
            600: "10m", 1200: "20m", 1800: "30m", 3600: "1h", 7200: "2h",
            10800: "3h", 14400: "4h", 18000: "5h", 21600: "6h"
        ]
        
        var efforts: [BestEffort] = []
        for (duration, data) in bestPowers {
            efforts.append(BestEffort(
                duration: duration,
                label: labels[duration]!,
                watts: data.watts,
                hr: data.hr,
                date: data.date,
                activityName: data.name
            ))
        }
        efforts.sort { $0.duration < $1.duration }
        
        await MainActor.run {
            self.bestEfforts = efforts
        }
        saveBestEffortsCache(efforts)
        
        let result = efforts.map { PowerPoint(duration: $0.duration, label: $0.label, watts: $0.watts) }
        savePowerCurveCache(result)
        
        return result
    }
    
    private func fetchActivityStream(activityId: Int) async -> (watts: [Int], heartrate: [Int])? {
        guard let token = accessToken else { return nil }
        
        let url = URL(string: "https://www.strava.com/api/v3/activities/\(activityId)/streams?keys=watts,heartrate&key_by_type=true")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let wattsArray = (json["watts"] as? [String: Any])?["data"] as? [Int] ?? []
                let hrArray = (json["heartrate"] as? [String: Any])?["data"] as? [Int] ?? []
                return (wattsArray, hrArray)
            }
        } catch {
            print("Fetch stream error: \(error)")
        }
        return nil
    }
    
    private func calculateBestPowers(from watts: [Int]) -> [Int: Int] {
        var bests: [Int: Int] = [
            5: 0, 10: 0, 30: 0, 60: 0, 120: 0, 300: 0, 600: 0,
            1200: 0, 1800: 0, 3600: 0, 7200: 0, 10800: 0,
            14400: 0, 18000: 0, 21600: 0
        ]
        
        let durations = [5, 10, 30, 60, 120, 300, 600, 1200, 1800, 3600, 7200, 10800, 14400, 18000, 21600]
        
        for duration in durations {
            if watts.count >= duration {
                var maxAvg = 0
                var currentSum = watts.prefix(duration).reduce(0, +)
                maxAvg = currentSum / duration
                
                for i in duration..<watts.count {
                    currentSum = currentSum - watts[i - duration] + watts[i]
                    let avg = currentSum / duration
                    if avg > maxAvg {
                        maxAvg = avg
                    }
                }
                bests[duration] = maxAvg
            }
        }
        
        return bests
            }
            
            private func calculateBestHR(from heartrate: [Int]) -> [Int: Int] {
                var bests: [Int: Int] = [
                    5: 0, 10: 0, 30: 0, 60: 0, 120: 0, 300: 0, 600: 0,
                    1200: 0, 1800: 0, 3600: 0, 7200: 0, 10800: 0,
                    14400: 0, 18000: 0, 21600: 0
                ]
                
                let durations = [5, 10, 30, 60, 120, 300, 600, 1200, 1800, 3600, 7200, 10800, 14400, 18000, 21600]
                
                for duration in durations {
                    if heartrate.count >= duration {
                        var maxAvg = 0
                        var currentSum = heartrate.prefix(duration).reduce(0, +)
                        maxAvg = currentSum / duration
                        
                        for i in duration..<heartrate.count {
                            currentSum = currentSum - heartrate[i - duration] + heartrate[i]
                            let avg = currentSum / duration
                            if avg > maxAvg {
                                maxAvg = avg
                            }
                        }
                        bests[duration] = maxAvg
                    }
                }
                
                return bests
            }
            
            private func savePowerCurveCache(_ data: [PowerPoint]) {
        var cacheData: [String: Any] = ["date": Date().timeIntervalSince1970]
        for point in data {
            cacheData[point.label] = point.watts
        }
        UserDefaults.standard.set(cacheData, forKey: "power_curve_cache")
    }
    
    private func loadCachedPowerCurve() -> (date: Date, data: [PowerPoint])? {
        guard let cache = UserDefaults.standard.dictionary(forKey: "power_curve_cache"),
              let timestamp = cache["date"] as? Double else {
            return nil
        }
        
        let data = [
            PowerPoint(duration: 5, label: "5s", watts: cache["5s"] as? Int ?? 0),
            PowerPoint(duration: 10, label: "10s", watts: cache["10s"] as? Int ?? 0),
            PowerPoint(duration: 30, label: "30s", watts: cache["30s"] as? Int ?? 0),
            PowerPoint(duration: 60, label: "1m", watts: cache["1m"] as? Int ?? 0),
            PowerPoint(duration: 120, label: "2m", watts: cache["2m"] as? Int ?? 0),
            PowerPoint(duration: 300, label: "5m", watts: cache["5m"] as? Int ?? 0),
            PowerPoint(duration: 600, label: "10m", watts: cache["10m"] as? Int ?? 0),
            PowerPoint(duration: 1200, label: "20m", watts: cache["20m"] as? Int ?? 0),
            PowerPoint(duration: 1800, label: "30m", watts: cache["30m"] as? Int ?? 0),
            PowerPoint(duration: 3600, label: "1h", watts: cache["1h"] as? Int ?? 0),
            PowerPoint(duration: 7200, label: "2h", watts: cache["2h"] as? Int ?? 0),
            PowerPoint(duration: 10800, label: "3h", watts: cache["3h"] as? Int ?? 0),
            PowerPoint(duration: 14400, label: "4h", watts: cache["4h"] as? Int ?? 0),
            PowerPoint(duration: 18000, label: "5h", watts: cache["5h"] as? Int ?? 0),
            PowerPoint(duration: 21600, label: "6h", watts: cache["6h"] as? Int ?? 0)
        ]
        
        return (Date(timeIntervalSince1970: timestamp), data)
    }
    
    private func saveBestEffortsCache(_ efforts: [BestEffort]) {
        if let encoded = try? JSONEncoder().encode(efforts) {
            UserDefaults.standard.set(encoded, forKey: "best_efforts_cache")
        }
    }
    
    private func loadCachedBestEfforts() {
            if let data = UserDefaults.standard.data(forKey: "best_efforts_cache"),
               let efforts = try? JSONDecoder().decode([BestEffort].self, from: data) {
                bestEfforts = efforts
            }
        }
        
        func fetchFullYearHistory(progressCallback: @escaping (String) -> Void) async -> Bool {
            guard let token = accessToken else { return false }
            
            // Check if we already have year history
            if UserDefaults.standard.data(forKey: "year_history_cache") != nil {
                progressCallback("Year history already loaded")
                return true
            }
            
            let calendar = Calendar.current
            let now = Date()
            let oneYearAgo = calendar.date(byAdding: .year, value: -1, to: now)!
            let after = Int(oneYearAgo.timeIntervalSince1970)
            
            progressCallback("Fetching activities from last year...")
            
            let activitiesURL = URL(string: "https://www.strava.com/api/v3/athlete/activities?after=\(after)&per_page=200")!
            var activitiesRequest = URLRequest(url: activitiesURL)
            activitiesRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            var allEfforts: [[String: Any]] = [] // Store all efforts with dates
            
            do {
                let (data, _) = try await URLSession.shared.data(for: activitiesRequest)
                guard let activities = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                    return false
                }
                
                let powerActivities = activities.filter { $0["device_watts"] as? Bool == true }
                progressCallback("Found \(powerActivities.count) activities with power data")
                
                for (index, activity) in powerActivities.enumerated() {
                    guard let activityId = activity["id"] as? Int else { continue }
                    
                    let activityName = activity["name"] as? String ?? "Unknown"
                    let activityDateString = activity["start_date"] as? String ?? ""
                    let activityDate = ISO8601DateFormatter().date(from: activityDateString) ?? Date()
                    let distance = activity["distance"] as? Double ?? 0 // meters
                    let movingTime = activity["moving_time"] as? Int ?? 0 // seconds
                    let calories = activity["calories"] as? Double ?? 0
                    let avgSpeed = activity["average_speed"] as? Double ?? 0 // m/s
                    let maxHR = activity["max_heartrate"] as? Int ?? 0
                    let avgHR = activity["average_heartrate"] as? Int ?? 0

                    print("Activity: \(activityName), MaxHR: \(maxHR), AvgHR: \(avgHR)")
                    progressCallback("Processing \(index + 1)/\(powerActivities.count): \(activityName)")
                    
                    if let streams = await fetchActivityStream(activityId: activityId) {
                        let activityBests = calculateBestPowers(from: streams.watts)
                        let hrBests = calculateBestHR(from: streams.heartrate)
                        
                        for (duration, watts) in activityBests where watts > 0 {
                            let hrForDuration = hrBests[duration] ?? 0
                            allEfforts.append([
                                "duration": duration,
                                "watts": watts,
                                "hrForDuration": hrForDuration,
                                "date": activityDate.timeIntervalSince1970,
                                "name": activityName,
                                "distance": distance,
                                "movingTime": movingTime,
                                "calories": calories,
                                "avgSpeed": avgSpeed,
                                "maxHR": maxHR,
                                "avgHR": avgHR
                            ])
                        }
                    }
                }
                
                // Save year history
                UserDefaults.standard.set(allEfforts, forKey: "year_history_cache")
                progressCallback("Saved \(allEfforts.count) power records")
                
                return true
            } catch {
                print("Fetch year history error: \(error)")
                return false
            }
        }
        
    func getHistoricalRank(for duration: Int, currentWatts: Int) -> (rank: Int, improvement: Double)? {
            guard let history = UserDefaults.standard.array(forKey: "year_history_cache") as? [[String: Any]] else {
                return nil
            }
            
            let durationEfforts = history
                .filter { $0["duration"] as? Int == duration }
                .compactMap { $0["watts"] as? Int }
                .sorted(by: >)
            
            guard !durationEfforts.isEmpty else { return nil }
            
            let rank = (durationEfforts.firstIndex(where: { currentWatts >= $0 }) ?? durationEfforts.count) + 1
            
            var improvement = 0.0
            if durationEfforts.count >= 2 && rank == 1 {
                let previousBest = durationEfforts[1]
                improvement = Double(currentWatts - previousBest) / Double(previousBest) * 100
            }
            
            return (rank, improvement)
        }
        
    func estimateThresholds() -> (ftp: Int, vt1Power: Int, vt2Power: Int, vt1HR: Int, vt2HR: Int, ftpHR: Int)? {
        guard !bestEfforts.isEmpty else { return nil }
        
        var best20min: (watts: Int, hr: Int) = (0, 0)
        var best60min: (watts: Int, hr: Int) = (0, 0)
        
        print("Estimating thresholds from \(bestEfforts.count) efforts")
        
        for effort in bestEfforts {
            print("Duration: \(effort.duration)s, Watts: \(effort.watts), HR: \(effort.hr)")
            if effort.duration == 1200 && effort.watts > best20min.watts {
                best20min = (effort.watts, effort.hr)
            }
            if effort.duration == 3600 && effort.watts > best60min.watts {
                best60min = (effort.watts, effort.hr)
            }
        }
        
        print("Best 20min: \(best20min.watts)W, Best 60min: \(best60min.watts)W")
            
            var estimatedFTP = 0
            var estimatedFTPHR = 0
            
        // Get 5min power for additional estimation
        var best5min: (watts: Int, hr: Int) = (0, 0)
        for effort in bestEfforts {
            if effort.duration == 300 && effort.watts > best5min.watts {
                best5min = (effort.watts, effort.hr)
            }
        }

        // Calculate FTP from multiple sources
        var ftpEstimates: [Int] = []
        var hrEstimates: [Int] = []

        if best5min.watts > 0 {
            ftpEstimates.append(Int(Double(best5min.watts) * 0.75))
            if best5min.hr > 0 { hrEstimates.append(Int(Double(best5min.hr) * 0.92)) }
        }
        if best20min.watts > 0 {
            ftpEstimates.append(Int(Double(best20min.watts) * 0.95))
            if best20min.hr > 0 { hrEstimates.append(Int(Double(best20min.hr) * 0.98)) }
        }

        if ftpEstimates.isEmpty {
            if best60min.watts > 0 {
                estimatedFTP = best60min.watts
                estimatedFTPHR = best60min.hr
            } else {
                return nil
            }
        } else {
            // Average of estimates, weighted towards 20min if available
            if ftpEstimates.count == 2 {
                // 15% from 5min, 85% from 20min - prioritize longer efforts
                estimatedFTP = Int(Double(ftpEstimates[0]) * 0.15 + Double(ftpEstimates[1]) * 0.85)
            } else {
                estimatedFTP = ftpEstimates[0]
            }
            estimatedFTPHR = hrEstimates.isEmpty ? 0 : hrEstimates.reduce(0, +) / hrEstimates.count
        }
            
            let estimatedVT2Power = Int(Double(estimatedFTP) * 0.88)
            let estimatedVT2HR = Int(Double(estimatedFTPHR) * 0.95)
            
            let estimatedVT1Power = Int(Double(estimatedFTP) * 0.75)
            let estimatedVT1HR = Int(Double(estimatedFTPHR) * 0.85)
            
            return (estimatedFTP, estimatedVT1Power, estimatedVT2Power, estimatedVT1HR, estimatedVT2HR, estimatedFTPHR)
        }
    }
