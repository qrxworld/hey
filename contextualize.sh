#!/bin/bash

# --- Configuration: Default Files/Directories to Exclude (Basenames) ---
# These use BASENAME matching and are skipped UNLESS overridden by --include
default_exclude_patterns=(
    ".git" "node_modules" ".DS_Store" ".gitignore" "package-lock.json"
    "yarn.lock" "dist" "build" "out" "target" ".vscode" ".idea" "*.pyc"
    "__pycache__"
)

# --- Arrays for command-line options ---
custom_ignore_patterns=() # Patterns from --ignore (match FULL path)
custom_include_patterns=() # Patterns from --include (match FULL path, take precedence)
paths_to_process=()      # File/directory arguments from the command line

# --- Argument Parsing Loop ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        --ignore)
            if [[ -z "$2" ]]; then
                echo "Error: --ignore requires a pattern argument." >&2
                exit 1
            fi
            # Store the pattern exactly as provided by the user
            custom_ignore_patterns+=("$2")
            shift 2 # Consume --ignore and its pattern
            ;;
        --include)
            if [[ -z "$2" ]]; then
                echo "Error: --include requires a pattern argument." >&2
                exit 1
            fi
            # Store the pattern exactly as provided by the user
            custom_include_patterns+=("$2")
            shift 2 # Consume --include and its pattern
            ;;
        --*) # Handle unknown options
           echo "Error: Unknown option '$1'" >&2
           exit 1
           ;;
        *) # Not an option, assume it's a file/directory path
            paths_to_process+=("$1")
            shift # Consume the path
            ;;
    esac
done

# --- Helper Function: Check if a path should be processed based on rules ---
# Returns 0 (true/success) if the item SHOULD be processed.
# Returns 1 (false/failure) if it should be SKIPPED.
should_process() {
    local item_path="$1" # The full path being checked (e.g., context/file.txt or ./subdir/another.log)
    local item_basename
    item_basename=$(basename -- "$item_path") # Used only for default excludes

    # === Priority 1: Custom INCLUDES (Full Path Match) ===
    # If a path matches an --include pattern, it's always processed.
    for pattern in "${custom_include_patterns[@]}"; do
        # Use [[ for reliable glob matching against the FULL path
        if [[ "$item_path" == $pattern ]]; then
            # echo "DEBUG: Explicitly including '$item_path' due to full path pattern '$pattern'" >&2
            return 0 # Process it
        fi
    done

    # === Priority 2: Custom IGNORES (Full Path Match) ===
    # If it wasn't explicitly included, check if it matches an --ignore pattern.
    for pattern in "${custom_ignore_patterns[@]}"; do
        # Use [[ for reliable glob matching against the FULL path
        if [[ "$item_path" == $pattern ]]; then
            # echo "DEBUG: Skipping '$item_path' due to --ignore full path pattern '$pattern'" >&2
            return 1 # Skip it
        fi
    done

    # === Priority 3: Default EXCLUDES (Basename Match) ===
    # If it wasn't included or ignored by custom rules, check default exclusions based on basename.
    for pattern in "${default_exclude_patterns[@]}"; do
        # Use [[ for reliable glob matching against the BASENAME
        if [[ "$item_basename" == $pattern ]]; then
            # echo "DEBUG: Skipping '$item_path' (basename '$item_basename') due to default exclude pattern '$pattern'" >&2
            return 1 # Skip it
        fi
    done

    # === Default: Process ===
    # If none of the above rules caused it to be skipped or explicitly included, process it.
    # echo "DEBUG: Processing '$item_path' by default (no matching rules)" >&2
    return 0 # Process it
}

# --- Helper Function: Process a single file ---
# (Same as before)
process_file() {
    local file_path="$1"
    if [ -f "$file_path" ] && [ -r "$file_path" ]; then
        echo "<file path=\"$file_path\">"
        cat -- "$file_path"
        echo # Ensure newline
        echo "</file>"
    else
         echo "<!-- Warning: Could not read file '$file_path', skipping processing. -->" >&2
    fi
}

# --- Main Script Logic ---
# (Same as before)
echo "<context>"

for path_arg in "${paths_to_process[@]}"; do
    if [ ! -e "$path_arg" ]; then
        echo "<!-- Warning: Path '$path_arg' does not exist, skipping. -->" >&2
        continue
    fi

    # Check the top-level argument (file or directory itself)
    if ! should_process "$path_arg"; then
        continue
    fi

    if [ -f "$path_arg" ]; then
        process_file "$path_arg"
    elif [ -d "$path_arg" ]; then
        find "$path_arg" -maxdepth 1 -type f -print0 | while IFS= read -r -d $'\0' file_in_dir; do
            # Check EACH file found inside the directory
            if should_process "$file_in_dir"; then
                process_file "$file_in_dir"
            fi
        done
    else
        echo "<!-- Warning: Path '$path_arg' is not a regular file or directory, skipping. -->" >&2
    fi
done

echo "</context>"
