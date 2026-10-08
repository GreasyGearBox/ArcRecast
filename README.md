# ArcRecast

**Author:** Mr.Bear  
**Platform:** Ashita 4 · Phoenix XI  
**Version:** 1.0.3

ArcRecast is a clean, updated ability recast tracker with a separate alert window that briefly displays the names of abilities as they become available.

## Features

- **Cooldown Tracker:** Displays ability names, countdown timers, and colored bars representing the time remaining on each cooldown.
- **Reverse Countdown:** At 20 seconds remaining, the draining bar reverses direction and begins filling until the ability is ready.
- **Ready Alerts:** When an ability comes off cooldown, its name briefly appears in a separate alert window before fading away.
- **Customizable Layout:** The recast tracker and alert window can be positioned and configured independently.

## Installation

1. Create a folder named `arcrecast` in your Ashita `addons` directory.
2. Extract the addon files into that folder. The entry file should be `addons/arcrecast/arcrecast.lua`.
3. In-game, enter `/addon load arcrecast`.
4. Use `/arcrecast` to open the configuration window.
5. Use `/arcrecast help` to see available commands.

Settings are saved automatically.

## Notes

ArcRecast runs independently of ArcUI. If using both, disable ArcUI's cooldown list and Ready notices to avoid duplicate displays.

The supplied Rajdhani font is distributed under the SIL Open Font License; see `arcrecast/assets/OFL.txt`. The addon source is licensed under the MIT License; see `LICENSE`.
