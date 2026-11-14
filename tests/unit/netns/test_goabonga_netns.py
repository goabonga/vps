# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>
# ruff: noqa: S603, S607
# The commands are fixed strings of this file, run in a sandbox.
"""Run the real helper against real namespaces, in a throw-away sandbox.

``unshare -rmn`` gives the test a user, a mount and a network namespace of its
own, in which it is root: the namespaces and the veth pairs it creates exist
nowhere else and vanish with the sandbox, so no privilege is needed. The tests
are skipped where the system does not allow that.
"""

import base64
import json
import os
import shutil
import subprocess
from pathlib import Path

import pytest

HELPER = Path(__file__).resolve().parents[3] / "roles" / "netns" / "files" / "goabonga-netns"
SEPARATOR = "@@@"


def sandbox_available() -> bool:
    if shutil.which("unshare") is None or shutil.which("ip") is None:
        return False
    probe = subprocess.run(
        [
            "unshare",
            "-rmn",
            "sh",
            "-c",
            "mount -t tmpfs tmpfs /run && ip link add t0 type veth peer name t1",
        ],
        capture_output=True,
        check=False,
    )
    return probe.returncode == 0


# Where the sandbox is not available the tests are skipped, which would look like a
# success: a pipeline that needs them sets NETNS_REQUIRE_SANDBOX=1, and they then
# run and fail loudly instead.
REQUIRED = os.environ.get("NETNS_REQUIRE_SANDBOX") == "1"

pytestmark = pytest.mark.skipif(
    not REQUIRED and not sandbox_available(),
    reason="unprivileged namespaces are not available",
)


def test_the_sandbox_is_available_when_it_is_required() -> None:
    if REQUIRED:
        assert sandbox_available(), "unprivileged namespaces are required and not available"


def sandbox(*steps: str) -> list[dict]:
    """Run the steps, in order, in one sandbox; return the output and the exit code of each."""
    script = "mount -t tmpfs tmpfs /run && mkdir -p /run/netns\n"
    for step in steps:
        script += f'{{ {step} ; }} 2>&1; echo "{SEPARATOR}$?"\n'
    result = subprocess.run(
        ["unshare", "-rmn", "bash", "-c", script], capture_output=True, text=True, check=False
    )
    assert result.returncode == 0, result.stderr
    outputs = []
    parts = result.stdout.split(SEPARATOR)
    # parts = output1, "code1\noutput2", "code2\noutput3", ..., "codeN\n"
    output = parts[0]
    for part in parts[1:]:
        code, _, rest = part.partition("\n")
        outputs.append({"output": output.strip(), "code": int(code)})
        output = rest
    return outputs


def write(path: Path, document: dict) -> str:
    """A step that replaces a description inside the sandbox."""
    encoded = base64.b64encode(json.dumps(document).encode()).decode()
    return f"echo {encoded} | base64 -d > {path}"


def config(tmp_path: Path, name: str = "svc", **overrides) -> Path:
    document = {
        "name": name,
        "loopback": True,
        "sysctl": {},
        "interfaces": [
            {
                "name": "eth0",
                "host_name": f"veth-{name}",
                "mtu": None,
                "addresses": ["10.200.1.2/30"],
                "host_addresses": ["10.200.1.1/30"],
                "routes": [{"to": "default", "via": "10.200.1.1"}],
            }
        ],
    }
    document.update(overrides)
    path = tmp_path / f"{name}.json"
    path.write_text(json.dumps(document), encoding="utf-8")
    return path


def helper(command: str, path: Path, *flags: str) -> str:
    return f"python3 {HELPER} {command} {path} {' '.join(flags)}"


def actions(step: dict) -> list[str]:
    return json.loads(step["output"])["actions"]


def test_apply_builds_the_namespace(tmp_path: Path) -> None:
    path = config(tmp_path)
    applied, host, inside, routes, verdict = sandbox(
        helper("apply", path),
        "ip -j addr show dev veth-svc",
        "ip -j -n svc addr show dev eth0",
        "ip -n svc route show",
        helper("check", path),
    )
    assert applied["code"] == 0
    assert "create the namespace svc" in actions(applied)
    assert "10.200.1.1" in host["output"]
    assert "10.200.1.2" in inside["output"]
    assert "default via 10.200.1.1 dev eth0" in routes["output"]
    assert json.loads(verdict["output"]) == {"ok": True, "problems": []}


def test_loopback_is_up(tmp_path: Path) -> None:
    path = config(tmp_path)
    _, loopback = sandbox(helper("apply", path), "ip -j -n svc link show dev lo")
    assert "UP" in json.loads(loopback["output"])[0]["flags"]


def test_second_apply_changes_nothing(tmp_path: Path) -> None:
    path = config(tmp_path)
    _, again = sandbox(helper("apply", path), helper("apply", path))
    assert again["code"] == 0
    assert actions(again) == []


def test_dry_run_reports_without_changing(tmp_path: Path) -> None:
    path = config(tmp_path)
    planned, namespaces = sandbox(helper("apply", path, "--dry-run"), "ip netns list")
    assert "create the namespace svc" in actions(planned)
    assert namespaces["output"] == ""


def test_a_changed_address_and_mtu_are_applied(tmp_path: Path) -> None:
    path = config(tmp_path)
    changed = json.loads(path.read_text())
    changed["interfaces"] = [
        {
            "name": "eth0",
            "host_name": "veth-svc",
            "mtu": 1400,
            "addresses": ["10.200.9.2/30"],
            "host_addresses": ["10.200.9.1/30"],
            "routes": [{"to": "default", "via": "10.200.9.1"}],
        }
    ]
    _, _, moved, inside, mtu, routes, settled = sandbox(
        helper("apply", path),
        write(path, changed),
        helper("apply", path),
        "ip -j -n svc addr show dev eth0",
        "ip -j -n svc link show dev eth0",
        "ip -n svc route show",
        helper("apply", path),
    )
    assert any("remove 10.200.1.2/30" in action for action in actions(moved))
    assert "10.200.9.2" in inside["output"] and "10.200.1.2" not in inside["output"]
    assert json.loads(mtu["output"])[0]["mtu"] == 1400
    assert "default via 10.200.9.1" in routes["output"]
    assert actions(settled) == []


def test_ipv6_addresses_and_routes(tmp_path: Path) -> None:
    path = config(
        tmp_path,
        interfaces=[
            {
                "name": "eth0",
                "host_name": "veth-svc",
                "addresses": ["fd00:200:1::2/64"],
                "host_addresses": ["fd00:200:1::1/64"],
                "routes": [{"to": "default", "via": "fd00:200:1::1"}],
            }
        ],
    )
    _, inside, routes, again = sandbox(
        helper("apply", path),
        "ip -j -n svc addr show dev eth0",
        "ip -6 -n svc route show",
        helper("apply", path),
    )
    assert "fd00:200:1::2" in inside["output"]
    assert "default via fd00:200:1::1" in routes["output"]
    assert actions(again) == []


def test_several_namespaces_and_interfaces(tmp_path: Path) -> None:
    one = config(tmp_path, "one")
    two = config(
        tmp_path,
        "two",
        interfaces=[
            {
                "name": "eth0",
                "host_name": "veth-two-a",
                "addresses": ["10.200.2.2/30"],
                "host_addresses": ["10.200.2.1/30"],
                "routes": [],
            },
            {
                "name": "eth1",
                "host_name": "veth-two-b",
                "addresses": ["10.200.3.2/30"],
                "host_addresses": ["10.200.3.1/30"],
                "routes": [],
            },
        ],
    )
    *_, listing, links = sandbox(
        helper("apply", one), helper("apply", two), "ip netns list", "ip -j -n two link show"
    )
    assert "one" in listing["output"] and "two" in listing["output"]
    assert {"eth0", "eth1", "lo"} <= {link["ifname"] for link in json.loads(links["output"])}


def test_extra_routes_are_installed_and_removed(tmp_path: Path) -> None:
    path = config(tmp_path)
    document = json.loads(path.read_text())
    document["interfaces"][0]["routes"] = [
        {"to": "10.50.0.0/16", "via": "10.200.1.1", "metric": 50}
    ]
    path.write_text(json.dumps(document))
    without = json.loads(path.read_text())
    without["interfaces"][0]["routes"] = []
    _, installed, _, _, removed = sandbox(
        helper("apply", path),
        "ip -n svc route show",
        write(path, without),
        helper("apply", path),
        "ip -n svc route show",
    )
    assert "10.50.0.0/16 via 10.200.1.1 dev eth0 metric 50" in installed["output"]
    assert "10.50.0.0/16" not in removed["output"]


def test_sysctl_is_set_inside_the_namespace_only(tmp_path: Path) -> None:
    path = config(tmp_path, sysctl={"net.ipv4.conf.all.arp_ignore": 1})
    _, inside, host, again = sandbox(
        helper("apply", path),
        "ip netns exec svc sysctl -n net.ipv4.conf.all.arp_ignore",
        "sysctl -n net.ipv4.conf.all.arp_ignore",
        helper("apply", path),
    )
    assert inside["output"] == "1"
    assert host["output"] == "0"
    assert actions(again) == []


def test_check_reports_a_drift(tmp_path: Path) -> None:
    path = config(tmp_path)
    _, _, verdict = sandbox(
        helper("apply", path), "ip -n svc addr del 10.200.1.2/30 dev eth0", helper("check", path)
    )
    assert verdict["code"] == 1
    assert any("10.200.1.2/30" in problem for problem in json.loads(verdict["output"])["problems"])


def test_a_foreign_host_interface_is_never_taken(tmp_path: Path) -> None:
    path = config(tmp_path)
    _, refused, namespaces, still_there = sandbox(
        "ip link add veth-svc type veth peer name other",
        helper("apply", path),
        "ip netns list",
        "ip -j link show dev veth-svc",
    )
    assert refused["code"] == 2
    assert "not managed" in refused["output"]
    assert namespaces["output"].split() == ["svc"] or namespaces["output"] == ""
    assert still_there["code"] == 0
    assert "ifalias" not in still_there["output"]


def test_a_foreign_namespace_is_never_taken(tmp_path: Path) -> None:
    path = config(tmp_path)
    _, refused = sandbox("ip netns add svc", helper("apply", path))
    assert refused["code"] == 2
    assert "not created by this program" in refused["output"]


def test_a_removed_interface_is_deleted(tmp_path: Path) -> None:
    path = config(tmp_path)
    document = json.loads(path.read_text())
    document["interfaces"] = []
    _, _, _, remaining = sandbox(
        helper("apply", path),
        write(path, document),
        helper("apply", path),
        "ip -j link show",
    )
    assert "veth-svc" not in remaining["output"]


def test_down_removes_what_it_created(tmp_path: Path) -> None:
    path = config(tmp_path)
    _, removed, namespaces, links = sandbox(
        helper("down", path, "--dry-run") + "; " + helper("apply", path),
        helper("down", path),
        "ip netns list",
        "ip -j link show",
    )
    assert removed["code"] == 0
    assert namespaces["output"] == ""
    assert "veth-svc" not in links["output"]


def test_down_refuses_while_a_process_uses_the_namespace(tmp_path: Path) -> None:
    path = config(tmp_path)
    _, refused, forced, namespaces = sandbox(
        helper("apply", path) + "; ip netns exec svc sleep 60 & sleep 1",
        helper("down", path),
        helper("down", path, "--force"),
        "ip netns list",
    )
    assert refused["code"] == 2
    assert "used by the processes" in refused["output"]
    assert forced["code"] == 0
    assert "svc" not in namespaces["output"].split()


def test_down_does_not_touch_a_namespace_it_did_not_create(tmp_path: Path) -> None:
    path = config(tmp_path)
    _, refused, namespaces = sandbox("ip netns add svc", helper("down", path), "ip netns list")
    assert refused["code"] == 2
    assert "svc" in namespaces["output"]


def test_an_invalid_name_is_refused(tmp_path: Path) -> None:
    path = config(
        tmp_path,
        interfaces=[
            {
                "name": "eth0",
                "host_name": "veth-a-name-too-long",
                "addresses": [],
                "host_addresses": [],
                "routes": [],
            }
        ],
    )
    (refused,) = sandbox(helper("apply", path))
    assert refused["code"] == 2
    assert "15 characters" in refused["output"]


def interface(name: str, host_name: str, address: str, host_address: str, **extra) -> dict:
    return {
        "name": name,
        "host_name": host_name,
        "addresses": [address],
        "host_addresses": [host_address],
        "routes": [],
        **extra,
    }


def validate(*namespaces: dict) -> tuple[int, dict]:
    """Run the pure validation of a set of descriptions, outside of any sandbox."""
    result = subprocess.run(
        [str(HELPER), "validate"],
        input=json.dumps({"namespaces": list(namespaces)}),
        capture_output=True,
        text=True,
        check=False,
    )
    return result.returncode, json.loads(result.stdout or result.stderr)


def namespace(name: str, *interfaces: dict) -> dict:
    return {"name": name, "interfaces": list(interfaces)}


def test_validate_accepts_a_sound_set() -> None:
    code, report = validate(
        namespace("a", interface("eth0", "veth-a", "10.200.1.2/30", "10.200.1.1/30")),
        namespace("b", interface("eth0", "veth-b", "10.200.2.2/30", "10.200.2.1/30")),
    )
    assert code == 0
    assert report == {"ok": True, "problems": []}


@pytest.mark.parametrize(
    ("declared", "expected"),
    [
        (
            [
                namespace("a", interface("eth0", "veth-a", "10.200.1.2/30", "10.200.1.1/30")),
                namespace("b", interface("eth0", "veth-b", "10.200.1.2/30", "10.200.1.1/30")),
            ],
            "overlap",
        ),
        (
            [
                namespace("a", interface("eth0", "veth-x", "10.200.1.2/30", "10.200.1.1/30")),
                namespace("b", interface("eth0", "veth-x", "10.200.2.2/30", "10.200.2.1/30")),
            ],
            "is used by",
        ),
        (
            [
                namespace("a", interface("eth0", "veth-a", "10.200.1.2/30", "10.200.1.1/30")),
                namespace("a", interface("eth0", "veth-b", "10.200.2.2/30", "10.200.2.1/30")),
            ],
            "declared twice",
        ),
        (
            [namespace("a", interface("eth0", "veth-a", "10.200.1.300/30", "10.200.1.1/30"))],
            "invalid address",
        ),
        (
            [
                namespace(
                    "a", interface("eth0", "veth-a-name-too-long", "10.200.1.2/30", "10.200.1.1/30")
                )
            ],
            "15 characters",
        ),
        (
            [
                namespace(
                    "a",
                    interface(
                        "eth0",
                        "veth-a",
                        "10.200.1.2/30",
                        "10.200.1.1/30",
                        routes=[{"to": "default", "via": "10.99.0.1"}],
                    ),
                )
            ],
            "on none of the networks",
        ),
        (
            [
                namespace(
                    "a",
                    interface("eth0", "veth-a", "10.200.1.2/30", "10.200.1.1/30"),
                    interface("eth0", "veth-b", "10.200.2.2/30", "10.200.2.1/30"),
                )
            ],
            "declared twice",
        ),
    ],
)
def test_validate_reports_each_kind_of_mistake(declared: list[dict], expected: str) -> None:
    code, report = validate(*declared)
    assert code == 1
    assert any(expected in problem for problem in report["problems"])


def test_an_address_overlapping_a_network_of_the_host_is_refused(tmp_path: Path) -> None:
    path = config(tmp_path)
    _, refused, links = sandbox(
        "ip link add other type dummy; ip addr add 10.200.1.5/24 dev other; ip link set other up",
        helper("apply", path),
        "ip -j link show",
    )
    assert refused["code"] == 2
    assert "overlaps" in refused["output"]
    assert "veth-svc" not in links["output"]


def test_validate_refuses_two_default_routes_of_the_same_metric() -> None:
    declared = namespace(
        "a",
        interface(
            "eth0",
            "veth-a",
            "10.200.1.2/30",
            "10.200.1.1/30",
            routes=[{"to": "default", "via": "10.200.1.1"}],
        ),
        interface(
            "eth1",
            "veth-b",
            "10.200.2.2/30",
            "10.200.2.1/30",
            routes=[{"to": "default", "via": "10.200.2.1"}],
        ),
    )
    code, report = validate(declared)
    assert code == 1
    assert any("default routes" in problem for problem in report["problems"])


def test_apply_reads_the_description_from_the_standard_input(tmp_path: Path) -> None:
    document = json.loads(config(tmp_path).read_text())
    encoded = base64.b64encode(json.dumps(document).encode()).decode()
    applied, again = sandbox(
        f"echo {encoded} | base64 -d | python3 {HELPER} apply -",
        f"echo {encoded} | base64 -d | python3 {HELPER} apply -",
    )
    assert "create the namespace svc" in actions(applied)
    assert actions(again) == []


def test_down_needs_only_the_name_of_the_namespace(tmp_path: Path) -> None:
    path = config(tmp_path)
    minimal = base64.b64encode(json.dumps({"name": "svc"}).encode()).decode()
    _, removed, namespaces, links = sandbox(
        helper("apply", path),
        f"echo {minimal} | base64 -d | python3 {HELPER} down -",
        "ip netns list",
        "ip -j link show",
    )
    assert removed["code"] == 0
    assert namespaces["output"] == ""
    assert "veth-svc" not in links["output"]
