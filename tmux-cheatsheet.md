# tmux Cheatsheet

Prefix key is Ctrl+a (remapped from default Ctrl+b)
Written for: tmux 3.3a with custom config

---

## Core concepts

```
server      runs inside the container, always alive even when you disconnect
session     a named workspace — survives detaching and reconnecting
window      a tab inside a session — full screen terminal
pane        a split inside a window — multiple terminals side by side
```

Hierarchy: server -> sessions -> windows -> panes

---

## Starting tmux

```bash
tmux                        # start a new session
tmux new -s name            # start a new session with a name
tmux attach                 # reattach to the last session
tmux attach -t name         # reattach to a specific named session
tmux ls                     # list all running sessions
tmux kill-server            # kill everything — all sessions destroyed
```

---

## Sessions

```
Ctrl+a d          detach — leave session running in background
Ctrl+a s          show all sessions (interactive switcher)
Ctrl+a $          rename current session
Ctrl+a (          switch to previous session
Ctrl+a )          switch to next session
```

Detach vs close:
- Detach (Ctrl+a d): you leave, session keeps running, all processes alive
- Kill session: everything in it is destroyed permanently

---

## Windows (tabs)

```
Ctrl+a c          new window (opens in current directory)
Ctrl+a ,          rename current window
Ctrl+a n          next window
Ctrl+a p          previous window
Ctrl+a 1-9        jump to window by number (starts at 1 with this config)
Ctrl+a &          close current window (kills all its panes)
Ctrl+a w          interactive window list
```

---

## Panes (splits)

```
Ctrl+a |          split vertically (side by side)
Ctrl+a -          split horizontally (top and bottom)
Ctrl+a x          close current pane
Ctrl+a z          zoom pane to full screen (toggle)
Ctrl+a space      cycle through pane layouts
```

Nvim-aware navigation (works in both tmux panes and nvim splits):

```
Ctrl+h            move left
Ctrl+j            move down
Ctrl+k            move up
Ctrl+l            move right
```

When the current pane is running nvim, these keys go to nvim.
When in a shell pane, they navigate between tmux panes.

---

## Copy mode (vi keys)

```
Ctrl+a [          enter copy mode
q                 exit copy mode
/                 search forward
?                 search backward
v                 start selection (visual mode)
y                 copy selection and exit copy mode
Ctrl+a ]          paste
```

Navigation in copy mode uses standard vi keys: h j k l, Ctrl+d, Ctrl+u, g, G

---

## Config

```
Ctrl+a r          reload ~/.tmux.conf without restarting tmux
```

Config file location: ~/.tmux.conf

---

## tmux-sessionizer

Press Ctrl+f inside nvim to open a floating fzf picker of your project folders.
Pick a project, press Enter — tmux switches to that session (or creates it).

```bash
# Also callable directly from the shell
tmux-sessionizer

# Or pass a path directly without fzf
tmux-sessionizer ~/workspace/donbass-post
```

The sessionizer creates sessions named after the folder.
Switching to an existing session preserves everything running in it.

---

## Daily workflow

```bash
# Enter container
docker compose exec app zsh

# Start or reattach to tmux
tmux attach || tmux

# Pick a project with sessionizer (from inside nvim: Ctrl+f)
# or from shell:
tmux-sessionizer

# Work in that session
# Ctrl+a c    new window for dev server
# Ctrl+a c    another window for gemini

# Leave without killing anything
Ctrl+a d

# Next day — reattach, everything still running
docker compose exec app zsh
tmux attach
```

---

## Session naming convention (suggestion)

```
donbass-post      backend/frontend work for that project
donbass-tour      same
scratch           throwaway experiments
gemini            dedicated gemini CLI session
```

---

## Mouse support

Mouse is enabled. You can:
- Click to select a pane
- Scroll to scroll back through output
- Click a window tab to switch to it

---

## Useful one-liners

```bash
# Kill a specific session by name
tmux kill-session -t donbass-post

# Rename a session from outside
tmux rename-session -t old-name new-name

# Run a command in a new session without attaching
tmux new -d -s build -c ~/workspace/donbass-post "npm run build"

# See all key bindings
tmux list-keys
```
