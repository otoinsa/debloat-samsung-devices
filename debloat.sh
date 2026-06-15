#!/bin/bash

# Interactive Samsung debloat + performance tweaks tool
# Toggle items with numbers, confirm to apply

ADB="/Users/oto/Library/Android/sdk/platform-tools/adb"

# --- All known safe-to-remove packages, grouped by category ---
declare -a BLOATWARE=(
	# Samsung Bixby & AI
	"com.samsung.android.app.routines:Bixby Routines"
	"com.samsung.android.rubin.app:Rubin (Personalization AI)"
	"com.samsung.android.intellivoiceservice:Intellivoice Service"

	# Samsung Games & Media
	"com.samsung.android.game.gamehome:Game Launcher / Gaming Hub"
	"com.samsung.android.game.gos:Game Optimizing Service"
	"com.samsung.android.aremoji:AR Emoji"
	"com.samsung.android.stickercenter:Sticker Center"
	"com.samsung.android.app.soundpicker:Sound Picker"
	"com.samsung.android.secsoundpicker:Secure Sound Picker"
	"com.samsung.android.video:Samsung Video Player"

	# Samsung Themes & Appearance
	"com.samsung.android.themecenter:Theme Center"
	"com.samsung.android.app.dressroom:Theme Park / Dress Room"

	# Samsung Cloud & Backup
	"com.samsung.android.scloud:Samsung Cloud"
	"com.samsung.storyservice:Samsung Story Service"
	"com.samsung.android.smartswitchassistant:Smart Switch Assistant"
	"com.sec.android.easyMover:Smart Switch / Easy Mover"
	"com.sec.android.easyMover.Agent:Smart Switch Agent"

	# Samsung Utility & Services
	"com.samsung.android.lool:Device Care"
	"com.samsung.android.dsms:Samsung Device Security"
	"com.samsung.android.forest:Digital Wellbeing (Forest)"
	"com.samsung.android.app.sharelive:Share Live"
	"com.samsung.android.app.parentalcare:Parental Controls"
	"com.samsung.android.app.watchmanagerstub:Galaxy Watch Manager Stub"
	"com.samsung.android.kidsinstaller:Kids Installer"
	"com.samsung.android.da.daagent:DA Agent"
	"com.samsung.android.dqagent:Device Quality Agent"
	"com.samsung.android.app.omcagent:OMC Agent"
	"com.samsung.android.callassistant:Call Assistant"
	"com.sec.android.app.billing:Samsung Billing"
	"com.sec.android.app.samsungapps:Galaxy Store"
	"com.sec.android.app.personalization:Personalization Service"

	# Facebook (pre-installed)
	"com.facebook.appmanager:Facebook App Manager"
	"com.facebook.services:Facebook Services"
	"com.facebook.system:Facebook System"

	# Microsoft & Other 3rd party pre-installs
	"com.microsoft.skydrive:Microsoft OneDrive"
	"com.aura.oobe.samsung.gl:Aura / Carrier App Store"
	"de.axelspringer.yana.zeropage:Samsung Free (Axel Springer)"
	"com.hiya.star:Hiya Caller ID"

	# Optional Google apps (keep if you use them)
	"com.google.android.apps.tachyon:Google Duo / Meet"
	"com.google.android.youtube:YouTube"
	"com.google.android.gm:Gmail"
	"com.google.android.apps.maps:Google Maps"
	"com.google.android.calendar:Google Calendar"
)

# --- Performance tweaks: label:description:command(s separated by ;) ---
declare -a TWEAKS=(
	# UI & rendering
	"Disable animations:Makes UI feel instant (most noticeable improvement):settings put global window_animation_scale 0;settings put global transition_animation_scale 0;settings put global animator_duration_scale 0"
	"Speed up animations (0.5x):Snappier UI while keeping visual feedback:settings put global window_animation_scale 0.5;settings put global transition_animation_scale 0.5;settings put global animator_duration_scale 0.5"
	"Force GPU rendering:Use GPU for all UI drawing, smoother scrolling:settings put global force_hw_ui 1"

	# Memory & CPU
	"Limit background processes to 4:Frees RAM by capping cached apps — persists after reboot:/system/bin/device_config set_sync_disabled_for_tests persistent;/system/bin/device_config put activity_manager max_cached_processes 4"
	"Disable Samsung GOS throttling:Stops Samsung throttling CPU/GPU in games and apps:settings put secure gamesdk_version 0;settings put secure game_home_enable 0;settings put secure game_auto_temperature_control 0"
	"Disable RAM Plus / ZRAM swap:Stops slow storage swapping — only beneficial on 4GB+ RAM:settings put global zram_enabled 0;settings put global ram_expand_size_list 0"

	# Storage
	"Clear all app caches:One-shot cache wipe to free up storage:pm trim-caches 999999999999999"

	# Background activity & updates
	"Disable Samsung OTA updates:Stops automatic OS update downloads and notifications:pm disable-user --user 0 com.sec.android.soagent;pm disable-user --user 0 com.wssyncmldm;settings put global ota_disable_automatic_update 1"
	"Disable Samsung update center:Removes Software Update entry and its background polling:pm disable-user --user 0 com.samsung.android.app.updatecenter;pm disable-user --user 0 com.samsung.android.sdm.config"
	"Enable adaptive battery:Lets Android learn which apps you use and restrict the rest:settings put global adaptive_battery_management_enabled 1"
	"Restrict global background data:Blocks background network for all apps not whitelisted (like Data Saver):cmd netpolicy set restrict_background true"
	"Block Play Store background updates:Stops Play Store from auto-downloading updates silently:cmd appops set com.android.vending RUN_IN_BACKGROUND ignore;cmd appops set com.android.vending RUN_ANY_IN_BACKGROUND deny"
	"Block Samsung Push Service background:Stops Samsung push/sync daemon from waking the device:cmd appops set com.sec.spp.push RUN_IN_BACKGROUND ignore;cmd appops set com.sec.spp.push RUN_ANY_IN_BACKGROUND deny"

	# Display & lock screen
	"Disable lock screen [⚠ no PIN/swipe protection]:Phone wakes straight to home screen — anyone can access it:settings put global lockscreen.disabled 1"
	"Force landscape orientation (apps + home):Locks rotation to landscape, disables auto-rotate:settings put system accelerometer_rotation 0;settings put system user_rotation 1"
	"Re-enable lock screen:Restores the lock screen if you disabled it:settings put global lockscreen.disabled 0"
	"Re-enable auto-rotate:Restores automatic screen rotation:settings put system accelerometer_rotation 1"

	# Gaming
	"Fixed performance mode [⚠ heats up]:Locks CPU/GPU to stable clocks, removes frequency variance — good for benchmarks and gaming sessions:cmd power set-fixed-performance-mode-enabled true"
	"Disable fixed performance mode:Returns CPU/GPU to normal dynamic clocking:cmd power set-fixed-performance-mode-enabled false"
	"Enhanced CPU responsiveness [Qualcomm]:Lets CPU spike to peak speed faster when needed — Snapdragon devices only:settings put global sem_enhanced_cpu_responsiveness 1"
	"Set game as active standby bucket:Stops Android throttling a game's background jobs and network — replace PACKAGE with your game:am set-standby-bucket PACKAGE active"
	"Kill all background apps before gaming:Frees maximum RAM by force-stopping cached background processes:am kill-all"
	"Disable Bixby key / game interruptions:Blocks Bixby and game_bixby from interrupting during gameplay:settings put secure game_bixby_block 1;settings put secure bixby_enabled_from_oobe 0"
)

# --- Check ADB connection ---
check_connection() {
	if ! $ADB devices | grep -q "device$"; then
		echo "❌ No device found."
		echo "   Enable USB Debugging and tap Allow on your phone."
		exit 1
	fi
}

# ============================================================
# DEBLOAT MODE
# ============================================================
run_debloat() {
	echo ""
	echo "Fetching installed packages..."
	INSTALLED=$($ADB shell pm list packages 2>/dev/null)
	echo ""

	declare -a PRESENT_PKGS=()
	declare -a PRESENT_DESCS=()

	for item in "${BLOATWARE[@]}"; do
		IFS=':' read -r pkg desc <<<"$item"
		if echo "$INSTALLED" | grep -q "package:$pkg"; then
			PRESENT_PKGS+=("$pkg")
			PRESENT_DESCS+=("$desc")
		fi
	done

	if [ ${#PRESENT_PKGS[@]} -eq 0 ]; then
		echo "No known bloatware found on this device."
		return
	fi

	declare -a SELECTED=()
	for i in "${!PRESENT_PKGS[@]}"; do SELECTED+=("0"); done

	print_debloat_list() {
		echo ""
		echo "  Number = toggle  |  a = all  |  n = none  |  r = remove selected  |  b = back"
		echo ""
		echo "  #    Status  App"
		echo "  ---  ------  ---"
		for i in "${!PRESENT_PKGS[@]}"; do
			local num=$((i + 1))
			local mark="[ ]"
			[ "${SELECTED[$i]}" = "1" ] && mark="[x]"
			printf "  %-4s %s  %s\n" "$num" "$mark" "${PRESENT_DESCS[$i]}"
			printf "             %s\n" "${PRESENT_PKGS[$i]}"
		done
		echo ""
	}

	while true; do
		print_debloat_list

		local selected_count=0
		for s in "${SELECTED[@]}"; do [ "$s" = "1" ] && selected_count=$((selected_count + 1)); done
		echo "  Selected: $selected_count / ${#PRESENT_PKGS[@]}"
		echo ""
		read -p "  > " input

		case "$input" in
			b|B) return ;;
			a|A) for i in "${!SELECTED[@]}"; do SELECTED[$i]="1"; done ;;
			n|N) for i in "${!SELECTED[@]}"; do SELECTED[$i]="0"; done ;;
			r|R)
				[ "$selected_count" -eq 0 ] && echo "  Nothing selected." && continue
				echo ""
				echo "  Removing $selected_count app(s):"
				for i in "${!PRESENT_PKGS[@]}"; do
					[ "${SELECTED[$i]}" = "1" ] && echo "    - ${PRESENT_DESCS[$i]}"
				done
				echo ""
				read -p "  Confirm? (yes/no): " confirm
				[ "$confirm" != "yes" ] && echo "  Cancelled." && continue
				echo ""
				local removed=0 failed=0
				for i in "${!PRESENT_PKGS[@]}"; do
					if [ "${SELECTED[$i]}" = "1" ]; then
						local pkg="${PRESENT_PKGS[$i]}" desc="${PRESENT_DESCS[$i]}"
						printf "  %-45s " "$desc..."
						if $ADB shell pm uninstall --user 0 "$pkg" >/dev/null 2>&1; then
							echo "✅"; removed=$((removed + 1))
						else
							echo "❌"; failed=$((failed + 1))
						fi
					fi
				done
				echo ""
				echo "  Done — Removed: $removed  Failed: $failed"
				echo "  Restore any app: adb shell cmd package install-existing <package>"
				echo ""
				read -p "  Press Enter to continue..." _
				# Rebuild list removing successfully uninstalled packages
				INSTALLED=$($ADB shell pm list packages 2>/dev/null)
				local NEW_PKGS=() NEW_DESCS=() NEW_SEL=()
				for i in "${!PRESENT_PKGS[@]}"; do
					if echo "$INSTALLED" | grep -q "package:${PRESENT_PKGS[$i]}"; then
						NEW_PKGS+=("${PRESENT_PKGS[$i]}")
						NEW_DESCS+=("${PRESENT_DESCS[$i]}")
						NEW_SEL+=("0")
					fi
				done
				PRESENT_PKGS=("${NEW_PKGS[@]}")
				PRESENT_DESCS=("${NEW_DESCS[@]}")
				SELECTED=("${NEW_SEL[@]}")
				;;
			''|*[!0-9]*) echo "  Invalid input." ;;
			*)
				local idx=$((input - 1))
				if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#PRESENT_PKGS[@]}" ]; then
					[ "${SELECTED[$idx]}" = "1" ] && SELECTED[$idx]="0" || SELECTED[$idx]="1"
				else
					echo "  Number out of range."
				fi
				;;
		esac
	done
}

# ============================================================
# TWEAKS MODE
# ============================================================
run_tweaks() {
	declare -a TWEAK_SEL=()
	for i in "${!TWEAKS[@]}"; do TWEAK_SEL+=("0"); done

	print_tweaks_list() {
		echo ""
		echo "  Number = toggle  |  a = all  |  n = none  |  r = apply selected  |  b = back"
		echo ""
		echo "  #    Status  Tweak"
		echo "  ---  ------  -----"
		for i in "${!TWEAKS[@]}"; do
			IFS=':' read -r label desc cmds <<<"${TWEAKS[$i]}"
			local num=$((i + 1))
			local mark="[ ]"
			[ "${TWEAK_SEL[$i]}" = "1" ] && mark="[x]"
			printf "  %-4s %s  %s\n" "$num" "$mark" "$label"
			printf "             %s\n" "$desc"
		done
		echo ""
	}

	while true; do
		print_tweaks_list

		local selected_count=0
		for s in "${TWEAK_SEL[@]}"; do [ "$s" = "1" ] && selected_count=$((selected_count + 1)); done
		echo "  Selected: $selected_count / ${#TWEAKS[@]}"
		echo ""
		read -p "  > " input

		case "$input" in
			b|B) return ;;
			a|A) for i in "${!TWEAK_SEL[@]}"; do TWEAK_SEL[$i]="1"; done ;;
			n|N) for i in "${!TWEAK_SEL[@]}"; do TWEAK_SEL[$i]="0"; done ;;
			r|R)
				[ "$selected_count" -eq 0 ] && echo "  Nothing selected." && continue
				echo ""
				echo "  Applying $selected_count tweak(s):"
				for i in "${!TWEAKS[@]}"; do
					IFS=':' read -r label desc cmds <<<"${TWEAKS[$i]}"
					[ "${TWEAK_SEL[$i]}" = "1" ] && echo "    - $label"
				done
				echo ""
				read -p "  Confirm? (yes/no): " confirm
				[ "$confirm" != "yes" ] && echo "  Cancelled." && continue
				echo ""
				local applied=0 failed=0
				for i in "${!TWEAKS[@]}"; do
					if [ "${TWEAK_SEL[$i]}" = "1" ]; then
						IFS=':' read -r label desc cmds <<<"${TWEAKS[$i]}"
						printf "  %-45s " "$label..."
						local ok=1
						IFS=';' read -ra CMD_LIST <<<"$cmds"
						for cmd in "${CMD_LIST[@]}"; do
							if ! $ADB shell "$cmd" >/dev/null 2>&1; then ok=0; fi
						done
						if [ "$ok" = "1" ]; then
							echo "✅"; applied=$((applied + 1))
						else
							echo "❌"; failed=$((failed + 1))
						fi
					fi
				done
				echo ""
				echo "  Done — Applied: $applied  Failed: $failed"
				echo ""
				read -p "  Press Enter to continue..." _
				for i in "${!TWEAK_SEL[@]}"; do TWEAK_SEL[$i]="0"; done
				;;
			''|*[!0-9]*) echo "  Invalid input." ;;
			*)
				local idx=$((input - 1))
				if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#TWEAKS[@]}" ]; then
					[ "${TWEAK_SEL[$idx]}" = "1" ] && TWEAK_SEL[$idx]="0" || TWEAK_SEL[$idx]="1"
				else
					echo "  Number out of range."
				fi
				;;
		esac
	done
}

# ============================================================
# GAMEPAD REMAP MODE
# ============================================================

# Standard Android gamepad buttons with their keyevent codes
declare -a GP_BUTTONS=(
	"A (Cross)        :KEYCODE_BUTTON_A:96"
	"B (Circle)       :KEYCODE_BUTTON_B:97"
	"X (Square)       :KEYCODE_BUTTON_X:99"
	"Y (Triangle)     :KEYCODE_BUTTON_Y:100"
	"L1 (Left Bumper) :KEYCODE_BUTTON_L1:102"
	"R1 (Right Bumper):KEYCODE_BUTTON_R1:103"
	"L2 (Left Trigger):KEYCODE_BUTTON_L2:104"
	"R2 (Right Trigger):KEYCODE_BUTTON_R2:105"
	"L3 (Left Stick)  :KEYCODE_BUTTON_THUMBL:106"
	"R3 (Right Stick) :KEYCODE_BUTTON_THUMBR:107"
	"Start            :KEYCODE_BUTTON_START:108"
	"Select           :KEYCODE_BUTTON_SELECT:109"
	"D-Pad Up         :KEYCODE_DPAD_UP:19"
	"D-Pad Down       :KEYCODE_DPAD_DOWN:20"
	"D-Pad Left       :KEYCODE_DPAD_LEFT:21"
	"D-Pad Right      :KEYCODE_DPAD_RIGHT:22"
	"D-Pad Center     :KEYCODE_DPAD_CENTER:23"
	"Mode / Guide     :KEYCODE_BUTTON_MODE:110"
)

# Actions that can be remapped to a button (label:keyevent code or special command)
declare -a GP_ACTIONS=(
	"Home screen            :KEYCODE_HOME:3"
	"Back                   :KEYCODE_BACK:4"
	"Recents / App switcher :KEYCODE_APP_SWITCH:187"
	"Notifications          :KEYCODE_NOTIFICATION:83"
	"Volume Up              :KEYCODE_VOLUME_UP:24"
	"Volume Down            :KEYCODE_VOLUME_DOWN:25"
	"Screenshot             :KEYCODE_SYSRQ:120"
	"Power / Screen off     :KEYCODE_POWER:26"
	"Toggle flashlight      :KEYCODE_CAMERA:27"
	"Media: Play/Pause      :KEYCODE_MEDIA_PLAY_PAUSE:85"
	"Media: Next track      :KEYCODE_MEDIA_NEXT:87"
	"Media: Prev track      :KEYCODE_MEDIA_PREVIOUS:88"
	"Enter / Confirm        :KEYCODE_ENTER:66"
	"Escape / Cancel        :KEYCODE_ESCAPE:111"
	"Search                 :KEYCODE_SEARCH:84"
	"Brightness Up          :KEYCODE_BRIGHTNESS_UP:221"
	"Brightness Down        :KEYCODE_BRIGHTNESS_DOWN:220"
	"Show keyboard          :KEYCODE_KEYBOARD_BACKLIGHT_UP:228"
	"Tab                    :KEYCODE_TAB:61"
	"Menu                   :KEYCODE_MENU:82"
)

run_gamepad() {
	echo ""
	echo "  ============================================"
	echo "  Gamepad Button Remapper"
	echo "  ============================================"
	echo ""
	echo "  Most buttons: grant KeyMapper permission (option 1)"
	echo "  Screenshot button: requires root keylayout (option 4)"
	echo ""

	while true; do
		echo "  ─────────────────────────────────────────────"
		echo "  [1]  Grant KeyMapper ADB permission (no root)"
		echo "  [2]  Test a button — send keyevent live"
		echo "  [3]  Detect which button I pressed"
		echo "  [4]  Install keylayout via root (remaps screenshot → Home)"
		echo "  [b]  Back"
		echo ""
		read -p "  > " gp_choice

		case "$gp_choice" in
			b|B) return ;;

			# --- Grant KeyMapper WRITE_SECURE_SETTINGS so it can remap without root ---
			1)
				echo ""
				echo "  This grants io.github.sds100.keymapper"
				echo "  WRITE_SECURE_SETTINGS permission via ADB."
				echo "  Install KeyMapper from Play Store first."
				echo ""
				read -p "  Proceed? (yes/no): " confirm
				[ "$confirm" != "yes" ] && echo "  Cancelled." && continue
				echo ""
				printf "  Granting permission... "
				if $ADB shell pm grant io.github.sds100.keymapper android.permission.WRITE_SECURE_SETTINGS 2>/dev/null; then
					echo "✅"
					echo ""
					echo "  KeyMapper now has full remapping capability."
					echo "  Open the app and set your button mappings there."
				else
					echo "❌"
					echo "  Make sure KeyMapper is installed:"
					echo "  https://play.google.com/store/apps/details?id=io.github.sds100.keymapper"
				fi
				echo ""
				read -p "  Press Enter to continue..." _
				;;

			# --- Send a keyevent to test a button action ---
			2)
				echo ""
				echo "  Select a BUTTON to send:"
				echo ""
				for i in "${!GP_BUTTONS[@]}"; do
					IFS=':' read -r label keycode code <<<"${GP_BUTTONS[$i]}"
					printf "  %-3s %s\n" "$((i+1))" "$label"
				done
				echo ""
				read -p "  Button number (or b to go back): " btn_choice
				[ "$btn_choice" = "b" ] && continue
				[[ ! "$btn_choice" =~ ^[0-9]+$ ]] && echo "  Invalid." && continue
				btn_idx=$((btn_choice - 1))
				[ "$btn_idx" -lt 0 ] || [ "$btn_idx" -ge "${#GP_BUTTONS[@]}" ] && echo "  Out of range." && continue

				IFS=':' read -r btn_label btn_keycode btn_code <<<"${GP_BUTTONS[$btn_idx]}"

				echo ""
				echo "  Select the ACTION to send:"
				echo ""
				for i in "${!GP_ACTIONS[@]}"; do
					IFS=':' read -r label keycode code <<<"${GP_ACTIONS[$i]}"
					printf "  %-3s %s\n" "$((i+1))" "$label"
				done
				echo ""
				read -p "  Action number (or b to go back): " act_choice
				[ "$act_choice" = "b" ] && continue
				[[ ! "$act_choice" =~ ^[0-9]+$ ]] && echo "  Invalid." && continue
				act_idx=$((act_choice - 1))
				[ "$act_idx" -lt 0 ] || [ "$act_idx" -ge "${#GP_ACTIONS[@]}" ] && echo "  Out of range." && continue

				IFS=':' read -r act_label act_keycode act_code <<<"${GP_ACTIONS[$act_idx]}"

				echo ""
				printf "  Sending %-20s → %s... " "$btn_label" "$act_label"
				if $ADB shell input keyevent "$act_code" >/dev/null 2>&1; then
					echo "✅ sent"
				else
					echo "❌ failed"
				fi
				echo ""
				read -p "  Press Enter to continue..." _
				;;

			# --- Live button detection via getevent ---
			3)
				echo ""
				echo "  Press any gamepad button on your controller."
				echo "  Listening for 5 seconds..."
				echo ""
				$ADB shell "timeout 5 getevent -l 2>/dev/null" | grep -E "EV_KEY|BTN|BUTTON|ABS" | while IFS= read -r line; do
					echo "  $line"
				done
				echo ""
				read -p "  Press Enter to continue..." _
				;;

			# --- Install .kl keylayout via root — remaps screenshot button to Home ---
			4)
				echo ""
				echo "  Installs Vendor_413d_Product_2103.kl onto the device"
				echo "  via Magisk root (su). Remaps the screenshot button"
				echo "  on your Zikway Gamwing to Home, system-wide."
				echo ""
				echo "  Requirements: phone must already be rooted with Magisk."
				echo "  Run option [4] Root phone from the main menu first."
				echo ""
				read -p "  Proceed? (yes/no): " confirm
				[ "$confirm" != "yes" ] && echo "  Cancelled." && continue

				SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
				KL_NAME="Vendor_413d_Product_2103.kl"
				KL_DEST="/system/usr/keylayout/$KL_NAME"
				KL_TMP="/tmp/$KL_NAME"

				# Write the keylayout file locally
				cat > "$KL_TMP" << 'KLEOF'
# Zikway Gamwing AoBing Max — custom keylayout (Vendor 413d / Product 2103)
# Remaps screenshot button (consumer control) to Home
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
KLEOF

				echo ""
				printf "  Pushing keylayout to /sdcard/... "
				$ADB push "$KL_TMP" /sdcard/Download/"$KL_NAME" >/dev/null 2>&1 && echo "✅" || { echo "❌ push failed"; continue; }

				printf "  Copying to $KL_DEST via su... "
				RESULT=$($ADB shell "su -c 'cp /sdcard/Download/$KL_NAME $KL_DEST && chmod 644 $KL_DEST && echo OK'" 2>/dev/null | tr -d '\r')

				if [ "$RESULT" = "OK" ]; then
					echo "✅"
					echo ""
					echo "  Keylayout installed. Reconnect the gamepad"
					echo "  (or reboot) and the screenshot button will go Home."
					echo ""
					read -p "  Reboot now? (yes/no): " do_reboot
					[ "$do_reboot" = "yes" ] && $ADB reboot
				else
					echo "❌"
					echo ""
					echo "  Root access denied or Magisk not active."
					echo "  Verify root: adb shell su -c 'id'"
				fi
				echo ""
				read -p "  Press Enter to continue..." _
				;;

			*) echo "  Enter 1, 2, 3, 4, or b." ;;
		esac
	done
}

# ============================================================
# MAIN MENU
# ============================================================
clear
echo "==================================="
echo "   Samsung Phone Optimizer"
echo "==================================="
echo ""
echo "Checking ADB connection..."
check_connection
DEVICE_MODEL=$($ADB shell getprop ro.product.model 2>/dev/null | tr -d '\r')
echo "✅ Connected: $DEVICE_MODEL"

while true; do
	echo ""
	echo "  What would you like to do?"
	echo ""
	echo "  [1]  Remove bloatware"
	echo "  [2]  Apply performance tweaks"
	echo "  [3]  Remap gamepad buttons"
	echo "  [4]  Root phone (Magisk)"
	echo "  [q]  Quit"
	echo ""
	read -p "  > " choice

	case "$choice" in
		1) run_debloat ;;
		2) run_tweaks ;;
		3) run_gamepad ;;
		4) echo ""; exec "$(dirname "$0")/root.sh" ;;
		q|Q) echo ""; echo "Goodbye!"; exit 0 ;;
		*) echo "  Enter 1, 2, 3, 4, or q." ;;
	esac
done
