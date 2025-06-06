#!/bin/bash

# Check for --model flag
model=""
if [[ "$1" == "--model" && -n "$2" ]]; then
    model="$2"
    shift 2  # Remove --model and its value from arguments
fi

message="$@"
timestamp=$(date "+%H%M")
today=$(date "+%y%m%d")
export PATH=$PATH

# If no message autocommit
if [ -z "$message" ]; then
    git add .
    message=$(git status; git diff --staged)

    # Add model flag if specified
    model_flag=""
    if [ -n "$model" ]; then
        model_flag="--model $model"
    fi

    prompt=$(cat << 'EOF'
Write a concise git commit message summarizing the changes shown.

Rules:
- One line only, no newlines
- Start with action verb (Add, Fix, Update, Remove, etc.)
- Be specific but brief
- Skip daily routine items like food/exercise checkboxes
- No formatting, quotes, or extra commentary
- Focus on code/content changes that matter

Context: You're looking at git diff output that may include:
- [ ] = tasks/todos
- [-] = paused tasks  
- [c] = current tasks
- HHMM timestamps = time-based notes
- <repo> = git commit references

Ignore routine personal tracking, focus on meaningful code/content changes. Focus on changes (eg lines begining with + or -)

Example: "Add user authentication middleware and update login flow"
EOF
)

    message=$(echo "$message" | bash "$HEY/hey.sh" $model_flag --prompt "Briefly summarize this git commit change. Output the message directly with no fluff, your response is echoed directly to the terminal so be brief. Multiple sentences ok and preferred, but do not use newlines (its a commit message). Do not add > or numbers or any comments like great job etc to user, just the raw commit message with NO FORMATTING OR ESCAPING. DO not be hyper descriptive, just summarize the major changes. It's not necessary to note every checkbox change if it's just casual things like food and exercise, which is done daily" | tr -d '\n')
    echo -e $BGBLUE"$message"$CLEAR
fi

# Ask if should commit
echo -e $MAGENTA"Should the message be committed ([Y]es / [n]o / [r]egenerate)?"$CLEAR
read -r should_commit

if [ -z "$should_commit" ] || [[ "$should_commit" =~ ^[Yy] ]]; then
    # Log to HISTORY AFTER confirmation but BEFORE commit
    repo=$(git remote get-url origin | awk -F: '{print $2}')
    if [ -f "$HISTORY" ]; then
        echo "$timestamp <$repo> $message" >> "$HISTORY"
    else
        echo -e $RED"HISTORY FILE DOES NOT EXIST YET;\n$GREEN However, COMMIT SUCCESSFUL. $YELLOW MESSAGE ADDED TO $TEAL xsel -ib $YELLOW INSTEAD $RESET"
        echo "$timestamp <$repo> $message" | xsel -ib
    fi
    
    # Now do the commit
    git add .
    git commit -m "$message"

    # Push to all remotes with error handling
    for remote in $(git remote); do
      echo -e "$BLUE Pushing to $remote...$CLEAR"
      if git push "$remote"; then
          echo -e "$GREEN Successfully pushed to $remote$CLEAR"
      else
          echo -e "$RED Failed to push to $remote$CLEAR"
      fi
    done

    echo -e "$GREEN Commit successful! $RESET"
elif [[ "$should_commit" =~ ^[Rr] ]]; then
    echo -e "$YELLOW Please enter a new commit message: $RESET"
    read -r new_message
    message="$new_message"
    
    # Log the regenerated message
    repo=$(git remote get-url origin | awk -F: '{print $2}')
    if [ -f "$HISTORY" ]; then
        echo "$timestamp <$repo> $message" >> "$HISTORY"
    else
        echo "$timestamp <$repo> $message" | xsel -ib
    fi
    
    git commit -m "$message"
    git push
    echo -e "$GREEN Commit successful with new message! $RESET"
else
    echo -e "$YELLOW Commit cancelled. $RESET"
fi

echo -e $RESET
