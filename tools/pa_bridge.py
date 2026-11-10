#!/usr/bin/env python3
"""Fork addition: the widget's read-only bridge to the /pa skill (lib/pa.ps1 runs it).

    python -I pa_bridge.py <pa tools dir> today       today's schedule as JSON
    python -I pa_bridge.py <pa tools dir> links       the PA widget's quick links as JSON (id, label, kind, area)
    python -I pa_bridge.py <pa tools dir> open <id>   open one quick link the way the PA widget does

Everything is read through /pa's own modules (due, areas, schedule), so the widget shows what the PA widget
shows. Nothing of /pa's is written here. A page link needs the PA widget's local server: it is started if it is
not running (open_widget.py --no-browser), and its access key goes only to the browser, never to stdout.
"""
from __future__ import annotations

import json
import subprocess
import sys
import webbrowser
from datetime import date
from pathlib import Path
from urllib.parse import quote


def fail(msg: str) -> int:
    print(msg)
    return 1


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    if len(sys.argv) < 3:
        return fail(__doc__.strip().splitlines()[0])
    tools, cmd = Path(sys.argv[1]), sys.argv[2]
    if not (tools / "due.py").is_file():
        return fail(f"/pa tools not found in {tools}")
    sys.path.insert(0, str(tools))
    import areas as AR  # noqa: E402
    import due  # noqa: E402

    cfg, _ = due.load_config(None)
    root = due.resolve_root(None, cfg)
    if not root:
        return fail("no data_root in the /pa skill's config.json")
    cfg = due.settings(root, cfg)

    if cmd == "today":
        out = {"assistant": cfg.get("assistant_name") or "the assistant", "date": date.today().isoformat(),
               "weekday": "", "week_kind": None, "phases": [], "all_day": [], "blocks": [], "none": False}
        if not cfg.get("schedule_file"):
            out["none"] = True
        else:
            import schedule as sch  # noqa: E402
            d = sch.day(sch.load(root / cfg["schedule_file"]), date.today())
            keep = ("start", "end", "title", "short", "label", "color", "fixed", "location")
            out.update(weekday=d["weekday"], week_kind=d["week_kind"],
                       phases=[str(p.get("label", "")) for p in d["phases"]],
                       all_day=[str(e.get("title", "")) for e in d["all_day"]],
                       blocks=[{k: b.get(k) for k in keep} for b in d["blocks"]])
        print(json.dumps(out, ensure_ascii=False))
        return 0

    links, _ = AR.links(AR.area_dirs(root, cfg)[0], root, cfg)
    if cmd == "links":
        print(json.dumps([{k: l[k] for k in ("id", "label", "kind", "area")} for l in links], ensure_ascii=False))
        return 0

    if cmd == "open":
        if len(sys.argv) < 4:
            return fail("open needs a link id")
        link = next((l for l in links if l["id"] == sys.argv[3]), None)
        if not link:
            return fail(f"no quick link {sys.argv[3]!r} any more")
        if link["kind"] == "url":
            url = link["href"]
        elif link["kind"] == "doc":
            url = Path(link["path"]).resolve().as_uri()   # a local file: no server needed
        else:
            # An area page is served by the PA widget's server, with its key.
            subprocess.run([sys.executable, "-I", str(tools / "open_widget.py"), "--no-browser"],
                           capture_output=True, timeout=30)
            key = (root / cfg.get("widget_dir", "_widget") / "key").read_text(encoding="utf-8").strip()
            url = f"http://127.0.0.1:{int(cfg.get('widget_port', 8765))}{link['href']}?k={quote(key)}"
        if not webbrowser.open(url):
            return fail("no browser to open it with")
        print(f"opened {link['label']}")
        return 0

    return fail(f"unknown command {cmd!r}")


if __name__ == "__main__":
    sys.exit(main())
