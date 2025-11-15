import Foundation
import Combine

struct FTPEntry: Codable, Identifiable {
    let id: UUID
    let date: Date
    let value: Int
    
    init(date: Date = Date(), value: Int) {
        self.id = UUID()
        self.date = date
        self.value = value
    }
}

class UserProfile: ObservableObject {
    @Published var ftp: Int = 250
    @Published var maxHR: Int = 190
    @Published var restingHR: Int = 50
    @Published var vt1Power: Int = 180
    @Published var vt2Power: Int = 230
    @Published var vt1HR: Int = 140
    @Published var vt2HR: Int = 165
    @Published var ftpHistory: [FTPEntry] = []
    @Published var useAutoEstimation: Bool = false
    
    init() {
        loadProfile()
    }
    
    func loadProfile() {
        if let saved = UserDefaults.standard.value(forKey: "user_ftp") as? Int { ftp = saved }
        if let saved = UserDefaults.standard.value(forKey: "user_maxHR") as? Int { maxHR = saved }
        if let saved = UserDefaults.standard.value(forKey: "user_restingHR") as? Int { restingHR = saved }
        if let saved = UserDefaults.standard.value(forKey: "user_vt1Power") as? Int { vt1Power = saved }
        if let saved = UserDefaults.standard.value(forKey: "user_vt2Power") as? Int { vt2Power = saved }
        if let saved = UserDefaults.standard.value(forKey: "user_vt1HR") as? Int { vt1HR = saved }
        if let saved = UserDefaults.standard.value(forKey: "user_vt2HR") as? Int { vt2HR = saved }
        if let saved = UserDefaults.standard.value(forKey: "user_useAutoEstimation") as? Bool { useAutoEstimation = saved }
        loadFTPHistory()
    }
    
    func saveProfile() {
        UserDefaults.standard.set(ftp, forKey: "user_ftp")
        UserDefaults.standard.set(maxHR, forKey: "user_maxHR")
        UserDefaults.standard.set(restingHR, forKey: "user_restingHR")
        UserDefaults.standard.set(vt1Power, forKey: "user_vt1Power")
        UserDefaults.standard.set(vt2Power, forKey: "user_vt2Power")
        UserDefaults.standard.set(vt1HR, forKey: "user_vt1HR")
        UserDefaults.standard.set(vt2HR, forKey: "user_vt2HR")
        UserDefaults.standard.set(useAutoEstimation, forKey: "user_useAutoEstimation")
        saveFTPHistory()
    }
    
    func addFTPEntry(value: Int, date: Date = Date()) -> (success: Bool, message: String) {
        let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date())!
        
        if date < oneYearAgo {
            return (false, "Date must be within the last year")
        }
        
        if date > Date() {
            return (false, "Date cannot be in the future")
        }
        
        let entry = FTPEntry(date: date, value: value)
        ftpHistory.append(entry)
        
        ftpHistory = ftpHistory
            .filter { $0.date >= oneYearAgo }
            .sorted { $0.date > $1.date }
        
        if ftpHistory.count > 20 {
            ftpHistory = Array(ftpHistory.prefix(20))
        }
        
        saveFTPHistory()
        return (true, "Entry added successfully")
    }
    
    func removeFTPEntry(id: UUID) {
        ftpHistory.removeAll { $0.id == id }
        saveFTPHistory()
    }
    
    func ftpTrend() -> (trend: String, percentage: Double, message: String) {
            guard ftpHistory.count >= 2 else {
                return ("stable", 0, "Add more FTP tests to see trends")
            }
            
            let sorted = ftpHistory.sorted { $0.date > $1.date }
            let latest = sorted[0].value
            let oldest = sorted[sorted.count - 1].value
            
            let totalChange = Double(latest - oldest) / Double(oldest) * 100
            let weeksSpan = Calendar.current.dateComponents([.weekOfYear], from: sorted.last!.date, to: sorted.first!.date).weekOfYear ?? 1
            let weeklyChange = weeksSpan > 0 ? totalChange / Double(weeksSpan) : totalChange
            
            if totalChange > 15 {
                return ("up", totalChange, "Excellent progress! +\(String(format: "%.1f", totalChange))% over \(weeksSpan) weeks (~\(String(format: "%.1f", weeklyChange))%/week)")
            } else if totalChange > 5 {
                return ("up", totalChange, "Good progress! +\(String(format: "%.1f", totalChange))% over \(weeksSpan) weeks")
            } else if totalChange < -10 {
                return ("down", totalChange, "FTP decreased \(String(format: "%.1f", abs(totalChange)))%. Consider recovery or reassessment.")
            } else if totalChange < -3 {
                return ("down", totalChange, "Minor decrease of \(String(format: "%.1f", abs(totalChange)))%")
            } else if totalChange > 0 {
                return ("up", totalChange, "Slight improvement of \(String(format: "%.1f", totalChange))%")
            } else if totalChange < 0 {
                return ("down", totalChange, "Slight decrease of \(String(format: "%.1f", abs(totalChange)))%")
            } else {
                return ("stable", 0, "FTP is stable")
            }
        }
        
        func ftpTrend12Weeks() -> (trend: String, percentage: Double, message: String) {
            let twelveWeeksAgo = Calendar.current.date(byAdding: .weekOfYear, value: -12, to: Date())!
            let recentHistory = ftpHistory.filter { $0.date >= twelveWeeksAgo }.sorted { $0.date > $1.date }
            
            guard recentHistory.count >= 2 else {
                return ("stable", 0, "Need more data in last 12 weeks")
            }
            
            let latest = recentHistory[0].value
            let oldest = recentHistory[recentHistory.count - 1].value
            
            let totalChange = Double(latest - oldest) / Double(oldest) * 100
            let weeksSpan = Calendar.current.dateComponents([.weekOfYear], from: recentHistory.last!.date, to: recentHistory.first!.date).weekOfYear ?? 1
            let weeklyChange = weeksSpan > 0 ? totalChange / Double(weeksSpan) : totalChange
            
            if totalChange > 10 {
                return ("up", totalChange, "+\(String(format: "%.1f", totalChange))% in \(weeksSpan) weeks (~\(String(format: "%.1f", weeklyChange))%/week)")
            } else if totalChange > 3 {
                return ("up", totalChange, "+\(String(format: "%.1f", totalChange))% in \(weeksSpan) weeks")
            } else if totalChange < -5 {
                return ("down", totalChange, "\(String(format: "%.1f", totalChange))% - consider recovery")
            } else if totalChange < 0 {
                return ("down", totalChange, "\(String(format: "%.1f", totalChange))% in \(weeksSpan) weeks")
            } else if totalChange > 0 {
                return ("up", totalChange, "+\(String(format: "%.1f", totalChange))% slight gain")
            } else {
                return ("stable", 0, "Stable over \(weeksSpan) weeks")
            }
        }
    private func loadFTPHistory() {
            if let data = UserDefaults.standard.data(forKey: "ftp_history"),
               let history = try? JSONDecoder().decode([FTPEntry].self, from: data) {
                ftpHistory = history
            }
        }
    private func saveFTPHistory() {
        if let encoded = try? JSONEncoder().encode(ftpHistory) {
            UserDefaults.standard.set(encoded, forKey: "ftp_history")
        }
    }
}
