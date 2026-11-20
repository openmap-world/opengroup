# OpenGroup

<img src="art/icon.png" width="128" alt="OpenGroup icon">

A group finder addon for WoW Forever that shows groups from every shard, not just yours. It's made by the creator of [OpenMap](https://github.com/openmap-world/openmap).

In Forever the Group Finder, Trade and LookingForGroup only show players on your own shard. OpenGroup users share their listings with each other through addon messages, so you can find and join groups on other shards too.

OpenGroup is free and always will be. If you'd like to support it, you can buy me a coffee on [Ko-fi](https://ko-fi.com/jigrobbulus).

## Features

- Browse groups and players from all shards, starting with your level, in columns you can sort, grouped by activity
- Search and filter by name, activity, category, shard or level
- See groups from the game's Group Finder and LFG chat on your own shard as well
- List your group, or yourself, for a dungeon, zone, quest or anything else, with a short note
- Set each open spot's role, class and level, and auto invite people who fit
- Your party sees your group's listing in their OpenGroup too
- A Whispers tab with your conversations, the people you know through OpenGroup first
- Right-click a player to whisper, invite, ask to join, add as a friend or ignore
- Shift-click a quest in your log to see who else is on it
- Warlock summons and battleground queue requests
- Post your listing in LookingForGroup chat, or tell your party, when you list (both optional)
- Minimap button, and a tab on the game's Group Finder

## How it works

OpenGroup talks to other players who have it installed using hidden addon whispers, which work across shards. It finds them through your friends list, guild, party, whispers, `/who` and LFG chat, and every user it finds tells it about a few more.

Listings are re-sent every 90 seconds and expire 5 minutes after the last update. Other users can see your character name, level, class, shard, what you listed for, your roles and your note.

Nothing is posted in public chat unless you leave "Post in LFG chat" ticked.

## Privacy

OpenGroup only talks to other players who run it, through the game's hidden addon messages. It has no internet access and sends nothing anywhere else. What other users can see is listed above. Players on your ignore list are hidden everywhere in OpenGroup, and their messages are ignored.

## Install

Install it from [CurseForge](https://www.curseforge.com/projects/1818236), or download the zip from the [releases](https://github.com/openmap-world/opengroup/releases) and copy the `OpenGroup` folder into `World of Warcraft\_forever_\Interface\AddOns`.

Type `/og` or click the minimap button to open it.

| Command | |
| --- | --- |
| `/og` | Open or close the window |
| `/og auto` | Turn auto invite on or off |
| `/og compact` | Turn compact rows on or off |
| `/og minimap` | Hide or show the minimap button |
| `/og status` | Show what OpenGroup can see, for bug reports |

## Bugs and feedback

This is a beta and it hasn't been tested with a lot of players yet. If something isn't working, please [open an issue](https://github.com/openmap-world/opengroup/issues) and include the output of `/og status`.

## Development

The addon is plain Lua with no libraries. The message format is described at the top of `OpenGroup/Proto.lua`.

The tests run outside the game:

```
python3 -m pip install lupa
python3 -I tools/test.py OpenGroup
python3 -I tools/ui_smoke.py OpenGroup
```

To work on it in game, link the folder into your AddOns folder (PowerShell, as administrator):

```
New-Item -ItemType SymbolicLink -Path "C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\OpenGroup" -Target "$PWD\OpenGroup"
```

## About Claude

I'm using Claude (Anthropic's AI) as a coding partner: it helps write and review code and helps me run the open-source side (reviewing pull requests and so on).

## Licence

MIT, see [LICENSE](LICENSE).
