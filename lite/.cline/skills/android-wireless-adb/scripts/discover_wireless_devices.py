#!/usr/bin/env python3
"""Discover wireless adb devices, connect the ones that need it, and describe them.

A single `adb mdns services` snapshot is not a complete device list. mDNS
announcements arrive over several seconds, and one phone can already be
connected on a different address than the one it advertises. This script
listens, collapses those duplicates, and prints one JSON object to stdout.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import select
import subprocess
import sys
import time

CONNECT_SERVICES = {"_adb-tls-connect._tcp", "_adb._tcp"}
PAIR_SERVICE = "_adb-tls-pairing._tcp"
FORM_FACTORS = {
    "phone",
    "tablet",
    "tv",
    "watch",
    "automotive",
    "desktop",
    "appliance",
    "emulator",
}
FIELD_RE = re.compile(r'^([A-Za-z0-9_]+):\s*(?:"([^"]*)"|(\S+))\s*$')
DEVICE_RE = re.compile(r"^(\S+)\s+(\S+)(?:\s+(.*))?$")
INSTANCE_CONNECT_RE = re.compile(r"^adb-(.+)-[A-Za-z0-9]{6}$")


def parse_proto_text(text: str) -> list[dict]:
    """Parse `adb mdns track-services --proto-text` output."""
    services: list[dict] = []
    current: dict | None = None
    depth = 0
    for raw in text.splitlines():
        stripped = raw.strip()
        if current is None:
            if stripped == "service {":
                current = {}
                depth = 1
            continue
        if stripped == "{":
            depth += 1
            continue
        if stripped == "}":
            depth -= 1
            if depth <= 0:
                if current.get("service") and current.get("ipv4") and current.get("port"):
                    services.append(current)
                current = None
            continue
        match = FIELD_RE.match(stripped)
        if not match:
            continue
        key, quoted, bare = match.group(1), match.group(2), match.group(3)
        value = quoted if quoted is not None else bare
        if key == "ipv6":
            current.setdefault("ipv6", []).append(value)
        elif key == "port":
            try:
                current["port"] = int(value)
            except ValueError:
                continue
        elif key not in current:
            current[key] = value
    return services


def parse_services_table(text: str) -> list[dict]:
    """Parse `adb mdns services` (instance, type, ipv4:port)."""
    services = []
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("List of"):
            continue
        parts = line.split()
        if len(parts) < 3 or ":" not in parts[2]:
            continue
        ip, port_text = parts[2].rsplit(":", 1)
        try:
            port = int(port_text)
        except ValueError:
            continue
        services.append(
            {
                "instance": parts[0],
                "service": parts[1],
                "ipv4": ip,
                "port": port,
            }
        )
    return services


def parse_devices(text: str) -> list[dict]:
    devices = []
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("List of"):
            continue
        match = DEVICE_RE.match(line)
        if not match:
            continue
        serial, state, rest = match.group(1), match.group(2), match.group(3) or ""
        details = dict(re.findall(r"([A-Za-z0-9_]+):(\S+)", rest))
        devices.append({"serial": serial, "state": state, "details": details})
    return devices


def parse_identity(text: str) -> dict:
    identity = {}
    for raw in text.splitlines():
        if "=" not in raw:
            continue
        key, value = raw.split("=", 1)
        value = value.strip()
        if value.casefold() in {"", "null", "none"}:
            continue
        identity[key.strip()] = value
    return identity


def parse_server_status(text: str) -> dict:
    status = {}
    for raw in text.splitlines():
        if ":" not in raw:
            continue
        key, value = raw.split(":", 1)
        status[key.strip()] = value.strip().strip('"')
    return status


def hardware_serial_hint(ad: dict) -> str:
    explicit = (ad.get("serial") or "").strip()
    if explicit:
        return explicit
    instance = ad.get("instance") or ""
    service = ad.get("service") or ""
    if service == "_adb-tls-connect._tcp":
        match = INSTANCE_CONNECT_RE.fullmatch(instance)
        if match:
            return match.group(1)
    if service == "_adb._tcp" and instance.startswith("adb-"):
        return instance[4:]
    return ""


def endpoint_of(ad: dict) -> str:
    return f"{ad.get('ipv4', '')}:{ad.get('port', '')}"


def serial_ip(serial: str) -> str:
    if serial.count(":") != 1:
        return ""
    host, port = serial.rsplit(":", 1)
    if port.isdigit() and host and not host.startswith("adb-"):
        return host
    return ""


def serial_port(serial: str) -> int | None:
    if serial.count(":") != 1:
        return None
    _host, port = serial.rsplit(":", 1)
    return int(port) if port.isdigit() else None


def _ipv4_parts(ip: str) -> tuple[int, int, int, int] | None:
    parts = ip.split(".")
    if len(parts) != 4:
        return None
    try:
        nums = tuple(int(part) for part in parts)
    except ValueError:
        return None
    if any(part < 0 or part > 255 for part in nums):
        return None
    return nums  # type: ignore[return-value]


def is_private_lan(ip: str) -> bool:
    parts = _ipv4_parts(ip)
    if parts is None:
        return False
    a, b, _c, _d = parts
    if a == 10:
        return True
    if a == 172 and 16 <= b <= 31:
        return True
    return a == 192 and b == 168


def is_cgnat(ip: str) -> bool:
    """Carrier-grade NAT, including Tailscale's 100.64.0.0/10 range."""
    parts = _ipv4_parts(ip)
    if parts is None:
        return False
    a, b, _c, _d = parts
    return a == 100 and 64 <= b <= 127


def normalize_model(value: str) -> str:
    return re.sub(r"[_\-]", "", value).casefold()


def form_factor(characteristics: str) -> str:
    for token in characteristics.split(","):
        token = token.strip()
        if token in FORM_FACTORS:
            return token
    return ""


def clean_name(value: str) -> str:
    value = value.strip().strip('"')
    if value.casefold() in {"", "null", "none"}:
        return ""
    return value


def describe_device(
    name: str,
    manufacturer: str,
    model: str,
    factor: str,
    release: str,
    sdk: str,
    abi: str,
) -> str:
    name = clean_name(name)
    manufacturer = manufacturer.strip()
    model = model.strip()
    ident = " ".join(part for part in (manufacturer, model) if part)
    if name and ident and ident.casefold() not in name.casefold():
        title = f"{name} — {ident}"
    else:
        title = name or ident or "Android device"
    extras = []
    if factor:
        extras.append(factor)
    if release:
        extras.append(f"Android {release}")
    if sdk:
        extras.append(f"API {sdk}")
    if abi:
        extras.append(abi)
    if extras:
        return f"{title} ({', '.join(extras)})"
    return title


def dedupe_services(services: list[dict]) -> list[dict]:
    best: dict[tuple, dict] = {}
    for ad in services:
        key = (ad.get("service"), ad.get("instance"), ad.get("ipv4"), ad.get("port"))
        previous = best.get(key)
        if previous is None or _richness(ad) > _richness(previous):
            best[key] = ad
    return list(best.values())


def _richness(ad: dict) -> int:
    score = 0
    for value in ad.values():
        if value not in ("", None, [], 0):
            score += 1
    return score


def _device_matches_ad(device: dict, ad: dict, identity: dict) -> bool:
    if device.get("state") != "device":
        return False
    ep = endpoint_of(ad)
    serial = device.get("serial", "")
    if serial == ep:
        return True
    hint = hardware_serial_hint(ad)
    if hint and identity.get("serialno") == hint:
        return True
    instance = ad.get("instance") or ""
    if instance and instance in serial:
        return True
    port = serial_port(serial)
    advertised = normalize_model(ad.get("product_model") or "")
    listed = normalize_model(device.get("details", {}).get("model", ""))
    if port is not None and port == ad.get("port") and advertised and advertised == listed:
        return True
    return False


def connect_targets(services: list[dict], devices: list[dict], identities: dict) -> list[dict]:
    """TLS (or legacy) advertisements that still need `adb connect`.

    An advertisement is already satisfied when any healthy transport is the
    same endpoint, the same hardware serial, or the same model on the same
    port (a VPN address reaching the TLS server mDNS advertises on the LAN).
    """
    pending: dict[str, dict] = {}
    for ad in services:
        if ad.get("service") not in CONNECT_SERVICES:
            continue
        if not ad.get("ipv4") or not ad.get("port"):
            continue
        if any(
            _device_matches_ad(device, ad, identities.get(device["serial"], {}))
            for device in devices
        ):
            continue
        hint = hardware_serial_hint(ad)
        key = f"hw:{hint}" if hint else f"ip:{ad['ipv4']}"
        current = pending.get(key)
        if current is None or _prefer_connect_ad(ad, current):
            pending[key] = ad
    return list(pending.values())


def _prefer_connect_ad(candidate: dict, current: dict) -> bool:
    def score(ad: dict) -> tuple:
        return (
            0 if ad.get("service") == "_adb-tls-connect._tcp" else 1,
            0 if is_private_lan(ad.get("ipv4") or "") else 1,
            ad.get("ipv4") or "",
            ad.get("port") or 0,
        )

    return score(candidate) < score(current)


def pairing_requests(services: list[dict], devices: list[dict], identities: dict) -> list[dict]:
    connect_ips = {
        ad.get("ipv4")
        for ad in services
        if ad.get("service") in CONNECT_SERVICES and ad.get("ipv4")
    }
    requests = []
    seen = set()
    for ad in services:
        if ad.get("service") != PAIR_SERVICE:
            continue
        ip = ad.get("ipv4") or ""
        if ip and ip in connect_ips:
            continue
        if any(
            _device_matches_ad(device, ad, identities.get(device["serial"], {}))
            for device in devices
        ):
            continue
        # Same LAN address already has a healthy wireless session.
        if ip and any(
            device.get("state") == "device" and serial_ip(device.get("serial", "")) == ip
            for device in devices
        ):
            continue
        ep = endpoint_of(ad) if ip and ad.get("port") else ""
        if ep in seen:
            continue
        seen.add(ep)
        instance = ad.get("instance") or ""
        requests.append(
            {
                "endpoint": ep,
                "instance": instance,
                "method": "qr" if instance.startswith("studio-") else "code",
                "product_model": ad.get("product_model") or "",
            }
        )
    return requests


def is_wireless_serial(serial: str) -> bool:
    if serial.startswith("emulator-"):
        return False
    if ":" in serial or "_adb" in serial:
        return True
    return False


def transport_rank(serial: str, mdns_endpoints: set[str]) -> tuple:
    ip = serial_ip(serial)
    return (
        0 if serial in mdns_endpoints else 1,
        0 if is_private_lan(ip) else 1,
        0 if "_adb-tls-connect" in serial else 1 if "_adb._tcp" in serial or ip else 2,
        1 if is_cgnat(ip) else 0,
        serial,
    )


def ad_metadata(ads: list[dict]) -> dict:
    meta = {
        "model": "",
        "name": "",
        "sdk_full": "",
        "serialno": "",
        "mdns_endpoint": "",
        "instance": "",
        "transport": "",
    }
    for ad in ads:
        service = ad.get("service") or ""
        if service not in CONNECT_SERVICES:
            continue
        if not meta["model"] and ad.get("product_model"):
            meta["model"] = ad["product_model"]
        if not meta["name"] and ad.get("given_name"):
            meta["name"] = ad["given_name"]
        if not meta["sdk_full"] and ad.get("build_version_sdk_full"):
            meta["sdk_full"] = ad["build_version_sdk_full"]
        if not meta["serialno"]:
            meta["serialno"] = hardware_serial_hint(ad)
        if service == "_adb-tls-connect._tcp" and ad.get("ipv4"):
            meta["mdns_endpoint"] = endpoint_of(ad)
            meta["instance"] = ad.get("instance") or meta["instance"]
            meta["transport"] = "tls"
        elif service == "_adb._tcp" and ad.get("ipv4") and not meta["mdns_endpoint"]:
            meta["mdns_endpoint"] = endpoint_of(ad)
            meta["instance"] = ad.get("instance") or meta["instance"]
            meta["transport"] = "legacy-tcp"
    return meta


def assemble_fleet(
    services: list[dict],
    devices: list[dict],
    identities: dict,
    *,
    limit: int | None,
    match: str | None,
    connected_endpoints: set[str] | None = None,
) -> dict:
    """Group transports by hardware serial and apply match/limit."""
    connected_endpoints = connected_endpoints or set()
    groups: dict[str, dict] = {}

    def ensure(key: str) -> dict:
        return groups.setdefault(key, {"ads": [], "transports": []})

    for ad in services:
        if ad.get("service") not in CONNECT_SERVICES:
            continue
        hint = hardware_serial_hint(ad)
        key = f"hw:{hint}" if hint else f"ep:{endpoint_of(ad)}"
        ensure(key)["ads"].append(ad)

    for device in devices:
        serial = device["serial"]
        if serial.startswith("emulator-"):
            continue
        identity = identities.get(serial, {})
        key = ""
        if identity.get("serialno"):
            key = f"hw:{identity['serialno']}"
        else:
            for ad in services:
                if ad.get("service") in CONNECT_SERVICES and _device_matches_ad(
                    device, ad, identity
                ):
                    hint = hardware_serial_hint(ad)
                    key = f"hw:{hint}" if hint else f"ep:{endpoint_of(ad)}"
                    break
        if not key:
            if is_wireless_serial(serial):
                key = f"adb:{serial}"
            else:
                continue
        ensure(key)["transports"].append(device)

    records = []
    ignored = []
    for group in groups.values():
        meta = ad_metadata(group["ads"])
        wireless = [
            device
            for device in group["transports"]
            if device.get("state") == "device" and is_wireless_serial(device["serial"])
        ]
        if not wireless:
            usb = [
                device["serial"]
                for device in group["transports"]
                if device.get("state") == "device" and not is_wireless_serial(device["serial"])
            ]
            if usb:
                ignored.append({"adb_serials": usb, "reason": "usb", "model": meta["model"]})
            continue
        mdns_endpoints = set()
        if meta["mdns_endpoint"]:
            mdns_endpoints.add(meta["mdns_endpoint"])
        chosen = min(wireless, key=lambda device: transport_rank(device["serial"], mdns_endpoints))
        identity = {}
        for device in wireless:
            identity.update(identities.get(device["serial"], {}))
        # Prefer the chosen transport's identity when it was queried.
        identity = {**identity, **identities.get(chosen["serial"], {})}
        name = clean_name(identity.get("device_name") or meta["name"])
        manufacturer = identity.get("manufacturer", "")
        model = identity.get("model") or meta["model"]
        factor = form_factor(identity.get("characteristics", ""))
        release = identity.get("release", "")
        sdk = identity.get("sdk_full") or identity.get("sdk") or meta["sdk_full"]
        abi = identity.get("abi", "")
        description = describe_device(name, manufacturer, model, factor, release, sdk, abi)
        aliases = sorted(device["serial"] for device in wireless if device["serial"] != chosen["serial"])
        connection = (
            "connected"
            if chosen["serial"] in connected_endpoints or meta["mdns_endpoint"] in connected_endpoints
            else "already-connected"
        )
        records.append(
            {
                "description": description,
                "adb_serial": chosen["serial"],
                "hardware_serial": identity.get("serialno") or meta["serialno"],
                "name": name,
                "manufacturer": manufacturer,
                "model": model,
                "product_device": identity.get("device", ""),
                "form_factor": factor,
                "android_release": release,
                "sdk": sdk,
                "abi": abi,
                "mdns_endpoint": meta["mdns_endpoint"],
                "mdns_instance": meta["instance"],
                "transport": meta["transport"] or "wireless",
                "state": "device",
                "connection": connection,
                "aliases": aliases,
            }
        )

    excluded = []
    if match:
        needle = match.casefold()
        kept = []
        for record in records:
            if needle in _haystack(record):
                kept.append(record)
            else:
                excluded.append(_brief(record, "match-miss"))
        records = kept
    records.sort(
        key=lambda record: (
            record["description"].casefold(),
            record.get("hardware_serial") or "",
            record["adb_serial"],
        )
    )
    selected = records
    if limit is not None:
        selected = records[:limit]
        excluded.extend(_brief(record, "over-limit") for record in records[limit:])
    return {"selected": selected, "excluded": excluded, "ignored": ignored}


def _haystack(record: dict) -> str:
    keys = (
        "description",
        "name",
        "manufacturer",
        "model",
        "hardware_serial",
        "adb_serial",
        "mdns_endpoint",
        "mdns_instance",
        "form_factor",
        "product_device",
    )
    return " ".join(str(record.get(key) or "") for key in keys).casefold()


def _brief(record: dict, reason: str) -> dict:
    return {
        "description": record["description"],
        "adb_serial": record["adb_serial"],
        "hardware_serial": record.get("hardware_serial") or "",
        "model": record.get("model") or "",
        "reason": reason,
    }


def fleet_notes(selected: list[dict]) -> list[str]:
    notes = []
    for record in selected:
        mdns_endpoint = record.get("mdns_endpoint") or ""
        serial = record["adb_serial"]
        if mdns_endpoint and mdns_endpoint != serial:
            notes.append(
                f"{record['description']} is already connected as {serial}; "
                f"mDNS advertises {mdns_endpoint}. That endpoint was left unused "
                "so the phone does not get a second session."
            )
        if record.get("aliases"):
            notes.append(
                f"{record['description']} has extra transports {', '.join(record['aliases'])}; "
                f"tests should use {serial}."
            )
    return notes


IDENTITY_COMMAND = "; ".join(
    [
        "printf '%s\\n' \"manufacturer=$(getprop ro.product.manufacturer)\"",
        "printf '%s\\n' \"model=$(getprop ro.product.model)\"",
        "printf '%s\\n' \"device=$(getprop ro.product.device)\"",
        "printf '%s\\n' \"characteristics=$(getprop ro.build.characteristics)\"",
        "printf '%s\\n' \"release=$(getprop ro.build.version.release)\"",
        "printf '%s\\n' \"sdk=$(getprop ro.build.version.sdk)\"",
        "printf '%s\\n' \"sdk_full=$(getprop ro.build.version.sdk_full)\"",
        "printf '%s\\n' \"abi=$(getprop ro.product.cpu.abi)\"",
        "printf '%s\\n' \"serialno=$(getprop ro.serialno)\"",
        "printf '%s\\n' \"device_name=$(settings get global device_name)\"",
    ]
)


def _run(args: list[str], timeout: float) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        args,
        capture_output=True,
        text=True,
        timeout=timeout,
        check=False,
    )


def _stop(proc: subprocess.Popen) -> None:
    if proc.poll() is not None:
        return
    proc.terminate()
    try:
        proc.wait(timeout=2)
    except subprocess.TimeoutExpired:
        proc.kill()
        proc.wait(timeout=2)


def listen_track(seconds: float) -> tuple[str, str]:
    proc = subprocess.Popen(
        ["adb", "mdns", "track-services", "--proto-text"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=False,
        bufsize=0,
    )
    assert proc.stdout is not None and proc.stderr is not None
    os.set_blocking(proc.stdout.fileno(), False)
    os.set_blocking(proc.stderr.fileno(), False)
    out = bytearray()
    err = bytearray()
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        if proc.poll() is not None:
            break
        remaining = deadline - time.monotonic()
        ready, _, _ = select.select(
            [proc.stdout, proc.stderr], [], [], min(0.4, max(0.0, remaining))
        )
        for stream, dest in ((proc.stdout, out), (proc.stderr, err)):
            if stream not in ready:
                continue
            try:
                chunk = stream.read()
            except BlockingIOError:
                continue
            if chunk:
                dest.extend(chunk)
    _stop(proc)
    for stream, dest in ((proc.stdout, out), (proc.stderr, err)):
        try:
            chunk = stream.read()
        except BlockingIOError:
            chunk = b""
        if chunk:
            dest.extend(chunk)
    return (
        out.decode("utf-8", errors="replace"),
        err.decode("utf-8", errors="replace"),
    )


def discover_services(listen_seconds: float) -> tuple[list[dict], str, str]:
    snapshots = []
    snapshot = _run(["adb", "mdns", "services"], timeout=15)
    snapshots.append(snapshot.stdout)
    track_out, track_err = listen_track(listen_seconds)
    snapshot = _run(["adb", "mdns", "services"], timeout=15)
    snapshots.append(snapshot.stdout)
    services = dedupe_services(parse_proto_text(track_out) + parse_services_table("\n".join(snapshots)))
    mode = "track-services --proto-text"
    if not services and track_err.strip():
        # Older platform-tools have `adb mdns services` and not proto-text.
        deadline = time.monotonic() + listen_seconds
        polled = list(snapshots)
        while time.monotonic() < deadline:
            polled.append(_run(["adb", "mdns", "services"], timeout=15).stdout)
            time.sleep(1)
        services = dedupe_services(parse_services_table("\n".join(polled)))
        mode = "mdns services"
    return services, mode, track_err.strip()


def list_attached() -> list[dict]:
    completed = _run(["adb", "devices", "-l"], timeout=15)
    if completed.returncode != 0 and not completed.stdout:
        raise RuntimeError((completed.stderr or completed.stdout or "adb devices failed").strip())
    return parse_devices(completed.stdout)


def identify(serial: str) -> dict:
    completed = _run(["adb", "-s", serial, "shell", IDENTITY_COMMAND], timeout=25)
    if completed.returncode != 0 and not completed.stdout.strip():
        return {}
    return parse_identity(completed.stdout)


def identify_ready(devices: list[dict], known: dict) -> dict:
    identities = dict(known)
    for device in devices:
        serial = device["serial"]
        if device.get("state") != "device" or serial in identities:
            continue
        if serial.startswith("emulator-"):
            continue
        print(f"reading identity for {serial}", file=sys.stderr)
        identities[serial] = identify(serial)
    return identities


def connect_endpoint(endpoint: str) -> tuple[bool, str]:
    completed = _run(["adb", "connect", endpoint], timeout=25)
    text = (completed.stdout or completed.stderr or "").strip()
    lowered = text.casefold()
    ok = completed.returncode == 0 and (
        "connected to" in lowered or "already connected" in lowered
    )
    return ok, text


def reconnect_endpoint(endpoint: str) -> tuple[bool, str]:
    _run(["adb", "disconnect", endpoint], timeout=15)
    return connect_endpoint(endpoint)


def redact(text: str, secret: str) -> str:
    if secret:
        return text.replace(secret, "******")
    return text


def run_pairs(pairs: list[tuple[str, str]]) -> list[dict]:
    results = []
    for endpoint, code in pairs:
        print(f"pairing {endpoint}", file=sys.stderr)
        completed = _run(["adb", "pair", endpoint, code], timeout=40)
        message = redact((completed.stdout or completed.stderr or "").strip(), code)
        lowered = message.casefold()
        ok = completed.returncode == 0 and "successfully paired" in lowered
        results.append({"endpoint": endpoint, "ok": ok, "message": message})
        if not ok:
            print(f"pair failed for {endpoint}: {message}", file=sys.stderr)
    return results


def server_info() -> dict:
    version = _run(["adb", "version"], timeout=15)
    status = _run(["adb", "server-status"], timeout=15)
    parsed = parse_server_status(status.stdout) if status.returncode == 0 else {}
    version_line = ""
    for line in version.stdout.splitlines():
        if line.lower().startswith("version "):
            version_line = line.split(" ", 1)[1].strip()
            break
    info = {
        "version": version_line or parsed.get("version", ""),
        "mdns_enabled": parsed.get("mdns_enabled", ""),
        "mdns_backend": parsed.get("mdns_backend", ""),
    }
    return info


def mdns_notes(info: dict) -> list[str]:
    notes = []
    enabled = (info.get("mdns_enabled") or "").casefold()
    backend = info.get("mdns_backend") or ""
    if enabled == "false":
        notes.append(
            "adb reports mdns_enabled=false. Set ADB_MDNS=1 and restart adb "
            "(adb kill-server drops every current session) before discovery can see unpaired devices."
        )
    elif backend and backend != "LIBADBMDNS":
        notes.append(
            f"adb mdns_backend is {backend}. Current platform-tools expect LIBADBMDNS; "
            "set ADB_MDNS_OPENSCREEN=0 and restart adb if discovery stays empty. "
            "Restarting drops every current session."
        )
    return notes


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--listen-seconds",
        type=float,
        default=12,
        help="how long to listen for mDNS announcements (default 12; a short snapshot misses devices)",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=None,
        help="maximum number of physical devices to select; default is every ready device",
    )
    parser.add_argument(
        "--match",
        default=None,
        help="case-insensitive substring matched against name, model, serial, and description",
    )
    parser.add_argument(
        "--pair",
        nargs=2,
        action="append",
        default=[],
        metavar=("HOST:PORT", "CODE"),
        help="pair one wireless-debugging code shown on the device; repeat for each device",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.limit is not None and args.limit < 0:
        print("--limit must be zero or greater", file=sys.stderr)
        return 1
    if args.listen_seconds <= 0:
        print("--listen-seconds must be greater than zero", file=sys.stderr)
        return 1
    try:
        info = server_info()
    except FileNotFoundError:
        json.dump({"error": "adb not found on PATH"}, sys.stdout, indent=2)
        sys.stdout.write("\n")
        return 1

    pair_results = run_pairs(args.pair) if args.pair else []
    print(f"listening for mDNS services ({args.listen_seconds:.0f}s)", file=sys.stderr)
    try:
        services, mode, track_error = discover_services(args.listen_seconds)
        print(f"discovered {len(services)} mDNS service(s) via {mode}", file=sys.stderr)
        devices = list_attached()
        identities = identify_ready(devices, {})
    except (OSError, subprocess.TimeoutExpired, RuntimeError) as exc:
        json.dump({"error": str(exc), "adb": info}, sys.stdout, indent=2)
        sys.stdout.write("\n")
        return 1

    targets = connect_targets(services, devices, identities)
    connected_endpoints: set[str] = set()
    failures = []
    for ad in targets:
        ep = endpoint_of(ad)
        existing = next((device for device in devices if device["serial"] == ep), None)
        print(f"connecting {ep}", file=sys.stderr)
        if existing and existing["state"] in {"offline", "unauthorized"}:
            ok, message = reconnect_endpoint(ep)
        else:
            ok, message = connect_endpoint(ep)
        if ok:
            connected_endpoints.add(ep)
        else:
            failures.append({"endpoint": ep, "error": message or "adb connect failed"})

    if connected_endpoints:
        time.sleep(0.5)
        try:
            devices = list_attached()
        except (OSError, subprocess.TimeoutExpired, RuntimeError) as exc:
            failures.append({"endpoint": "", "error": str(exc)})
        identities = identify_ready(devices, identities)

    fleet = assemble_fleet(
        services,
        devices,
        identities,
        limit=args.limit,
        match=args.match,
        connected_endpoints=connected_endpoints,
    )
    notes = mdns_notes(info) + fleet_notes(fleet["selected"])
    if track_error and not services:
        notes.append(track_error.splitlines()[-1])
    if args.limit is not None and len(fleet["selected"]) < args.limit:
        notes.append(
            f"Requested {args.limit} device(s); {len(fleet['selected'])} ready device(s) matched."
        )
    needs_pairing = pairing_requests(services, devices, identities)
    payload = {
        "adb": info,
        "discovery_mode": mode,
        "listen_seconds": args.listen_seconds,
        "discovered_services": [
            {
                "instance": ad.get("instance", ""),
                "service": ad.get("service", ""),
                "ipv4": ad.get("ipv4", ""),
                "port": ad.get("port", 0),
                "product_model": ad.get("product_model", ""),
                "build_version_sdk_full": ad.get("build_version_sdk_full", ""),
                "given_name": ad.get("given_name", ""),
                "serial": ad.get("serial", "") or hardware_serial_hint(ad),
                "hostname": ad.get("hostname", ""),
            }
            for ad in services
        ],
        "selected": fleet["selected"],
        "excluded": fleet["excluded"],
        "needs_pairing": needs_pairing,
        "pair_results": pair_results,
        "failures": failures,
        "ignored": fleet["ignored"],
        "notes": notes,
    }
    json.dump(payload, sys.stdout, indent=2)
    sys.stdout.write("\n")
    if args.limit == 0:
        return 0
    return 0 if fleet["selected"] else 2


if __name__ == "__main__":
    sys.exit(main())
