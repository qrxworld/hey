# hey.sh - Terminal AI Assistant Framework

A lightweight Bash framework for building AI-powered terminal tools and agents. Integrates with your shell for seamless AI assistance, supporting OpenRouter, Groq, and **local models via Ollama**. Chain commands to create multi-step AI workflows directly in your terminal.

## Prerequisites

*   Bash 4.0+
*   Required command-line tools: `curl`, `jq`
*   Optional but recommended: `more` (for paging), `xsel` or `wl-copy` or `pbcopy` (for clipboard integration)
*   **API Key/Host Configuration:**
    *   For **OpenRouter**: API key from [https://openrouter.ai](https://openrouter.ai)
    *   For **Groq**: API key from [https://groq.com](https://groq.com)
    *   For **Ollama**:
        *   Ollama installed and running ([https://ollama.ai](https://ollama.ai)).
        *   Models pulled locally (e.g., `ollama pull llama3`).
        *   The `API_OLLAMA_HOST` environment variable set (usually `http://localhost:11434`).

## Quick Setup

```bash
# 1. Clone the repository
git clone https://github.com/qrxer/hey # Or your repo URL
cd hey.sh

# 2. Add essential configuration to your ~/.bashrc or ~/.zshrc
#    Only set the keys/hosts for the services you intend to use.
export API_OPENROUTER='sk-or-v1-...'    # Required for OpenRouter
export API_GROQ='gsk_...'               # Required for Groq
export API_OLLAMA_HOST='http://localhost:11434' # Required for Ollama

# 3. Set hey.sh base directory and default preferences
export HEY_BASE="$HOME/path/to/hey.sh" # Adjust path to where you cloned it
export HEY_HOSTNAME='openrouter'       # Default API: openrouter | groq | ollama
export HEY_MODEL='anthropic/claude-3.5-sonnet' # Default model for the chosen hostname (see models.conf)
# Or for Ollama:
# export HEY_HOSTNAME='ollama'
# export HEY_MODEL='llama3'             # A model you have pulled with Ollama

# 4. Create an alias for easy access
alias hey="$HEY_BASE/chat.sh"

# 5. Apply changes to your current shell session
source ~/.bashrc # or source ~/.zshrc
```

## Usage

### Basic Commands

```bash
# Ask a direct question (uses default model/hostname)
hey "Explain the 'curl' command in simple terms"

# Use a specific hostname and model
hey --hostname ollama --model llama3 "Translate 'hello world' to French"

# Provide a system prompt for context or role-playing
hey "Analyze this Go code for potential bugs" "You are an expert Go developer security auditor."

# Interactive chat session (Ctrl+D or empty prompt to exit)
hey "Let's plan a project" --loop

# Use pager for long responses
hey "Summarize the history of Linux" --more
```

### Command Line Options

```bash
hey [prompt] [system_prompt_shorthand] [flags]

Flags:
  --hostname <name>   # API provider: openrouter | groq | ollama
  --model <id>        # Specific model ID to use (overrides defaults/aliases)
  --prompt <text>     # Your question/prompt (alternative to first positional argument)
  --system <text>     # System prompt for context (alternative to second positional argument)
  --debug             # Enable verbose debug output
  --more              # Use 'more' pager for long responses
  --loop              # Enable interactive chat mode (keeps history between prompts)
  --stream            # Enable streaming output (currently primarily for Ollama)

Model Shortcuts (uses model defined in models.conf for the current hostname):
  --sota              # Use the defined 'state-of-the-art' model
  --flash             # Use the defined 'fast' model
  --search            # Use the defined 'search-optimized' model
  --rp                # Use the defined 'role-playing' model
  --liquid            # Use the defined 'fluid conversation' model
  --code              # Use the defined 'code-optimized' model

Shorthand Syntax:
  # These are equivalent:
  hey "Analyze this" "You are an expert"
  hey --prompt "Analyze this" --system "You are an expert"
```

### Piping and Chaining (Building Agents)

`hey.sh` reads from standard input, allowing you to pipe data into it as context. You can chain multiple `hey` commands together, passing the output of one as input/context to the next, to create complex, multi-step AI workflows or simple agents.

```bash
# Basic Piping: Get review on git changes
git diff | hey "Review these code changes for potential issues"

# Basic Piping: Analyze logs
tail -n 100 error.log | hey "Find critical errors in these logs"

# Chaining Example: Plan -> Implement -> Review
# 1. Create a plan based on existing code
cat my_script.py | hey "Create a step-by-step plan to add error handling" > plan.md

# 2. Use the plan and code to generate new code (might need refinement)
cat plan.md my_script.py | hey --code "Implement the error handling based on the plan" > my_script_v2.py

# 3. Review the generated code against the plan
cat plan.md my_script_v2.py | hey "Does this code correctly implement the plan?"
```
*(Note: The effectiveness of chaining depends heavily on the model's capabilities and the clarity of prompts.)*

## Configuration

### Environment Variables

*   `HEY_BASE`: Path to the `hey.sh` installation directory.
*   `HEY_HOSTNAME`: Default API provider (`openrouter`, `groq`, or `ollama`).
*   `HEY_MODEL`: Default model ID for the selected `HEY_HOSTNAME`.
*   `API_OPENROUTER`: Your OpenRouter API key (if using OpenRouter).
*   `API_GROQ`: Your Groq API key (if using Groq).
*   `API_OLLAMA_HOST`: URL of your running Ollama API (e.g., `http://localhost:11434`, if using Ollama).

### `models.conf`

This file defines the specific model IDs used by default and for the shortcut flags (`--sota`, `--flash`, etc.) for each supported hostname (OpenRouter, Groq, Ollama). You can customize these to your preferred models available on each platform.

*   For **Ollama**, ensure the model names match those you have pulled locally (check with `ollama list`).

## Project Structure

```
hey.sh/
├── chat.sh        # Main script, handles logic and API calls
├── default        # Sets default HEY_HOSTNAME and model variables
├── models.conf    # Defines default/alias models per hostname
├── colors         # Terminal color definitions
└── contextualize.sh # (Optional utility for gathering file context - not part of core chat flow)
└── README.md      # This file```

## Examples

### Code Assistance

```bash
# Explain a piece of code
cat utils.js | hey "Explain this JavaScript function"

# Generate a commit message from staged changes
git diff --staged | hey "Write a concise git commit message for these changes"

# Suggest refactoring improvements
cat old_code.java | hey --code "Suggest improvements for this Java code"```

### System Administration

```bash
# Analyze system logs for errors (requires appropriate permissions)
journalctl -n 50 --no-pager | hey "Summarize any errors or warnings in these logs"

# Explain a configuration file
cat /etc/nginx/nginx.conf | hey "Explain the main sections of this Nginx config"
```

## Contributing

1.  Fork the repository.
2.  Create your feature branch (`git checkout -b feature/AmazingFeature`).
3.  Commit your changes (`git commit -m 'Add some AmazingFeature'`).
4.  Push to the branch (`git push origin feature/AmazingFeature`).
5.  Open a Pull Request.

## License

MIT

---

**Security Note:** Keep API keys secure. Avoid committing them directly into configuration files stored in version control. Use environment variables or secure secret management solutions.
