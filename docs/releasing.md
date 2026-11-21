# Releasing

## First time only

1. Create the CurseForge project. In `OpenGroup/OpenGroup.toc`, replace the placeholder comment with `## X-Curse-Project-ID: <id>`.
2. Create a CurseForge API token and add it on GitHub as an Actions secret called `CF_API_KEY`.
3. In the repo settings, create an environment called `curseforge` with yourself as a required reviewer. Do this before the first upload.

## Each release

1. Test it in game.
2. Set `## Version` in the toc (without the `v`) and add notes under `## v<version>` in `CHANGELOG.md`.
   Set `P.VERSION` in Proto.lua to the same, and `P.RELEASED` to it too. A build whose version ends in -test, -dev or -alpha shows `P.RELEASED` to other players, so it never tells them a version is out.
3. Tag it and push the tag, e.g. `git tag v0.6.0-beta` then `git push origin v0.6.0-beta`. This runs the tests, builds the zip and creates the GitHub release. Beta and alpha tags are marked as pre-releases.
4. To upload to CurseForge, go to Actions, pick "release", click "Run workflow" and enter the tag. Release type "auto" takes it from the tag (-alpha, -beta, otherwise a full release); pick alpha, beta or release to choose. It waits for your approval, does a dry run, then uploads.

Pushing a tag never uploads to CurseForge on its own.

You can build the zip locally with `python -P tools/package/build.py v0.6.0-beta`. It goes in `dist/`.

If the CurseForge dry run says it can't find the game version, set `CF_GAME_VERSIONS` to CurseForge's id for it in `.github/workflows/release.yml`.
