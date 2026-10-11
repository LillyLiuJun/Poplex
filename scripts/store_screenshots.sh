#!/usr/bin/env bash
# ==============================================================================
# scripts/store_screenshots.sh
# 
# 一键 App Store 截图自动化辅助脚本 (iPhone 17 Pro Max · 1320x2868)
# ==============================================================================

set -euo pipefail

DEVICE_NAME="iPhone 17 Pro Max"
BUNDLE_ID="com.lilyliu.AIEnglishApp"
OUTPUT_DIR="store_screenshots"

# 动态查找 iPhone 17 Pro Max 的 UDID
DEVICE_ID=$(xcrun simctl list devices available | grep "$DEVICE_NAME" | head -n 1 | sed -E 's/.*\(([0-9A-F-]+)\).*/\1/')

if [ -z "$DEVICE_ID" ]; then
    echo "❌ 未找到可用的 $DEVICE_NAME 模拟器，请检查 Xcode 模拟器配置"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

boot_and_override_status_bar() {
    echo "📱 启动模拟器: $DEVICE_NAME ($DEVICE_ID)..."
    xcrun simctl boot "$DEVICE_ID" 2>/dev/null || true
    open -a Simulator 2>/dev/null || true
    
    echo "🌐 设置 12 小时制与 en_US Locale (确保时间为 9:41 无前导零)..."
    xcrun simctl spawn "$DEVICE_ID" defaults write "Apple Global Domain" AppleLocale -string "en_US" 2>/dev/null || true
    xcrun simctl spawn "$DEVICE_ID" defaults write "Apple Global Domain" AppleICUForce24HourTime -bool false 2>/dev/null || true

    echo "✨ 锁定苹果官方发布会状态栏 (9:41 · 100% 纯黑满电 · 4格蜂窝 + 3格WiFi)..."
    xcrun simctl status_bar "$DEVICE_ID" override \
        --time "9:41" \
        --batteryState discharging \
        --batteryLevel 100 \
        --cellularMode active \
        --cellularBars 4 \
        --wifiMode active \
        --wifiBars 3
}

get_app_path() {
    local local_app="build/DerivedData/Build/Products/Debug-iphonesimulator/AIEnglishApp.app"
    if [ -d "$local_app" ]; then
        echo "$local_app"
        return
    fi
    local app_path
    app_path=$(find ~/Library/Developer/Xcode/DerivedData -name "AIEnglishApp.app" -path "*/Debug-iphonesimulator/*" 2>/dev/null | head -n 1)
    if [ -z "$app_path" ] || [ ! -d "$app_path" ]; then
        echo "🔨 未找到编译包，正在执行 xcodebuild 编译..."
        xcodebuild -project AIEnglishApp.xcodeproj \
            -scheme AIEnglishApp \
            -destination "id=$DEVICE_ID" \
            -derivedDataPath build/DerivedData \
            -quiet build
        app_path="build/DerivedData/Build/Products/Debug-iphonesimulator/AIEnglishApp.app"
    fi
    echo "$app_path"
}

install_app() {
    local app_path
    app_path=$(get_app_path)
    echo "📦 安装应用到模拟器 ($DEVICE_ID): $app_path"
    xcrun simctl install "$DEVICE_ID" "$app_path"
}

capture_screen() {
    local name="$1"
    local file_path="${OUTPUT_DIR}/${name}.png"
    echo "📸 截取当前屏幕到: $file_path"
    xcrun simctl io "$DEVICE_ID" screenshot "$file_path"
    local resolution
    resolution=$(sips -g pixelWidth -g pixelHeight "$file_path" 2>/dev/null | grep -E "pixelWidth|pixelHeight" | awk '{print $2}' | paste -sd "x" -)
    echo "✅ 截图完成！分辨率: ${resolution} (App Store 官方 6.9 吋顶规)"
}

case "${1:-start}" in
    start)
        boot_and_override_status_bar
        install_app
        echo "🚀 启动 App (Store Demo 模式)..."
        xcrun simctl terminate "$DEVICE_ID" "$BUNDLE_ID" 2>/dev/null || true
        xcrun simctl launch "$DEVICE_ID" "$BUNDLE_ID" -storeDemo
        echo ""
        echo "👉 模拟器已就绪！您可以在模拟器中自由滑动、浏览。"
        echo "👉 随时截取当前画面运行: bash scripts/store_screenshots.sh capture <文件名>"
        ;;

    tab)
        target_tab="${2:-today}"
        boot_and_override_status_bar
        echo "🚀 启动 App 并直达 Tab: $target_tab..."
        xcrun simctl terminate "$DEVICE_ID" "$BUNDLE_ID" 2>/dev/null || true
        xcrun simctl launch "$DEVICE_ID" "$BUNDLE_ID" -storeDemo -startTab "$target_tab"
        ;;

    conversation)
        boot_and_override_status_bar
        echo "🚀 启动 App 并直达对话练习页..."
        xcrun simctl terminate "$DEVICE_ID" "$BUNDLE_ID" 2>/dev/null || true
        xcrun simctl launch "$DEVICE_ID" "$BUNDLE_ID" -storeDemo -startTab mine -startConversation
        ;;

    capture)
        name="${2:-screenshot_$(date +%Y%m%d_%H%M%S)}"
        capture_screen "$name"
        ;;

    capture-all)
        boot_and_override_status_bar
        install_app
        
        echo "📸 [1/3] 自动截取 Tab 1 (Today 首页)..."
        xcrun simctl terminate "$DEVICE_ID" "$BUNDLE_ID" 2>/dev/null || true
        SIMCTL_CHILD_STORE_DEMO=1 SIMCTL_CHILD_START_TAB=today xcrun simctl launch "$DEVICE_ID" "$BUNDLE_ID" -storeDemo -startTab today
        sleep 5
        capture_screen "01_today_feed"

        echo "📸 [2/3] 自动截取 Tab 2 (Mine 资产与主题)..."
        xcrun simctl terminate "$DEVICE_ID" "$BUNDLE_ID" 2>/dev/null || true
        SIMCTL_CHILD_STORE_DEMO=1 SIMCTL_CHILD_START_TAB=mine xcrun simctl launch "$DEVICE_ID" "$BUNDLE_ID" -storeDemo -startTab mine
        sleep 5
        capture_screen "02_mine_topics"

        echo "📸 [3/3] 自动截取沉浸对话练习页..."
        xcrun simctl terminate "$DEVICE_ID" "$BUNDLE_ID" 2>/dev/null || true
        SIMCTL_CHILD_STORE_DEMO=1 SIMCTL_CHILD_START_TAB=mine SIMCTL_CHILD_START_CONVERSATION=1 xcrun simctl launch "$DEVICE_ID" "$BUNDLE_ID" -storeDemo -startTab mine -startConversation
        sleep 5
        capture_screen "03_conversation_practice"

        echo ""
        echo "🎉 全部截图已生成完毕，保存在 ${OUTPUT_DIR}/ 目录！"
        ;;

    clean-status)
        echo "🧹 还原模拟器状态栏..."
        xcrun simctl status_bar "$DEVICE_ID" clear
        echo "✅ 状态栏已恢复系统默认状态"
        ;;

    *)
        echo "用法: bash scripts/store_screenshots.sh [start | tab today|mine | conversation | capture <name> | capture-all | clean-status]"
        ;;
esac
