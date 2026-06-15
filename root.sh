#!/bin/bash

# Magisk root helper for Samsung SM-A057G (Galaxy A05s)
# Requires: adb, heimdall (brew install heimdall)
# Steps: push AP firmware → Magisk patches it on phone → pull back → flash via heimdall

ADB="/Users/oto/Library/Android/sdk/platform-tools/adb"
FIRMWARE_DIR="$(dirname "$0")/tmp/firmware"
PATCHED_DIR="$(dirname "$0")/tmp/patched"

# Gamepad keylayout file for Zikway Gamwing AoBing Max (Vendor 413d / Product 2103)
# Applied after root — remaps the screenshot combo to Home
GAMEPAD_KL_NAME="Vendor_413d_Product_2103.kl"
GAMEPAD_KL_CONTENT='# Zikway Gamwing AoBing Max — custom keylayout
# Remap screenshot button (consumer control vol+power) to Home
key 102  HOME
key 115  VOLUME_UP
key 116  POWER

# Standard gamepad buttons
key 304  BUTTON_A
key 305  BUTTON_B
key 307  BUTTON_X
key 308  BUTTON_Y
key 310  BUTTON_L1
key 311  BUTTON_R1
key 312  BUTTON_L2
key 313  BUTTON_R2
key 314  BUTTON_THUMBL
key 315  BUTTON_THUMBR
key 316  BUTTON_MODE
key 317  BUTTON_START
key 318  BUTTON_SELECT
'

# -------------------------------------------------------

check_tool() {
	if ! command -v "$1" &>/dev/null; then
		echo "❌ '$1' not found. Install with: brew install $1"
		exit 1
	fi
}

check_adb() {
	if ! $ADB devices | grep -q "device$\|device "; then
		echo "❌ No device found via ADB."
		echo "   Connect via USB or run: adb tcpip 5555 && adb connect <ip>:5555"
		exit 1
	fi
}

print_header() {
	echo ""
	echo "==================================="
	echo "   Samsung Root Helper (Magisk)"
	echo "==================================="
	echo ""
}

# -------------------------------------------------------
# STEP 1: Check prerequisites
# -------------------------------------------------------
step_check() {
	echo "Checking prerequisites..."
	echo ""
	check_tool heimdall

	printf "  heimdall... "; heimdall version 2>/dev/null | head -1 && echo "✅" || echo "❌"
	printf "  adb...      "; $ADB version 2>/dev/null | head -1 && echo "" || echo "❌"

	echo ""
	echo "  ⚠  Before continuing:"
	echo "     • Backup your phone (photos, contacts, etc.)"
	echo "     • Knox will be permanently tripped (Samsung Pay disabled)"
	echo "     • Your data will NOT be erased"
	echo "     • OEM Unlock must be enabled in Developer Options"
	echo ""
	read -p "  Continue? (yes/no): " confirm
	[ "$confirm" != "yes" ] && echo "Aborted." && exit 0
}

# -------------------------------------------------------
# STEP 2: Push AP firmware to phone for Magisk to patch
# -------------------------------------------------------
step_push_ap() {
	echo ""
	echo "── Step 1: Push AP firmware to phone ──────────────"
	echo ""

	# Find AP file in tmp/firmware
	AP_FILE=$(ls "$FIRMWARE_DIR"/AP_*.tar.md5 2>/dev/null | head -1)

	if [ -z "$AP_FILE" ]; then
		echo "  ❌ No AP firmware file found in tmp/firmware/"
		echo ""
		echo "  Download your firmware first:"
		echo "  1. Install Bifrost: https://github.com/zacharee/SamloaderKotlin/releases"
		echo "  2. Model: SM-A057G"
		echo "  3. Region: check Settings → About phone → Software info"
		echo "     (first 3 letters of 'Service provider software version')"
		echo "  4. Download and move the AP_*.tar.md5 file to: tmp/firmware/"
		echo ""
		exit 1
	fi

	echo "  Found: $(basename "$AP_FILE")"
	echo ""
	check_adb

	echo "  Pushing to /sdcard/Download/..."
	$ADB push "$AP_FILE" /sdcard/Download/
	echo ""
	echo "  ✅ Done. Now on your phone:"
	echo "     1. Open the Magisk app"
	echo "     2. Tap Install → Select and Patch a File"
	echo "     3. Navigate to Downloads → pick $(basename "$AP_FILE")"
	echo "     4. Wait for patching to complete"
	echo ""
	read -p "  Press Enter once Magisk has finished patching..." _
}

# -------------------------------------------------------
# STEP 3: Pull patched image back from phone
# -------------------------------------------------------
step_pull_patched() {
	echo ""
	echo "── Step 2: Pull patched image from phone ───────────"
	echo ""
	check_adb

	REMOTE_FILE=$($ADB shell "ls /sdcard/Download/magisk_patched_*.tar 2>/dev/null" | tr -d '\r' | head -1)

	if [ -z "$REMOTE_FILE" ]; then
		echo "  ❌ No magisk_patched_*.tar found in /sdcard/Download/"
		echo "     Make sure Magisk finished patching and try again."
		exit 1
	fi

	echo "  Found: $REMOTE_FILE"
	echo "  Pulling to tmp/patched/..."
	$ADB pull "$REMOTE_FILE" "$PATCHED_DIR/"
	PATCHED_LOCAL=$(ls "$PATCHED_DIR"/magisk_patched_*.tar 2>/dev/null | head -1)
	echo ""
	echo "  ✅ Saved: $(basename "$PATCHED_LOCAL")"
}

# -------------------------------------------------------
# STEP 4: Flash via Heimdall
# -------------------------------------------------------
step_flash() {
	echo ""
	echo "── Step 3: Flash patched boot image ────────────────"
	echo ""

	PATCHED_FILE=$(ls "$PATCHED_DIR"/magisk_patched_*.tar 2>/dev/null | head -1)

	if [ -z "$PATCHED_FILE" ]; then
		echo "  ❌ No patched file found in tmp/patched/"
		echo "     Run steps 1 and 2 first."
		exit 1
	fi

	echo "  Will flash: $(basename "$PATCHED_FILE")"
	echo ""
	echo "  ⚠  Put phone into Download Mode:"
	echo "     Power off → hold Vol Down + Vol Up → plug USB → press Vol Up to confirm"
	echo ""
	read -p "  Phone in Download Mode and USB connected? (yes/no): " ready
	[ "$ready" != "yes" ] && echo "Aborted." && exit 0

	echo ""
	echo "  Flashing..."

	# Extract boot.img from the tar if needed
	BOOT_IMG="$PATCHED_DIR/boot.img"
	tar -xf "$PATCHED_FILE" -C "$PATCHED_DIR/" 2>/dev/null
	BOOT_IMG=$(ls "$PATCHED_DIR"/*.img 2>/dev/null | head -1)

	if [ -z "$BOOT_IMG" ]; then
		echo "  ❌ Could not extract .img from patched tar."
		exit 1
	fi

	echo "  Using: $(basename "$BOOT_IMG")"
	echo ""

	if heimdall flash --BOOT "$BOOT_IMG" --no-reboot 2>/dev/null; then
		echo ""
		echo "  ✅ Flash successful!"
		echo ""
		echo "  Now:"
		echo "  1. Hold Vol Up + Power to boot into recovery"
		echo "  2. No factory reset needed — just reboot system"
		echo "  3. Magisk app will be on your home screen"
	else
		echo ""
		echo "  ❌ Heimdall flash failed."
		echo "  Make sure the phone is in Download Mode and USB is connected."
	fi
}

# -------------------------------------------------------
# STEP 5: Install gamepad keylayout (post-root)
# -------------------------------------------------------
step_keylayout() {
	echo ""
	echo "── Step 4: Install gamepad keylayout (post-root) ───"
	echo ""
	echo "  This remaps the screenshot button on your"
	echo "  Zikway Gamwing AoBing Max to Home."
	echo "  Requires Magisk root to already be active."
	echo ""
	check_adb

	# Write the .kl file locally then push via Magisk's su
	KL_TMP="/tmp/$GAMEPAD_KL_NAME"
	echo "$GAMEPAD_KL_CONTENT" > "$KL_TMP"

	$ADB push "$KL_TMP" /sdcard/Download/"$GAMEPAD_KL_NAME"

	# Use su to copy into the keylayout directory
	RESULT=$($ADB shell "su -c 'cp /sdcard/Download/$GAMEPAD_KL_NAME /system/usr/keylayout/$GAMEPAD_KL_NAME && chmod 644 /system/usr/keylayout/$GAMEPAD_KL_NAME && echo OK'" 2>/dev/null | tr -d '\r')

	if [ "$RESULT" = "OK" ]; then
		echo "  ✅ Keylayout installed."
		echo "  Reboot and reconnect the gamepad — screenshot button will now go Home."
		echo ""
		read -p "  Reboot now? (yes/no): " reboot
		[ "$reboot" = "yes" ] && $ADB reboot
	else
		echo "  ❌ Failed — is Magisk root active?"
		echo "     Open Magisk, make sure it shows 'Installed' and reboot once after flashing."
		echo ""
		echo "  You can run this step again after confirming root with:"
		echo "  adb shell su -c 'id'"
	fi
}

# -------------------------------------------------------
# MAIN
# -------------------------------------------------------
print_header

echo "  What would you like to do?"
echo ""
echo "  [1]  Full root walkthrough (steps 1–3)"
echo "  [2]  Push AP firmware to phone only"
echo "  [3]  Pull patched image from phone only"
echo "  [4]  Flash patched image via Heimdall only"
echo "  [5]  Install gamepad keylayout (post-root)"
echo "  [q]  Quit"
echo ""
read -p "  > " choice

case "$choice" in
	1)
		step_check
		step_push_ap
		step_pull_patched
		step_flash
		;;
	2) check_adb; step_push_ap ;;
	3) check_adb; step_pull_patched ;;
	4) step_flash ;;
	5) step_keylayout ;;
	q|Q) echo "Goodbye!"; exit 0 ;;
	*) echo "Invalid choice."; exit 1 ;;
esac
