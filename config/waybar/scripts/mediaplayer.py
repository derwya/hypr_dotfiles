#!/usr/bin/env python3
import json
import subprocess
import sys


def get_player_status():
    try:
        # Get all active players
        result = subprocess.run(
            ["playerctl", "-l"], capture_output=True, text=True, timeout=1
        )

        if result.returncode != 0 or not result.stdout.strip():
            return None

        players = result.stdout.strip().split("\n")

        # Prioritize players
        priority = [
            "spotify",
            "youtubemusic",
            "youtube",
            "vlc",
            "mpv",
            "soundcloud",
            "tidal",
            "deezer",
            "apple-music",
            "zen",
            "firefox",
            "chromium",
            "brave",
            "edge",
            "opera",
        ]
        selected_player = None

        for p in priority:
            for player in players:
                if p in player.lower():
                    selected_player = player
                    break
            if selected_player:
                break

        if not selected_player:
            selected_player = players[0]

        # Get metadata
        metadata = {}
        for key in ["artist", "title", "status"]:
            try:
                result = subprocess.run(
                    [
                        "playerctl",
                        "-p",
                        selected_player,
                        "metadata",
                        "--format",
                        f"{{{{ {key} }}}}",
                    ],
                    capture_output=True,
                    text=True,
                    timeout=1,
                )
                if result.returncode == 0:
                    metadata[key] = result.stdout.strip()
            except:
                pass

        if not metadata.get("title"):
            return None

        # Determine icon class with more specificity
        player_lower = selected_player.lower()

        # Check URL for YouTube Music specifically
        try:
            url_result = subprocess.run(
                [
                    "playerctl",
                    "-p",
                    selected_player,
                    "metadata",
                    "--format",
                    "{{ xesam:url }}",
                ],
                capture_output=True,
                text=True,
                timeout=1,
            )
            url = url_result.stdout.strip() if url_result.returncode == 0 else ""

            if "music.youtube.com" in url:
                icon_class = "youtubemusic"
            elif "youtube.com" in url or "youtu.be" in url:
                icon_class = "youtube"
            elif "soundcloud.com" in url:
                icon_class = "soundcloud"
            elif "tidal.com" in url:
                icon_class = "tidal"
            elif "deezer.com" in url:
                icon_class = "deezer"
            elif "music.apple.com" in url:
                icon_class = "apple-music"
            elif "spotify" in player_lower:
                icon_class = "spotify"
            elif "vlc" in player_lower:
                icon_class = "vlc"
            elif "mpv" in player_lower:
                icon_class = "mpv"
            elif "zen" in player_lower:
                icon_class = "zen"
            elif "firefox" in player_lower:
                icon_class = "firefox"
            elif "chromium" in player_lower:
                icon_class = "chromium"
            elif "brave" in player_lower:
                icon_class = "brave"
            elif "edge" in player_lower:
                icon_class = "edge"
            elif "opera" in player_lower:
                icon_class = "opera"
            else:
                icon_class = "default"
        except:
            icon_class = "default"

        # Format output
        artist = metadata.get("artist", "Unknown Artist")
        title = metadata.get("title", "Unknown Title")
        status = metadata.get("status", "Playing")

        # Truncate if too long
        if len(artist) + len(title) > 45:
            if len(title) > 30:
                title = title[:27] + "..."
            if len(artist) > 20:
                artist = artist[:17] + "..."

        text = f"{artist} - {title}"

        output = {
            "text": text,
            "tooltip": f"{artist}\n{title}\n{status}",
            "class": icon_class,
            "alt": status.lower(),
        }

        return output

    except Exception as e:
        return None


if __name__ == "__main__":
    status = get_player_status()

    if status:
        print(json.dumps(status))
    else:
        # No media playing
        print(
            json.dumps(
                {"text": ":3", "tooltip": "No media playing", "class": "default"}
            )
        )

    sys.stdout.flush()

