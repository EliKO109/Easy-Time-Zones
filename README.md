# 🕐 Easy Time Zones

A beautiful, minimal macOS menu bar app that shows the time across multiple time zones at a glance.

![macOS](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![Version](https://img.shields.io/github/v/release/EliKO109/Easy-Time-Zones)

---

## ✨ Features

- 🌍 Track any number of cities and time zones
- 🕹️ Time Travel Slider – scrub forward/backward in time
- 🔍 Smart city search powered by CoreLocation & MapKit
- 🎨 Customizable accent color
- 📋 One-click copy of time summaries
- 🔔 Auto-notifies you when a new version is available

---

## 📥 Install

> [!WARNING]
> **This app is not notarized by Apple.** Always right-click → Open the first time to bypass macOS Gatekeeper. The one-liner installer script and DMG are open-source — you can review them before running.

### Option 1 – One-liner Terminal (Easiest)

```bash
curl -fsSLO https://raw.githubusercontent.com/EliKO109/Easy-Time-Zones/main/install.sh && bash install.sh
```

The installer verifies the SHA-256 digest of the downloaded DMG against the asset metadata published in the latest GitHub release.

### Option 2 – Manual Download

1. Go to [Releases](https://github.com/EliKO109/Easy-Time-Zones/releases/latest).
2. Download `EasyTimeZones-<version>.dmg` and the matching `.sha256` file.
3. Verify integrity: `shasum -a 256 -c EasyTimeZones-<version>.dmg.sha256`
4. Open the DMG and drag **Easy Time Zones.app** to your `/Applications` folder.
5. Right-click → Open the first time.

---

## 🔄 Updating

The app checks for updates automatically on launch. When a new version is available, a banner appears in the menu — just click it to download.

To update manually, repeat the install step above (it replaces the existing version).

---

## 🛠 Build from Source

```bash
git clone https://github.com/EliKO109/Easy-Time-Zones.git
cd Easy-Time-Zones
open "Easy Time Zones.xcodeproj"
```

Then press **Cmd+R** in Xcode to run.

---

## 📄 License

MIT © Eli Kony
