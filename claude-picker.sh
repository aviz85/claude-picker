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

# Get projects sorted by usage count (descending) - WITHOUT sb
get_other_projects() {
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

# Build sectioned list: sb | separator | projects | separator | create
# Args: $1 = query (optional), $2 = projects_file
build_picker_list() {
    local query="$1"
    local projects_file="$2"

    # Section 1: sb (always first, if matches query or no query)
    if [[ -d "$HOME/sb" ]]; then
        if [[ -z "$query" ]] || echo "sb" | grep -qi "$query"; then
            echo "sb"
        fi
    fi

    # Separator after sb section
    echo "──────────────────────────"

    # Section 2: Other projects (filtered)
    if [[ -z "$query" ]]; then
        cat "$projects_file"
    else
        grep -i "$query" "$projects_file" || true
    fi

    # Separator before create section
    echo "──────────────────────────"

    # Section 3: Create option (only if query exists and doesn't match exactly)
    if [[ -n "$query" ]]; then
        # Check if exact match exists (sb or other project)
        if [[ "$query" != "sb" ]] && ! grep -qix "$query" "$projects_file"; then
            echo "➕ Create: $query"
        fi
    fi
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

        # Write project list to temp file (without sb)
        local projects_file=$(mktemp)
        get_other_projects > "$projects_file"

        # Build initial list with sections
        local initial_list=$(mktemp)
        build_picker_list "" "$projects_file" > "$initial_list"

        # fzf with sectioned layout
        local selected=$(cat "$initial_list" | fzf --height=40% --reverse --border \
            --prompt="Project: " \
            --header="sb=default | ↓ to create new" \
            --preview="[[ '{}' == '➕ Create:'* ]] && echo '📁 New folder will be created' || [[ '{}' == '───'* ]] && echo '' || ls -la $HOME/{} 2>/dev/null | head -20" \
            --preview-window=right:50% \
            --bind "change:reload(
                q={q};
                if [[ -d $HOME/sb ]] && { [[ -z \$q ]] || echo sb | grep -qi \$q; }; then echo sb; fi;
                echo '──────────────────────────';
                if [[ -z \$q ]]; then cat $projects_file; else grep -i \$q $projects_file || true; fi;
                echo '──────────────────────────';
                if [[ -n \$q ]] && [[ \$q != 'sb' ]] && ! grep -qix \$q $projects_file; then echo \"➕ Create: \$q\"; fi
            )")

        rm -f "$projects_file" "$initial_list"

        # Handle selection (skip separators)
        if [[ "$selected" == "───"* ]]; then
            echo -e "\033[1;33mStaying in ~\033[0m"
        elif [[ "$selected" == "➕ Create: "* ]]; then
            local new_folder="${selected#➕ Create: }"
            echo -e "\033[1;35m📁 Creating: $new_folder\033[0m"
            mkdir -p "$HOME/$new_folder"
            update_usage "$new_folder"
            cd "$HOME/$new_folder"
            echo -e "\033[1;32m→ $new_folder\033[0m"
            cld
        elif [[ -n "$selected" ]]; then
            update_usage "$selected"
            cd "$HOME/$selected"
            echo -e "\033[1;32m→ $selected\033[0m"
            cld
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
