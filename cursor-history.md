## 📋 VoiceInk Custom Build - Upgrade Notes from Cursor

### **Project Overview**
- **Repository**: Custom fork at [https://github.com/artvandelay/VoiceInk](https://github.com/artvandelay/VoiceInk)
- **Original**: [https://github.com/Beingpax/VoiceInk](https://github.com/Beingpax/VoiceInk)
- **Local Path**: `/Users/jigar/LLM-apps/VoiceInk`
- **User**: artvandelay (GitHub username)

### **Setup Summary (What We Did)**

#### 1. **Build Environment Setup**
- **macOS**: 14.5 (Sonoma)
- **Xcode**: 16 (required - original project uses objectVersion 77)
- **Issue**: Project needed Xcode 16 but user had 15.4
- **Solution**: Installed Xcode 16 (compatible with macOS 14.5)

#### 2. **Whisper.cpp Framework Build**
- **Problem**: Project expected `whisper.xcframework` but wasn't included in repo
- **Solution**: 
  ```bash
  git clone https://github.com/ggerganov/whisper.cpp.git
  cd whisper.cpp
  ./build-xcframework.sh
  mv build-apple/whisper.xcframework /Users/jigar/LLM-apps/VoiceInk/Frameworks/
  ```
- **Result**: Framework already integrated in project settings, just needed the file

#### 3. **Xcode 16 Compatibility Fixes**
- **ENABLE_NATIVE_SPEECH_ANALYZER**: Removed from build settings (caused SpeechTranscriber errors)
- **Info.plist conflict**: Removed `INFOPLIST_FILE = VoiceInk/Info.plist` (conflicted with `GENERATE_INFOPLIST_FILE = YES`)
- **String: Identifiable**: Restored extension needed for SwiftUI sheets
- **SpeechTranscriber type**: Changed parameter from `SpeechTranscriber` to `Any` in NativeAppleTranscriptionService.swift:155

#### 4. **Code Signing Setup**
- **Team ID**: Changed to `TQKX6M645L` (user's developer account)
- **Bundle IDs**: Changed from `com.prakashjoshipax.*` to `com.artvandelay.*`

#### 5. **Git Workflow Setup**
```bash
# Set up fork tracking
git remote rename origin upstream
git remote add origin https://github.com/artvandelay/VoiceInk.git

# Create custom branch for modifications
git checkout -b custom-build
git add -A && git commit -m "Custom build setup: Updated team ID, bundle identifiers, and Xcode 16 compatibility fixes"
git push -u origin custom-build
```

### **Current State**
- ✅ **Build Status**: SUCCESS (with 81 harmless warnings)
- ✅ **Installation**: Copied to `/Applications/VoiceInk.app`
- ✅ **Git Setup**: Fork with upstream tracking configured
- ✅ **Branch**: `custom-build` contains all working modifications

### **🔄 UPGRADE PROCEDURE** (Future Updates)

#### **When Original VoiceInk Repository Updates:**

1. **Fetch Updates from Upstream**
   ```bash
   cd /Users/jigar/LLM-apps/VoiceInk
   git checkout main
   git fetch upstream
   git merge upstream/main
   git push origin main
   ```

2. **Apply Updates to Custom Build**
   ```bash
   git checkout custom-build
   git rebase main
   ```

3. **Handle Conflicts (if any)**
   - Git will pause on conflicts
   - Edit conflicted files manually
   - Common conflict areas:
     - `VoiceInk.xcodeproj/project.pbxproj` (team ID, bundle IDs)
     - Build settings changes
     - New dependencies
   ```bash
   git add .
   git rebase --continue
   ```

4. **Rebuild Whisper Framework (if needed)**
   - Check if whisper.cpp dependency updated
   - If yes, rebuild framework:
   ```bash
   rm -rf Frameworks/whisper.xcframework
   git clone https://github.com/ggerganov/whisper.cpp.git /tmp/whisper.cpp
   cd /tmp/whisper.cpp && ./build-xcframework.sh
   mv build-apple/whisper.xcframework /Users/jigar/LLM-apps/VoiceInk/Frameworks/
   cd /Users/jigar/LLM-apps/VoiceInk
   git add Frameworks/whisper.xcframework
   git commit -m "Update whisper.xcframework to latest version"
   ```

5. **Build & Test**
   ```bash
   # Open in Xcode
   open VoiceInk.xcodeproj
   # Build (Cmd+B) and fix any new compatibility issues
   ```

6. **Reinstall**
   ```bash
   # Find the built app
   cp -R "~/Library/Developer/Xcode/DerivedData/VoiceInk-*/Build/Products/Debug/VoiceInk.app" "/Applications/"
   ```

7. **Push Updated Custom Build**
   ```bash
   git push origin custom-build
   ```

### **⚠️ Potential Upgrade Issues & Solutions**

#### **Swift Version Updates**
- **Problem**: New Swift features, deprecations
- **Solution**: Address compiler warnings, update deprecated APIs

#### **New Dependencies**
- **Problem**: New Swift Package Manager dependencies
- **Solution**: Let Xcode resolve automatically, check for conflicts

#### **Build System Changes**
- **Problem**: Xcode project format updates
- **Solution**: May need newer Xcode version

#### **Whisper.cpp Integration Changes**
- **Problem**: Framework interface changes
- **Solution**: Rebuild framework, update integration code if needed

### **🚨 Emergency Fallback**
If upgrade breaks everything:
```bash
git checkout custom-build
git reset --hard HEAD~1  # Go back to last working commit
```

### **📁 Important File Locations**
- **Project**: `/Users/jigar/LLM-apps/VoiceInk/`
- **Built App**: `~/Library/Developer/Xcode/DerivedData/VoiceInk-*/Build/Products/Debug/VoiceInk.app`
- **Installed App**: `/Applications/VoiceInk.app`
- **Whisper Framework**: `/Users/jigar/LLM-apps/VoiceInk/Frameworks/whisper.xcframework`

### **🔧 Key Customizations to Preserve**
1. **Team ID**: `TQKX6M645L`
2. **Bundle IDs**: `com.artvandelay.*` pattern
3. **Build Settings**: No `ENABLE_NATIVE_SPEECH_ANALYZER`
4. **Info.plist**: Only `GENERATE_INFOPLIST_FILE = YES`
5. **String Extension**: Keep `String: Identifiable` for SwiftUI
6. **SpeechTranscriber**: Keep parameter as `Any` type

---
*Last Updated: September 16, 2025*  
*Status: Working build with successful installation*