#!/bin/bash

# PhotoSwiftUISmoothly Build Script
# Performance optimization and development utilities

echo "🚀 PhotoSwiftUISmoothly Build Script"
echo "=================================="

# Function to check if Xcode is available
check_xcode() {
    if ! command -v xcodebuild &> /dev/null; then
        echo "❌ Xcode not found. Please install Xcode to continue."
        exit 1
    fi
    echo "✅ Xcode detected"
}

# Function to clean build artifacts
clean_build() {
    echo "🧹 Cleaning build artifacts..."
    xcodebuild clean -project PhotoSwiftUISmoothly.xcodeproj -scheme PhotoSwiftUISmoothly
    echo "✅ Build cleaned"
}

# Function to build for debugging
build_debug() {
    echo "🔨 Building for debugging..."
    xcodebuild build -project PhotoSwiftUISmoothly.xcodeproj -scheme PhotoSwiftUISmoothly -configuration Debug
    echo "✅ Debug build complete"
}

# Function to build for release (performance optimized)
build_release() {
    echo "🚀 Building for release (performance optimized)..."
    xcodebuild build -project PhotoSwiftUISmoothly.xcodeproj -scheme PhotoSwiftUISmoothly -configuration Release
    echo "✅ Release build complete"
}

# Function to run performance tests
run_performance_tests() {
    echo "⚡ Running performance tests..."
    # Add custom performance testing here
    echo "📊 Performance tests would run here"
    echo "   - Memory usage monitoring"
    echo "   - Scrolling performance"
    echo "   - Image loading benchmarks"
}

# Function to analyze code
analyze_code() {
    echo "🔍 Analyzing code for performance issues..."
    xcodebuild analyze -project PhotoSwiftUISmoothly.xcodeproj -scheme PhotoSwiftUISmoothly
    echo "✅ Code analysis complete"
}

# Function to show help
show_help() {
    echo "Usage: $0 {clean|debug|release|test|analyze|help}"
    echo ""
    echo "Commands:"
    echo "  clean    - Clean build artifacts"
    echo "  debug    - Build for debugging"
    echo "  release  - Build for release (optimized)"
    echo "  test     - Run performance tests"
    echo "  analyze  - Analyze code for issues"
    echo "  help     - Show this help message"
}

# Main script logic
case "$1" in
    clean)
        check_xcode
        clean_build
        ;;
    debug)
        check_xcode
        build_debug
        ;;
    release)
        check_xcode
        build_release
        ;;
    test)
        check_xcode
        run_performance_tests
        ;;
    analyze)
        check_xcode
        analyze_code
        ;;
    help|*)
        show_help
        ;;
esac

echo ""
echo "🎉 Script completed!"
