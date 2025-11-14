import Foundation
import Combine

class StravaService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var accessToken: String?
    
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
            if cacheAge < 86400 {
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
        
        var bestPowers: [Int: Int] = [
            5: 0,
            10: 0,
            30: 0,
            60: 0,
            120: 0,
            300: 0,
            600: 0,
            1200: 0,
            1800: 0,
            3600: 0,
            7200: 0,
            10800: 0,
            14400: 0,
            18000: 0,
            21600: 0
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
                
                if let streamPowers = await fetchActivityStream(activityId: activityId) {
                    let activityBests = calculateBestPowers(from: streamPowers)
                    
                    for (duration, watts) in activityBests {
                        if watts > bestPowers[duration]! {
                            bestPowers[duration] = watts
                        }
                    }
                }
            }
        } catch {
            print("Fetch activities error: \(error)")
            return nil
        }
        
        let result = [
            PowerPoint(duration: 5, label: "5s", watts: bestPowers[5]!),
            PowerPoint(duration: 10, label: "10s", watts: bestPowers[10]!),
            PowerPoint(duration: 30, label: "30s", watts: bestPowers[30]!),
            PowerPoint(duration: 60, label: "1m", watts: bestPowers[60]!),
            PowerPoint(duration: 120, label: "2m", watts: bestPowers[120]!),
            PowerPoint(duration: 300, label: "5m", watts: bestPowers[300]!),
            PowerPoint(duration: 600, label: "10m", watts: bestPowers[600]!),
            PowerPoint(duration: 1200, label: "20m", watts: bestPowers[1200]!),
            PowerPoint(duration: 1800, label: "30m", watts: bestPowers[1800]!),
            PowerPoint(duration: 3600, label: "1h", watts: bestPowers[3600]!),
            PowerPoint(duration: 7200, label: "2h", watts: bestPowers[7200]!),
            PowerPoint(duration: 10800, label: "3h", watts: bestPowers[10800]!),
            PowerPoint(duration: 14400, label: "4h", watts: bestPowers[14400]!),
            PowerPoint(duration: 18000, label: "5h", watts: bestPowers[18000]!),
            PowerPoint(duration: 21600, label: "6h", watts: bestPowers[21600]!)
        ]
        
        savePowerCurveCache(result)
        
        return result
    }
    
    private func fetchActivityStream(activityId: Int) async -> [Int]? {
        guard let token = accessToken else { return nil }
        
        let url = URL(string: "https://www.strava.com/api/v3/activities/\(activityId)/streams?keys=watts&key_by_type=true")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let wattsData = json["watts"] as? [String: Any],
               let wattsArray = wattsData["data"] as? [Int] {
                return wattsArray
            }
        } catch {
            print("Fetch stream error: \(error)")
        }
        return nil
    }
    
    private func calculateBestPowers(from watts: [Int]) -> [Int: Int] {
        var bests: [Int: Int] = [
            5: 0,
            10: 0,
            30: 0,
            60: 0,
            120: 0,
            300: 0,
            600: 0,
            1200: 0,
            1800: 0,
            3600: 0,
            7200: 0,
            10800: 0,
            14400: 0,
            18000: 0,
            21600: 0
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
}
