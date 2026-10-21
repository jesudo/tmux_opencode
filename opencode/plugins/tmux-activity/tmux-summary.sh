#!/bin/sh
# Print one wrapped row of each window's most-recent OpenCode session title.

session=$1
row=${2:-1}
kind=${3:-title}
# Six 26-column cells fit within the 161-column tmux client width.
cell_width=24

tmux list-panes -s -t "$session" \
  -F '#{window_index}|#{window_active}|#{pane_current_command}|#{@opencode_updated_at}|#{@opencode_summary}|#{@opencode_next_step}' |
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
      }
    }
    END {
      for (window in windows) print window "|" active[window] "|" summary[window] "|" next_step[window]
    }
  ' |
  sort -n -k1,1 |
  awk -F '|' -v wanted="$row" -v width="$cell_width" -v kind="$kind" '
    function wrapped(text, target, max_width,    words, count, line, word, position) {
      count = 1
      line = ""
      split(text, words, " ")

      for (position = 1; position <= length(words); position++) {
        word = words[position]
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
      prefix = ""
      wrap_width = width
      available = width - length(prefix)
      value = wrapped(text, wanted, wrap_width)
      left = $2 == "1" ? "│" : " "
      right = $2 == "1" ? "│" : " "
      printf "%s%s%-*s%s", left, prefix, available, value, right
    }
  '
