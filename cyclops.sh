#!/usr/bin/env bash

#####
# configurables
#####
#
# default camera device
declare -r DEV_DEFAULT='/dev/video0'
#
# what you get when you press shift + <number> (mapping to the number)
declare -rA UPPER_DIGITS=(['!']=1 ['"']=2 ['§']=3 ['$']=4 ['%']=5 ['&']=6 ['/']=7 ['(']=8 [')']=9 ['=']=0)
#####


# using info from
# - https://github.com/dylanaraps/writing-a-tui-in-bash
# - https://stackoverflow.com/a/24016147
function save_term()
{
	# save current terminal content
	printf '\e[?1049h'

	# hide cursor
	printf '\e[?25l'
}

function restore_term()
{
	# show cursor
	printf '\e[?25h'

	# restore saved terminal content
	printf '\e[?1049l'
}

function clear_term()
{
	printf '\e[2J'
}

function write_at()
{
	declare -ri X=$1 Y=$2
	declare -r TXT=$3

	printf '\e[%d;%dH%s' "$Y" "$X" "$TXT"
}

declare -Ai MIN MAX STEP VAL
declare -a SAVED
declare STATUS
declare DEV


function init()
{
	DEV=$1

	# do we have v4l2-ctl?
	if ! type -p v4l2-ctl &> /dev/random; then
		echo '"v4l2-ctl" is not available in default PATH' >&2
		exit 1
	fi

	if [[ -z "$DEV" ]]; then
		DEV=$DEV_DEFAULT
		printf -v STATUS 'No video device specified, using default "%s".' "${DEV}"
	fi
	readonly DEV

	declare -r CONTROLS=$(v4l2-ctl -d "$DEV" -L 2>/dev/random)
	declare -i CUR_MIN CUR_MAX CUR_STEP CUR_VAL
	declare CTRL

	if [[ -z "$CONTROLS" ]]; then
		# output explicitly or it will be lost ... like tears in rain
		[[ -n "${STATUS}" ]] && echo "${STATUS}" >&2
		printf 'Could not open camera "%s".\n' "${DEV}" >&2
		exit 2
	fi

	while read -r; do
		# get 'min', 'max', 'step', 'value' for all lines with '_absolute'
		[[ "$REPLY" =~ ^[[:blank:]]+([[:lower:]]+)_absolute\ .*\
min=([[:digit:]-]+).*\
max=([[:digit:]-]+).*\
step=([[:digit:]-]+).*\
value=([[:digit:]-]+) ]] || continue

		CTRL=${BASH_REMATCH[1],,}
		CUR_MIN=${BASH_REMATCH[2]}
		CUR_MAX=${BASH_REMATCH[3]}
		CUR_STEP=${BASH_REMATCH[4]}
		CUR_VAL=${BASH_REMATCH[5]}

		# we only care about pan, tilt, and zoom
		[[ ' pan zoom tilt ' == *"$CTRL"* ]] || continue

		# remember those in our global vars
		MIN[$CTRL]=$(( CUR_MIN / CUR_STEP + 1 ))
		MAX[$CTRL]=$(( CUR_MAX / CUR_STEP - 1 ))
		VAL[$CTRL]=$(( CUR_VAL / CUR_STEP))
		STEP[$CTRL]=$CUR_STEP
	done <<< "$CONTROLS"
	readonly MIN MAX STEP

	# sanity check
	for CTRL in pan zoom tilt; do
		if [[ -z ${MIN[$CTRL]} ]]; then
			[[ -n "${STATUS}" ]] && echo "${STATUS}" >&2 # output explicitly or it will be lost
			printf 'Video control "%s" is not available. Is "%s" the correct camera?\n' "${CTRL}" "${DEV}" >&2
			exit 3
		fi
	done
}

function set_camera()
{
	declare CTRL # avoid "inheriting" the read-only version

	v4l2-ctl -d "$DEV" \
	$(for CTRL in pan tilt zoom; do
		printf ' -c %s_absolute=%d' $CTRL $(( VAL[$CTRL] * STEP[$CTRL] ))
	done)
}

function preview()
{
	# do we have ffplay?
	if ! type -p ffplay &> /dev/random; then
		STATUS='"ffplay" is not available in default PATH'
	else
		ffplay -i "$DEV" -fflags nobuffer -f video4linux2 -framerate 60 \
		       -input_format mjpeg -video_size hd720 &>/dev/random &
	fi
}

function adjust()
{
	declare -r CTRL=$1
	declare -ri FACTOR=$2

	# update value
	(( VAL[$CTRL] += FACTOR ))

	# bounds check and enforcement
	(( ${VAL[$CTRL]} > ${MAX[$CTRL]} )) && {
		VAL[$CTRL]=${MAX[$CTRL]}
		STATUS="${CTRL} capped due to overflow"
	}
	(( ${VAL[$CTRL]} < ${MIN[$CTRL]} )) && {
		VAL[$CTRL]=${MIN[$CTRL]}
		STATUS="${CTRL} capped due to underflow"
	}

	set_camera
}

function show_tui()
{
 	clear_term
 	printf '\e[5;93m' # coloured, blinking test
	write_at 1 1 "${STATUS}"
	printf '\e[0m' # reset text to normal
	write_at 5 4 "Pan:  $(( -VAL[pan]))"
	write_at 5 5 "Tilt: ${VAL[tilt]}"
	write_at 5 6 "Zoom: ${VAL[zoom]}"
	write_at 1 9 "Saved: ${!SAVED[*]}"
	write_at 1 13 'Use w, a, s, d to pan and tilt the camera. e and c to zoom in and out. Hold Shift for larger steps.
Shift + <number> to store a state. <number> to recall a stored state.
r to reset to standard "forward" direction. p for a preview using ffplay.
ESC or Ctrl + c to exit.'
}

function save_state() {
	declare -ri SLOT=$1

	SAVED[${SLOT}]="${VAL['pan']}:${VAL['tilt']}:${VAL['zoom']}"
}

function load_state() {
	declare -ri SLOT=$1
	declare -r STATE=${SAVED[${SLOT}]}

	if [[ -z "$STATE" ]]; then
		STATUS="State \"${SLOT}\" unset!"
		return
	fi
	IFS=':' read VAL['pan'] VAL['tilt'] VAL['zoom'] <<< "$STATE"
	set_camera
}

function reset()
{
	declare CTRL

	for CTRL in pan tilt zoom; do
		VAL[$CTRL]=0
	done
	set_camera
}

function main_loop()
{
	declare -ir SMALL=1 LARGE=10
	declare -i FACTOR=1

	# read a single character
	while read -rsn1; do
		STATUS=''

		# check case & filter special keys that produce ESC sequences
		case "$REPLY" in
			[[:upper:]]) FACTOR=$LARGE ;;
			[[:lower:]]) FACTOR=$SMALL ;;
			$'\e')
				# if there is anything else in STDIN (i.e. an ESC sequence),
				# clear it; but also note the fact (we abuse FACTOR for that)
				FACTOR=0
				until ! read -rsn1 -t0; do read -rsn1; FACTOR=1; done
				(( FACTOR == 0 )) && return # ESC key pressed, we are done
				continue ;;
		esac

		case "$REPLY" in
			[aA]) adjust 'pan' $FACTOR ;;
			[dD]) adjust 'pan' $(( FACTOR *= -1 )) ;;
			[wW]) adjust 'tilt' $FACTOR ;;
			[sS]) adjust 'tilt' $(( FACTOR *= -1 )) ;;
			[eE]) adjust 'zoom' $FACTOR ;;
			[cC]) adjust 'zoom' $(( FACTOR *= -1 )) ;;
			[r]) reset ;;
			[p]) preview ;;
			[[:digit:]]) load_state "$REPLY";;
			[${!UPPER_DIGITS[@]}]) save_state "${UPPER_DIGITS[$REPLY]}";;
			*) STATUS="Unknown key '${REPLY}'! $STATUS" ;;
		esac

		show_tui
	done
}

init "$1"
save_term
trap 'restore_term' EXIT # make sure we restore everything on exit

show_tui

main_loop
