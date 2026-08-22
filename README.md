# Nt_Holdem

## [Showcase](https://www.youtube.com/watch?v=vqeU-jXScK4)

Nt_Holdem is a server-authoritative multiplayer Texas Hold'em resource for RedM. It supports the RSG and VORP frameworks and includes native poker animations, synchronized cards and props, NPC players, spectator support, configurable stakes, and multiple table locations.

## Features

- Two to six human and NPC players with a rotating dealer  
- Sequential shuffled 52-card deck; cards are never randomly selected during a hand  
- Check, Call, Raise, Fold, and All In with configurable blinds and betting limits  
- Flop, turn, river, showdown, split pots, and complete Texas Hold'em hand evaluation  
- Server-side cards, action validation, cash debits, and payouts  
- PolyZone-pulled NPC players with configurable personalities and spectator rendering  
- Synchronized native poker animations, cards, chips, and table props  
- Full-screen NUI with bundled card styles, camera controls, and UI scaling  
- Configurable stakes and card decks selected when a table is opened  
- Additional tables can be added by duplicating a single keyed config entry  

## Requirements

- A RedM server  
- `rsg-core` or `vorp_core`  

## Installation

1. Place `Nt_Holdem` in your server's resources folder.  
2. Set `Config.Framework` in `shared/config.lua` to `RSG` or `VORP`.  
3. Configure stakes, NPC behavior, and general settings in `shared/config.lua`.  
4. Configure table locations and seating in `shared/configTables.lua`.  
5. Add `ensure Nt_Holdem` to your server configuration after your framework resource.  

Players can approach an enabled poker table and use the configured interaction key to join a game.  

## License and Warranty

This project's source code is licensed under the GNU General Public License v3.0 (GPL-3.0). See the LICENSE file for details.  
TThis software is provided WITHOUT ANY WARRANTY. See the GNU GPLv3 for details.

Images and screenshots derived from Red Dead Redemption 2 are not covered by this license and remain the property of their respective rights holders. Red Dead Redemption 2 © Rockstar Games / Take-Two Interactive.
