# Windows build fix (path too long)

## Problem

Building from `Downloads\a_chatz_production_starter (1)\...` can fail with:

```text
error MSB3491: ... exceeds the OS max path limit. The fully qualified file name must be less than 260 characters.
```

## Solutions (pick one)

### Option A — Use the helper script (recommended)

From PowerShell:

```powershell
cd "C:\Users\andzani\Downloads\a_chatz_production_starter (1)\a_chatz_production_starter"
.\scripts\run_windows.ps1
```

This uses a short junction at `C:\achatz` and runs `flutter run -d windows`.

### Option B — Work from `C:\achatz` directly

A junction may already exist:

```powershell
cd C:\achatz
flutter clean
flutter pub get
flutter run -d windows
```

### Option C — Move the project

Copy or clone the repo to a short path, e.g. `C:\dev\achatz`, then build there.

### Option D — Enable long paths (Windows 10+)

1. Settings → System → About → Advanced system settings  
2. Or Group Policy: **Enable Win32 long paths**  
3. Reboot, then `flutter clean` and rebuild  

---

**Verified:** `flutter build windows --debug` succeeds from `C:\achatz`.
