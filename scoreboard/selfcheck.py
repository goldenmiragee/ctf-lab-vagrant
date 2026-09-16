#!/usr/bin/env python3
"""scoreboard/selfcheck.py -- integrity check for the flag pipeline.

The one runnable check behind the lab's non-trivial logic. Run:

    python scoreboard/selfcheck.py

It verifies the PUBLIC artifact (scoreboard/flags.json) is well-formed and, when
the private sources are present, that the whole generate.py pipeline is
consistent (hashes match answers; every planted flag has a value in flags.env).

Exit code 0 = all good; non-zero = a problem worth fixing before committing.
Stdlib only.
"""
import hashlib
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
FLAGS_JSON = os.path.join(HERE, "flags.json")

EXPECTED_TOTAL = 90
EXPECTED_PER_LEVEL = {"basic": 30, "medium": 30, "hard": 30}
HEX64 = re.compile(r"^[0-9a-f]{64}$")


def sha256(text: str) -> str:
    return hashlib.sha256(text.strip().encode("utf-8")).hexdigest()


def check(cond, msg, errors):
    if not cond:
        errors.append(msg)


def main() -> int:
    errors = []

    # ---- public flags.json ------------------------------------------------
    if not os.path.exists(FLAGS_JSON):
        print(f"FAIL: {FLAGS_JSON} missing — run 'python generate.py'.")
        return 1
    with open(FLAGS_JSON, encoding="utf-8") as fh:
        data = json.load(fh)

    flags = data.get("flags", [])
    check(data.get("count") == len(flags), "count field != number of flags", errors)
    check(len(flags) == EXPECTED_TOTAL, f"expected {EXPECTED_TOTAL} flags, got {len(flags)}", errors)

    per_level = {}
    ids = []
    for f in flags:
        ids.append(f.get("id"))
        per_level[f["level"]] = per_level.get(f["level"], 0) + 1
        # no plaintext / location leaked into the public file
        check("answer" not in f, f"{f.get('id')}: leaks 'answer'", errors)
        check("plant_path" not in f, f"{f.get('id')}: leaks 'plant_path'", errors)
        # valid hash
        check(bool(HEX64.match(f.get("answer_sha256", ""))),
              f"{f.get('id')}: malformed answer_sha256", errors)
        # required display fields
        for k in ("id", "machine", "level", "category", "question"):
            check(k in f and f[k] != "", f"{f.get('id')}: missing '{k}'", errors)

    check(len(set(ids)) == len(ids), "duplicate flag ids in flags.json", errors)
    for lvl, want in EXPECTED_PER_LEVEL.items():
        check(per_level.get(lvl) == want,
              f"level '{lvl}': expected {want}, got {per_level.get(lvl)}", errors)

    # machines list must cover exactly the machines used by flags
    used = {f["machine"] for f in flags}
    check(set(data.get("machines", [])) == used,
          "machines list does not match machines used by flags", errors)

    # ---- private cross-check (only if sources are present) ----------------
    src_path = os.path.join(ROOT, "flags_source.py")
    did_crosscheck = False
    if os.path.exists(src_path):
        did_crosscheck = True
        sys.path.insert(0, ROOT)
        import flags_source as src  # type: ignore
        src_by_id = {f["id"]: f for f in src.FLAGS}
        pub_by_id = {f["id"]: f for f in flags}
        check(set(src_by_id) == set(pub_by_id),
              "id mismatch between flags_source.py and flags.json (re-run generate.py)", errors)
        for fid, sf in src_by_id.items():
            pf = pub_by_id.get(fid)
            if pf:
                check(sha256(sf["answer"]) == pf["answer_sha256"],
                      f"{fid}: hash in flags.json != sha256(answer) (re-run generate.py)", errors)

        # every planted flag must have a value in flags.env
        env_path = os.path.join(ROOT, "provision", "flags.env")
        if os.path.exists(env_path):
            env_txt = open(env_path, encoding="utf-8").read()
            for f in src.FLAGS:
                if f.get("planted"):
                    check(f"FLAG_{f['id']}=" in env_txt,
                          f"{f['id']}: planted but missing from provision/flags.env", errors)
        else:
            print("note: provision/flags.env absent — run generate.py to plant flags on the VMs.")

    # ---- report -----------------------------------------------------------
    if errors:
        print(f"FAIL: {len(errors)} problem(s):")
        for e in errors:
            print(f"  - {e}")
        return 1

    scope = "public + private pipeline" if did_crosscheck else "public flags.json"
    print(f"OK: {len(flags)} flags, {EXPECTED_PER_LEVEL} per level, "
          f"{len(used)} machines. Verified {scope}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
