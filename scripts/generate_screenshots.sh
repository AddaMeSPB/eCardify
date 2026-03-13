#!/bin/bash
#
# generate_screenshots.sh — App Store screenshot pipeline for eCardify
#
# Usage:
#   ./scripts/generate_screenshots.sh              # en-US only
#   ./scripts/generate_screenshots.sh --all         # all 10 locales
#   ./scripts/generate_screenshots.sh --validate    # check dimensions
#   ./scripts/generate_screenshots.sh --locale de-DE  # single locale
#
# Requirements:
#   - Xcode with iOS 17+ simulator
#   - iPhone 16 Pro Max simulator installed
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SPM_DIR="$PROJECT_DIR/eCardifySPM"
SCREENSHOTS_DIR="$PROJECT_DIR/fastlane/screenshots"
SIMULATOR="iPhone 16 Pro Max"

# All supported locales (must match ScreenshotLocaleConfig.all)
ALL_LOCALES=(
    "en-US"
    "de-DE"
    "es-MX"
    "fr-FR"
    "it"
    "ja"
    "ko"
    "pt-BR"
    "zh-Hans"
    "ru"
)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info()  { echo -e "${BLUE}ℹ ${NC}$*"; }
log_ok()    { echo -e "${GREEN}✓ ${NC}$*"; }
log_warn()  { echo -e "${YELLOW}⚠ ${NC}$*"; }
log_error() { echo -e "${RED}✗ ${NC}$*"; }

# ──────────────────────────────────────────────
# Functions
# ──────────────────────────────────────────────

generate_for_locale() {
    local locale="$1"
    log_info "Generating screenshots for locale: $locale"

    mkdir -p "$SCREENSHOTS_DIR/$locale"

    # xcodebuild test may exit non-zero in record mode; allow failures
    GENERATE_SCREENSHOTS=1 \
    SCREENSHOT_LOCALE="$locale" \
    xcodebuild test \
        -workspace "$PROJECT_DIR/eCardify.xcworkspace" \
        -scheme "ScreenshotTests" \
        -destination "platform=iOS Simulator,name=$SIMULATOR" \
        -resultBundlePath "$PROJECT_DIR/.build/screenshots-$locale.xcresult" \
        -quiet \
        2>&1 | while IFS= read -r line; do
            if echo "$line" | grep -q "Test Suite.*passed"; then
                log_ok "$line"
            elif echo "$line" | grep -q "error:"; then
                log_error "$line"
            fi
        done || true

    # Count generated files
    local count
    count=$(find "$SCREENSHOTS_DIR/$locale" -name "*.png" 2>/dev/null | wc -l | tr -d ' ')
    log_ok "Generated $count screenshots for $locale"
}

validate_screenshots() {
    log_info "Validating screenshot dimensions..."
    local errors=0

    for locale_dir in "$SCREENSHOTS_DIR"/*/; do
        [ -d "$locale_dir" ] || continue
        local locale
        locale=$(basename "$locale_dir")

        for png in "$locale_dir"*.png; do
            [ -f "$png" ] || continue
            local filename
            filename=$(basename "$png")

            local width height
            width=$(sips -g pixelWidth "$png" 2>/dev/null | tail -1 | awk '{print $2}')
            height=$(sips -g pixelHeight "$png" 2>/dev/null | tail -1 | awk '{print $2}')

            if echo "$filename" | grep -q "_iPhone"; then
                # iPhone 6.9": 1320×2868
                if [ "$width" = "1320" ] && [ "$height" = "2868" ]; then
                    log_ok "$locale/$filename → ${width}×${height}"
                else
                    log_error "$locale/$filename → ${width}×${height} (expected 1320×2868)"
                    errors=$((errors + 1))
                fi
            elif echo "$filename" | grep -q "_iPad"; then
                # iPad Pro 13": 2064×2752
                if [ "$width" = "2064" ] && [ "$height" = "2752" ]; then
                    log_ok "$locale/$filename → ${width}×${height}"
                else
                    log_error "$locale/$filename → ${width}×${height} (expected 2064×2752)"
                    errors=$((errors + 1))
                fi
            else
                log_warn "$locale/$filename → ${width}×${height} (unknown device)"
            fi
        done
    done

    if [ $errors -gt 0 ]; then
        log_error "$errors screenshot(s) have incorrect dimensions"
        return 1
    else
        log_ok "All screenshots have correct dimensions"
    fi
}

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  (none)           Generate en-US screenshots only"
    echo "  --all            Generate screenshots for all 10 locales"
    echo "  --locale LOCALE  Generate screenshots for a single locale"
    echo "  --validate       Validate existing screenshot dimensions"
    echo "  --clean          Remove all generated screenshots"
    echo "  -h, --help       Show this help message"
}

# ──────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────

cd "$PROJECT_DIR"

case "${1:-}" in
    --all)
        log_info "Generating screenshots for ALL ${#ALL_LOCALES[@]} locales..."
        echo ""
        for locale in "${ALL_LOCALES[@]}"; do
            generate_for_locale "$locale"
            echo ""
        done
        log_info "Validating dimensions..."
        validate_screenshots
        echo ""
        log_ok "Done! Screenshots saved to: $SCREENSHOTS_DIR"
        ;;

    --locale)
        if [ -z "${2:-}" ]; then
            log_error "Missing locale argument. Usage: $0 --locale en-US"
            exit 1
        fi
        generate_for_locale "$2"
        echo ""
        log_ok "Done! Screenshots saved to: $SCREENSHOTS_DIR/$2"
        ;;

    --validate)
        validate_screenshots
        ;;

    --clean)
        log_warn "Removing all generated screenshots..."
        rm -rf "$SCREENSHOTS_DIR"/*/
        log_ok "Cleaned: $SCREENSHOTS_DIR"
        ;;

    -h|--help)
        show_usage
        ;;

    "")
        log_info "Generating en-US screenshots only (use --all for all locales)"
        echo ""
        generate_for_locale "en-US"
        echo ""
        log_ok "Done! Screenshots saved to: $SCREENSHOTS_DIR/en-US"
        ;;

    *)
        log_error "Unknown option: $1"
        show_usage
        exit 1
        ;;
esac
