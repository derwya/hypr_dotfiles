#!/bin/bash

# Check if any player is active
if ! playerctl status &>/dev/null; then
    echo '{"text":"","class":"inactive","alt":"inactive"}'
    exit 0
fi

STATUS=$(playerctl status 2>/dev/null)

case "$1" in
    play)
        if [ "$STATUS" = "Playing" ]; then
            echo '{"text":"","class":"playing","alt":"playing"}'
        else
            echo '{"text":"","class":"paused","alt":"paused"}'
        fi
        ;;
    prev)
        echo '{"text":"󰒮","class":"active","alt":"active"}'
        ;;
    next)
        echo '{"text":"󰒭","class":"active","alt":"active"}'
        ;;
    *)
        echo '{"text":"","class":"inactive","alt":"inactive"}'
        ;;
esac
