---
name: android-wireless-adb
description: Discover Android devices with adb mDNS, pair and connect each wireless-debugging device (or a requested count), and describe it from adb before running tests on the selected serials. Use when testing on Android hardware over Wi-Fi, wireless debugging, adb mdns, adb pair, or adb connect.
---

# Wireless Android device testing

Discover the fleet with the bundled script, then run the project's device tests on the selected serials. The script listens for mDNS, connects endpoints that are not already up, collapses duplicate routes to the same phone, and describes each device from adb.

A one-shot `adb mdns services` is not a device list. Announcements show up over several seconds, and a phone can already be connected on a different address than the one it advertises.

## 1. Discover and connect

Run `scripts/discover_wireless_devices.py` from the directory that contains this SKILL.md. Python 3 standard library only. Stdout is one JSON object; progress goes to stderr.

```bash
python3 "<skill-dir>/scripts/discover_wireless_devices.py"
python3 "<skill-dir>/scripts/discover_wireless_devices.py" --limit 1
python3 "<skill-dir>/scripts/discover_wireless_devices.py" --match "SM-S938"
python3 "<skill-dir>/scripts/discover_wireless_devices.py" --pair 192.168.1.20:37123 123456
```

- Default: every physical device that reaches adb state `device`.
- The user asked for a count: `--limit N`. Selection is alphabetical by description. Report every excluded device. When fewer than N are ready, test the ready ones and say the fleet was short.
- The user named a device: `--match` against the settings name, model, hardware serial, or description. Prefer `--match` over `--limit` when they named a device.
- Repeat `--pair HOST:PORT CODE` once per device. `HOST:PORT` and the code come from **Wireless debugging → Pair device with pairing code**. The code is not copied into the JSON.
- Pass `--listen-seconds` only to lengthen a listen that came back short. The default is 12 seconds.

Exit 0 means `selected` is non-empty. Exit 2 means nothing is ready to test. Read the JSON either way.

## 2. Use the JSON

| Field | Use |
|---|---|
| `selected[]` | The test fleet. One entry per physical device. |
| `selected[].adb_serial` | The only serial to pass to `adb -s` and `ANDROID_SERIAL`. |
| `selected[].description` | The name to show the user. |
| `selected[].mdns_endpoint` | The `_adb-tls-connect` address from mDNS. It can differ from `adb_serial` when a healthy session already exists on another address. |
| `needs_pairing[]` | No session yet. `method: code` needs a pairing code. `method: qr` is an Android Studio QR service (`studio-…`); ask the user to open **Pair device with pairing code** instead. |
| `excluded[]` | Ready devices left out by `--limit` or `--match`. |
| `failures[]` | Connect attempts that did not reach `device`. |
| `notes[]` | Duplicate routes, a short fleet, or an mDNS backend that needs a restart. |

`needs_pairing` stops the test run. Ask for each code, rerun with `--pair`, and do not invent a code. `adb pair` without a code waits on stdin; always pass the code as the argument.

A failure on one endpoint does not drop other `selected` devices.

## 3. Describe a device

Use `description` as written. It is built from the device, then from the mDNS record when the device is not connected yet:

1. `settings get global device_name` (the name in Android settings), or mDNS `given_name` on adb Wi-Fi 2.0.
2. `ro.product.manufacturer` and `ro.product.model`, or mDNS `product_model`.
3. Android release and SDK (`ro.build.version.sdk_full` when set).
4. Form factor only when `ro.build.characteristics` contains `phone`, `tablet`, `tv`, `watch`, `automotive`, `desktop`, `appliance`, or `emulator`. `nosdcard` is not a type.

Example shape: `Kitchen tablet — samsung SM-X110 (tablet, Android 15, API 35, arm64-v8a)`.

## 4. Run the tests

One physical device per invocation. Other transports may stay attached, including a second route to a phone you are not testing, so an unscoped `adb` command fails with `more than one device/emulator`.

For each `selected` entry:

1. `adb -s SERIAL …` for every adb call. For a tool that calls adb itself, set `ANDROID_SERIAL=SERIAL` for that invocation only. `-s` overrides `ANDROID_SERIAL`.
2. Run the project's existing device-test command (Gradle `connected*AndroidTest`, an instrumentation runner, Maestro, Marathon, or the repo's documented equivalent).
3. Keep going after a device fails. Record description, `adb_serial`, command, and pass/fail.
4. On failure, capture `adb -s SERIAL logcat -d -t 200` and `adb -s SERIAL exec-out screencap -p > <temp>.png`. Leave those artifacts out of git.

Report the fleet before a long run: description, `adb_serial`, and whether `connection` is `already-connected` or `connected`.

There is no device-test command in the repo: say so and stop, rather than inventing a sample app.

## 5. Connection rules

- Connect to `_adb-tls-connect._tcp`. The pairing port is a different, short-lived port and only exists while the pairing screen is open. After a successful pair, discover again and connect to the TLS port.
- Prefer an already-healthy transport over opening the mDNS address as a second session. Same hardware serial on a LAN address and a CGNAT address (`100.64.0.0/10`, used by overlay networks) is one phone.
- `_adb._tcp` is legacy cleartext from `adb tcpip`. Use it only when that device has no TLS service. Leave `adb tcpip` alone.
- Ports are random and change when wireless debugging restarts. Rediscover. Do not store endpoints in the repo.
- `adb server-status` should show `mdns_enabled: true`. On current platform-tools, `mdns_backend` should be `LIBADBMDNS`. When the JSON says discovery is off or the backend is obsolete, set `ADB_MDNS=1` or `ADB_MDNS_OPENSCREEN=0` as that note says. Restart adb only after the user accepts that `adb kill-server` drops every session.
- Same Wi-Fi as the computer, wireless debugging on. A VPN, AP client isolation, or a multicast filter can hide mDNS while an existing `ip:port` session still works; the script keeps those sessions.
- Phones and tablets: Android 11 or higher. TV and Wear: Android 13 or higher. Wear on Android 11 does not use this flow.
- The screen has to have been on when wireless debugging was enabled. A dark phone that never started the TLS server has nothing to advertise.
