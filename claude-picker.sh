#!/bin/bash
# Claude Code folder picker - runs on terminal startup
# If in home dir: show folder picker with fzf, then cd + cld
# If elsewhere: just run cld

# Skip if not interactive shell
[[ $- != *i* ]] && return

# Skip if already ran in this session
[[ -n "$CLAUDE_PICKER_RAN" ]] && return
export CLAUDE_PICKER_RAN=1

# Skip if running inside Claude Code or other tools
[[ -n "$CLAUDE_CODE" ]] && return
[[ "$TERM_PROGRAM" == "vscode" ]] && return

USAGE_FILE="$HOME/.claude/project-usage.json"

# Initialize usage file if missing
init_usage_file() {
    if [[ ! -f "$USAGE_FILE" ]]; then
        mkdir -p "$(dirname "$USAGE_FILE")"
        echo '{"usage":{"sb":1},"recent":["sb"]}' > "$USAGE_FILE"
    fi
}

# Get projects sorted by usage count (descending)
# sb is ALWAYS first (default project), then others by usage
get_sorted_projects() {
    # sb first (if exists)
    [[ -d "$HOME/sb" ]] && echo "sb"

    # Flatten JSON for reliable parsing
    local usage_data=$(cat "$USAGE_FILE" 2>/dev/null | tr -d '\n\r\t ')

    # Use temp file to avoid subshell output loss
    local tmp_file=$(mktemp)

    # Use while read to handle spaces in folder names
    ls -1 "$HOME" | grep -v -E "^(Library|Applications|Public|Pictures|Music|Movies|Documents|Downloads|Desktop|sb|\..*)$" | while IFS= read -r proj; do
        local count=$(echo "$usage_data" | grep -o "\"$proj\":[0-9]*" | head -1 | cut -d: -f2)
        [[ -z "$count" ]] && count=0
        printf "%010d\t%s\n" "$count" "$proj" >> "$tmp_file"
    done
    sort -rn "$tmp_file" | cut -f2-
    rm -f "$tmp_file"
}

# Update usage count for selected project
update_usage() {
    local project="$1"
    [[ -z "$project" ]] && return

    init_usage_file

    # Read and flatten current data
    local data=$(cat "$USAGE_FILE" | tr -d '\n\r\t ')

    # Get current count
    local current_count=$(echo "$data" | grep -o "\"$project\":[0-9]*" | head -1 | cut -d: -f2)
    [[ -z "$current_count" ]] && current_count=0
    local new_count=$((current_count + 1))

    # Update or add the count
    if echo "$data" | grep -q "\"$project\":"; then
        # Update existing
        data=$(echo "$data" | sed "s/\"$project\":[0-9]*/\"$project\":$new_count/")
    else
        # Add new entry after "usage":{
        data=$(echo "$data" | sed "s/\"usage\":{/\"usage\":{\"$project\":$new_count,/")
    fi

    # Update recent list (keep last 5, project at front)
    local old_recent=$(echo "$data" | grep -o '"recent":\[[^]]*\]' | sed 's/"recent":\[//' | sed 's/\]//')
    local new_recent="\"$project\""
    if [[ -n "$old_recent" ]]; then
        local filtered=$(echo "$old_recent" | tr ',' '\n' | grep -v "\"$project\"" | head -4 | tr '\n' ',' | sed 's/,$//')
        [[ -n "$filtered" ]] && new_recent="$new_recent,$filtered"
    fi
    data=$(echo "$data" | sed "s/\"recent\":\[[^]]*\]/\"recent\":[$new_recent]/")

    # Write back (single line for reliable parsing)
    echo "$data" > "$USAGE_FILE"
}

claude_picker() {
    local current_dir="$(pwd)"
    local home_dir="$HOME"

    # Only show picker if we're in home directory
    if [[ "$current_dir" == "$home_dir" ]]; then
        init_usage_file

        # Get recent projects for display
        local recent=$(cat "$USAGE_FILE" 2>/dev/null | tr -d '\n\r\t ' | \
            grep -o '"recent":\[[^]]*\]' | sed 's/"recent":\[//' | sed 's/\]//' | \
            tr -d '"' | tr ',' ' ' | cut -d' ' -f1-3)

        echo -e "\033[1;36m📂 Select project folder (sorted by usage)\033[0m"
        [[ -n "$recent" ]] && echo -e "\033[0;90mRecent: $recent\033[0m"

        # Use --print-query to capture typed text
        local result=$(get_sorted_projects | \
            fzf --height=40% --reverse --border \
                --prompt="Project: " \
                --header="Type to filter, Enter to select, ESC to cancel" \
                --preview="[[ -d \"$HOME/{}\" ]] && ls -la $HOME/{} 2>/dev/null | head -20 || echo '📁 New folder: {}'" \
                --preview-window=right:50% \
                --print-query \
                --bind "change:reload(get_sorted_projects | grep -i {q} || true; [[ -n {q} ]] && ! ls -1 $HOME | grep -qix {q} && echo '➕ Create: {q}')")

        # Parse result: first line is query, second line is selection
        local query=$(echo "$result" | head -1)
        local selected=$(echo "$result" | tail -1)

        # Check if user selected "Create new" option
        if [[ "$selected" == "➕ Create: "* ]]; then
            local new_folder="${selected#➕ Create: }"
            echo -e "\033[1;35m📁 Creating new folder: $new_folder\033[0m"
            mkdir -p "$HOME/$new_folder"
            update_usage "$new_folder"
            cd "$HOME/$new_folder"
            echo -e "\033[1;32m→ $new_folder\033[0m"
            cld
        elif [[ -n "$selected" && ! "$selected" == "➕ "* ]]; then
            update_usage "$selected"
            cd "$HOME/$selected"
            echo -e "\033[1;32m→ $selected\033[0m"
            cld
        elif [[ -n "$query" && ! -d "$HOME/$query" ]]; then
            # User typed something and pressed Enter but no match - offer to create
            echo -e "\033[1;33mFolder '$query' doesn't exist.\033[0m"
            read -p "Create it? (y/N): " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                mkdir -p "$HOME/$query"
                update_usage "$query"
                cd "$HOME/$query"
                echo -e "\033[1;32m→ $query\033[0m"
                cld
            else
                echo -e "\033[1;33mStaying in ~\033[0m"
            fi
        else
            echo -e "\033[1;33mStaying in ~\033[0m"
        fi
    else
        # Not in home, just run cld
        cld
    fi
}

# Auto-run on shell start
claude_picker
