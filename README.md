# Cyclops
Simple and convenient TUI for the OBSBOT Tiny 4k webcam (or any other webcam controllable via `v4l2-ctl`).

The OBSBOT webcam allows to adjust its tilt, pan, and zoom via software; i.e. it's a pan-tilt-zoom (PTZ) camera.
Unfortunately, there seems to be no implementation that supports convenient WASD controls instead of providing raw numerical values.
This script provides a simple TUI (text user interface) for that purpose.
In addition, the TUI can also store up to 10 configurations to easily switch between, e.g. focusing on (1) the speaker of a presentation, (2) the blackboard, (3) an experimental setup, (4) the presentation slides, ...

# Prerequists
- webcam ;-)
- `v4l2-tl`
- optional: `ffplay` for preview

# Setup
- copy the script
- optional: adjust the defaults and number key mappings (default: QWERTZ keyboard) in the beginning of the script

# Usage
- Start the script and, optionally, pass the device file of the webcam to control (default: `/dev/video0`).
- Controls
  - move camera (use upper case letters for larger steps)
    - pan:  `a` + `d`
    - tilt: `w` + `s`
    - zoom: `e` + `c`
  - reset camera to "forward" direction: `r`
  - save configuration: `<Shift> + <number>`
  - apply configuration: `<number`
  - open preview window: `p`
  - quit: `<ESC>` (or just `kill`/`<Ctrl> + c` it)
