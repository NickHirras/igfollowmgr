#!/bin/bash

# GitHub Actions Setup Script
# This script helps set up the repository for GitHub Actions

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_status "Setting up GitHub Actions for IG Follow Manager"

# Check if we're in a git repository
if [ ! -d ".git" ]; then
    print_error "This is not a git repository. Please run this script from the root of your git repository."
    exit 1
fi

# Check if GitHub Actions workflows exist
if [ ! -d ".github/workflows" ]; then
    print_error "GitHub Actions workflows not found. Please ensure the .github/workflows directory exists."
    exit 1
fi

print_status "GitHub Actions workflows found"

# Check Flutter installation
if ! command -v flutter &> /dev/null; then
    print_warning "Flutter is not installed or not in PATH"
    print_status "Please install Flutter from https://flutter.dev/docs/get-started/install"
else
    FLUTTER_VERSION=$(flutter --version | head -n 1)
    print_success "Found $FLUTTER_VERSION"
fi

# Check if pubspec.yaml exists
if [ ! -f "pubspec.yaml" ]; then
    print_error "pubspec.yaml not found. This doesn't appear to be a Flutter project."
    exit 1
fi

print_success "Flutter project detected"

# Check for required files
print_status "Checking for required files..."

required_files=(
    ".github/workflows/ci.yml"
    ".github/workflows/release.yml"
    ".github/workflows/build-platform.yml"
    ".github/workflows/config.yml"
    ".github/README.md"
    "scripts/build.sh"
)

missing_files=()
for file in "${required_files[@]}"; do
    if [ ! -f "$file" ]; then
        missing_files+=("$file")
    fi
done

if [ ${#missing_files[@]} -gt 0 ]; then
    print_error "Missing required files:"
    for file in "${missing_files[@]}"; do
        echo "  - $file"
    done
    exit 1
fi

print_success "All required files found"

# Check Flutter dependencies
print_status "Checking Flutter dependencies..."
flutter pub get

# Run Flutter doctor
print_status "Running Flutter doctor..."
flutter doctor

# Check if tests pass
print_status "Running tests..."
if flutter test; then
    print_success "Tests passed"
else
    print_warning "Some tests failed. Please fix them before using GitHub Actions."
fi

# Check code analysis
print_status "Running code analysis..."
if flutter analyze; then
    print_success "Code analysis passed"
else
    print_warning "Code analysis found issues. Please fix them before using GitHub Actions."
fi

# Check formatting
print_status "Checking code formatting..."
if dart format --output=none --set-exit-if-changed .; then
    print_success "Code formatting is correct"
else
    print_warning "Code formatting issues found. Run 'dart format .' to fix them."
fi

print_success "GitHub Actions setup completed!"

echo ""
print_status "Next steps:"
echo "1. Push your changes to GitHub"
echo "2. Go to your repository's Actions tab"
echo "3. Enable GitHub Actions if prompted"
echo "4. Test the workflows by:"
echo "   - Pushing to main/develop branch (triggers CI)"
echo "   - Creating a tag starting with 'v' (triggers release)"
echo "   - Using the 'Build Platform' workflow manually"
echo ""
print_status "For Android releases, you'll need to set up code signing:"
echo "1. Generate a keystore file"
echo "2. Add the following secrets to your GitHub repository:"
echo "   - ANDROID_KEYSTORE_BASE64"
echo "   - ANDROID_KEYSTORE_PASSWORD"
echo "   - ANDROID_KEY_ALIAS"
echo "   - ANDROID_KEY_PASSWORD"
echo "3. Update android/app/build.gradle.kts for signing"
echo ""
print_status "For iOS releases, you'll need to set up code signing in Xcode"
echo ""
print_status "For more information, see .github/README.md"
