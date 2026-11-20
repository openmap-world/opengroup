# Security

Please don't report security problems in a public issue. Use the Security tab on this repository and click "Report a vulnerability". Only the maintainers can see those reports. You should get a reply within a week.

This covers the addon and the release workflow. For example: another player being able to affect your client through OpenGroup's messages, the addon posting in chat or inviting people without being asked, or something that could expose the CurseForge key. Bugs in the game itself or in other addons aren't covered.

A few things that help keep it safe:

- Addons have no internet access in WoW. OpenGroup never runs code it gets from other players, and it doesn't use any libraries.
- Messages from other players are read as plain text and numbers. Anything malformed is ignored.
- CI only has read access. The CurseForge key is only used when a maintainer starts an upload by hand and approves it.
