#!/bin/bash

# Interactive restore tool — detects uninstalled/disabled packages and lets you restore them

ADB="/Users/oto/Library/Android/sdk/platform-tools/adb"

# Known package names mapped to friendly labels
declare -A LABELS=(
	[com.samsung.android.app.routines]="Bixby Routines"
	[com.samsung.android.rubin.app]="Rubin (Personalization AI)"
	[com.samsung.android.intellivoiceservice]="Intellivoice Service"
	[com.samsung.android.game.gamehome]="Game Launcher / Gaming Hub"
	[com.samsung.android.game.gos]="Game Optimizing Service"
	[com.samsung.android.aremoji]="AR Emoji"
	[com.samsung.android.stickercenter]="Sticker Center"
	[com.samsung.android.app.soundpicker]="Sound Picker"
	[com.samsung.android.secsoundpicker]="Secure Sound Picker"
	[com.samsung.android.video]="Samsung Video Player"
	[com.samsung.android.themecenter]="Theme Center"
	[com.samsung.android.themestore]="Galaxy Themes"
	[com.samsung.android.app.dressroom]="Theme Park / Dress Room"
	[com.samsung.android.scloud]="Samsung Cloud"
	[com.samsung.storyservice]="Samsung Story Service"
	[com.samsung.android.smartswitchassistant]="Smart Switch Assistant"
	[com.sec.android.easyMover]="Smart Switch / Easy Mover"
	[com.sec.android.easyMover.Agent]="Smart Switch Agent"
	[com.samsung.android.lool]="Device Care"
	[com.samsung.android.dsms]="Samsung Device Security"
	[com.samsung.android.forest]="Digital Wellbeing (Forest)"
	[com.samsung.android.app.sharelive]="Share Live"
	[com.samsung.android.app.parentalcare]="Parental Controls"
	[com.samsung.android.app.watchmanagerstub]="Galaxy Watch Manager Stub"
	[com.samsung.android.kidsinstaller]="Kids Installer"
	[com.samsung.android.da.daagent]="DA Agent"
	[com.samsung.android.dqagent]="Device Quality Agent"
	[com.samsung.android.app.omcagent]="OMC Agent"
	[com.samsung.android.callassistant]="Call Assistant"
	[com.sec.android.app.billing]="Samsung Billing"
	[com.sec.android.app.samsungapps]="Galaxy Store"
	[com.sec.android.app.personalization]="Personalization Service"
	[com.facebook.appmanager]="Facebook App Manager"
	[com.facebook.services]="Facebook Services"
	[com.facebook.system]="Facebook System"
	[com.microsoft.skydrive]="Microsoft OneDrive"
	[com.aura.oobe.samsung.gl]="Aura / Carrier App Store"
	[de.axelspringer.yana.zeropage]="Samsung Free (Axel Springer)"
	[com.hiya.star]="Hiya Caller ID"
	[com.google.android.apps.tachyon]="Google Duo / Meet"
	[com.google.android.youtube]="YouTube"
	[com.google.android.gm]="Gmail"
	[com.google.android.apps.maps]="Google Maps"
	[com.google.android.calendar]="Google Calendar"
)

# --- Check ADB ---
echo "==================================="
echo "   Samsung Restore Tool"
echo "==================================="
echo ""
echo "Checking ADB connection..."
if ! $ADB devices | grep -q "device$"; then
	echo "❌ No device found."
	echo "   Enable USB Debugging and tap Allow on your phone."
	exit 1
fi

DEVICE_MODEL=$($ADB shell getprop ro.product.model 2>/dev/null | tr -d '\r')
echo "✅ Connected: $DEVICE_MODEL"
echo ""
echo "Scanning for uninstalled/disabled packages..."

# Get all packages (including uninstalled) vs currently active ones
ALL=$($ADB shell pm list packages -u 2>/dev/null | sed 's/package://' | tr -d '\r' | sort)
ACTIVE=$($ADB shell pm list packages 2>/dev/null | sed 's/package://' | tr -d '\r' | sort)

# Packages present on the system but removed/disabled for user 0
declare -a REMOVED_PKGS=()
declare -a REMOVED_DESCS=()

while IFS= read -r pkg; do
	if ! echo "$ACTIVE" | grep -qx "$pkg"; then
		label="${LABELS[$pkg]}"
		[ -z "$label" ] && label="$pkg" # use raw package name if not in known list
		REMOVED_PKGS+=("$pkg")
		REMOVED_DESCS+=("$label")
	fi
done <<<"$ALL"

if [ ${#REMOVED_PKGS[@]} -eq 0 ]; then
	echo "Nothing to restore — no removed or disabled packages found."
	exit 0
fi

echo "Found ${#REMOVED_PKGS[@]} removed/disabled package(s)."

# --- Selection state ---
declare -a SELECTED=()
for i in "${!REMOVED_PKGS[@]}"; do SELECTED+=("0"); done

print_list() {
	echo ""
	echo "  Number = toggle  |  a = all  |  n = none  |  r = restore selected  |  q = quit"
	echo ""
	echo "  #    Status  App"
	echo "  ---  ------  ---"
	for i in "${!REMOVED_PKGS[@]}"; do
		local num=$((i + 1))
		local mark="[ ]"
		[ "${SELECTED[$i]}" = "1" ] && mark="[x]"
		printf "  %-4s %s  %s\n" "$num" "$mark" "${REMOVED_DESCS[$i]}"
		# Only print raw package name if the label is the same (unknown package)
		[ "${REMOVED_DESCS[$i]}" = "${REMOVED_PKGS[$i]}" ] || printf "             %s\n" "${REMOVED_PKGS[$i]}"
	done
	echo ""
}

# --- Interactive loop ---
while true; do
	print_list

	local_count=0
	for s in "${SELECTED[@]}"; do [ "$s" = "1" ] && local_count=$((local_count + 1)); done
	echo "  Selected: $local_count / ${#REMOVED_PKGS[@]}"
	echo ""
	read -p "  > " input

	case "$input" in
		q|Q) echo "Goodbye!"; exit 0 ;;
		a|A) for i in "${!SELECTED[@]}"; do SELECTED[$i]="1"; done ;;
		n|N) for i in "${!SELECTED[@]}"; do SELECTED[$i]="0"; done ;;
		r|R)
			[ "$local_count" -eq 0 ] && echo "  Nothing selected." && continue
			echo ""
			echo "  Restoring $local_count package(s):"
			for i in "${!REMOVED_PKGS[@]}"; do
				[ "${SELECTED[$i]}" = "1" ] && echo "    - ${REMOVED_DESCS[$i]}"
			done
			echo ""
			read -p "  Confirm? (yes/no): " confirm
			[ "$confirm" != "yes" ] && echo "  Cancelled." && continue
			echo ""
			restored=0; failed=0
			for i in "${!REMOVED_PKGS[@]}"; do
				if [ "${SELECTED[$i]}" = "1" ]; then
					pkg="${REMOVED_PKGS[$i]}"
					desc="${REMOVED_DESCS[$i]}"
					printf "  %-45s " "$desc..."
					if $ADB shell cmd package install-existing "$pkg" >/dev/null 2>&1; then
						echo "✅"; restored=$((restored + 1))
					else
						echo "❌"; failed=$((failed + 1))
					fi
				fi
			done
			echo ""
			echo "  Done — Restored: $restored  Failed: $failed"
			echo ""
			read -p "  Press Enter to continue..." _
			# Rebuild list — remove successfully restored packages
			ACTIVE=$($ADB shell pm list packages 2>/dev/null | sed 's/package://' | tr -d '\r' | sort)
			NEW_PKGS=(); NEW_DESCS=(); NEW_SEL=()
			for i in "${!REMOVED_PKGS[@]}"; do
				if ! echo "$ACTIVE" | grep -qx "${REMOVED_PKGS[$i]}"; then
					NEW_PKGS+=("${REMOVED_PKGS[$i]}")
					NEW_DESCS+=("${REMOVED_DESCS[$i]}")
					NEW_SEL+=("0")
				fi
			done
			REMOVED_PKGS=("${NEW_PKGS[@]}")
			REMOVED_DESCS=("${NEW_DESCS[@]}")
			SELECTED=("${NEW_SEL[@]}")
			[ ${#REMOVED_PKGS[@]} -eq 0 ] && echo "  All packages restored." && exit 0
			;;
		''|*[!0-9]*) echo "  Invalid input." ;;
		*)
			idx=$((input - 1))
			if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#REMOVED_PKGS[@]}" ]; then
				[ "${SELECTED[$idx]}" = "1" ] && SELECTED[$idx]="0" || SELECTED[$idx]="1"
			else
				echo "  Number out of range."
			fi
			;;
	esac
done
