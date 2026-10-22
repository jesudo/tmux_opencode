#!/bin/sh
# Print one wrapped row of each window's most-recent OpenCode session title.

session=$1
row=${2:-1}
kind=${3:-title}
# Tab titles use 20/12 columns after their one-character status glyph, plus a gap.
full_width=21
thin_width=13

tmux list-panes -s -t "$session" \
  -F '#{window_index}|#{window_active}|#{pane_current_command}|#{@opencode_updated_at}|#{@opencode_summary}|#{@opencode_next_step}|#{@opencode_activity}' |
  awk -F '|' '
    {
      windows[$1] = 1
      active[$1] = $2
    }
    $3 == "opencode" && $5 != "" {
      timestamp = $4 + 0
      if (!seen[$1] || timestamp > newest[$1]) {
        seen[$1] = 1
        newest[$1] = timestamp
        summary[$1] = $5
        next_step[$1] = $6
        activity[$1] = $7
      }
    }
    END {
      for (window in windows) print window "|" active[window] "|" summary[window] "|" next_step[window] "|" activity[window]
    }
  ' |
  sort -n -k1,1 |
  awk -F '|' -v wanted="$row" -v full_width="$full_width" -v thin_width="$thin_width" -v kind="$kind" '
    function wrapped(text, target, max_width,    words, count, line, word, position) {
      count = 1
      line = ""
      split(text, words, " ")

      for (position = 1; position <= length(words); position++) {
        word = words[position]
        if (length(word) > max_width) word = substr(word, 1, max_width)
        if (length(line) && length(line) + 1 + length(word) > max_width) {
          if (count == target) return line
          count++
          line = word
        } else {
          line = line ? line " " word : word
        }
      }

      return count == target ? line : ""
    }
    {
      text = kind == "next" ? $4 : $3
      lower = tolower(text)
      if (kind == "next" && lower ~ /(prompt|transient|internal|model|session|generation|instruction)/) {
        text = "No action needed"
      }
      width = ($2 != "1" && ($5 == "aging" || $5 == "stale")) ? thin_width : full_width
      left = $2 == "1" ? "│" : ""
      right = $2 == "1" ? "│" : ""
      available = width - ($2 == "1" ? 2 : 0)
      value = wrapped(text, wanted, available)
      printf "%s%-*s%s ", left, available, value, right
    }
  '
