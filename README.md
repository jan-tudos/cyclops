# Cyclops
Simple and convinent TUI for the OBSBOT Tiny 4k webcam (or any other webcam controllable via `v4l2-ctl`).

The OBSBOT webcam allows to adjust its tilt, pan, and zoom via software.
Unfortunately, there seems to be no implementation that supports convenient WASD controls instead of providing raw numerical values.
This script provides a simple TUI (text user interface) for just that.
In addition, the TUI can also store up to 10 configurations to easily switch between, e.g. focusing on (1) the speaker of a presentation, (2) the blackboard, (3) an experimental setup, and (4) the presentation slides.

# Prerequists
- webcam ;-)
- `v4l2-tl`
- optional: `ffplay` for a quick preview

# Setup
- copy the script
- optional: adjust the defaults and number key mappings (default: QWERTZ keyboard) in the beginning of the script

# Usage
- Start the script and, optionally, pass the device file of the webcam to control (default: `/dev/video0`).
- Controls
  - move camera (use upper case lettern for larger increase/decrease)
    - `a` + `d` = pan 
    - `w` + `s` = tilt
    - `e` + `c` = zoom
  - store configuration: `<Ctrl> + <number`
  - restore configuration: `<Ctrl> + <Shift> + <number>`
  - `p` = open preview window
  - quit: `<ESC>` (or just `kill`/`<Ctrl> + c` it)
