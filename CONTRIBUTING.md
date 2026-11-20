# Contributing

Bug reports, ideas and pull requests are welcome.

## Bugs

Open an issue with what you did, what you expected and what happened. Please include the output of `/og status` and a screenshot if you can.

## Ideas

Open an issue and describe how you'd use it in game.

## Pull requests

- Keep it plain Lua with no libraries.
- OpenGroup should never post in public chat unless the player turned that on.
- If you change a message format, update the notes at the top of `OpenGroup/Proto.lua` and make sure older versions ignore it safely.
- Run the tests before you open the pull request:

```
python3 -m pip install lupa
python3 -I tools/test.py OpenGroup
python3 -I tools/ui_smoke.py OpenGroup
```

- If you tested it in game, say what you tried.

Contributions are shared under the MIT licence in [LICENSE](LICENSE).
