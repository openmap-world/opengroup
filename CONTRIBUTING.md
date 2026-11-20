# Contributing

Thanks for wanting to help!

**Bugs.** Open an issue with what you did, what you expected, and what happened instead. Paste the output of `/og status` too, it tells me your shard and what OpenGroup could see at the time. Screenshots help a lot.

**Ideas.** Open an issue and describe how you'd use it in game. Small and specific is easiest to pick up.

**Code.** Pull requests are welcome. A few things to keep in mind:

- Keep it plain Lua with no libraries, and keep the addon quiet. It should never post in public chat unless the player asked it to.
- If you change a message on the wire, update the format notes at the top of `OpenGroup/Proto.lua`, and make sure older versions still read it or ignore it safely.
- Run the tests before you send it:

```
python3 -m pip install lupa
python3 -I tools/test.py OpenGroup
python3 -I tools/ui_smoke.py OpenGroup
```

- Try it in game if you can, and say in the pull request what you tested.

By contributing you agree your work is shared under the MIT licence in [LICENSE](LICENSE).
