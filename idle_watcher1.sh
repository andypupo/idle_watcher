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


# --- NEW FUNCTION ---
# Function to check if the screen is locked
# Returns 0 (shell success) if locked, 1 (shell failure) if unlocked.
is_screen_locked() {
    local lock_status
    # Use gdbus to check the standard GNOME screensaver service
    lock_status=$(gdbus call --session \
        --dest org.gnome.ScreenSaver \
        --object-path /org/gnome/ScreenSaver \
        --method org.gnome.ScreenSaver.GetActive 2>/dev/null)
    
    # Output is like "(boolean true,)" or "(boolean false,)"
    if [[ "$lock_status" == *"true"* ]]; then
        return 0 # 0 means "true" (locked)
    else
        return 1 # 1 means "false" (not locked)
    fi
}


# Main loop
while true; do
    CURRENT_IDLE_MS=$(get_idle_time_ms)

    # --- MODIFIED LOGIC ---
    # Check BOTH conditions:
    # 1. Is the user idle long enough?
    # 2. Is the screen NOT locked? (Note the '!' to invert the function's success)
    if [ "$CURRENT_IDLE_MS" -ge "$IDLE_TIME_MS" ] && ! is_screen_locked; then
        echo "Idle for ${CURRENT_IDLE_MS}ms and screen is UNLOCKED. Threshold reached."
        echo "Running video script: $SCRIPT_PATH"
        
        # Run the python script
        "$SCRIPT_PATH"
        
        echo "Video script finished. Waiting for user activity or screen lock..."
        
        # Wait until the user is no longer idle OR the screen gets locked
        # This prevents the script from re-launching immediately
        CURRENT_IDLE_MS=$(get_idle_time_ms) # Re-check idle time before loop
        while [ "$CURRENT_IDLE_MS" -ge "$IDLE_TIME_MS" ] && ! is_screen_locked; do
            sleep 5 # Check every 5 seconds for activity or lock
            CURRENT_IDLE_MS=$(get_idle_time_ms)
        done
        
        echo "User is active or screen is locked. Resuming idle watch."

    # Added this 'elif' for clearer logging
    elif [ "$CURRENT_IDLE_MS" -ge "$IDLE_TIME_MS" ]; then
        echo "Idle for ${CURRENT_IDLE_MS}ms, but screen is LOCKED. Skipping script."
    fi
    
    # How often to check the idle time
    sleep 10
done
