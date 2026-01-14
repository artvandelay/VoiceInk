import Foundation
import AppKit

@MainActor
class LicenseViewModel: ObservableObject {
    enum LicenseState: Equatable {
        case trial(daysRemaining: Int)
        case trialExpired
        case licensed
    }

    @Published private(set) var licenseState: LicenseState = .trial(daysRemaining: 7)  // Default to trial
    @Published var licenseKey: String = ""
    @Published var isValidating = false
    @Published var validationMessage: String?
    @Published private(set) var activationsLimit: Int = 0

    private let trialPeriodDays = 7
    private let polarService = PolarService()
    private let userDefaults = UserDefaults.standard
    private let licenseManager = LicenseManager.shared

    init() {
        loadLicenseState()
    }

    func startTrial() {
        // Only set trial start date if it hasn't been set before
        if licenseManager.trialStartDate == nil {
            licenseManager.trialStartDate = Date()
            licenseState = .trial(daysRemaining: trialPeriodDays)
            NotificationCenter.default.post(name: .licenseStatusChanged, object: nil)
        }
    }

    private func loadLicenseState() {
        // DISABLED: Always set to licensed state - no trial, no network calls
        licenseState = .licensed
        activationsLimit = 0
    }
    
    var canUseApp: Bool {
        // DISABLED: Always allow app usage - no license checks
        return true
    }
    
    func openPurchaseLink() {
        if let url = URL(string: "https://tryvoiceink.com/buy") {
            NSWorkspace.shared.open(url)
        }
    }
    
    func validateLicense() async {
        // DISABLED: No network calls - always succeed locally
        isValidating = true
        licenseState = .licensed
        validationMessage = "License validated successfully! (Offline mode)"
        NotificationCenter.default.post(name: .licenseStatusChanged, object: nil)
        isValidating = false
    }
    
    func removeLicense() {
        // Remove all license data from Keychain
        licenseManager.removeAll()

        // Reset UserDefaults flags
        userDefaults.set(false, forKey: "VoiceInkLicenseRequiresActivation")
        userDefaults.set(false, forKey: "VoiceInkHasLaunchedBefore")  // Allow trial to restart
        userDefaults.activationsLimit = 0

        licenseState = .trial(daysRemaining: trialPeriodDays)  // Reset to trial state
        licenseKey = ""
        validationMessage = nil
        activationsLimit = 0
        NotificationCenter.default.post(name: .licenseStatusChanged, object: nil)
        loadLicenseState()
    }
}


// UserDefaults extension for non-sensitive license settings
extension UserDefaults {
    var activationsLimit: Int {
        get { integer(forKey: "VoiceInkActivationsLimit") }
        set { set(newValue, forKey: "VoiceInkActivationsLimit") }
    }
}
