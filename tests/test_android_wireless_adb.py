#!/usr/bin/env python3
"""Parser and fleet-selection tests for wireless adb discovery.

Live handsets are not required. The discovery script is imported from the
full profile; the lite copy is kept byte-identical by SourceTreeTests.
"""

import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = (
    ROOT
    / "full"
    / ".cline"
    / "skills"
    / "android-wireless-adb"
    / "scripts"
    / "discover_wireless_devices.py"
)

PROTO = """
Services:
tls {
  service {
    instance: "adb-R5CY13WRJXH-x8fg7q"
    service: "_adb-tls-connect._tcp"
    ipv4: "192.168.1.223"
    ipv6: "fe80:0:0:0:8458:aff:fe24:237a"
    port: 38103
    product_model: "SM-S938U1"
    build_version_sdk_full: "36.1"
    mdns_service_version: "1"
    hostname: "Android.local"
  }
}
tls {
  service {
    instance: "adb-R5CR71NJ2AF-O9f2Fd"
    service: "_adb-tls-connect._tcp"
    ipv4: "192.168.1.224"
    port: 44593
    product_model: "SM-G998U1"
    build_version_sdk_full: ""
    hostname: "Android-2.local"
  }
}
"""

TABLE = """
List of discovered mdns services
adb-R5CR71NJ2AF-O9f2Fd	_adb-tls-connect._tcp	192.168.1.224:44593
adb-14141FDF600081-QXjCrW	_adb-tls-pairing._tcp	192.168.86.38:33861
"""


def load_module():
    spec = importlib.util.spec_from_file_location("discover_wireless_devices", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class ParseTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.mod = load_module()

    def test_proto_text_keeps_both_phones_and_empty_sdk(self):
        services = self.mod.parse_proto_text(PROTO)
        self.assertEqual(
            [("SM-S938U1", 38103, "36.1"), ("SM-G998U1", 44593, "")],
            [(item["product_model"], item["port"], item["build_version_sdk_full"]) for item in services],
        )
        self.assertEqual("R5CR71NJ2AF", self.mod.hardware_serial_hint(services[1]))
        self.assertEqual("R5CY13WRJXH", self.mod.hardware_serial_hint(services[0]))

    def test_services_table_parses_tabs(self):
        services = self.mod.parse_services_table(TABLE)
        self.assertEqual("_adb-tls-connect._tcp", services[0]["service"])
        self.assertEqual(44593, services[0]["port"])
        self.assertEqual("_adb-tls-pairing._tcp", services[1]["service"])

    def test_devices_long_format(self):
        text = (
            "List of devices attached\n"
            "100.77.187.99:44593    device product:p3quew model:SM_G998U1 device:p3q transport_id:1\n"
            "emulator-5554          device product:sdk_gphone64_arm64 model:sdk_gphone64_arm64\n"
        )
        devices = self.mod.parse_devices(text)
        self.assertEqual("SM_G998U1", devices[0]["details"]["model"])
        self.assertEqual("device", devices[0]["state"])
        self.assertEqual("emulator-5554", devices[1]["serial"])

    def test_identity_keeps_spaces_and_drops_null(self):
        identity = self.mod.parse_identity(
            "manufacturer=samsung\nmodel=SM-G998U1\ndevice_name=BOBAK's S21 Ultra\nserialno=null\n"
        )
        self.assertEqual("BOBAK's S21 Ultra", identity["device_name"])
        self.assertNotIn("serialno", identity)

    def test_nosdcard_is_not_a_form_factor(self):
        self.assertEqual("", self.mod.form_factor("nosdcard"))
        self.assertEqual("phone", self.mod.form_factor("phone"))
        description = self.mod.describe_device(
            "BOBAK's S21 Ultra", "samsung", "SM-G998U1", "", "15", "35", "arm64-v8a"
        )
        self.assertEqual(
            "BOBAK's S21 Ultra — samsung SM-G998U1 (Android 15, API 35, arm64-v8a)",
            description,
        )
        phone = self.mod.describe_device(
            "BOBAK's S25 Ultra", "samsung", "SM-S938U1", "phone", "16", "36.1", "arm64-v8a"
        )
        self.assertIn("(phone, Android 16, API 36.1, arm64-v8a)", phone)


class FleetTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.mod = load_module()

    def setUp(self):
        self.services = self.mod.dedupe_services(self.mod.parse_proto_text(PROTO))
        self.devices = self.mod.parse_devices(
            "List of devices attached\n"
            "100.77.187.99:44593    device product:p3quew model:SM_G998U1 device:p3q transport_id:1\n"
            "192.168.1.223:38103    device product:pa3quew model:SM_S938U1 device:pa3q transport_id:2\n"
        )
        self.identities = {
            "100.77.187.99:44593": {
                "manufacturer": "samsung",
                "model": "SM-G998U1",
                "device": "p3q",
                "characteristics": "nosdcard",
                "release": "15",
                "sdk": "35",
                "abi": "arm64-v8a",
                "serialno": "R5CR71NJ2AF",
                "device_name": "BOBAK's S21 Ultra",
            },
            "192.168.1.223:38103": {
                "manufacturer": "samsung",
                "model": "SM-S938U1",
                "device": "pa3q",
                "characteristics": "phone",
                "release": "16",
                "sdk": "36",
                "sdk_full": "36.1",
                "abi": "arm64-v8a",
                "serialno": "R5CY13WRJXH",
                "device_name": "BOBAK's S25 Ultra",
            },
        }

    def test_existing_cgnat_session_is_not_connected_again(self):
        targets = self.mod.connect_targets(self.services, self.devices, self.identities)
        self.assertEqual([], targets)
        # Same conclusion from model+port when getprop has not run yet.
        targets = self.mod.connect_targets(self.services, self.devices, {})
        self.assertEqual([], [self.mod.endpoint_of(item) for item in targets])

    def test_fleet_dedupes_to_two_descriptions(self):
        fleet = self.mod.assemble_fleet(
            self.services, self.devices, self.identities, limit=None, match=None
        )
        self.assertEqual(
            [
                "BOBAK's S21 Ultra — samsung SM-G998U1 (Android 15, API 35, arm64-v8a)",
                "BOBAK's S25 Ultra — samsung SM-S938U1 (phone, Android 16, API 36.1, arm64-v8a)",
            ],
            [item["description"] for item in fleet["selected"]],
        )
        by_model = {item["model"]: item for item in fleet["selected"]}
        self.assertEqual("100.77.187.99:44593", by_model["SM-G998U1"]["adb_serial"])
        self.assertEqual("192.168.1.224:44593", by_model["SM-G998U1"]["mdns_endpoint"])
        self.assertEqual("", by_model["SM-G998U1"]["form_factor"])
        self.assertEqual("phone", by_model["SM-S938U1"]["form_factor"])
        self.assertEqual("192.168.1.223:38103", by_model["SM-S938U1"]["adb_serial"])
        notes = self.mod.fleet_notes(fleet["selected"])
        self.assertTrue(any("192.168.1.224:44593" in note for note in notes))

    def test_limit_and_match(self):
        limited = self.mod.assemble_fleet(
            self.services, self.devices, self.identities, limit=1, match=None
        )
        self.assertEqual(1, len(limited["selected"]))
        self.assertEqual("over-limit", limited["excluded"][0]["reason"])
        matched = self.mod.assemble_fleet(
            self.services, self.devices, self.identities, limit=None, match="S25"
        )
        self.assertEqual(["SM-S938U1"], [item["model"] for item in matched["selected"]])
        self.assertEqual("match-miss", matched["excluded"][0]["reason"])

    def test_new_tls_device_is_a_connect_target_and_legacy_loses(self):
        services = [
            {
                "instance": "adb-NEWDEVICE-Ab12Cd",
                "service": "_adb-tls-connect._tcp",
                "ipv4": "192.168.1.50",
                "port": 40001,
                "product_model": "Pixel 8",
            },
            {
                "instance": "adb-NEWDEVICE",
                "service": "_adb._tcp",
                "ipv4": "192.168.1.50",
                "port": 5555,
            },
        ]
        targets = self.mod.connect_targets(services, [], {})
        self.assertEqual(["192.168.1.50:40001"], [self.mod.endpoint_of(item) for item in targets])

    def test_pairing_code_and_qr_are_classified(self):
        services = self.mod.parse_services_table(TABLE) + [
            {
                "instance": "studio-58m7E2fq4",
                "service": "_adb-tls-pairing._tcp",
                "ipv4": "192.168.1.80",
                "port": 42111,
            }
        ]
        requests = self.mod.pairing_requests(services, [], {})
        by_ip = {item["endpoint"]: item["method"] for item in requests}
        self.assertEqual("code", by_ip["192.168.86.38:33861"])
        self.assertEqual("qr", by_ip["192.168.1.80:42111"])
        self.assertNotIn("192.168.1.224:44593", by_ip)

    def test_lan_transport_wins_when_both_routes_are_already_up(self):
        devices = self.devices + self.mod.parse_devices(
            "192.168.1.224:44593    device product:p3quew model:SM_G998U1 device:p3q transport_id:3\n"
        )
        identities = dict(self.identities)
        identities["192.168.1.224:44593"] = self.identities["100.77.187.99:44593"]
        fleet = self.mod.assemble_fleet(
            self.services, devices, identities, limit=None, match=None
        )
        s21 = next(item for item in fleet["selected"] if item["model"] == "SM-G998U1")
        self.assertEqual("192.168.1.224:44593", s21["adb_serial"])
        self.assertIn("100.77.187.99:44593", s21["aliases"])

    def test_redact_pairing_code(self):
        self.assertEqual(
            "Successfully paired to 192.168.1.20:37123",
            self.mod.redact("Successfully paired to 192.168.1.20:37123", "515109"),
        )
        self.assertNotIn("515109", self.mod.redact("bad code 515109", "515109"))


if __name__ == "__main__":
    unittest.main()
