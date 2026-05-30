# Gemini CLI Workflow Reference

## Starting a session

```bash
gemini
```

Always run one of these at the start:

```
/strict    # mentor mode — default, resists giving direct answers
/relax     # deadline/lab mode — direct answers allowed if explicitly asked
```

---

## Feeding context — @ syntax

Type these directly inside a live gemini session as your message.

```
@path/to/file.ts          # inject a single file into the conversation
@src/                     # inject an entire folder
@repomix-output.md        # feed your whole codebase packed by repomix
```

Example for code review:

```bash
# 1. Pack the codebase from inside the project folder
bash repomix.sh

# 2. Start gemini
gemini

# 3. Feed it and ask
@repomix-output.md find weaknesses, missed patterns, maintenance problems
```

---

## Memory and context

```
/memory show              # see exact concatenated context Gemini is working with
                          # use this to verify GEMINI.md and commands loaded correctly
/memory add <text>        # append something permanently to ~/.gemini/GEMINI.md
```

Example:

```
/memory add I tend to forget null checks when working with optional chaining
```

That gets saved permanently to your global GEMINI.md immediately.

---

## Saving and resuming sessions

```
/chat save my-session     # saves conversation to a file
/chat resume my-session   # resumes it in a future session
```

Useful for deep learning sessions you want to continue the next day without
losing context. The conversation history is preserved exactly.

---

## Checking available tools and commands

```
/tools      # shows what Gemini can touch: files, shell, web search
/commands   # lists all your custom slash commands
/help       # general help
```

---

## Custom commands location

```
~/.gemini/commands/strict.toml    ->  /strict
~/.gemini/commands/relax.toml     ->  /relax
```

To add a new command, create a new .toml file in that folder:

```toml
description = "Short description of what this command does"

prompt = """
Your prompt text here.
Can be multiple lines.
"""
```

---

## File structure

```
~/.gemini/
├── GEMINI.md              # permanent context: who you are, how you learn
└── commands/
    ├── strict.toml        # /strict — mentor mode
    └── relax.toml         # /relax  — deadline mode
```

---

## Daily workflow

```
gemini          # start session
/strict         # working on your projects — growth mode
# or
/relax          # Python labs, coursework, deadline pressure

@src/auth.ts    # reviewing a specific file
# or
@repomix-output.md review this for weaknesses
```

---

## Repomix integration

Your repomix.sh script packs the entire codebase into a single markdown file
that you can feed to Gemini for a full codebase review.

```bash
# Run from inside your project folder
bash repomix.sh

# Then inside gemini:
@repomix-output.md review this for weaknesses and missed patterns
```

The output file is gitignored — safe to regenerate anytime.

---

## MCP servers (future)

Gemini CLI supports MCP (Model Context Protocol) servers for external integrations.
Add notes here as you explore them.

```
# TODO: explore filesystem MCP for deeper project navigation
```
