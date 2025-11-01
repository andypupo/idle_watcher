#!/usr/bin/env python3

"""
This script plays a specified number of random video files from a
directory using VLC.
"""

import sys
import random
import subprocess
from pathlib import Path

# --- Configuration ---

# IMPORTANT: Update this path to your video directory.
# The path you gave was "/home/andrea/Videos/'China 2025'".
# This script assumes the directory is named "China 2025" (with a space).
# If the name is different, please correct it here.
VIDEO_DIR = Path("/home/andrea/Videos/China 2025")

# Number of random videos to pick and play
NUM_VIDEOS = 20

# Valid video file extensions to look for
VIDEO_EXTENSIONS = {".mp4", ".mkv", ".avi", ".mov", ".flv", ".webm"}

# --- End Configuration ---

def play_videos():
    """
    Finds and plays random videos from the configured directory.
    """
    if not VIDEO_DIR.is_dir():
        print(f"Error: Directory not found: {VIDEO_DIR}", file=sys.stderr)
        print("Please check the VIDEO_DIR path in this script.", file=sys.stderr)
        sys.exit(1)

    # Find all video files by matching extensions
    try:
        all_videos = [
            f for f in VIDEO_DIR.iterdir()
            if f.is_file() and f.suffix.lower() in VIDEO_EXTENSIONS
        ]
    except PermissionError:
        print(f"Error: Permission denied for directory: {VIDEO_DIR}", file=sys.stderr)
        sys.exit(1)

    if not all_videos:
        print(f"Error: No videos with extensions {VIDEO_EXTENSIONS} found in {VIDEO_DIR}", file=sys.stderr)
        sys.exit(1)

    # Select random videos
    # If there are fewer videos than NUM_VIDEOS, it will play all of them
    num_to_play = min(NUM_VIDEOS, len(all_videos))
    selected_videos = random.sample(all_videos, num_to_play)

    # Build the VLC command
    # --fullscreen: Start in fullscreen
    # --play-and-exit: Exit VLC after the playlist is finished
    command = ["mplayer", "-fs"] + [str(p) for p in selected_videos]

    print(f"Playing {num_to_play} random video(s) from {VIDEO_DIR}...")
    
    try:
        # Run the VLC command
        subprocess.run(command, check=True)
    except FileNotFoundError:
        print("Error: 'vlc' command not found.", file=sys.stderr)
        print("Please make sure VLC is installed: sudo apt install vlc", file=sys.stderr)
        sys.exit(1)
    except subprocess.CalledProcessError as e:
        print(f"Error during VLC execution: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"An unexpected error occurred: {e}", file=sys.stderr)
        sys.exit(1)

    print("VLC playback finished.")

if __name__ == "__main__":
    play_videos()
