#!/bin/bash
# Usage: ./debug.sh [commands]
# 	if not exist commands, it will start a bash shell.

ct_name="debug-$(uuidgen)"

if [ $# -gt 0 ]; then
	kubectl run "$ct_name" --rm -i --restart='Never' \
		--image ghcr.io/efficacy38/debug-container:master -- sh -c "$@"
else
	kubectl run "$ct_name" --rm -it --restart='Never' \
		--image ghcr.io/efficacy38/debug-container:master -- bash
fi

