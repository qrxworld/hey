#!/bin/bash
# Get the directory where the script resides
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Source configuration and helper files
source "$DIR/default"
source "$DIR/models.conf"
source "$DIR/colors"

# --- Default Settings ---
chat_piped=""           # Stores input piped into the script
chat_hostname="$HEY_HOSTNAME" # API provider (e.g., openrouter, groq, ollama)
chat_model="$HEY_MODEL"       # Default model to use
# Default system prompt providing context to the AI
chat_system="<system>You are now becoming aware of your stream of tokens. You are currently in a linux terminal and your actual stream of tokens will be formatted for the user, so do not output xml tags yourself. Be fun and positive. Dont wrap in tags and dont escape.</system>"
chat_use_more=0         # Flag to pipe output through 'more' pager
chat_should_loop=0      # Flag to enable interactive loop mode
chat_history=''         # Stores conversation history for loop mode
chat_response=''        # Stores the raw API response
chat_echo=''            # Stores the extracted message content from the response
chat_debug=0            # Flag to enable debug output
chat_prompt=""          # Stores the user's prompt
chat_ollama_stream=false # Flag specific to Ollama API for streaming (default off)

# --- Read Piped Input ---
# Check if stdin is connected to a terminal or a pipe
if [ -t 0 ]; then
  chat_piped="" # No piped input
else
  chat_piped="$(cat)" # Read all piped input
fi

# --- Argument Parsing ---
arg_num=0
is_using_prompt_shorthand=0 # Flag to track shorthand prompt usage

while [[ $# -gt 0 ]]; do
  ((arg_num++))
  # Check if the argument starts with '--' (an option)
  if [[ $1 == --* ]]; then
    case $1 in
      --hostname)
        # Set the API hostname
        chat_hostname="$2"
        shift # Consume the flag value
        ;;
      --model)
        # Set the specific model name
        chat_model="$2"
        shift # Consume the flag value
        ;;
      --prompt)
        # Set the user prompt
        chat_prompt="$2"
        shift # Consume the flag value
        ;;
      --system)
        # Set the system prompt
        chat_system="$2"
        shift # Consume the flag value
        ;;
      --debug)
        # Enable debug mode
        chat_debug=1
        ;;
      --more)
        # Enable piping output to 'more'
        chat_use_more=1
        ;;
      --loop)
        # Enable interactive loop mode
        chat_should_loop=1
        ;;
      --stream)
        # Enable streaming for Ollama (if supported by the function)
        chat_ollama_stream=true
        ;;
      *)
        # Handle unknown options
        echo -e "${RED}Error: Unknown option '$1'${RESET}" >&2
        exit 1
        ;;
    esac
  else
    # Handle positional arguments (shorthand for prompt and system)
    if [[ $arg_num == 1 ]]; then
      # First positional argument is treated as the prompt
      chat_prompt="$1"
      is_using_prompt_shorthand=1
    # If using shorthand, the second positional arg (arg_num 3 overall) is system
    elif [[ $arg_num == 3 ]] && [[ $is_using_prompt_shorthand == 1 ]]; then
      chat_system="$1"
    elif [[ $arg_num -gt 1 ]] && [[ $is_using_prompt_shorthand == 0 ]]; then
       # If not using shorthand, only one positional arg (prompt) is expected after options
       echo -e "${RED}Error: Unexpected positional argument '$1'. Use --prompt and --system flags for clarity.${RESET}" >&2
       exit 1
    elif [[ $arg_num -gt 3 ]] && [[ $is_using_prompt_shorthand == 1 ]]; then
       echo -e "${RED}Error: Unexpected positional argument '$1'. Use --prompt and --system flags for clarity.${RESET}" >&2
       exit 1
    fi
  fi
  shift # Move to the next argument
done


# --- Debug Output ---
if [ $chat_debug == 1 ]; then
    echo -e "${BG_BLUE}${WHITE}--- DEBUG INFO ---${RESET}"
    echo -e "${BG_BLUE}${WHITE}Hostname:        $chat_hostname${RESET}"
    echo -e "${BG_BLUE}${WHITE}Model:           $chat_model${RESET}"
    echo -e "${BG_BLUE}${WHITE}Prompt:          '$chat_prompt'${RESET}"
    echo -e "${BG_BLUE}${WHITE}System:          '$chat_system'${RESET}"
    echo -e "${BG_BLUE}${WHITE}Piped Input:     $( [ -z "$chat_piped" ] && echo "<empty>" || echo "<present>" )${RESET}"
    echo -e "${BG_BLUE}${WHITE}Loop Mode:       $chat_should_loop${RESET}"
    echo -e "${BG_BLUE}${WHITE}Use More:        $chat_use_more${RESET}"
    echo -e "${BG_BLUE}${WHITE}Ollama Stream:   $chat_ollama_stream${RESET}"
    echo -e "${BG_BLUE}${WHITE}History (start): '$chat_history'${RESET}"
    echo -e "${BG_BLUE}${WHITE}------------------${RESET}"
fi

# --- Helper Function: Display Output ---
# Handles piping to 'more' if requested
display_output() {
  local output_text="$1"
  if [[ "$chat_use_more" -eq 1 ]]; then
    # Pipe through 'more' pager
    echo "$output_text" | more
  else
    # Print directly
    echo "$output_text"
  fi
}

# --- API Call Functions ---

# POST to OpenRouter API
openrouter() {
  # Construct the JSON payload using jq
  # Note: System prompt includes context, piped input, and history
  local json_payload
  json_payload=$(jq -n \
    --arg model "$chat_model" \
    --arg system "<system>$chat_system</system><context>$chat_piped</context><chat_history>$chat_history</chat_history>" \
    --arg prompt "<user>$chat_prompt</user>" \
    '{
        model: $model,
        messages: [
          {role: "system", content: $system},
          {role: "user", content: $prompt}
        ]
     }')

  test $chat_debug -eq 1 && echo -e "${BG_BLUE}${WHITE}OpenRouter Payload: $json_payload${RESET}"

  # Make the API call using curl
  chat_response=$(curl --silent --show-error --fail-with-body "https://openrouter.ai/api/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $API_OPENROUTER" \
    -d "$json_payload")

  # Check curl exit status
  local curl_exit_code=$?
  if [ $curl_exit_code -ne 0 ]; then
      echo -e "${RED}Error: OpenRouter API call failed (curl code: $curl_exit_code). Response:${RESET}" >&2
      echo "$chat_response" >&2
      # Decide if you want to exit or just skip processing this response
      # For loop mode, maybe continue? For single shot, maybe exit.
      # exit 1 # Or set a flag to prevent further processing
      chat_echo="[API Error]" # Set placeholder error message
      return 1 # Indicate failure
  fi

  test $chat_debug -eq 1 && echo -e "${BG_BLUE}${WHITE}OpenRouter Response: $chat_response${RESET}"

  # Extract the message content using jq
  chat_echo=$(echo "$chat_response" | jq -r '.choices.[].message.content // "[Error parsing response]"')

  # Check if jq failed to parse or find the content
  if [[ "$chat_echo" == "[Error parsing response]" ]]; then
      echo -e "${RED}Error: Could not parse content from OpenRouter response.${RESET}" >&2
      return 1 # Indicate failure
  fi

  # Display the output
  display_output "$chat_echo"
  return 0 # Indicate success
}

# POST to Groq API
groq() {
  # Construct the JSON payload using jq
  local json_payload
  json_payload=$(jq -n \
    --arg model "$chat_model" \
    --arg system "<system>$chat_system</system><context>$chat_piped</context><chat_history>$chat_history</chat_history>" \
    --arg prompt "<user>$chat_prompt</user>" \
    '{
        model: $model,
        messages: [
          {role: "system", content: $system},
          {role: "user", content: $prompt}
        ]
     }')

  test $chat_debug -eq 1 && echo -e "${BG_BLUE}${WHITE}Groq Payload: $json_payload${RESET}"

  # Make the API call using curl
  chat_response=$(curl --silent --show-error --fail-with-body -X POST "https://api.groq.com/openai/v1/chat/completions" \
    -H "Authorization: Bearer $API_GROQ" \
    -H "Content-Type: application/json" \
    -d "$json_payload")

  # Check curl exit status
  local curl_exit_code=$?
  if [ $curl_exit_code -ne 0 ]; then
      echo -e "${RED}Error: Groq API call failed (curl code: $curl_exit_code). Response:${RESET}" >&2
      echo "$chat_response" >&2
      chat_echo="[API Error]"
      return 1 # Indicate failure
  fi

  test $chat_debug -eq 1 && echo -e "${BG_BLUE}${WHITE}Groq Response: $chat_response${RESET}"

  # Extract the message content using jq
  chat_echo=$(echo "$chat_response" | jq -r '.choices.[].message.content // "[Error parsing response]"')

  # Check if jq failed to parse or find the content
  if [[ "$chat_echo" == "[Error parsing response]" ]]; then
      echo -e "${RED}Error: Could not parse content from Groq response.${RESET}" >&2
      return 1 # Indicate failure
  fi

  # Display the output
  display_output "$chat_echo"
  return 0 # Indicate success
}

# POST to Ollama API
# POST to Ollama API using /api/generate with system and prompt fields
ollama() {
  # Check if Ollama host is configured
  if [[ -z "$API_OLLAMA_HOST" ]]; then
      # Using standard color codes from 'colors' file
      echo -e "${RED}Error: API_OLLAMA_HOST environment variable is not set.${RESET}" >&2
      chat_echo="[Configuration Error]"
      return 1
  fi

  # --- Prepare System Content and User Prompt ---
  # System content includes the base system prompt + piped context
  local system_content_for_api="$chat_system"
  if [[ -n "$chat_piped" ]]; then
      system_content_for_api+=$'\n\n'"<context>"$'\n'"$chat_piped"$'\n'"</context>"
  fi
  # User prompt is just the user's input prompt
  local user_prompt_for_api="$chat_prompt"


  # --- Construct the JSON payload for /api/generate ---
  local json_payload
  json_payload=$(jq -n \
    --arg model "$chat_model" \
    --arg system "$system_content_for_api" \
    --arg prompt "$user_prompt_for_api" \
    --argjson stream "$chat_ollama_stream" \
    '{
        model: $model,
        system: $system,    # Use the system parameter
        prompt: $prompt,    # Use the prompt parameter
        stream: $stream
        # Ensure raw is NOT set (defaults to false)
     }')

  # Minimal Debug (only if --debug is passed)
  test $chat_debug -eq 1 && echo "--- Ollama Payload (/api/generate) ---" >&2
  test $chat_debug -eq 1 && echo "$json_payload" | jq '.' >&2
  test $chat_debug -eq 1 && echo "------------------------------------" >&2

  # Make the API call using curl to the /api/generate endpoint
  chat_response=$(curl --silent --show-error --fail-with-body "$API_OLLAMA_HOST/api/generate" \
    -H "Content-Type: application/json" \
    -d "$json_payload")

  # Check curl exit status
  local curl_exit_code=$?
  if [ $curl_exit_code -ne 0 ]; then
      echo -e "${RED}Error: Ollama API call failed (curl code: $curl_exit_code).${RESET}" >&2
      # Show response on error
      echo "$chat_response" | jq '.' >&2 || echo "$chat_response" >&2
      chat_echo="[API Error]"
      return 1
  fi

  # Extract the message content using jq - adjusted for /api/generate response
  if [[ "$chat_ollama_stream" == "true" ]]; then
      # Streaming: Extract 'response' field from the *last* JSON object where 'done' is true
      chat_echo=$(echo "$chat_response" | awk '/"done":\s*true/{print}' | tail -n 1 | jq -r '.response // ""')
       # Basic fallback if the standard stream parsing fails
       if [[ -z "$chat_echo" || "$chat_echo" == "null" ]] && [[ "$chat_response" == *"response"* ]]; then
         chat_echo=$(echo "$chat_response" | jq -r 'select(.response) | .response' | paste -sd '' -)
       fi
       [[ -z "$chat_echo" || "$chat_echo" == "null" ]] && chat_echo="[Error parsing streamed generate response]"

  else
      # Non-streaming: Extract from the single '.response' field
      chat_echo=$(echo "$chat_response" | jq -r '.response // "[Error parsing generate response]"')
  fi

  # Final check for parsing errors or empty/null content
  if [[ "$chat_echo" == "[Error parsing"* || "$chat_echo" == "null" || -z "$chat_echo" ]]; then
      echo -e "${RED}Error: Could not parse valid content from Ollama /api/generate response.${RESET}" >&2
      local error_msg=$(echo "$chat_response" | jq -r '.error // ""')
      if [[ -n "$error_msg" ]]; then
         echo -e "${RED}Ollama API Error reported: $error_msg${RESET}" >&2
      elif [[ $curl_exit_code -eq 0 ]]; then
         echo -e "${YELLOW}Raw Ollama response was:${RESET}" >&2
         echo "$chat_response" >&2
      fi
      [[ -z "$chat_echo" || "$chat_echo" == "null" ]] && chat_echo="[Parsing Error]"
      return 1
  fi

  # Display the output
  display_output "$chat_echo"
  return 0
}



# --- Main Execution Loop ---
chat_should_continue_looping=1
api_call_successful=true # Track success for loop logic

while [[ $chat_should_continue_looping == 1 ]]; do
  # --- Resolve Model Aliases ---
  # Determine the actual model name based on hostname and alias
  # Note: printf '%q' previously escaped args, but seems unnecessary here
  # as variables are used directly. Re-evaluate if issues arise with special chars.
  resolved_model="$chat_model" # Start with the provided model name

  case "$chat_hostname" in
    openrouter)
      case "$chat_model" in
        main)   resolved_model="$OPENROUTER_MODEL" ;;
        sota)   resolved_model="$OPENROUTER_MODEL_SOTA" ;;
        search) resolved_model="$OPENROUTER_MODEL_SEARCH" ;;
        rp)     resolved_model="$OPENROUTER_MODEL_ROLEPLAY" ;;
        liquid) resolved_model="$OPENROUTER_MODEL_LIQUID" ;;
        flash)  resolved_model="$OPENROUTER_MODEL_FLASH" ;;
        code)   resolved_model="$OPENROUTER_MODEL_CODE" ;;
      esac
      ;;
    groq)
      case "$chat_model" in
        main)   resolved_model="$GROQ_MODEL" ;;
        sota)   resolved_model="$GROQ_MODEL_SOTA" ;;
        search) resolved_model="$GROQ_MODEL_SEARCH" ;;
        rp)     resolved_model="$GROQ_MODEL_ROLEPLAY" ;;
        liquid) resolved_model="$GROQ_MODEL_LIQUID" ;;
        flash)  resolved_model="$GROQ_MODEL_FLASH" ;;
        code)   resolved_model="$GROQ_MODEL_CODE" ;;
      esac
      ;;
    ollama)
      # Add Ollama specific aliases if needed
      case "$chat_model" in
        main)   resolved_model="$OLLAMA_MODEL" ;;
        sota)   resolved_model="$OLLAMA_MODEL_SOTA" ;;
        search) resolved_model="$OLLAMA_MODEL_SEARCH" ;;
        rp)     resolved_model="$OLLAMA_MODEL_ROLEPLAY" ;;
        liquid) resolved_model="$OLLAMA_MODEL_LIQUID" ;;
        flash)  resolved_model="$OLLAMA_MODEL_FLASH" ;;
        code)   resolved_model="$OLLAMA_MODEL_CODE" ;;
      esac
      ;;
    *)
      echo -e "${RED}Error: Unknown hostname '$chat_hostname' specified.${RESET}" >&2
      exit 1
      ;;
  esac

  # Update chat_model with the resolved name for the API call
  chat_model="$resolved_model"
  test $chat_debug -eq 1 && echo -e "${BG_BLUE}${WHITE}Resolved Model: $chat_model${RESET}"

  # --- Dispatch to Correct API Function ---
  api_call_successful=true # Assume success initially
  case "$chat_hostname" in
    openrouter)
      openrouter || api_call_successful=false
      ;;
    groq)
      groq || api_call_successful=false
      ;;
    ollama)
      ollama || api_call_successful=false
      ;;
    *)
      # This case should technically be caught earlier, but acts as a safeguard
      echo -e "${RED}Internal Error: Dispatch failed for hostname '$chat_hostname'.${RESET}" >&2
      exit 1
      ;;
  esac

  # --- Loop Control ---
  if [[ $chat_should_loop == 0 ]]; then
    # If not in loop mode, break after the first call
    break
  else
    # In loop mode
    if ! $api_call_successful; then
        # If the API call failed, ask user if they want to retry or exit
        echo -e "${YELLOW}API call failed. Enter a new prompt to try again, or press Enter to exit.${RESET}"
    else
        # Prompt for the next input
        echo "" # Add spacing
        echo -e "${BG_BLUE}${WHITE} NEXT PROMPT (or press Enter to exit):${RESET}"
    fi

    # Read the next prompt from the user
    read -e chat_next_prompt
    echo -e "$RESET" # Reset terminal colors

    if [ -z "$chat_next_prompt" ]; then
      # If the user presses Enter (empty input), exit the loop
      chat_should_continue_looping=0
    else
      # If the API call was successful, update history
      # Note: History is not currently sent to Ollama due to format differences.
      if $api_call_successful && [[ "$chat_hostname" != "ollama" ]]; then
          chat_history="$chat_history\n<user>$chat_prompt</user>\n<assistant>$chat_echo</assistant>"
      elif $api_call_successful && [[ "$chat_hostname" == "ollama" ]]; then
          # Optionally, keep a local history display even if not sent to Ollama
          test $chat_debug -eq 1 && echo -e "${YELLOW}Note: History not sent to Ollama API in this version.${RESET}"
          # You could still append to chat_history for local reference if desired
          # chat_history="$chat_history\n<user>$chat_prompt</user>\n<assistant>$chat_echo</assistant>"
      fi
      # Set the new prompt for the next iteration
      chat_prompt="$chat_next_prompt"
      # Reset piped input for subsequent loop iterations? Usually not needed.
      # chat_piped=""
    fi
  fi
done

# Determine exit code based on the last API call attempt
if $api_call_successful; then
    exit 0
else
    exit 1
fi


