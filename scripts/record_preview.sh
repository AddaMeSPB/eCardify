#!/bin/bash
#
# record_preview.sh — App Store preview video recording for eCardify
#
# Usage:
#   ./scripts/record_preview.sh              # Record preview on iPhone simulator
#   ./scripts/record_preview.sh --convert    # Convert recorded .mov to App Store format
#
# Flow:
#   1. Boots iPhone 17 Pro Max simulator
#   2. Builds & installs eCardify in DEMO_MODE
#   3. Records simulator video (press Ctrl+C to stop)
#   4. Converts to App Store spec (886x1920, H.264, 30fps)
#
# Requirements:
#   - Xcode with iPhone 17 Pro Max simulator
#   - ffmpeg (brew install ffmpeg)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$PROJECT_DIR/fastlane/previews"
RAW_VIDEO="$OUTPUT_DIR/raw_recording.mov"
FINAL_VIDEO="$OUTPUT_DIR/eCardify_Preview_iPhone.mp4"
SIMULATOR="iPhone 17 Pro Max"
BUNDLE_ID="cardify.addame.com.eCardify"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}ℹ ${NC}$*"; }
log_ok()    { echo -e "${GREEN}✓ ${NC}$*"; }
log_warn()  { echo -e "${YELLOW}⚠ ${NC}$*"; }
log_error() { echo -e "${RED}✗ ${NC}$*"; }

# ──────────────────────────────────────────────
# Convert existing recording
# ──────────────────────────────────────────────

convert_video() {
    if [ ! -f "$RAW_VIDEO" ]; then
        log_error "No raw recording found at $RAW_VIDEO"
        log_info "Run without --convert first to record a video"
        exit 1
    fi

    if ! command -v ffmpeg &> /dev/null; then
        log_error "ffmpeg not found. Install with: brew install ffmpeg"
        exit 1
    fi

    log_info "Converting to App Store format (886×1920, H.264, 30fps)..."

    ffmpeg -y -i "$RAW_VIDEO" \
        -vf "scale=886:1920:force_original_aspect_ratio=decrease,pad=886:1920:(ow-iw)/2:(oh-ih)/2:black" \
        -c:v libx264 -preset slow -crf 18 \
        -pix_fmt yuv420p \
        -r 30 \
        -an \
        -movflags +faststart \
        "$FINAL_VIDEO"

    log_ok "Preview video saved to: $FINAL_VIDEO"

    # Show file info
    local duration
    duration=$(ffprobe -v quiet -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$FINAL_VIDEO" 2>/dev/null | cut -d. -f1)
    local size
    size=$(du -h "$FINAL_VIDEO" | cut -f1)

    log_info "Duration: ${duration}s | Size: $size"

    if [ "$duration" -lt 15 ]; then
        log_warn "Video is under 15s — App Store requires 15-30 seconds"
    elif [ "$duration" -gt 30 ]; then
        log_warn "Video is over 30s — App Store requires 15-30 seconds"
    else
        log_ok "Duration is within App Store limits (15-30s)"
    fi
}

# ──────────────────────────────────────────────
# Record
# ──────────────────────────────────────────────

record() {
    mkdir -p "$OUTPUT_DIR"

    # Find or boot simulator
    log_info "Looking for $SIMULATOR simulator..."
    local sim_id
    sim_id=$(xcrun simctl list devices available -j | python3 -c "
import json, sys
data = json.load(sys.stdin)
for runtime, devices in data['devices'].items():
    for d in devices:
        if d['name'] == '$SIMULATOR' and d['isAvailable']:
            print(d['udid'])
            sys.exit(0)
sys.exit(1)
" 2>/dev/null) || {
        log_error "Could not find available $SIMULATOR simulator"
        log_info "Available simulators:"
        xcrun simctl list devices available | grep -i "iphone.*pro.*max"
        exit 1
    }

    log_ok "Found simulator: $sim_id"

    # Boot if needed
    local state
    state=$(xcrun simctl list devices -j | python3 -c "
import json, sys
data = json.load(sys.stdin)
for runtime, devices in data['devices'].items():
    for d in devices:
        if d['udid'] == '$sim_id':
            print(d['state'])
            sys.exit(0)
" 2>/dev/null)

    if [ "$state" != "Booted" ]; then
        log_info "Booting simulator..."
        xcrun simctl boot "$sim_id"
        sleep 3
    fi

    # Open Simulator.app
    open -a Simulator

    # Build and install with DEMO_MODE
    log_info "Building eCardify with DEMO_MODE..."
    cd "$PROJECT_DIR"

    xcodebuild build \
        -workspace eCardify.xcworkspace \
        -scheme eCardify \
        -destination "platform=iOS Simulator,id=$sim_id" \
        -quiet 2>&1 | tail -5

    # Find the built app
    local app_path
    app_path=$(xcodebuild build \
        -workspace eCardify.xcworkspace \
        -scheme eCardify \
        -destination "platform=iOS Simulator,id=$sim_id" \
        -showBuildSettings 2>/dev/null | grep -m1 "BUILT_PRODUCTS_DIR" | awk '{print $3}')/eCardify.app

    if [ -d "$app_path" ]; then
        log_info "Installing app..."
        xcrun simctl install "$sim_id" "$app_path"
    fi

    # Launch with DEMO_MODE
    log_info "Launching in DEMO_MODE..."
    xcrun simctl terminate "$sim_id" "$BUNDLE_ID" 2>/dev/null || true
    xcrun simctl launch "$sim_id" "$BUNDLE_ID" -DEMO_MODE

    sleep 2

    echo ""
    log_warn "═══════════════════════════════════════════════"
    log_warn "  RECORDING WILL START IN 3 SECONDS"
    log_warn ""
    log_warn "  Suggested flow (15-30 seconds):"
    log_warn "    1. Show card list with 3 demo cards"
    log_warn "    2. Tap a card to view full design"
    log_warn "    3. Go back, tap + to create new card"
    log_warn "    4. Fill in a few fields"
    log_warn "    5. Scroll to see the Pay button"
    log_warn ""
    log_warn "  Press Ctrl+C to stop recording"
    log_warn "═══════════════════════════════════════════════"
    echo ""

    sleep 3

    log_info "🔴 Recording started..."
    xcrun simctl io "$sim_id" recordVideo --codec=h264 "$RAW_VIDEO" || true

    echo ""
    log_ok "Recording saved to: $RAW_VIDEO"
    log_info "Run '$0 --convert' to convert to App Store format"
}

# ──────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────

case "${1:-}" in
    --convert)
        convert_video
        ;;
    -h|--help)
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  (none)       Record a preview video"
        echo "  --convert    Convert raw recording to App Store format"
        echo "  -h, --help   Show this help"
        ;;
    "")
        record
        ;;
    *)
        log_error "Unknown option: $1"
        exit 1
        ;;
esac
