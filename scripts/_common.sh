#!/bin/bash

#=================================================
# COMMON VARIABLES
#=================================================

OPENWEBUI_VERSION="0.8.10"

#=================================================
# COMMON HELPERS
#=================================================

# Wait for the app to respond on its port
wait_for_port() {
    local port="$1"
    local timeout="${2:-120}"
    local i=0
    while [ "$i" -lt "$timeout" ]; do
        if curl -s -o /dev/null -w '' "http://127.0.0.1:$port/" 2>/dev/null; then
            return 0
        fi
        sleep 5
        i=$((i + 5))
    done
    return 1
}
