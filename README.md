# OpenGroup

**A group finder for WoW Forever that sees every shard, not just yours.**

Forever splits each realm into shards, and the Group Finder, Trade and LookingForGroup only show the one you're on. You can stand in Orgrimmar with thousands of people online and find two groups for Blackrock Depths. OpenGroup lets the players who run it share their listings with each other, whatever shard they're on, so there's always someone to group with.

OpenGroup is free and always will be. If you'd like to support it, you can buy me a coffee on [Ko-fi](https://ko-fi.com/jigrobbulus).

## What it does

- **Browse** groups and players from every shard. Filter by dungeon, zone or quest. Each row shows the level, class, roles and shard.
- **List a group, or just yourself**, in a couple of clicks. Pick your roles, then a dungeon (typing "brd" or "strat" works), a zone, a quest from your log, or anything you like. Add a note: "casual", "first time", "500 dps pumper".
- **Your own shard too.** While OpenGroup is new, Browse also shows groups from the game's Group Finder and LFM posts in LookingForGroup and Trade, so it's never empty. When you list, it can post one line in LookingForGroup for people who don't have the addon yet.
- **Leaders see everyone queued** for the same thing, with the roles you still need at the top.
- **Quests.** Shift-click a quest in your log to see who's on it, and list yourself for it in one click.
- **Warlock summons.** Warlocks list where they summon to and their price, and anyone can ask for one.
- **Battleground queues.** Stand at a battlemaster and offer to queue people, or ask someone to queue you so you can stay out in the world.
- **Tell my party.** When your group lists, OpenGroup says so in party chat. You can turn it off.
- A banner across the window and a glowing minimap eye while you're listed, and an OpenGroup tab on the game's own Group Finder.

## How it works

There's no server. Players running OpenGroup talk to each other with hidden addon whispers, which the game carries between shards. Nothing goes into a public channel unless you leave "Post in LookingForGroup" ticked when you list.

The network grows on its own. OpenGroup sends a hidden hello to people you already play with: friends, guildmates, your group, people you whisper, names from your `/who` searches and people posting in LookingForGroup. Only OpenGroup users answer. Each answer brings a few more OpenGroup players they know about, so finding one is enough to reach the rest.

A listing is passed on a couple of times and re-sent every 90 seconds while you're online. It disappears 5 minutes after the last update, so the list never fills up with people who logged off.

When you list, other OpenGroup players see your character's name, level, class and shard, what you're listed for, your roles and your note. Nothing else is sent.

## Getting started

Install it from CurseForge, or copy the `OpenGroup` folder into `World of Warcraft\_forever_\Interface\AddOns`. Then type `/og` or click the minimap eye.

| Command | What it does |
| --- | --- |
| `/og` | Open or close OpenGroup |
| `/og minimap` | Hide or show the minimap button |
| `/og shard` | Show which shard you're on |
| `/og status` | What OpenGroup can see right now (handy for bug reports) |

## Early days

This is a test release. OpenGroup gets better the more people run it, so if you like it, tell your guild and your friends.

A few things haven't been tested with lots of players yet, like big networks and busy weekend evenings. If something looks wrong, please [open an issue](https://github.com/openmap-world/opengroup/issues) and paste what `/og status` says.

## Help build it

Bug reports, ideas and pull requests are all welcome.

The addon is plain Lua with no libraries. The message format is written up at the top of `OpenGroup/Proto.lua`. The tests run outside the game:

```
python3 -m pip install lupa
python3 -I tools/test.py OpenGroup       # message format, a small multi-shard network, chat parsing
python3 -I tools/ui_smoke.py OpenGroup   # opens the window against a mock game UI and clicks through it
```

To work on it in game, link the folder into your AddOns (PowerShell, as administrator):

```
New-Item -ItemType SymbolicLink -Path "C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\OpenGroup" -Target "$PWD\OpenGroup"
```

## About Claude

I'm using Claude (Anthropic's AI) as a coding partner: it helps write and review code and helps me run the open-source side (reviewing pull requests and so on).

## Licence

MIT, see [LICENSE](LICENSE).
