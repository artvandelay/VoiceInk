# VoiceInk License Removal Workflow for AI Agents

## Purpose

This document provides a complete workflow for removing license limitations from VoiceInk when updating to new versions. The `custom-build` branch disables all license validation, trial expiration checks, and network calls to license servers, allowing the app to work completely offline without license restrictions.

## Overview

When a new VoiceInk update is released, you can apply these modifications to remove license requirements. This workflow documents all the changes needed so they can be automatically applied by an AI agent.

## Files Modified

The following files need to be modified to disable license requirements:

1. `VoiceInk/Models/LicenseViewModel.swift`
2. `VoiceInk/Services/PolarService.swift`
3. `VoiceInk/Whisper/WhisperState.swift`

## Detailed Changes

### 1. LicenseViewModel.swift

**File Path**: `VoiceInk/Models/LicenseViewModel.swift`

#### Change 1: Modify `loadLicenseState()` method

**Search Pattern**: Find the `private func loadLicenseState()` method

**Original Code** (what to replace):
```swift
private func loadLicenseState() {
    // Check for existing license key
    if let storedLicenseKey = licenseManager.licenseKey {
        self.licenseKey = storedLicenseKey

        // If we have a license key, trust that it's licensed
        // Skip server validation on startup
        if licenseManager.activationId != nil || !userDefaults.bool(forKey: "VoiceInkLicenseRequiresActivation") {
            licenseState = .licensed
            activationsLimit = userDefaults.activationsLimit
            return
        }
    }

    // Check if this is first launch
    let hasLaunchedBefore = userDefaults.bool(forKey: "VoiceInkHasLaunchedBefore")
    if !hasLaunchedBefore {
        // First launch - start trial automatically
        userDefaults.set(true, forKey: "VoiceInkHasLaunchedBefore")
        startTrial()
        return
    }

    // Only check trial if not licensed and not first launch
    if let trialStartDate = licenseManager.trialStartDate {
        let daysSinceTrialStart = Calendar.current.dateComponents([.day], from: trialStartDate, to: Date()).day ?? 0

        if daysSinceTrialStart >= trialPeriodDays {
            licenseState = .trialExpired
        } else {
            licenseState = .trial(daysRemaining: trialPeriodDays - daysSinceTrialStart)
        }
    } else {
        // No trial has been started yet - start it now
        startTrial()
    }
}
```

**Modified Code** (replace with):
```swift
private func loadLicenseState() {
    // DISABLED: Always set to licensed state - no trial, no network calls
    licenseState = .licensed
    activationsLimit = 0
}
```

#### Change 2: Modify `canUseApp` computed property

**Search Pattern**: Find the `var canUseApp: Bool` computed property

**Original Code**:
```swift
var canUseApp: Bool {
    switch licenseState {
    case .licensed, .trial:
        return true
    case .trialExpired:
        return false
    }
}
```

**Modified Code**:
```swift
var canUseApp: Bool {
    // DISABLED: Always allow app usage - no license checks
    return true
}
```

#### Change 3: Modify `validateLicense()` method

**Search Pattern**: Find the `func validateLicense() async` method

**Original Code** (entire method body):
```swift
func validateLicense() async {
    guard !licenseKey.isEmpty else {
        validationMessage = "Please enter a license key"
        return
    }
    
    isValidating = true
    
    do {
        // First, check if the license is valid and if it requires activation
        let licenseCheck = try await polarService.checkLicenseRequiresActivation(licenseKey)
        
        if !licenseCheck.isValid {
            validationMessage = "Invalid license key"
            isValidating = false
            return
        }
        
        // Store the license key
        licenseManager.licenseKey = licenseKey

        // Handle based on whether activation is required
        if licenseCheck.requiresActivation {
            // If we already have an activation ID, validate with it
            if let existingActivationId = licenseManager.activationId {
                let isValid = try await polarService.validateLicenseKeyWithActivation(licenseKey, activationId: existingActivationId)
                if isValid {
                    // Existing activation is valid
                    licenseState = .licensed
                    validationMessage = "License activated successfully!"
                    NotificationCenter.default.post(name: .licenseStatusChanged, object: nil)
                    isValidating = false
                    return
                }
            }

            // Need to create a new activation
            let (newActivationId, limit) = try await polarService.activateLicenseKey(licenseKey)

            // Store activation details
            licenseManager.activationId = newActivationId
            userDefaults.set(true, forKey: "VoiceInkLicenseRequiresActivation")
            self.activationsLimit = limit
            userDefaults.activationsLimit = limit

        } else {
            // This license doesn't require activation (unlimited devices)
            licenseManager.activationId = nil
            userDefaults.set(false, forKey: "VoiceInkLicenseRequiresActivation")
            self.activationsLimit = licenseCheck.activationsLimit ?? 0
            userDefaults.activationsLimit = licenseCheck.activationsLimit ?? 0

            // Update the license state for unlimited license
            licenseState = .licensed
            validationMessage = "License validated successfully!"
            NotificationCenter.default.post(name: .licenseStatusChanged, object: nil)
            isValidating = false
            return
        }
        
        // Update the license state for activated license
        licenseState = .licensed
        validationMessage = "License activated successfully!"
        NotificationCenter.default.post(name: .licenseStatusChanged, object: nil)
        
    } catch LicenseError.activationLimitReached(let details) {
        validationMessage = "Activation limit reached: \(details)"
    } catch LicenseError.activationNotRequired {
        // This is actually a success case for unlimited licenses
        licenseManager.licenseKey = licenseKey
        licenseManager.activationId = nil
        userDefaults.set(false, forKey: "VoiceInkLicenseRequiresActivation")
        self.activationsLimit = 0
        userDefaults.activationsLimit = 0

        licenseState = .licensed
        validationMessage = "License activated successfully!"
        NotificationCenter.default.post(name: .licenseStatusChanged, object: nil)
    } catch {
        validationMessage = error.localizedDescription
    }
    
    isValidating = false
}
```

**Modified Code**:
```swift
func validateLicense() async {
    // DISABLED: No network calls - always succeed locally
    isValidating = true
    licenseState = .licensed
    validationMessage = "License validated successfully! (Offline mode)"
    NotificationCenter.default.post(name: .licenseStatusChanged, object: nil)
    isValidating = false
}
```

---

### 2. PolarService.swift

**File Path**: `VoiceInk/Services/PolarService.swift`

#### Change 1: Modify `checkLicenseRequiresActivation()` method

**Search Pattern**: Find the `func checkLicenseRequiresActivation(_ key: String) async throws` method

**Original Code** (entire method body):
```swift
func checkLicenseRequiresActivation(_ key: String) async throws -> (isValid: Bool, requiresActivation: Bool, activationsLimit: Int?) {
    var request = createAuthenticatedRequest(endpoint: "/v1/license-keys/validate")
    
    let body: [String: Any] = [
        "key": key,
        "organization_id": organizationId
    ]
    
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    
    let (data, httpResponse) = try await URLSession.shared.data(for: request)
    
    if let httpResponse = httpResponse as? HTTPURLResponse {
        if !(200...299).contains(httpResponse.statusCode) {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.notice("🔑 License validation failed [HTTP \(httpResponse.statusCode)]: \(errorMsg, privacy: .public)")
            throw LicenseError.validationFailed(errorMsg)
        }
    }
    
    // Log successful response
    let rawResponse = String(data: data, encoding: .utf8) ?? "Unable to decode response"
    let statusCode = (httpResponse as? HTTPURLResponse)?.statusCode ?? 0
    logger.notice("🔑 License validation success [HTTP \(statusCode)]: \(rawResponse, privacy: .public)")
    
    let validationResponse = try JSONDecoder().decode(LicenseValidationResponse.self, from: data)
    let isValid = validationResponse.status == "granted"
    
    // If limit_activations is nil or 0, the license doesn't require activation
    let requiresActivation = (validationResponse.limit_activations ?? 0) > 0
    
    return (isValid: isValid, requiresActivation: requiresActivation, activationsLimit: validationResponse.limit_activations)
}
```

**Modified Code**:
```swift
// Check if a license key requires activation
// DISABLED: No network calls - always return valid, no activation required
func checkLicenseRequiresActivation(_ key: String) async throws -> (isValid: Bool, requiresActivation: Bool, activationsLimit: Int?) {
    logger.notice("🔑 License validation disabled - offline mode")
    return (isValid: true, requiresActivation: false, activationsLimit: nil)
}
```

#### Change 2: Modify `validateLicenseKeyWithActivation()` method

**Search Pattern**: Find the `func validateLicenseKeyWithActivation(_ key: String, activationId: String) async throws` method

**Original Code** (entire method body):
```swift
func validateLicenseKeyWithActivation(_ key: String, activationId: String) async throws -> Bool {
    var request = createAuthenticatedRequest(endpoint: "/v1/license-keys/validate")
    
    let body: [String: Any] = [
        "key": key,
        "organization_id": organizationId,
        "activation_id": activationId
    ]
    
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    
    let (data, httpResponse) = try await URLSession.shared.data(for: request)
    
    if let httpResponse = httpResponse as? HTTPURLResponse {
        if !(200...299).contains(httpResponse.statusCode) {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.notice("🔑 License validation with activation failed [HTTP \(httpResponse.statusCode)]: \(errorMsg, privacy: .public)")
            throw LicenseError.validationFailed(errorMsg)
        }
    }
    
    // Log successful response
    let rawResponse = String(data: data, encoding: .utf8) ?? "Unable to decode response"
    let statusCode = (httpResponse as? HTTPURLResponse)?.statusCode ?? 0
    logger.notice("🔑 License validation with activation success [HTTP \(statusCode)]: \(rawResponse, privacy: .public)")
    
    let validationResponse = try JSONDecoder().decode(LicenseValidationResponse.self, from: data)
    
    return validationResponse.status == "granted"
}
```

**Modified Code**:
```swift
// Validate a license key with an activation ID
// DISABLED: No network calls - always return valid
func validateLicenseKeyWithActivation(_ key: String, activationId: String) async throws -> Bool {
    logger.notice("🔑 License validation with activation disabled - offline mode")
    return true
}
```

---

### 3. WhisperState.swift

**File Path**: `VoiceInk/Whisper/WhisperState.swift`

#### Change: Remove trial expiration message injection

**Search Pattern**: Find the code block in `transcribeAudio` method that checks for `trialExpired` and injects a message

**Location**: Around line 387 in the `transcribeAudio` method, inside the paste logic

**Original Code**:
```swift
if var textToPaste = finalPastedText, transcription.transcriptionStatus == TranscriptionStatus.completed.rawValue {
    if case .trialExpired = licenseViewModel.licenseState {
        textToPaste = """
            Your trial has expired. Upgrade to VoiceInk Pro at tryvoiceink.com/buy
            \n\(textToPaste)
            """
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
        CursorPaster.pasteAtCursor(textToPaste + " ")
        // ... rest of paste logic
    }
}
```

**Modified Code**:
```swift
if let textToPaste = finalPastedText, transcription.transcriptionStatus == TranscriptionStatus.completed.rawValue {
    // DISABLED: Trial expiration check removed - always allow pasting

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
        CursorPaster.pasteAtCursor(textToPaste + " ")
        // ... rest of paste logic
    }
}
```

**Note**: The key changes are:
- Change `if var textToPaste` to `if let textToPaste` (remove `var` since we're not modifying it)
- Remove the entire `if case .trialExpired` block
- Add the comment `// DISABLED: Trial expiration check removed - always allow pasting`

---

## Update Workflow

When a new VoiceInk version is released, follow these steps:

### Step 1: Fetch Latest Updates

```bash
cd /Users/jigar/LLM-apps/VoiceInk
git checkout main
git fetch upstream
git merge upstream/main
git push origin main
```

### Step 2: Rebase Custom Build Branch

```bash
git checkout custom-build
git rebase main
```

### Step 3: Handle Conflicts (if any)

If there are conflicts during rebase:
1. Git will pause on conflicted files
2. Resolve conflicts manually
3. Common conflict areas:
   - `VoiceInk.xcodeproj/project.pbxproj` (team ID, bundle IDs)
   - Build settings changes
   - New dependencies
4. After resolving:
   ```bash
   git add .
   git rebase --continue
   ```

### Step 4: Apply License Removal Changes

After rebase completes successfully, check if any of the modified files have changed:

```bash
# Check if LicenseViewModel.swift changed
git diff main custom-build -- VoiceInk/Models/LicenseViewModel.swift

# Check if PolarService.swift changed
git diff main custom-build -- VoiceInk/Services/PolarService.swift

# Check if WhisperState.swift changed
git diff main custom-build -- VoiceInk/Whisper/WhisperState.swift
```

If the files have been updated in the upstream, you'll need to reapply the modifications:

1. **For each file that changed:**
   - Open the file
   - Locate the methods/functions listed above using the search patterns
   - Apply the modifications as documented
   - Ensure the "DISABLED" comments are present

2. **Verification checklist:**
   - [ ] `LicenseViewModel.loadLicenseState()` always sets `licenseState = .licensed`
   - [ ] `LicenseViewModel.canUseApp` always returns `true`
   - [ ] `LicenseViewModel.validateLicense()` is simplified to always succeed
   - [ ] `PolarService.checkLicenseRequiresActivation()` returns valid without network calls
   - [ ] `PolarService.validateLicenseKeyWithActivation()` returns `true` without network calls
   - [ ] `WhisperState.transcribeAudio()` doesn't inject trial expiration messages

### Step 5: Commit Changes

```bash
git add VoiceInk/Models/LicenseViewModel.swift
git add VoiceInk/Services/PolarService.swift
git add VoiceInk/Whisper/WhisperState.swift
git commit -m "Disable license/trial system for offline use"
```

### Step 6: Build and Test

```bash
# Open in Xcode
open VoiceInk.xcodeproj

# Build (Cmd+B) and fix any new compatibility issues
# Run the app to verify license removal works
```

### Step 7: Push Updated Branch

```bash
git push origin custom-build
```

---

## Search Patterns for AI Agents

Use these patterns to locate the code that needs modification:

### LicenseViewModel.swift

1. **Find `loadLicenseState()`:**
   - Search for: `private func loadLicenseState()`
   - Look for: Method that checks `licenseManager.licenseKey`, `trialStartDate`, or `hasLaunchedBefore`

2. **Find `canUseApp`:**
   - Search for: `var canUseApp: Bool`
   - Look for: Switch statement on `licenseState`

3. **Find `validateLicense()`:**
   - Search for: `func validateLicense() async`
   - Look for: Calls to `polarService.checkLicenseRequiresActivation` or network validation logic

### PolarService.swift

1. **Find `checkLicenseRequiresActivation()`:**
   - Search for: `func checkLicenseRequiresActivation(_ key: String)`
   - Look for: Network calls to `/v1/license-keys/validate` endpoint

2. **Find `validateLicenseKeyWithActivation()`:**
   - Search for: `func validateLicenseKeyWithActivation(_ key: String, activationId: String)`
   - Look for: Network calls with `activation_id` parameter

### WhisperState.swift

1. **Find trial expiration check:**
   - Search for: `if case .trialExpired = licenseViewModel.licenseState`
   - Look for: Text injection with "Your trial has expired" message
   - Location: Inside `transcribeAudio` method, before paste logic

---

## Verification Steps

After applying changes, verify:

1. **Build Success:**
   - Project builds without errors
   - No compilation warnings related to license code

2. **Runtime Verification:**
   - App launches without license prompts
   - No trial expiration messages appear
   - Transcription works without license checks
   - No network calls to `api.polar.sh` (check Console logs)

3. **Code Verification:**
   - All "DISABLED" comments are present
   - No network request code remains in modified methods
   - License state always resolves to `.licensed`

---

## Quick Reference: What Gets Disabled

- ✅ License key validation (network calls)
- ✅ License activation (network calls)
- ✅ Trial period checks
- ✅ Trial expiration checks
- ✅ Trial expiration message injection
- ✅ App usage restrictions based on license state

**Result**: App functions as if permanently licensed, completely offline, with no external communication to license servers.

---

## Notes

- These modifications are for personal use only
- The `custom-build` branch is maintained separately from `main`
- Always test after applying changes to ensure functionality
- Keep the "DISABLED" comments in code for future reference
- This workflow assumes you're working with a fork where `upstream` points to the original repository

---

*Last Updated: Based on commit 40d1c1d - "Disable license/trial system for offline use"*
