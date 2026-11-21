import sys, os, heapq, random
from lupa.lua51 import LuaRuntime
# usage: python tools/feed_sim.py OpenGroup [users ...] [--lines N] [--know PCT] [--check]
# Simulates World chat with the real Nearby.lua / Proto.lua code: one Lua state per player,
# chat numbers of ~20 players, one reporter in Trade per number adding --lines lines (default 2)
# every 20-second round. Reports each player's World chat sends per minute (the budget is 24)
# and how many players have each round's lines one and two rounds later.
# --know: the percentage of other players each one knows (default 100).
# --check: fail if anyone goes over the budget, or (at full knowledge) lines miss anyone after 2 rounds.
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
D = sys.argv[1]
args = sys.argv[2:]
LINES = int(args[args.index("--lines") + 1]) if "--lines" in args else 2
KNOW = float(args[args.index("--know") + 1]) if "--know" in args else 100.0
CHECK = "--check" in args
DEBUG = "--debug" in args
sizes = [int(a) for i, a in enumerate(args) if a.isdigit() and (i == 0 or args[i - 1] not in ("--lines", "--know"))] or [50, 200, 500]
src = {f: open(os.path.join(D, f), encoding="utf-8").read() for f in ["Proto.lua", "Activities.lua", "Nearby.lua"]}
BUDGET, BURST, ROUND, LATENCY = 24, 12, 20, 0.3

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
function L.live() return L.peers end
function L.ignored() return false end
function L.onChange() end
function L.print() end
function L.probe() end
function L.send(to, m) if m:sub(1, 2) == "T1" then SENT = SENT + 1 end BUS(name, to, m) end
function L.receive(msg, sender)
  local k, d = OpenGroup_Proto.parse(msg)
  if k == "T1" then L.onFeed(sender, d, msg) elseif k == "R1" and L.onReporter then L.onReporter(sender, d) end
end
"""

def run(n):
    random.seed(n)
    numbers = max(3, n // 20)
    names = ["Player%04d" % i for i in range(n)]
    num_of = {nm: 100 + (i % numbers) for i, nm in enumerate(names)}
    reporters = {}
    for nm in names:
        reporters.setdefault(num_of[nm], nm)
    timers, bus, seq = [], [], [0]
    states = {}
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
        states[nm] = rt
    for nm in names: mk(nm)
    for nm in names:
        know = [o for o in names if o != nm and random.random() * 100 < KNOW]
        st = states[nm]
        add = st.eval("function(o, s) OpenGroup.peers[o] = { shard = s, level = 60, seen = 0, v = '0.6.3-test' } end")
        for o in know: add(o, num_of[o])
    capture = {nm: states[nm].eval("function(chan, who, text) return OpenGroup_Nearby.captureFeed(chan, who, text, nil) end") for nm in names}
    report = {nm: states[nm].eval("function() return OpenGroup_Nearby.feedReport() end") for nm in names}
    has = {nm: states[nm].eval("function(keys) local n = 0 for i = 1, #keys do if OpenGroup_Nearby.hasLine(keys[i]) then n = n + 1 end end return n end") for nm in names}
    sent_total = {nm: 0 for nm in names}
    per_minute_max = 0
    minute_start = {nm: 0 for nm in names}
    window = {}
    round_keys = {}
    coverage = {}
    T_END = ROUND * 6
    t = 0.0
    step = 0.1
    last_round = -1
    while t <= T_END + 1e-9:
        now[0] = t
        for st in states.values(): st.globals().SIM_T = t
        r = int(t // ROUND)
        if r != last_round and abs(t - r * ROUND) < 1e-9:
            # measure: lines of earlier rounds, how many players have them
            for rr, keys in round_keys.items():
                age = r - rr
                if age in (1, 2) and keys:
                    lk = states[names[0]].table_from(keys)
                    total = 0
                    for nm in names:
                        got = has[nm](states[nm].table_from(keys))
                        total += got
                        if DEBUG and got < len(keys) and age == 2:
                            miss = [k.split("")[0] for k in keys if not states[nm].eval("function(k) return OpenGroup_Nearby.hasLine(k) end")(k)]
                            print("missing", nm, num_of[nm], got, len(keys), miss[:6], states[nm].eval("function() local s = OpenGroup_Nearby.stats return s.feedDropped, s.feedFwd end")())
                    coverage.setdefault(age, []).append(total / (len(keys) * n))
            last_round = r
            if r < 4:
                keys = []
                for numb, rep in reporters.items():
                    for k in range(LINES):
                        who = "Trader%d_%d_%d" % (numb, r, k)
                        if k % 3 == 2:
                            text = "LFM BRD need heals round %d %d" % (r, k)
                            chan = "LookingForGroup %d" % numb
                        else:
                            text = "WTS {i%d} %dg each round %d" % (12000 + k, k + 1, r)
                            chan = "Trade %d" % numb
                        capture[rep](chan, who, text)
                        keys.append(who + "\x1f" + text)
                round_keys[r] = keys
                for numb, rep in reporters.items(): report[rep]()
        while timers and timers[0][0] <= t + 1e-9:
            _, _, nm, fn = heapq.heappop(timers)
            fn()
        while bus and bus[0][0] <= t + 1e-9:
            _, _, frm, to, m = heapq.heappop(bus)
            if to in states: states[to].globals().OpenGroup.receive(m, frm)
        # sends per player per minute (a sliding 60-second window, sampled each second)
        if abs(t - round(t)) < 1e-9:
            for nm in names:
                s = states[nm].globals().SENT
                window.setdefault(nm, []).append((t, s))
                w = window[nm]
                while w and w[0][0] < t - 60: w.pop(0)
                per_minute_max = max(per_minute_max, s - w[0][1])
        t = round(t + step, 6)
    if DEBUG:
        for nm in names:
            dr = states[nm].eval("function() return OpenGroup_Nearby.stats.feedDropped end")()
            if dr: print("dropped", nm, dr)
    feed_sends = per_minute_max
    c1 = sum(coverage.get(1, [0])) / max(1, len(coverage.get(1, [])))
    c2 = sum(coverage.get(2, [0])) / max(1, len(coverage.get(2, [])))
    print(f"{n} players on {numbers} chat numbers, {LINES} new lines per number per round, knowing {KNOW:.0f}% of the others:")
    print(f"  most World chat messages sent by one player in any 60 seconds: {feed_sends} (budget {BUDGET} a minute plus a burst of {BURST})")
    print(f"  players with a round's lines: {100*c1:.1f}% one round later, {100*c2:.1f}% two rounds later")
    return feed_sends, c1, c2

ok = True
for n in sizes:
    s, c1, c2 = run(n)
    if CHECK and (s > BUDGET + BURST or (KNOW >= 100 and c2 < 0.999)): ok = False
assert ok, "World chat simulation: over the budget or lines missed"
