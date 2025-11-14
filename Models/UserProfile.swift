import Foundation
import Combine

class UserProfile: ObservableObject {
    @Published var ftp: Int = 250
    @Published var maxHR: Int = 190
    @Published var restingHR: Int = 50
    @Published var vt1Power: Int = 180
    @Published var vt2Power: Int = 230
    @Published var vt1HR: Int = 140
    @Published var vt2HR: Int = 165
    
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
    }
    
    func saveProfile() {
        UserDefaults.standard.set(ftp, forKey: "user_ftp")
        UserDefaults.standard.set(maxHR, forKey: "user_maxHR")
        UserDefaults.standard.set(restingHR, forKey: "user_restingHR")
        UserDefaults.standard.set(vt1Power, forKey: "user_vt1Power")
        UserDefaults.standard.set(vt2Power, forKey: "user_vt2Power")
        UserDefaults.standard.set(vt1HR, forKey: "user_vt1HR")
        UserDefaults.standard.set(vt2HR, forKey: "user_vt2HR")
    }
}
