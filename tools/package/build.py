# Builds the release zip, as the release workflow does on a tag (.github/workflows/release.yml): one
# OpenGroup/ folder, only the files git tracks under OpenGroup/ as committed. The toc's "## Version"
# must already match the tag (0.6.0-beta for v0.6.0-beta). Runs the offline tests first. Writes
# dist/OpenGroup-<version>.zip and, for the release notes and the CurseForge changelog,
# dist/OpenGroup-<version>-changelog.md (that version's section of CHANGELOG.md). curseforge.py
# uploads what it writes (docs/releasing.md).
#
# usage: python -P tools/package/build.py <version> [--dirty] [--no-tests]
#   <version>: as CHANGELOG.md heads it, e.g. v0.6.0-beta
#   --dirty: allow uncommitted changes under OpenGroup/ (the zip still takes the committed files)
import os, re, subprocess, sys, zipfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DIST = os.path.join(ROOT, "dist")
ADDON = "OpenGroup"
TOC = ADDON + "/OpenGroup.toc"
LOG = "CHANGELOG.md"
args = [a for a in sys.argv[1:] if not a.startswith("--")]
if len(args) != 1:
    sys.exit("usage: python -P tools/package/build.py <version> [--dirty] [--no-tests]")
version = args[0]
if not re.match(r"^v\d+\.\d+\.\d+(-[a-z0-9.]+)?$", version):
    sys.exit("version should look like v0.6.0 or v0.6.0-beta")


def git(*a):
    return subprocess.run(["git", "-C", ROOT] + list(a), check=True, capture_output=True).stdout


# the changelog: this version's own section
md = open(os.path.join(ROOT, LOG), encoding="utf-8").read()
m = re.search(r"^## %s\b.*?$(.*?)(?=^## |\Z)" % re.escape(version), md, re.M | re.S)
if not m or not m.group(1).strip():
    sys.exit("%s has no notes under '## %s' (docs/releasing.md)" % (LOG, version))
notes = m.group(1).strip() + "\n"

dirty = git("status", "--porcelain", "--", ADDON, LOG).decode().strip()
if dirty and "--dirty" not in sys.argv:
    sys.exit("uncommitted changes (commit them, or --dirty to package what's committed):\n" + dirty)

# the committed toc's version must be the tag's
toc = git("show", "HEAD:" + TOC).decode("utf-8")
tv = re.search(r"^## Version:\s*(\S+)", toc, re.M)
if not tv or tv.group(1) != version[1:]:
    sys.exit("%s says ## Version: %s, the tag is %s: bump the toc first"
             % (TOC, tv.group(1) if tv else "(none)", version))

if "--no-tests" not in sys.argv:
    for c in (["tools/test.py", ADDON], ["tools/ui_smoke.py", ADDON]):
        r = subprocess.run([sys.executable] + c, cwd=ROOT, capture_output=True, text=True)
        if r.returncode != 0:
            sys.exit("failed: %s\n%s%s" % (" ".join(c), r.stdout[-3000:], r.stderr[-3000:]))
        print("ok:", " ".join(c))

# the committed files (as a fresh checkout has them), not the working tree's
files = sorted(f for f in git("ls-tree", "-r", "-z", "--name-only", "HEAD", "--", ADDON).decode().split("\0") if f)
if TOC not in files:
    sys.exit(TOC + " isn't committed")
os.makedirs(DIST, exist_ok=True)
out = os.path.join(DIST, "OpenGroup-%s.zip" % version)
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
    for f in files:
        info = zipfile.ZipInfo(f, date_time=(2026, 1, 1, 0, 0, 0))
        info.compress_type = zipfile.ZIP_DEFLATED
        info.external_attr = 0o644 << 16
        z.writestr(info, git("show", "HEAD:" + f))
NOTES = os.path.join(DIST, "OpenGroup-%s-changelog.md" % version)
with open(NOTES, "w", encoding="utf-8", newline="\n") as f:
    f.write(notes)
head = git("rev-parse", "--short", "HEAD").decode().strip()
print("wrote %s (%d files, %.1f KB, from %s)" % (os.path.relpath(out, ROOT), len(files), os.path.getsize(out) / 1e3, head))
print("changelog: %s" % os.path.relpath(NOTES, ROOT))
