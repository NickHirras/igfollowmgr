# GitHub Actions Workflows

This repository includes several GitHub Actions workflows to automate building, testing, and releasing the IG Follow Manager Flutter application.

## Workflows

### 1. CI (`ci.yml`)
**Triggers:** Push to `main`/`develop` branches, Pull Requests

**Purpose:** Continuous Integration - runs tests, code analysis, and basic build checks on every push and PR.

**Jobs:**
- **Test**: Runs Flutter unit tests
- **Analyze**: Runs `flutter analyze` and checks code formatting
- **Build Check**: Verifies that the app can build for Android, Web, and Linux

### 2. Release (`release.yml`)
**Triggers:** Git tags starting with `v*`, Manual dispatch

**Purpose:** Creates full releases with builds for all supported platforms.

**Platforms Built:**
- **Android**: APK and App Bundle (AAB)
- **iOS**: Xcode archive (requires manual code signing)
- **Web**: Static web build
- **Windows**: Windows executable
- **macOS**: macOS app bundle and DMG
- **Linux**: Linux executable and AppImage

**Usage:**
```bash
# Create a release by pushing a tag
git tag v1.0.0
git push origin v1.0.0

# Or trigger manually from GitHub Actions tab
```

### 3. Build Platform (`build-platform.yml`)
**Triggers:** Manual dispatch only

**Purpose:** Build for specific platforms on-demand without creating a full release.

**Options:**
- **Platform**: Choose specific platform or "all"
- **Build Type**: Debug or Release
- **Upload Artifact**: Whether to upload build artifacts

**Usage:**
1. Go to Actions tab in GitHub
2. Select "Build Platform" workflow
3. Click "Run workflow"
4. Choose your options

## Setup Requirements

### For Android Releases
To build signed Android releases, you'll need to:

1. Generate a keystore file
2. Add the following secrets to your GitHub repository:
   - `ANDROID_KEYSTORE_BASE64`: Base64 encoded keystore file
   - `ANDROID_KEYSTORE_PASSWORD`: Keystore password
   - `ANDROID_KEY_ALIAS`: Key alias
   - `ANDROID_KEY_PASSWORD`: Key password

3. Update `android/app/build.gradle.kts` to use the signing configuration:

```kotlin
android {
    signingConfigs {
        release {
            keyAlias System.getenv("ANDROID_KEY_ALIAS")
            keyPassword System.getenv("ANDROID_KEY_PASSWORD")
            storeFile file(System.getenv("ANDROID_KEYSTORE_BASE64"))
            storePassword System.getenv("ANDROID_KEYSTORE_PASSWORD")
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.getByName("release")
        }
    }
}
```

### For iOS Releases
iOS builds require:
1. Apple Developer account
2. Provisioning profiles and certificates
3. Code signing setup in Xcode

The current workflow builds without code signing. For App Store distribution, you'll need to:
1. Set up code signing in Xcode
2. Configure the workflow to use your signing certificates

### For Desktop Releases
Desktop builds work out of the box but may require:
- **Windows**: Visual Studio Build Tools
- **macOS**: Xcode Command Line Tools
- **Linux**: Additional system packages (handled by workflow)

## Artifacts

### Release Artifacts
When a release is created, the following artifacts are uploaded:
- `igfollowmgr-android.apk` - Android APK
- `igfollowmgr-android.aab` - Android App Bundle
- `igfollowmgr-ios.xcarchive` - iOS Archive
- `igfollowmgr-web.zip` - Web build
- `igfollowmgr-windows.zip` - Windows executable
- `igfollowmgr-macos.dmg` - macOS DMG
- `igfollowmgr-linux.AppImage` - Linux AppImage

### CI Artifacts
CI builds create artifacts for testing and verification purposes.

## Environment Variables

The workflows use the following environment variables:
- `FLUTTER_VERSION`: Flutter SDK version (currently 3.24.5)
- `GITHUB_TOKEN`: Automatically provided by GitHub

## Troubleshooting

### Common Issues

1. **Build Failures**: Check the logs for specific error messages
2. **Missing Dependencies**: Ensure all Flutter dependencies are properly declared in `pubspec.yaml`
3. **Code Signing Issues**: Verify your signing certificates and provisioning profiles
4. **Platform-Specific Issues**: Check platform-specific requirements in the Flutter documentation

### Getting Help

1. Check the Actions tab for detailed logs
2. Review Flutter documentation for platform-specific build requirements
3. Ensure your Flutter version is compatible with the workflow version

## Customization

### Adding New Platforms
To add support for new platforms:
1. Add the platform to the matrix in `release.yml`
2. Add build steps for the new platform
3. Update artifact upload steps
4. Update the release notes template

### Modifying Build Steps
You can customize build steps by:
1. Adding environment variables
2. Modifying build commands
3. Adding pre/post build steps
4. Changing artifact paths

### Adding Tests
To add integration tests:
1. Create test files in `integration_test/` directory
2. Update the CI workflow to run integration tests
3. Add test-specific dependencies to `pubspec.yaml`
