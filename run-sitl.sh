#!/usr/bin/env bash
set -eu
world=iris_runway.sdf
defaults=/opt/gazebo/lucid-sitl.parm
if [[ ${TOF:-0} == 1 ]]; then
    world=lucid_tof.sdf
    defaults+=,/opt/gazebo/tof.parm
fi
options=(-s --headless-rendering)
if [[ ${GUI:-0} == 1 ]]; then
    options=()
fi
gz sim "${options[@]}" -r -v 3 "$world" &
simulator=$!
arducopter --model JSON --home=-35.363262,149.165237,584,0 \
    --defaults "$defaults" --serial0 tcp:0:nowait &
controller=$!
trap 'kill "$simulator" "$controller" 2>/dev/null || true' EXIT
trap 'exit 0' INT TERM
wait -n "$simulator" "$controller"
