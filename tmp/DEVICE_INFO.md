# Device Info

## Phone — Samsung Galaxy A05s

| Field | Value |
|-------|-------|
| Model | SM-A057G |
| Device codename | a05s |
| Brand | Samsung |
| Serial | R7AY2045FJA |
| Android version | 15 |
| SDK | 35 |
| Build | AP3A.240905.015.A2.A057GXXU7DYE5 |
| Security patch | 2025-05-01 |
| CPU ABI | arm64-v8a |
| Platform | bengal (Qualcomm Snapdragon 680) |
| Region / CSC | EUX |

### Firmware download (Bifrost)
- Model: `SM-A057G`
- Region: `EUX`
- Tool: https://github.com/zacharee/SamloaderKotlin/releases
- Drop downloaded `AP_*.tar.md5` into `tmp/firmware/`

### ADB wireless
- IP: `192.168.1.51`
- Enable: `adb tcpip 5555` via USB, then `adb connect 192.168.1.51:5555`

---

## Gamepad — Zikway Gamwing AoBing Max

| Field | Value |
|-------|-------|
| Name | Zikway Gamwing AoBing Max |
| USB Vendor ID | `413d` |
| USB Product ID | `2103` |
| Keylayout filename | `Vendor_413d_Product_2103.kl` |
| Keylayout path (rooted) | `/system/usr/keylayout/Vendor_413d_Product_2103.kl` |
| Input interfaces | `event10` (gamepad), `event11` (consumer control / screenshot button) |
| Connection | USB-C |

### Screenshot button
- Sends: `KEYCODE_VOLUME_UP` + `KEYCODE_POWER` via Consumer Control interface (`event11`)
- Interceptable by KeyMapper: ❌ (consumed by Android system before accessibility layer)
- Fix: root + custom `.kl` file remapping scancode `102` to `HOME`
- The `.kl` file is pre-written in `root.sh` step 5
