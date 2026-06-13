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
	"Disable animations:Makes UI feel instant (most noticeable improvement):settings put global window_animation_scale 0;settings put global transition_animation_scale 0;settings put global animator_duration_scale 0"
	"Speed up animations (0.5x):Snappier UI while keeping visual feedback:settings put global window_animation_scale 0.5;settings put global transition_animation_scale 0.5;settings put global animator_duration_scale 0.5"
	"Limit background processes to 4:Frees RAM by capping cached apps (persists after reboot):/system/bin/device_config set_sync_disabled_for_tests persistent;/system/bin/device_config put activity_manager max_cached_processes 4"
	"Force GPU rendering:Use GPU for all UI drawing, smoother scrolling:settings put global force_hw_ui 1"
	"Disable Samsung GOS throttling:Stops Samsung CPU/GPU throttling in games and apps:settings put secure gamesdk_version 0;settings put secure game_home_enable 0;settings put secure game_auto_temperature_control 0"
	"Clear all app caches:One-shot cache wipe to free storage:pm trim-caches 999999999999999"
	"Disable RAM Plus / ZRAM swap:Stops slow storage swapping — only good if phone has 4GB+ RAM:settings put global zram_enabled 0;settings put global ram_expand_size_list 0"
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
	echo "  [q]  Quit"
	echo ""
	read -p "  > " choice

	case "$choice" in
		1) run_debloat ;;
		2) run_tweaks ;;
		q|Q) echo ""; echo "Goodbye!"; exit 0 ;;
		*) echo "  Enter 1, 2, or q." ;;
	esac
done
