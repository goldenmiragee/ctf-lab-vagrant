#!/usr/bin/env python3
"""generate.py -- build public/private flag artifacts from the master source.

Reads flags_source.py (private) or falls back to flags_source.example.py so a
fresh clone still builds a working lab. Produces:

  scoreboard/flags.json   PUBLIC  -> questions, hints, categories, SHA-256 hashes
  answers-key.md          PRIVATE -> human-readable plaintext answer key (gitignored)
  provision/flags.env     PRIVATE -> FLAG_<ID>="value" for planted flags (gitignored)

Answers are compared case-sensitively after trimming surrounding whitespace, so
the hash is sha256(answer.strip()). Keep that identical in scoreboard/app.js.

Usage:  python generate.py
Stdlib only. No third-party deps.
"""
import hashlib
import json
import os
import sys
from datetime import datetime, timezone

HERE = os.path.dirname(os.path.abspath(__file__))


def load_source():
    """Prefer the private master; fall back to the committed example template."""
    sys.path.insert(0, HERE)
    try:
        import flags_source as src  # type: ignore
        origin = "flags_source.py"
    except ModuleNotFoundError:
        try:
            import flags_source_example as src  # not the real name; handled below
        except ModuleNotFoundError:
            src = None
        origin = None
    if origin is None:
        # example file is named flags_source.example.py (not importable directly)
        example = os.path.join(HERE, "flags_source.example.py")
        if not os.path.exists(example):
            sys.exit("ERROR: neither flags_source.py nor flags_source.example.py found.")
        ns = {}
        with open(example, "r", encoding="utf-8") as fh:
            exec(compile(fh.read(), example, "exec"), ns)  # noqa: S102 (trusted local file)
        return ns["FLAGS"], "flags_source.example.py (fallback)"
    return src.FLAGS, origin


def sha256(text: str) -> str:
    return hashlib.sha256(text.strip().encode("utf-8")).hexdigest()


def main() -> int:
    flags, origin = load_source()
    print(f"[generate] source: {origin}  ({len(flags)} flags)")

    # ---- validation --------------------------------------------------------
    ids = [f["id"] for f in flags]
    if len(set(ids)) != len(ids):
        sys.exit("ERROR: duplicate flag ids present.")
    for f in flags:
        for key in ("id", "machine", "level", "category", "question", "answer", "planted"):
            if key not in f:
                sys.exit(f"ERROR: flag {f.get('id','?')} missing field '{key}'")
        if f["level"] not in ("basic", "medium", "hard"):
            sys.exit(f"ERROR: flag {f['id']} has bad level '{f['level']}'")
        if f["planted"] and not f.get("plant_path"):
            sys.exit(f"ERROR: planted flag {f['id']} has no plant_path")

    # machine order as first-seen in the source (drives tab order)
    machines = []
    for f in flags:
        if f["machine"] not in machines:
            machines.append(f["machine"])

    # ---- public flags.json (NO plaintext answers) --------------------------
    public = {
        "generated_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "count": len(flags),
        "machines": machines,
        "levels": ["basic", "medium", "hard"],
        "flags": [
            {
                "id": f["id"],
                "machine": f["machine"],
                "level": f["level"],
                "category": f["category"],
                "question": f["question"],
                "hint": f.get("hint", ""),
                "answer_sha256": sha256(f["answer"]),
            }
            for f in flags
        ],
    }
    out_json = os.path.join(HERE, "scoreboard", "flags.json")
    with open(out_json, "w", encoding="utf-8") as fh:
        json.dump(public, fh, indent=2)
        fh.write("\n")
    print(f"[generate] wrote {out_json}")

    # guard: the public file must expose ONLY the hash, never a plaintext answer.
    # (A naive "is the answer a substring of the JSON" check gives false positives,
    #  because short answers like "GET"/"root" legitimately appear in question text.)
    for pf in public["flags"]:
        if "answer" in pf or "plant_path" in pf:
            sys.exit(f"ERROR: public flag {pf['id']} leaks a plaintext/location field")
        h = pf["answer_sha256"]
        if len(h) != 64 or any(c not in "0123456789abcdef" for c in h):
            sys.exit(f"ERROR: flag {pf['id']} has malformed answer_sha256")

    # ---- private answers-key.md -------------------------------------------
    lines = [
        "# Answer Key (PRIVATE -- gitignored, never commit)",
        "",
        f"_Generated {public['generated_at']} from {origin}._",
        "",
        "> This file contains PLAINTEXT flags/answers and solution mechanics.",
        "> It exists so you can grade yourself and rebuild the lab. Do not commit it.",
        "",
    ]
    for m in machines:
        lines.append(f"## {m}")
        lines.append("")
        for lvl in ("basic", "medium", "hard"):
            group = [f for f in flags if f["machine"] == m and f["level"] == lvl]
            if not group:
                continue
            lines.append(f"### {lvl.capitalize()}")
            lines.append("")
            for f in group:
                lines.append(f"- **{f['id']}** ({f['category']})")
                lines.append(f"  - Q: {f['question']}")
                lines.append(f"  - Answer: `{f['answer']}`")
                if f["planted"]:
                    lines.append(f"  - Planted at: `{f['plant_path']}`")
                lines.append(f"  - Fix: {f['remediation']}")
            lines.append("")
    out_key = os.path.join(HERE, "answers-key.md")
    with open(out_key, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines))
    print(f"[generate] wrote {out_key}")

    # ---- private provision/flags.env (planted flags only) ------------------
    env_lines = [
        "# flags.env -- PRIVATE (gitignored). Sourced by provision/*.sh to plant flags.",
        "# Auto-generated by generate.py. Do not edit by hand; do not commit.",
        "",
    ]
    for f in flags:
        if f["planted"]:
            val = f["answer"].replace('"', '\\"')
            env_lines.append(f'export FLAG_{f["id"]}="{val}"')
    out_env = os.path.join(HERE, "provision", "flags.env")
    with open(out_env, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(env_lines) + "\n")
    print(f"[generate] wrote {out_env}")

    print("[generate] done.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
