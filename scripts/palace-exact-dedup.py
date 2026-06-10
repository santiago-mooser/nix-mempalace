"""Remove exact-duplicate drawers from a MemPalace ChromaDB palace.

Claude Code writes a new transcript file on every resume/compaction, each
containing the full prior history. The convo miner keys drawer IDs on
(source_file, chunk_index), so every re-mined lineage files the same
exchanges again under new IDs. This script collapses exact document-text
duplicates among miner-added drawers, keeping the closet-referenced copy
when one exists, else the earliest filed_at.

Stop all mempalace MCP servers before running with --apply.

Usage:
    nix develop ~/repos/nix-mempalace --command \
        python3 scripts/palace-exact-dedup.py [--apply] [--cull-tiny N]
"""

import argparse
import re
from collections import defaultdict

import chromadb

MINER = "mempalace"
BATCH = 500


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--palace", default="/home/santiago/.mempalace/palace")
    ap.add_argument("--apply", action="store_true", help="delete (default: dry run)")
    ap.add_argument(
        "--cull-tiny",
        type=int,
        default=0,
        metavar="N",
        help="also delete miner-added convo drawers shorter than N chars",
    )
    args = ap.parse_args()

    client = chromadb.PersistentClient(path=args.palace)
    drawers = client.get_collection("mempalace_drawers")
    closets = client.get_collection("mempalace_closets")

    closet_refs = set()
    for doc in closets.get(include=["documents"])["documents"]:
        closet_refs.update(re.findall(r"drawer_[^\s,|]+", doc or ""))

    data = drawers.get(include=["documents", "metadatas"])
    ids, docs, metas = data["ids"], data["documents"], data["metadatas"]
    print(f"drawers={len(ids)} closet-referenced={len(closet_refs)}")

    def deletable(i):
        return metas[i].get("added_by") == MINER

    groups = defaultdict(list)
    for i, d in enumerate(docs):
        if d:
            groups[d].append(i)

    deletes = []
    for idxs in groups.values():
        if len(idxs) < 2:
            continue
        protected = [i for i in idxs if not deletable(i)]
        candidates = [i for i in idxs if deletable(i)]
        if not candidates:
            continue
        if protected:
            deletes.extend(ids[i] for i in candidates)
            continue
        candidates.sort(
            key=lambda i: (
                ids[i] not in closet_refs,
                metas[i].get("filed_at") or "9999",
                ids[i],
            )
        )
        deletes.extend(ids[i] for i in candidates[1:])
    print(f"duplicate copies: {len(deletes)}")

    if args.cull_tiny:
        dead = set(deletes)
        tiny = [
            ids[i]
            for i, d in enumerate(docs)
            if ids[i] not in dead
            and deletable(i)
            and metas[i].get("ingest_mode") == "convos"
            and d is not None
            and len(d) < args.cull_tiny
            and ids[i] not in closet_refs
        ]
        print(f"tiny fragments (<{args.cull_tiny} chars): {len(tiny)}")
        deletes.extend(tiny)

    print(f"total to delete: {len(deletes)}  remaining: {len(ids) - len(deletes)}")
    if not args.apply:
        print("DRY RUN — pass --apply to delete.")
        return
    for s in range(0, len(deletes), BATCH):
        drawers.delete(ids=deletes[s : s + BATCH])
    print(f"done; drawers now: {drawers.count()}")


if __name__ == "__main__":
    main()
