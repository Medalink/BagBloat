#!/usr/bin/env python3
# Generates Bag Bloat's QuestZones.lua: questID -> AreaTable ID of the zone where
# a quest that an item starts is turned in.
#
# Rerun (from the addon repo root; paths are examples):
#   python -I tools/gen_quest_zones.py \
#       --pfquest <dir with pfQuest db/ files: quests.lua units.lua objects.lua enUS_zones.lua> \
#       --itemsparse <ItemSparse.csv from the Forever client> \
#       --areatable <AreaTable.csv from the Forever client> \
#       --out QuestZones.lua [--commit <pfQuest sha>]
#
# --pfquest takes a flat folder holding quests.lua, units.lua, objects.lua and
# enUS_zones.lua (pfQuest's db/enUS/zones.lua); the "db_" prefixed names that a
# flattened download gives are accepted too. Standard library only, deterministic.
# The pfQuest files are parsed as text and never executed.

import argparse
import csv
import os
import re
import sys

csv.field_size_limit(1 << 28)

CLASSIC_MAX = 10000  # quest IDs below this are the classic range


class LuaData:
    """Minimal parser for the data-only Lua tables pfQuest ships."""

    def __init__(self, text):
        self.s = text
        self.i = 0
        self.n = len(text)

    def ws(self):
        s, n = self.s, self.n
        while self.i < n:
            c = s[self.i]
            if c in " \t\r\n":
                self.i += 1
            elif s.startswith("--", self.i):
                j = s.find("\n", self.i)
                self.i = n if j < 0 else j
            else:
                break

    def value(self):
        self.ws()
        c = self.s[self.i]
        if c == "{":
            return self.table()
        if c in "\"'":
            return self.string(c)
        m = NUM.match(self.s, self.i)
        if m:
            self.i = m.end()
            t = m.group(0)
            return float(t) if any(ch in t for ch in ".eE") else int(t)
        m = WORD.match(self.s, self.i)
        if not m:
            raise ValueError("bad token at %d" % self.i)
        self.i = m.end()
        return {"true": True, "false": False, "nil": None}.get(m.group(0), m.group(0))

    def string(self, q):
        s = self.s
        self.i += 1
        out = []
        while s[self.i] != q:
            if s[self.i] == "\\":
                self.i += 1
                out.append(ESC.get(s[self.i], s[self.i]))
            else:
                out.append(s[self.i])
            self.i += 1
        self.i += 1
        return "".join(out)

    def table(self):
        self.i += 1
        d = {}
        pos = 1
        while True:
            self.ws()
            c = self.s[self.i]
            if c == "}":
                self.i += 1
                return d
            if c == ",":
                self.i += 1
                continue
            if c == "[":
                self.i += 1
                k = self.value()
                self.ws()
                if self.s[self.i] != "]":
                    raise ValueError("expected ] at %d" % self.i)
                self.i += 1
                self.ws()
                if self.s[self.i] != "=":
                    raise ValueError("expected = at %d" % self.i)
                self.i += 1
                d[k] = self.value()
            else:
                d[pos] = self.value()
                pos += 1


NUM = re.compile(r"-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?")
WORD = re.compile(r"[A-Za-z_][A-Za-z_0-9]*")
ESC = {"n": "\n", "t": "\t", "r": "\r"}


def load_lua(path):
    """Parse `pfDB["x"]["y"] = { ... }` and return the table."""
    with open(path, "r", encoding="utf-8") as f:
        text = f.read()
    start = text.index("=") + 1
    p = LuaData(text)
    p.i = start
    return p.value()


def find(dirpath, *names):
    for n in names:
        p = os.path.join(dirpath, n)
        if os.path.isfile(p):
            return p
    raise SystemExit("missing pfQuest file, tried: %s in %s" % (", ".join(names), dirpath))


def norm(name):
    return re.sub(r"[^a-z0-9]", "", name.lower())


def top_zone(coords):
    """(zone, spawns in that zone, total spawns) for the zone with the most spawns, lowest id on ties."""
    counts = {}
    for c in coords.values():
        if isinstance(c, dict) and len(c) >= 3 and isinstance(c[3], int) and c[3] > 0:
            counts[c[3]] = counts.get(c[3], 0) + 1
    if not counts:
        return None
    zone = min(counts, key=lambda z: (-counts[z], z))
    return zone, counts[zone], sum(counts.values())


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--pfquest", required=True)
    ap.add_argument("--itemsparse", required=True)
    ap.add_argument("--areatable")
    ap.add_argument("--out", required=True)
    ap.add_argument("--commit", default="104f35678ca39ab1fb78b655f815cc7016f5e0c8")
    ap.add_argument("--report", help="optional path for a tab-separated report of every emitted row")
    a = ap.parse_args()

    quests = load_lua(find(a.pfquest, "quests.lua", "db_quests.lua"))
    units = load_lua(find(a.pfquest, "units.lua", "db_units.lua"))
    objects = load_lua(find(a.pfquest, "objects.lua", "db_objects.lua"))
    zname = load_lua(find(a.pfquest, "enUS_zones.lua", "db_enUS_zones.lua"))

    # item -> quest from the client
    starters = {}  # questID -> [itemIDs]
    names = {}
    with open(a.itemsparse, "r", encoding="utf-8", newline="") as f:
        for row in csv.DictReader(f):
            q = int(row["StartQuestID"] or 0)
            if q > 0:
                it = int(row["ID"])
                starters.setdefault(q, []).append(it)
                names[it] = row["Display_lang"]
    total = len(starters)
    classic = sorted(q for q in starters if q < CLASSIC_MAX)

    # pfQuest "started by item" cross-check
    pf_item_start = {}
    for q, d in quests.items():
        ids = d.get("start", {}).get("I") if isinstance(d.get("start"), dict) else None
        if isinstance(ids, dict):
            pf_item_start[q] = set(ids.values())
    agree = disagree = pf_unknown_start = 0
    for q in classic:
        if q not in quests:
            continue
        s = pf_item_start.get(q)
        if s is None:
            pf_unknown_start += 1
        elif s & set(starters[q]):
            agree += 1
        else:
            disagree += 1
    pf_only = sorted(q for q in pf_item_start if q not in starters)

    area = {}
    if a.areatable:
        with open(a.areatable, "r", encoding="utf-8", newline="") as f:
            for row in csv.DictReader(f):
                area[int(row["ID"])] = row["AreaName_lang"]

    skipped = {"quest unknown to pfQuest": [], "no ender": [], "ender has no spawn": [],
               "ender spawns in several zones": []}
    result = {}
    for q in classic:
        d = quests.get(q)
        if d is None:
            skipped["quest unknown to pfQuest"].append(q)
            continue
        end = d.get("end")
        if not isinstance(end, dict) or not (end.get("U") or end.get("O")):
            skipped["no ender"].append(q)
            continue
        pick = None
        for kind, db in (("U", units), ("O", objects)):
            cands = []
            for eid in (end.get(kind) or {}).values():
                z = top_zone((db.get(eid) or {}).get("coords") or {})
                if z:
                    cands.append((-z[2], eid, z[0], z[1] != z[2]))  # most spawns, then lowest id
            if cands:
                pick = min(cands)
                break
        if pick is None:
            skipped["ender has no spawn"].append(q)
            continue
        # An ender seen in more than one zone travels (the Darkmoon Faire): no single zone is right.
        if pick[3]:
            skipped["ender spawns in several zones"].append(q)
            continue
        result[q] = pick[2]

    # zone ids must name the same place in pfQuest and the Forever AreaTable
    dropped = []
    if a.areatable:
        for q in sorted(result):
            z = result[q]
            if z not in area or norm(area[z]) != norm(zname.get(z, "\0")):
                dropped.append((z, zname.get(z), area.get(z), q))
        bad = {z for z, _, _, _ in dropped}
        for q in [q for q, z in result.items() if z in bad]:
            del result[q]
    else:
        print("no --areatable: zone ids not checked against the client", file=sys.stderr)

    keys = sorted(result)
    entries = ["[%d]=%d" % (q, result[q]) for q in keys]
    lines = []
    cur = "  "
    for e in entries:
        add = e + ","
        if len(cur) + len(add) + 1 > 100 and cur.strip():
            lines.append(cur.rstrip())
            cur = "  "
        cur += add + " "
    if cur.strip():
        lines.append(cur.rstrip())

    out = [
        "-- Generated by tools/gen_quest_zones.py. Do not edit.",
        "-- questID -> AreaTable ID of the zone where the quest is turned in, for quests an item starts.",
        "-- Derived from pfQuest (MIT), commit %s, and the Forever client's ItemSparse." % a.commit,
        "local _, ns = ...",
        "ns.QUEST_AREA = {",
    ] + lines + ["}", ""]
    text = "\n".join(out)
    text.encode("ascii")  # fail loudly on non-ASCII
    with open(a.out, "w", encoding="ascii", newline="\n") as f:
        f.write(text)

    if a.report:
        with open(a.report, "w", encoding="ascii", newline="\n") as f:
            for q in keys:
                for it in sorted(starters[q]):
                    nm = names[it].encode("ascii", "replace").decode("ascii")
                    zn = (area.get(result[q]) or zname.get(result[q], "?")).encode("ascii", "replace").decode("ascii")
                    f.write("%d\t%s\t%d\t%d\t%s\n" % (it, nm, q, result[q], zn))

    print("starter quests in ItemSparse: %d" % total)
    print("in classic range (<%d): %d" % (CLASSIC_MAX, len(classic)))
    print("pfQuest item-start cross-check: %d agree, %d disagree, %d have no item start in pfQuest" % (agree, disagree, pf_unknown_start))
    print("pfQuest item-started quests ItemSparse does not list: %d" % len(pf_only))
    for why, qs in skipped.items():
        print("skipped, %s: %d %s" % (why, len(qs), qs))
    print("dropped zone ids (name mismatch): %d" % len({z for z, _, _, _ in dropped}))
    for z, pn, an, q in dropped:
        print("  zone %d pfQuest=%r client=%r (quest %d)" % (z, pn, an, q))
    print("emitted: %d" % len(result))


if __name__ == "__main__":
    main()
