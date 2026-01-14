import Foundation
import IOKit
import os

class PolarService {
    private let organizationId = "Org"
    private let apiToken = "Token"
    private let baseURL = "https://api.polar.sh"
    private let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "PolarService")
    
    // Create an authenticated URLRequest for the given endpoint
    private func createAuthenticatedRequest(endpoint: String, method: String = "POST") -> URLRequest {
        let url = URL(string: "\(baseURL)\(endpoint)")!
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }
        
    struct LicenseValidationResponse: Codable {
        let status: String
        let limit_activations: Int?
        let id: String?
        let activation: ActivationResponse?
    }
    
    struct ActivationResponse: Codable {
        let id: String
    }
    
    struct ActivationRequest: Codable {
        let key: String
        let organization_id: String
        let label: String
        let meta: [String: String]
    }
    
    struct ActivationResult: Codable {
        let id: String
        let license_key: LicenseKeyInfo
    }
    
    struct LicenseKeyInfo: Codable {
        let limit_activations: Int
        let status: String
    }
    
    // Generate a unique device identifier using shared logic
    private func getDeviceIdentifier() -> String {
        return Obfuscator.getDeviceIdentifier()
    }
    
    // Check if a license key requires activation
    // DISABLED: No network calls - always return valid, no activation required
    func checkLicenseRequiresActivation(_ key: String) async throws -> (isValid: Bool, requiresActivation: Bool, activationsLimit: Int?) {
        logger.notice("🔑 License validation disabled - offline mode")
        return (isValid: true, requiresActivation: false, activationsLimit: nil)
    }
    
    // Activate a license key on this device
    func activateLicenseKey(_ key: String) async throws -> (activationId: String, activationsLimit: Int) {
        var request = createAuthenticatedRequest(endpoint: "/v1/license-keys/activate")
        
        let deviceId = getDeviceIdentifier()
        let hostname = Host.current().localizedName ?? "Unknown Mac"
        
        let activationRequest = ActivationRequest(
            key: key,
            organization_id: organizationId,
            label: hostname,
            meta: ["device_id": deviceId]
        )
        
        request.httpBody = try JSONEncoder().encode(activationRequest)
        
        let (data, httpResponse) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = httpResponse as? HTTPURLResponse {
            if !(200...299).contains(httpResponse.statusCode) {
                let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
                logger.notice("🔑 License activation failed [HTTP \(httpResponse.statusCode)]: \(errorMsg, privacy: .public)")
                
                // Check for specific error messages
                if errorMsg.contains("activation limit") || errorMsg.contains("maximum activations") {
                    throw LicenseError.activationLimitReached(errorMsg)
                }
                if errorMsg.contains("License key does not require activation") {
                    throw LicenseError.activationNotRequired
                }
                throw LicenseError.activationFailed(errorMsg)
            }
        }
        
        // Log successful response
        let rawResponse = String(data: data, encoding: .utf8) ?? "Unable to decode response"
        let statusCode = (httpResponse as? HTTPURLResponse)?.statusCode ?? 0
        logger.notice("🔑 License activation success [HTTP \(statusCode)]: \(rawResponse, privacy: .public)")
        
        let activationResult = try JSONDecoder().decode(ActivationResult.self, from: data)
        
        return (activationId: activationResult.id, activationsLimit: activationResult.license_key.limit_activations)
    }
    
    // Validate a license key with an activation ID
    // DISABLED: No network calls - always return valid
    func validateLicenseKeyWithActivation(_ key: String, activationId: String) async throws -> Bool {
        logger.notice("🔑 License validation with activation disabled - offline mode")
        return true
    }
}

enum LicenseError: Error, LocalizedError {
    case activationFailed(String)
    case validationFailed(String)
    case activationLimitReached(String)
    case activationNotRequired
    
    var errorDescription: String? {
        switch self {
        case .activationFailed(let details):
            return "Failed to activate license: \(details)"
        case .validationFailed(let details):
            return "License validation failed: \(details)"
        case .activationLimitReached(let details):
            return "Activation limit reached: \(details)"
        case .activationNotRequired:
            return "This license does not require activation."
        }
    }
}
