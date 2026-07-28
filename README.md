# Thaydor

## Overview of Thaydor
Thaydor is a 2D dungeon realtime multiplayer death match game run in a console.

## Description

Thaydor is a death match multiplayer dungeon game, the object is to
kill other players explore the map and utilize treasures.  In the
screenshot below the current player is represented by the white
triangle and the anonymous other player is represented by the blue
triangle.

The walls are in red and closed doors in white and an unspecified
treasure exists on the edge of the middle left wall.

The game occurs in realtime, a player becomes tired with movement
and health (Wounds) will slowly regenerate.

## User control summary

```
F1 help
F2 inventory
ESC ESC to quit
```

### Complete key descriptions

```
Cursor L/R/U/D   Turn or move one square
SHIFT Cursor     Move 9 spaces forward or turn
ALT Cursor       Fire magic arrow forward or move 1 perpendicular
CTRL Cursor      Turn or fire normal arrow
'1'..'9'         move 1..9 squares forward
'a'              attack with sword
'c'              close door in front of you
'd' <no> <ret>   drop treasure in front of you
'e'              examine wall for secret door in front of you
'f'              fire normal arrow
'g'              get treasure in front of you
'h'              help
'i'              inventory
'l'              turn left
'm'              fire magic arrow
'o'              open door in front of you
'p'              parry with sword
'q'              checkpoint status
'r'              turn right
's' ... <ret>    speak
't'              thrust with sword
'u' <no> <ret>   use treasure
'v'              vault turn
'x'              fire blow dart
F11              toggle full screen
F12              toggle animation mode
ESC ESC          quit
```

[![Product Name Screen Shot][product-screenshot]]

## Treasures

1. Magic Key.

A single use treasure which will convert a closed door into a
secret for a short while.

3. Magic Spring.

Teleports the player somewhere random in the map.
The spring also is teleported elsewhere.

4. Sack Of Coal.

A cursed sack which is heavy and can only be dropped in
a random room.

5. Sack Of Coal.

A cursed sack which is heavy and can only be dropped in
a random room.

6. Hot Iron.

A cursed treasure which inflicts minor damage to the owner when picked up.

7. Hand Grenade.

This treasure can be used, as such the pin is pulled and it will
detonate in about half a minute.  Every player within the room
will experience sizeable damage.

8. Magic Sword.

Inflicts higher damage and uses slightly less effort to wield.

9. Magic Shoes.

Allows the owner to move with less effort.

10. Sleep Potion.

Causes the user to sleep for about half a minute.

11. Lump of Iron.

A repelling magnet.  All treasures owned by every player in this room is scattered randomly in the dungeon.

12. Treasure Trove.

Describes the location of all unheld treasures.

13. Speed Potion.

Increases the scheduling priority of the player.

14. Magic Shield.

Reflects normal arrows and blow darts.

16. Arrow Quiver.

More normal arrows.

17. Magic Arrows.

More magic arrows.

18. Salve.

Increases the players health.

19. GPS.

Can be used to reveal the coordinates of the player in the dungeon.

20. Infinite Quiver.

Provides the owner with infinite arrow or blow darts.

21. Blow Dart.

If owned then the player can fire freeze darts using 'x'.
If the freeze dart hits a player it causes the recipient to
freeze for 3 seconds.

22. Magic Goggles.

Reveals all secret doors to the owner of this treasure.

## Installation

0. Install GNU/Linux.

1. Install dependencies.
   ```sh
   apt install flex gm2 make
   ```

2. Clone repository.
   ```sh
   git clone https://github.com/gaiusm/thaydor
   ```

3. Build source code.
   ```sh
   cd thaydor
   mkdir build
   cd build
   ../configure
   make
   ```

4. Run server.
   ```sh
   ./server/thaydorserver ../maps/star
   ```
   ../maps/star is a tiny five room training map.
   ../maps/m1 and ../maps/m2 are larger 40 room maps.

5. Run client local to the server.
   ```sh
   ./client/thaydor
   ```

6. Or run the client on a different machine.
   ```sh
   ./client/thaydor servername:7000
   ```

## About

Thaydor is mostly in written Modula-2, most of the server code was
written in 1985 and 1986.  It originally ran on a 4.77 Mhz 8086
supporting two serial consoles and the main PC screen.  The current
implementation uses the GNU Modula-2 coroutine library, sockets, ANSI
colours a limited amount of Unicode glyphs.

The client has recently been written and the server has been overhauled
to implement different character classes, limited animation and many more
treasures.

## Authors
Gaius Mulley <gaiusmod2@gmail.com>

## License

This project is licensed under the GPLv3 License - see the COPYING
file for details.

## Acknowledgements
Inspired by a single player game The Temple of Apshai.

[product-screenshot]: images/screenshot.png