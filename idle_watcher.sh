#!/bin/bash

# This script monitors user idle time on a GNOME desktop (like Ubuntu 24.04).
# When idle time exceeds a threshold, it executes a specified script.

# --- Configuration ---

# The idle time to wait for, in minutes.
IDLE_TIME_MINUTES=1

# The path to the Python script to run.
# This assumes 'play_videos.py' is in the SAME directory as this script.
SCRIPT_PATH="$(dirname "$0")/play_videos.py"

# --- End Configuration ---

# Convert minutes to milliseconds for the gdbus command
IDLE_TIME_MS=$((IDLE_TIME_MINUTES * 60 * 1000))

echo "Idle watcher started."
echo "Will run script after $IDLE_TIME_MINUTES minutes (${IDLE_TIME_MS}ms) of inactivity."
echo "Watching for user idle time..."

# Function to get current idle time in milliseconds
get_idle_time_ms() {
    local idle_time_str
    local idle_time_ms="0" # Default to 0

    # First, try to use xprintidle (common on X11)
    # This requires 'sudo apt install xprintidle'
    if command -v xprintidle &> /dev/null; then
        idle_time_ms_check=$(xprintidle 2>/dev/null)
        # Check if xprintidle output is a valid number
        if [[ "$idle_time_ms_check" =~ ^[0-9]+$ ]]; then
            echo "$idle_time_ms_check"
            return
        fi
    fi

    # If xprintidle fails or isn't installed, try the gdbus method (common on Wayland)
    idle_time_str=$(gdbus call --session \
        --dest org.gnome.Mutter.IdleMonitor \
        --object-path /org/gnome/Mutter.IdleMonitor \
        --method org.gnome.Mutter.IdleMonitor.GetIdletime 2>/dev/null)
    
    # The output is like "(uint64 123456,)"
    # We parse out the number.
    idle_time_ms_check=$(echo "$idle_time_str" | cut -d' ' -f2 | tr -d ',)')

    # Final check to ensure we have a number
    if [[ "$idle_time_ms_check" =~ ^[0-9]+$ ]]; then
        echo "$idle_time_ms_check"
    else
        # If all methods fail, echo 0 to prevent script errors
        echo "$idle_time_ms"
    fi
}


# Main loop
while true; do
    CURRENT_IDLE_MS=$(get_idle_time_ms)

    if [ "$CURRENT_IDLE_MS" -ge "$IDLE_TIME_MS" ]; then
        echo "Idle for ${CURRENT_IDLE_MS}ms. Threshold of ${IDLE_TIME_MS}ms reached."
        echo "Running video script: $SCRIPT_PATH"
        
        # Run the python script
        "$SCRIPT_PATH"
        
        echo "Video script finished. Waiting for user activity to resume watching..."
        
        # Wait until the user is no longer idle
        # This prevents the script from re-launching immediately
        while [ "$CURRENT_IDLE_MS" -ge "$IDLE_TIME_MS" ]; do
            sleep 5 # Check every 5 seconds for activity
            CURRENT_IDLE_MS=$(get_idle_time_ms)
        done
        
        echo "User is active. Resuming idle watch."
    fi
    
    # How often to check the idle time
    sleep 10
done
