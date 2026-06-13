# Debloat Samsung Devices

An interactive terminal tool to remove pre-installed bloatware and apply performance tweaks on Samsung phones — no root required, using ADB.

## What it does

- **Debloat** — lists only the bloatware packages actually present on your device, lets you toggle them by number, then removes them all at once
- **Performance tweaks** — disable animations, limit background processes, stop Samsung GOS throttling, clear caches, and more
- All removals use `--user 0` so they're reversible — a factory reset or a single ADB command restores anything

## Requirements

- **ADB** installed on your computer
  - macOS: `brew install android-platform-tools`
  - Linux: `sudo apt install android-sdk-platform-tools`
  - Windows: [Download platform-tools](https://developer.android.com/tools/releases/platform-tools)
- A Samsung phone running Android 10 or later

> **Note:** The script hardcodes the ADB path for macOS (`/Users/<you>/Library/Android/sdk/platform-tools/adb`). Edit the `ADB=` line at the top of `debloat.sh` if yours is different (`which adb` to find it).

## Phone setup (one time)

1. Settings → About Phone → tap **Build number** 7 times
2. Settings → Developer options → enable **USB Debugging**
3. Connect via USB, select **File Transfer** mode, tap **Allow** on the popup

Verify the connection:
```bash
adb devices
# should show: <serial>    device
```

## Usage

```bash
chmod +x debloat.sh
./debloat.sh
```

You'll see a main menu:

```
===================================
   Samsung Phone Optimizer
===================================
✅ Connected: SM-A145F

  [1]  Remove bloatware
  [2]  Apply performance tweaks
  [q]  Quit
```

### Controls (same in both modes)

| Input | Action |
|-------|--------|
| `1`–`N` | Toggle item on/off |
| `a` | Select all |
| `n` | Deselect all |
| `r` | Apply / remove selected (asks for confirmation) |
| `b` | Back to main menu |
| `q` | Quit |

## Bloatware removed

| Category | Apps |
|----------|------|
| Bixby & AI | Bixby Routines, Rubin AI, Intellivoice |
| Games & Media | Game Launcher, Game Optimizing Service, AR Emoji, Sticker Center, Sound Picker, Samsung Video |
| Themes | Theme Center, Dress Room |
| Cloud & Backup | Samsung Cloud, Story Service, Smart Switch (both) |
| Utility | Device Care, Device Security, Digital Wellbeing, Share Live, Parental Controls, Galaxy Watch Stub, Kids Installer, DA/DQ/OMC Agents, Call Assistant, Samsung Billing, Galaxy Store, Personalization |
| 3rd party pre-installs | Facebook App Manager/Services/System, Microsoft OneDrive, Aura Carrier Store, Samsung Free (Axel Springer), Hiya Caller ID |
| Optional Google | Duo/Meet, YouTube, Gmail, Maps, Calendar |

## Performance tweaks

| Tweak | Effect |
|-------|--------|
| Disable animations | UI feels instant |
| Speed up animations (0.5x) | Snappier with visual feedback |
| Limit background processes to 4 | Frees RAM, persists after reboot |
| Force GPU rendering | Smoother scrolling |
| Disable Samsung GOS throttling | Stops CPU/GPU throttling in apps |
| Clear all app caches | One-shot storage cleanup |
| Disable RAM Plus / ZRAM swap | Reduces storage swapping lag (4GB+ RAM only) |

## Restoring removed apps

Any removed app can be restored without a factory reset:

```bash
adb shell cmd package install-existing <package.name>
```

Example:
```bash
adb shell cmd package install-existing com.samsung.android.game.gamehome
```

## Safety notes

- Only packages confirmed safe by the community (XDA, SamFlux, Android debloat lists) are included
- Nothing that affects calls, SMS, contacts, camera, launcher, or core Android is touched
- If something breaks after removal, restore the app with the command above
