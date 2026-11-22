# Changelog

## v0.6.3-beta

World chat
- A new World chat tab shows the useful LookingForGroup and Trade lines from every chat number where someone runs OpenGroup: trade ads, crafters and group posts. Chatter, gold sellers, boosts and website links are left out.
- Lines are kept for 3 hours and you can search them by text or item name, so "crusader" finds an enchant someone posted an hour ago. When you log in, OpenGroup fills in the last hour from another OpenGroup player.
- Trade from your own chat number keeps coming in when you leave the city, as long as another OpenGroup player on your number is in one.
- Lines use your own chat colours, names show in class colours, and item and enchant links work as normal links.
- Group posts are marked with a gold bar. Clicking one shows that group in Browse.
- Lines travel compressed and are passed along between OpenGroup players, so nobody sends more than a small share. "Share Trade chat from my chat number" in Settings turns sharing yours off.

Browse
- A Group column shows five slots per group: the members (class icon and role), then the roles the group still needs with a coloured ring around them (gold when it is a role you play), then any free places. If a group is missing two damage dealers you see two slots for it. The note line says it in words, for example "Needs Heal, 2 DPS".
- Solo players show "LFG" and the roles they play. Within each activity, groups and players looking for a group are listed separately.
- The All / Groups / Players button shows everyone, groups only or players only.
- Click an activity's header to show only that activity. Shift-click adds more, and clicking again shows everything.
- Filter > Pick activities opens a checklist where you can press a box and drag to tick several at once, with quick picks for your level, dungeons and raids.
- Cards: the Cards / Rows button shows two groups per line with the slots spelled out and Ask to join and Whisper buttons on each card.
- Players queued for several dungeons show under each one, and the search box matches every dungeon they queued for, including short names like scholo, ubrs or dme.
- Group Finder searches cover every language. Pick single languages in Filter > Language.

Listing
- When you list for a dungeon, OpenGroup can list you in the game's own Group Finder too, so players without the addon see you. Leave takes it down again. You can turn this off on the List page or in Settings.
- Posting in LookingForGroup chat is now its own button on the listed bar.
- While you are listed, a popup tells you when someone turns up who fits: players with a role your group needs, or groups that need a role you play. Each person is announced once, and there is at most one popup every 15 seconds. You can turn the popup and its sound off in Settings.
- Accepting a quest no longer switches Browse to that quest. For quests people group for, Browse offers to show the groups for it or list you for it, and the list stays as it was.

Find players
- A new tab runs a /who for the classes and levels you need and lists the players with their level, class, zone and guild. Whisper one, or use Whisper next to go down the list. Each click opens the chat box with your message and you press Enter.
- With several classes ticked, each Search click looks for the next class and adds its players to the list.

Finding other OpenGroup players
- Players you mouse over or walk past get a quiet hello, and every OpenGroup player you meet passes on up to 20 others they know.
- LFG and Trade chat are read much better: LF1, LF2M, "need 2 more", class requests like "need priest", more role spellings, raids, Forever's own dungeons, level ranges, and posts in German, French, Spanish, Portuguese and Russian.
- The number after Trade and LookingForGroup now shows as the chat number ("Chat 47"). Chat numbers that share a Group Finder are treated as one server.

Settings and fixes
- The Network tab is now Settings, with every switch in one place and your chat number and the OpenGroup players you know below it.
- Report a problem (in Settings, or /og bug) gives you a link that opens a report on GitHub with your version and game details filled in. No character names are included.
- Combat: OpenGroup no longer runs a /who or Group Finder search when you open the window or switch tabs. Searches only run from their own buttons and never in combat, which fixes the "Interface action failed" messages. Listing in the game's Group Finder and posting in LFG wait until after combat.
- Test builds no longer make other players' OpenGroup say a new version is out.

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
