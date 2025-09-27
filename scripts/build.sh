#!/bin/bash

# IG Follow Manager Build Script
# This script helps build the app locally for different platforms

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS] [PLATFORM]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -c, --clean    Clean build before building"
    echo "  -t, --test     Run tests before building"
    echo "  -r, --release  Build in release mode (default: debug)"
    echo ""
    echo "Platforms:"
    echo "  android        Build for Android"
    echo "  ios            Build for iOS"
    echo "  web            Build for Web"
    echo "  windows        Build for Windows"
    echo "  macos          Build for macOS"
    echo "  linux          Build for Linux"
    echo "  all            Build for all platforms"
    echo ""
    echo "Examples:"
    echo "  $0 android                    # Build Android debug"
    echo "  $0 -r android                 # Build Android release"
    echo "  $0 -c -t web                  # Clean, test, and build web"
    echo "  $0 -r all                     # Build all platforms in release mode"
}

# Default values
CLEAN=false
TEST=false
RELEASE=false
PLATFORM=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -c|--clean)
            CLEAN=true
            shift
            ;;
        -t|--test)
            TEST=true
            shift
            ;;
        -r|--release)
            RELEASE=true
            shift
            ;;
        android|ios|web|windows|macos|linux|all)
            PLATFORM="$1"
            shift
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Check if platform is specified
if [ -z "$PLATFORM" ]; then
    print_error "Platform must be specified"
    show_usage
    exit 1
fi

# Set build mode
BUILD_MODE="debug"
if [ "$RELEASE" = true ]; then
    BUILD_MODE="release"
fi

print_status "Building IG Follow Manager for $PLATFORM in $BUILD_MODE mode"

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    print_error "Flutter is not installed or not in PATH"
    exit 1
fi

# Get Flutter version
FLUTTER_VERSION=$(flutter --version | head -n 1)
print_status "Using $FLUTTER_VERSION"

# Clean if requested
if [ "$CLEAN" = true ]; then
    print_status "Cleaning build..."
    flutter clean
fi

# Get dependencies
print_status "Getting dependencies..."
flutter pub get

# Run tests if requested
if [ "$TEST" = true ]; then
    print_status "Running tests..."
    flutter test
fi

# Build function for each platform
build_android() {
    print_status "Building Android..."
    if [ "$RELEASE" = true ]; then
        flutter build apk --release
        flutter build appbundle --release
        print_success "Android APK and AAB built successfully"
    else
        flutter build apk --debug
        print_success "Android APK built successfully"
    fi
}

build_ios() {
    print_status "Building iOS..."
    flutter build ios --$BUILD_MODE --no-codesign
    print_success "iOS build completed (no code signing)"
}

build_web() {
    print_status "Building Web..."
    flutter build web --$BUILD_MODE
    print_success "Web build completed"
}

build_windows() {
    print_status "Building Windows..."
    flutter build windows --$BUILD_MODE
    print_success "Windows build completed"
}

build_macos() {
    print_status "Building macOS..."
    flutter build macos --$BUILD_MODE
    print_success "macOS build completed"
}

build_linux() {
    print_status "Building Linux..."
    flutter build linux --$BUILD_MODE
    print_success "Linux build completed"
}

# Build based on platform
case $PLATFORM in
    android)
        build_android
        ;;
    ios)
        build_ios
        ;;
    web)
        build_web
        ;;
    windows)
        build_windows
        ;;
    macos)
        build_macos
        ;;
    linux)
        build_linux
        ;;
    all)
        print_status "Building for all platforms..."
        build_android
        build_ios
        build_web
        build_windows
        build_macos
        build_linux
        print_success "All platforms built successfully"
        ;;
esac

print_success "Build completed successfully!"
print_status "Build artifacts are in the build/ directory"
