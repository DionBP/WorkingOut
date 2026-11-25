#!/usr/bin/env python3
"""Build WorkingOut's pinned, offline exercise snapshot from reviewed source inputs."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
INPUT = ROOT / "Data" / "Exercises"
APP = ROOT / "iOS" / "PadelApp"
OUTPUT = APP / "ExerciseData" / "ExerciseSnapshot.json"

MUSCLES = {
    "abdominals": "core", "abductors": "abductors", "adductors": "adductors", "biceps": "biceps",
    "calves": "calves", "chest": "chest", "forearms": "forearms", "glutes": "glutes",
    "hamstrings": "hamstrings", "lats": "back", "lower back": "back", "middle back": "back",
    "neck": "neck", "quadriceps": "quads", "shoulders": "shoulders", "traps": "traps", "triceps": "triceps",
}
EQUIPMENT = {
    None: "other", "bands": "bands", "barbell": "barbell", "body only": "bodyweight", "cable": "cable",
    "dumbbell": "dumbbells", "e-z curl bar": "ezBar", "exercise ball": "exerciseBall", "foam roll": "foamRoll",
    "kettlebells": "kettlebell", "machine": "machine", "medicine ball": "medicineBall", "other": "other",
}


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def validate(snapshot, aliases, translations, media):
    ids = [row["id"] for row in snapshot["exercises"]]
    source_ids = [row["sourceID"] for row in snapshot["exercises"]]
    legacy = set(re.findall(r'\.init\(id: "([^"]+)"', (APP / "Views/Training/ExerciseCatalog.swift").read_text()))
    assert len(ids) == len(set(ids)) == len(set(source_ids)) and len(ids) >= 800
    assert set(aliases) <= set(source_ids) and set(aliases.values()) <= legacy
    assert len(set(aliases.values())) == len(aliases)
    assert set(translations) <= (set(ids) | legacy)
    assert set(media["exercises"]) <= legacy
    assert re.fullmatch(r"[a-f0-9]{40}", media["revision"])
    catalog = read(APP / "WorkingOut.xcstrings")["strings"]
    for row in snapshot["exercises"]:
        assert row["id"] == aliases.get(row["sourceID"], "fedb:" + row["sourceID"])
        assert row["name"] and all(row["instructions"])
        assert row.get("danish") == translations.get(row["id"])
        for muscle in row["primary"] + row["secondary"]:
            assert "muscle." + muscle in catalog
        assert "equipment." + row["equipment"] in catalog
    for entry in translations.values():
        assert entry["name"].strip() and all(step.strip() for step in entry["instructions"]) and entry["instructions"]
    for slug in media["exercises"].values():
        assert re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", slug)
    rows = snapshot["exercises"]
    assert snapshot["media"] == media
    return len([row for row in rows if row.get("danish")]), len(rows)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, help="Use exact upstream JSON bytes from a local file")
    parser.add_argument("--check", action="store_true", help="Check the bundled snapshot without network access")
    args = parser.parse_args()

    source = read(INPUT / "source.json")
    aliases = read(INPUT / "aliases.json")
    translations = read(INPUT / "da.json")
    media = read(INPUT / "media.json")
    revision = source["revision"]
    assert re.fullmatch(r"[a-f0-9]{40}", revision)
    if args.check:
        snapshot = read(OUTPUT)
    else:
        if args.input:
            payload = args.input.read_bytes()
        else:
            url = f"https://raw.githubusercontent.com/yuhonas/free-exercise-db/{revision}/dist/exercises.json"
            with urllib.request.urlopen(url, timeout=30) as response:
                payload = response.read()
        assert hashlib.sha256(payload).hexdigest() == source["sha256"], "Upstream bytes differ from source lock"
        exercises = []
        for row in json.loads(payload):
            source_id = row["id"]
            exercise_id = aliases.get(source_id, "fedb:" + source_id)
            exercises.append({
                "id": exercise_id, "sourceID": source_id, "name": row["name"],
                "instructions": [step.strip() for step in row["instructions"] if step.strip()],
                "primary": sorted({MUSCLES[value] for value in row["primaryMuscles"]}),
                "secondary": sorted({MUSCLES[value] for value in row["secondaryMuscles"]}),
                "equipment": EQUIPMENT[row["equipment"]], "danish": translations.get(exercise_id),
            })
        exercises.sort(key=lambda row: row["id"])
        snapshot = {"schema": 1, "source": source, "exercises": exercises, "media": media}
    assert snapshot["schema"] == 1 and snapshot["source"] == source
    translated, total = validate(snapshot, aliases, translations, media)
    if not args.check:
        OUTPUT.write_text(json.dumps(snapshot, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n", encoding="utf-8")
    print(f"Checked {total} imported exercises. {translated} have exercise-specific Danish translations.")


if __name__ == "__main__":
    main()
