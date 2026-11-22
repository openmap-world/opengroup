import sys, os, heapq, random
from lupa.lua51 import LuaRuntime
# usage: python tools/feed_sim.py OpenGroup [players ...] [--lines N] [--know PCT] [--root-leaves]
#                                 [--repair SECONDS] [--check] [--debug]
# Simulates World chat with the real Nearby.lua / Proto.lua code: one Lua state per player,
# chat numbers of ~20 players, one reporter in Trade per number adding --lines lines (default 2)
# every 20-second round. Reports the most World chat messages any player sent in a 60-second
# window (the budget is 24 a minute plus a burst of 12) and how many of the players online have
# each round's lines 1 and 2 rounds later (and at the end, with --repair).
#   --know PCT      each player knows only this share of the others (default 100)
#   --root-leaves   the tree's root logs off 5 seconds into round 2
#   --repair S      the periodic repair runs every S seconds (in the game: 600)
#   --check         fail if anyone goes over the budget, or lines miss anyone after 2 rounds
#                   (with full knowledge)
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
D = sys.argv[1]
args = sys.argv[2:]
def opt(name, default, cast=float):
    return cast(args[args.index(name) + 1]) if name in args else default
LINES = opt("--lines", 2, int)
KNOW = opt("--know", 100.0)
REPAIR = opt("--repair", 0, int)
ROOT_LEAVES = "--root-leaves" in args
CHECK = "--check" in args
DEBUG = "--debug" in args
valued = {"--lines", "--know", "--repair"}
sizes = [int(a) for i, a in enumerate(args) if a.isdigit() and (i == 0 or args[i - 1] not in valued)] or [50, 200, 500]
src = {f: open(os.path.join(D, f), encoding="utf-8").read() for f in ["Proto.lua", "Activities.lua", "Nearby.lua"]}
BUDGET, BURST, ROUND, LATENCY = 24, 12, 20, 0.3
LINE_ROUNDS = 4

STUB = r"""
local name, num, inTrade = ...
SIM_T = 0
function time() return math.floor(SIM_T) end
function GetTime() return SIM_T end
function UnitLevel() return 60 end
function CreateFrame() return { RegisterEvent = function() end, SetScript = function() end } end
function GetChannelList()
  if inTrade then return 1, "Trade " .. num, false, 4, "LookingForGroup " .. num, false end
  return 4, "LookingForGroup " .. num, false
end
C_Timer = { After = function(d, fn) AFTER(d, fn) end, NewTicker = function() end }
SENT = 0
OpenGroupDB = {}
OpenGroup = { peers = {}, listings = {}, nearby = {}, remote = {} }
local L = OpenGroup
function L.shard() return num end
function L.me() return name end
function L.isMe(n) return n == name end
function L.short(n) return n end
function L.live()
  local out = {}
  for n, p in pairs(L.peers) do if not (p.off and time() - p.off < 600) then out[n] = p end end
  return out
end
function L.ignored() return false end
function L.onChange() end
function L.print() end
function L.probe() end
function L.send(to, m) if m:sub(1, 2) == "T1" then SENT = SENT + 1 end BUS(name, to, m) end
-- the game's "No player named X is currently playing" (Core.lua's check)
function SEND_FAILED(to)
  local p = L.peers[to]
  if p then
    p.off = time()
    if L.onPeerGone then L.onPeerGone(to) end
  end
end
function L.receive(msg, sender)
  local k, d = OpenGroup_Proto.parse(msg)
  if k == "T1" then L.onFeed(sender, d, msg)
  elseif k == "R1" and L.onReporter then L.onReporter(sender, d)
  elseif k == "B1" and L.onBacklogAsk then L.onBacklogAsk(sender, d) end
end
"""

def run(n):
    random.seed(n)
    numbers = max(3, n // 20)
    names = ["Player%04d" % i for i in range(n)]
    num_of = {nm: 100 + (i % numbers) for i, nm in enumerate(names)}
    # one reporter per chat number, anywhere in name order (here: the last name on each number)
    reporters = {}
    for nm in names:
        reporters[num_of[nm]] = nm
    timers, bus, seq = [], [], [0]
    states, gone = {}, set()
    now = [0.0]
    def mk(nm):
        rt = LuaRuntime()
        g = rt.globals()
        def after(d, fn, nm=nm):
            seq[0] += 1
            heapq.heappush(timers, (now[0] + d, seq[0], nm, fn))
        def send(frm, to, m):
            seq[0] += 1
            heapq.heappush(bus, (now[0] + LATENCY, seq[0], frm, to, m))
        g.AFTER, g.BUS = after, send
        rt.eval("function(s, ...) return loadstring(s)(...) end")(STUB, nm, num_of[nm], reporters[num_of[nm]] == nm)
        for f in ["Proto.lua", "Activities.lua", "Nearby.lua"]: rt.execute(src[f])
        rt.execute("OpenGroup_Nearby.bindHistory()")
        if REPAIR: rt.execute("OpenGroup_Nearby.REPAIR_EVERY = %d" % REPAIR)
        states[nm] = rt
    for nm in names: mk(nm)
    for nm in names:
        know = [o for o in names if o != nm and random.random() * 100 < KNOW]
        add = states[nm].eval("function(o, s) OpenGroup.peers[o] = { shard = s, level = 60, seen = 0, v = '0.6.3-test' } end")
        for o in know: add(o, num_of[o])
    capture = {nm: states[nm].eval("function(chan, who, text) return OpenGroup_Nearby.captureFeed(chan, who, text, nil) end") for nm in names}
    report = {nm: states[nm].eval("function() return OpenGroup_Nearby.feedReport() end") for nm in names}
    repair = {nm: states[nm].eval("function() return OpenGroup_Nearby.feedRepairTick() end") for nm in names}
    has = {nm: states[nm].eval("function(keys) local n = 0 for i = 1, #keys do if OpenGroup_Nearby.hasLine(keys[i]) then n = n + 1 end end return n end") for nm in names}
    per_minute_max = 0
    window, round_keys, coverage = {}, {}, {}
    rounds = LINE_ROUNDS + 2 + ((REPAIR * 2) // ROUND + 1 if REPAIR else 0)
    T_END = ROUND * rounds
    root = min(names)
    def cover(keys):
        online = [nm for nm in names if nm not in gone]
        total = 0
        for nm in online:
            got = has[nm](states[nm].table_from(keys))
            total += got
            if DEBUG and got < len(keys): print("missing", nm, got, len(keys))
        return total / (len(keys) * len(online))
    t, step, last_round = 0.0, 0.1, -1
    while t <= T_END + 1e-9:
        now[0] = t
        for st in states.values(): st.globals().SIM_T = t
        r = int(t // ROUND)
        if ROOT_LEAVES and root not in gone and t >= 2 * ROUND + 5:
            gone.add(root)
        if r != last_round and abs(t - r * ROUND) < 1e-9:
            for rr, keys in round_keys.items():
                if r - rr in (1, 2) and keys:
                    cv = cover(keys)
                    coverage.setdefault(r - rr, []).append(cv)
                    if DEBUG: print("round", rr, "after", r - rr, "coverage", cv)
            last_round = r
            if r < LINE_ROUNDS:
                keys = []
                for numb, rep in reporters.items():
                    if rep in gone: continue
                    for k in range(LINES):
                        who = "Trader%d_%d_%d" % (numb, r, k)
                        if k % 3 == 2:
                            text, chan = "LFM BRD need heals round %d %d" % (r, k), "LookingForGroup %d" % numb
                        else:
                            text, chan = "WTS {i%d} %dg each round %d" % (12000 + k, k + 1, r), "Trade %d" % numb
                        capture[rep](chan, who, text)
                        keys.append(who + "\x1f" + text)
                round_keys[r] = keys
                for numb, rep in reporters.items():
                    if rep not in gone: report[rep]()
        if REPAIR and abs(t - round(t)) < 1e-9:
            for nm in names:
                if nm not in gone: repair[nm]()
        while timers and timers[0][0] <= t + 1e-9:
            _, _, nm, fn = heapq.heappop(timers)
            if nm not in gone: fn()
        while bus and bus[0][0] <= t + 1e-9:
            _, _, frm, to, m = heapq.heappop(bus)
            if to in gone:
                # the game tells the sender the player isn't online
                if frm not in gone: states[frm].globals().SEND_FAILED(to)
            elif to in states:
                states[to].globals().OpenGroup.receive(m, frm)
        if abs(t - round(t)) < 1e-9:
            for nm in names:
                s = states[nm].globals().SENT
                w = window.setdefault(nm, [])
                w.append((t, s))
                while w and w[0][0] < t - 60: w.pop(0)
                per_minute_max = max(per_minute_max, s - w[0][1])
        t = round(t + step, 6)
    if DEBUG:
        for nm in names[:6]:
            print("stats", nm, states[nm].eval("function() local s = OpenGroup_Nearby.stats return s.feedDropped, s.feedFwd, s.failovers or 0, s.feedIn end")())
    end_cov = cover([k for r in sorted(round_keys) for k in round_keys[r]])
    c1 = sum(coverage.get(1, [0])) / max(1, len(coverage.get(1, [])))
    c2 = sum(coverage.get(2, [0])) / max(1, len(coverage.get(2, [])))
    extra = []
    if KNOW < 100: extra.append("knowing %.0f%% of the others" % KNOW)
    if ROOT_LEAVES: extra.append("the root logs off in round 2")
    if REPAIR: extra.append("repair every %ds" % REPAIR)
    print(f"{n} players on {numbers} chat numbers, {LINES} new lines per number per round" + ("; " + ", ".join(extra) if extra else "") + ":")
    print(f"  most World chat messages sent by one player in any 60 seconds: {per_minute_max} (budget {BUDGET} a minute plus a burst of {BURST})")
    print(f"  players online with a round's lines: {100*c1:.1f}% one round later, {100*c2:.1f}% two rounds later"
          + (f", {100*end_cov:.1f}% at the end ({rounds - LINE_ROUNDS} rounds after the last lines)" if REPAIR else ""))
    return per_minute_max, c1, c2, end_cov

ok = True
for n in sizes:
    s, c1, c2, e = run(n)
    if CHECK and (s > BUDGET + BURST or (KNOW >= 100 and c2 < 0.999)): ok = False
assert ok, "World chat simulation: over the budget or lines missed"
