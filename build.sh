#!/usr/bin/env sh

# Copyright (C) 2021  Nicole Alassandro

# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation, either version 3 of the License, or (at your option)
# any later version.

# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.

# You should have received a copy of the GNU General Public License along
# with this program.  If not, see <http://www.gnu.org/licenses/>.

set -e

APP_NAME="Main"
APP_VERS="0.0.0"

BLD_DIR="Build/$BUILD_CONFIG"
APP_DIR="$BLD_DIR/$APP_NAME.app"
CON_DIR="$APP_DIR/Contents"
EXE_DIR="$CON_DIR/MacOS"
RES_DIR="$CON_DIR/Resources"

EXE_BIN="$EXE_DIR/$APP_NAME"

rm -rf "$BLD_DIR"
mkdir -p "$APP_DIR"
mkdir -p "$CON_DIR"
mkdir -p "$EXE_DIR"
mkdir -p "$RES_DIR"

touch "$CON_DIR/Info.plist"

cat << EOF > "$CON_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
    <dict>
        <key>CFBundleName</key>
        <string>$APP_NAME</string>
        <key>CFBundleDisplayName</key>
        <string>$APP_NAME</string>
        <key>CFBundleExecutable</key>
        <string>$APP_NAME</string>
        <key>CFBundleIdentifier</key>
        <string>com.lassandroan.$APP_NAME</string>
        <key>CFBundleVersion</key>
        <string>$APP_VERS</string>
        <key>CFBundleShortVersionString</key>
        <string>$APP_VERS</string>
        <key>NSHumanReadableCopyright</key>
        <string>Copyright Nicole Alassandro</string>
        <key>NSPrincipalClass</key>
        <string>NSApplication</string>
        <key>CFBundleIconName</key>
        <string>AppIcon</string>
        <key>LSArchitecturePriority</key>
        <array>
            <string>x86_64</string>
        </array>
        <key>CFBundleDevelopmentRegion</key>
        <string>English</string>
        <key>CFBundlePackageType</key>
        <string>APPL</string>
        <key>LSApplicationCategoryType</key>
        <string>public.app-category.games</string>
        <key>LSMinimumSystemVersion</key>
        <string>10.6.0</string>
        <key>NSHighResolutionCapable</key>
        <true/>
        <key>NSQuitAlwaysKeepsWindows</key>
        <false/>
    </dict>
</plist>
EOF

cp -r Resources/ "$RES_DIR"

clang \
    -g \
    -isysroot $(xcrun --show-sdk-path) \
    -framework Cocoa \
    -framework Metal \
    -framework MetalKit \
    -framework GLKit \
    -fobjc-arc \
    -o "$EXE_BIN" \
    Source/Main.m

metal -O2 -std=osx-metal1.1 -c -o shaders.air Source/shaders.metal
metal-ar r shaders.metal-ar shaders.air
metallib -o "$RES_DIR/shaders.metallib" shaders.metal-ar
rm *.air *.metal-ar
