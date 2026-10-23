#!/usr/bin/env python3
# Print one wrapped row of each window's most-recent OpenCode session title.
# Use display columns rather than byte counts so typographic quotes and other
# Unicode text do not shift the summary rows.

import re
import subprocess
import sys
import unicodedata


session = sys.argv[1]
row = int(sys.argv[2]) if len(sys.argv) > 2 else 1
kind = sys.argv[3] if len(sys.argv) > 3 else "title"
full_width = 21
thin_width = 9


def character_width(character):
    if unicodedata.combining(character) or unicodedata.category(character) == "Cf":
        return 0
    return 2 if unicodedata.east_asian_width(character) in {"F", "W"} else 1


def display_width(text):
    return sum(character_width(character) for character in text)


def trim_to_width(text, maximum):
    result = []
    width = 0
    for character in text:
        character_size = character_width(character)
        if width + character_size > maximum:
            break
        result.append(character)
        width += character_size
    return "".join(result)


def wrapped(text, target, maximum):
    count = 1
    line = ""
    for word in text.split():
        word = trim_to_width(word, maximum)
        if line and display_width(line) + 1 + display_width(word) > maximum:
            if count == target:
                return line
            count += 1
            line = word
        else:
            line = f"{line} {word}" if line else word
    return line if count == target else ""


result = subprocess.run(
    [
        "tmux",
        "list-panes",
        "-s",
        "-t",
        session,
        "-F",
        "#{window_index}|#{window_active}|#{pane_current_command}|#{@opencode_updated_at}|#{@opencode_summary}|#{@opencode_next_step}|#{@opencode_activity}",
    ],
    check=False,
    capture_output=True,
    text=True,
    errors="replace",
)

windows = {}
latest = {}
for line in result.stdout.splitlines():
    fields = line.split("|", 6)
    if len(fields) != 7:
        continue
    window, active, command, updated, summary, next_step, activity = fields
    windows[window] = active
    if command != "opencode" or not summary:
        continue
    try:
        timestamp = float(updated)
    except ValueError:
        timestamp = 0
    if window not in latest or timestamp > latest[window][0]:
        latest[window] = (timestamp, summary, next_step, activity)

for window in sorted(windows, key=lambda value: int(value)):
    active = windows[window]
    _, summary, next_step, activity = latest.get(window, (0, "", "", ""))
    text = next_step if kind == "next" else summary
    if kind == "next" and re.search(r"(prompt|transient|internal|model|session|generation|instruction)", text, re.IGNORECASE):
        text = "No action needed"

    width = thin_width if active != "1" and activity in {"aging", "stale"} else full_width
    left = "│" if active == "1" else ""
    right = "│" if active == "1" else ""
    available = width - 2 if active == "1" else width
    value = wrapped(text, row, available)
    print(f"{left}{value}{' ' * (available - display_width(value))}{right} ", end="")
