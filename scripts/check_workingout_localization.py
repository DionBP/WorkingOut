#!/usr/bin/env python3
"""Check Phase 2 UI and catalog identifiers against the checked-in String Catalog."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "iOS" / "PadelApp"
TRAINING = APP / "Views" / "Training"

catalog = json.loads((APP / "WorkingOut.xcstrings").read_text(encoding="utf-8"))["strings"]
keys = set()
for path in [*TRAINING.glob("*.swift"), APP / "Views" / "RootTabView.swift", APP / "Health" / "TrainingStore.swift"]:
    source = path.read_text(encoding="utf-8")
    keys.update(re.findall(r'\b(?:text|action|filter)\("([A-Za-z0-9]+)"', source))
    keys.update(re.findall(r'issue = "([A-Za-z0-9]+)"', source))
    if path.name in {"WorkingOutLanguage.swift", "ImportedExercises.swift"}:
        continue
    for pair in re.findall(r'\? "([A-Za-z0-9]+)" : "([A-Za-z0-9]+)"', source):
        keys.update(pair)

definition = re.compile(
    r'\.init\(id: "([^"]+)", primary: "([^"]+)", secondary: "([^"]+)", equipment: "([^"]+)", movement: "([^"]+)"'
)
exercises = definition.findall((TRAINING / "ExerciseCatalog.swift").read_text(encoding="utf-8"))
exercise_ids = {exercise[0] for exercise in exercises}
assert len(exercise_ids) >= 100 and len(exercise_ids) == len(exercises), "Invalid exercise identifiers"
for exercise, primary, secondary, equipment, movement in exercises:
    keys.update({f"exercise.{exercise}", f"muscle.{primary}", f"equipment.{equipment}", f"movement.{movement}"})
    if secondary != "none":
        keys.add(f"muscle.{secondary}")

template_source = (TRAINING / "ProgramViews.swift").read_text(encoding="utf-8")
for name, members in re.findall(r'\("([^"]+)", \[([^]]+)\]\)', template_source):
    keys.add(f"program.{name}")
    assert set(re.findall(r'"([^"]+)"', members)) <= exercise_ids, f"Invalid template: {name}"

keys.update(f"language.{key}" for key in ["system", "da", "en"])
keys.update(f"appearance.{key}" for key in ["system", "light", "dark"])
keys.update(f"weekday.{day}" for day in range(1, 8))
keys.update(f"range.{day}" for day in [-1, 0, 7, 30, 90, 365])
assert keys <= catalog.keys(), f"Missing keys: {', '.join(sorted(keys - catalog.keys()))}"

def check_translations(strings, label):
    for key, entry in strings.items():
        for language in ["en", "da"]:
            unit = entry.get("localizations", {}).get(language, {}).get("stringUnit", {})
            assert unit.get("state") == "translated" and unit.get("value", "").strip(), f"{label}: {key} ({language})"

check_translations(catalog, "WorkingOut")
for path in [APP / "InfoPlist.xcstrings", ROOT / "WatchApp/PadelWatch/InfoPlist.xcstrings"]:
    check_translations(json.loads(path.read_text(encoding="utf-8"))["strings"], path)
print(f"Checked {len(catalog)} bilingual strings and {len(exercise_ids)} exercise IDs.")
