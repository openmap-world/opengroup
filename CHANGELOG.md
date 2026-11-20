# Changelog

## v0.6.3-test

- Find players: a new tab that runs a /who search for the players you want (class, levels, zone, name) and lists them with their level, class, zone and guild. /who reaches every server, so it finds people the Group Finder and Trade don't show you
- Open it from a spot ("Find players" in the spot editor) or from the listed bar: it picks the classes that fill the spot and the levels for your activity
- Whisper a player, or click Whisper next to go down the list: each click opens the chat box on them with your message, and you press Enter. People you've whispered, players on your ignore list and OpenGroup players (who see your listing anyway) are skipped. The message is saved
- When /who stops at 50, it says so and offers to narrow the search to your zone or half the level range
- Channel numbers aren't servers: the number the game puts after Trade, LookingForGroup and General is now shown as "Chat 47", and several numbers can share one hidden server. OpenGroup groups them by how much of each other's Group Finder matches, shows rows as "Your server", "Other server" or "Chat 61" (not known yet), and shows your server on the Network tab and in /og status ("Your server: Chat 47 + 56", or "You're on Chat 47" before another number matched)
- Group Finder searches cover every language now, not just your own (the game's default only returns your language). Browse's Filter menu has a Language list: All languages, or pick the ones you want. The game's own language setting is left alone
- When your chat number changes (joining a group elsewhere, a zone change), OpenGroup notices, updates "You're on Chat N" and tells the OpenGroup players you know
- List in the game's Group Finder too (test): when you list for a dungeon or another activity the game knows, the List click also lists you in the game's own Group Finder, so players without OpenGroup on your server see it. "Also list in Group Finder" on the List page turns it off; Leave takes it down. Solo or as leader only
- Posting in LookingForGroup chat is now its own button on the listed bar (Post in LFG), since the game allows one such action per click
- Finds other OpenGroup users faster: players you mouse over or walk past (their nameplates) get a quiet hello, one every 2 seconds, each at most once a session; and every user you meet now passes on up to 20 others they know instead of 8. /og status shows hellos by reason
- Players queued for several activities: Group by activity lists them under each one, and with an Activity filter or a search only under the matching ones. The Activity column shows the matching one first ("Scholomance +2") and the tooltip lists them all
- The search box matches every activity a player is queued for, and short names like scholo, strat, ubrs, lbrs, brd, dme, zf, sm, rfd, gnomer
- Groups passed on from other servers' Group Finder keep every activity they're queued for (up to four)
- Network tab: "Share LFG chat from my server" has its own row and no longer runs into the player list
- One OpenGroup player per server passes on its Group Finder (the Group Finder is shared by the numbers on a server), and one per chat number passes on its LFG chat (chat stays per number, even on a shared server)

## v0.6.2-beta

- Groups from the game's Group Finder on other shards: OpenGroup players pass on what their Group Finder shows, so you see groups from other shards too (marked GF, with the shard and who saw them). Groups already in your own Group Finder aren't repeated, and /og status shows per shard how much of their Group Finder matches yours
- LookingForGroup chat from other shards: recent LFG posts are passed on too and show as "LFG <shard>" rows. Untick "Share LFG chat from my shard" on the Network tab to stop sharing yours
- Fixed: two-part names ("Stuxnet Metasploit") were cut to the first word when taken from your target, your party or yourself. Test connection to target, the party listing popup and passed-on listings now use the full name
- Players whose shard isn't known yet show as "Shard unknown" instead of "Shard 0"
- The CurseForge upload can now be told which file type to use

## v0.6.1

- Players on your ignore list are hidden in Browse, Whispers and auto invite, and their messages are ignored
- A listing passed on by another player shows as unconfirmed until its leader confirms it, and is dropped if they don't
- Limits on how many messages one player can send and how many listings are kept
- Notes on keeping the message format compatible, in Proto.lua and CONTRIBUTING

## v0.6.0-beta

First public beta.

- Browse and list groups across all shards
- Groups from the game's Group Finder and LFG chat on your shard, with a Search button that searches the Group Finder for you
- Browse opens on your level: columns you can sort, grouping by activity or shard, a search box, a Filter menu and a compact mode
- Pick each open spot's role, class and level, and auto invite people who fit
- Your party sees your group's listing in their OpenGroup too: a line in chat, the listed bar and the minimap light
- Whispers tab: your conversations with class colours, levels and the game's whisper colours, people you know through OpenGroup first
- Right-click a player for Whisper, Invite, Ask to Join, Add friend or Ignore
- List tab with category tiles, your recent listings and dungeons for your level
- Optional post in LookingForGroup chat when you list, and a party chat message
- Quest search (shift-click a quest in your log)
- Warlock summons and battleground queue requests
- Minimap button, and a tab on the game's Group Finder
- Opens in combat, and the window can be resized
- New icon
