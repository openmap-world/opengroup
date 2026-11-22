import sys, os
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
from lupa.lua51 import LuaRuntime
# usage: python tools/chat_corpus.py OpenGroup [--min PERCENT] [-v]
# Runs every line of tools/chat_corpus.txt through the chat parser (Nearby.lua, N.parse) against
# Forever-style activity names, and reports the hit rate. Fails below --min (default 0).
D = sys.argv[1]
MIN = float(sys.argv[sys.argv.index("--min") + 1]) if "--min" in sys.argv else 0
VERBOSE = "-v" in sys.argv
here = os.path.dirname(os.path.abspath(__file__))
src = {f: open(os.path.join(D, f), encoding="utf-8").read() for f in ["Proto.lua", "Activities.lua", "Nearby.lua"]}

lua = LuaRuntime()
lua.execute(r"""
function time() return 5000 end
function GetTime() return 5000 end
function UnitLevel() return 58 end
function GetChannelList() return 1, "LookingForGroup 47", false end
function CreateFrame() return { RegisterEvent = function() end, SetScript = function() end } end
C_Timer = { After = function() end, NewTicker = function() end }
OpenGroup = { shard = function() return 47 end, isMe = function() return false end, probe = function() end, onChange = function() end, print = function() end }
local ACTS = {
  {1, "Ragefire Chasm", "RFC", 13, 18}, {2, "Wailing Caverns", "WC", 17, 24}, {3, "The Deadmines", "VC", 17, 26},
  {4, "Shadowfang Keep", "SFK", 22, 30}, {5, "Blackfathom Deeps", "BFD", 24, 32}, {6, "The Stockade", "Stocks", 24, 32},
  {7, "Gnomeregan", "Gnomer", 29, 38}, {8, "Razorfen Kraul", "RFK", 29, 38},
  {9, "Scarlet Monastery (Graveyard)", "SM GY", 28, 38}, {10, "Scarlet Monastery (Library)", "SM Lib", 29, 39},
  {11, "Scarlet Monastery (Armory)", "SM Arm", 32, 42}, {12, "Scarlet Monastery (Cathedral)", "SM Cath", 35, 45},
  {13, "Razorfen Downs", "RFD", 37, 46}, {14, "Uldaman", "Ulda", 41, 51}, {15, "Zul'Farrak", "ZF", 42, 50},
  {16, "Maraudon", "Mara", 46, 55}, {17, "Sunken Temple", "ST", 50, 58}, {18, "Blackrock Depths", "BRD", 52, 60},
  {19, "Lower Blackrock Spire", "LBRS", 55, 60}, {20, "Upper Blackrock Spire", "UBRS", 59, 60},
  {21, "Dire Maul (East)", "DM East", 54, 60}, {22, "Dire Maul (West)", "DM West", 56, 60}, {23, "Dire Maul (North)", "DM North", 56, 60},
  {24, "Scholomance", "", 58, 60}, {25, "Stratholme (Main Gate)", "", 58, 60}, {26, "Stratholme (Service Gate)", "", 58, 60},
  {27, "Blackmaw Hold", "", 55, 60}, {28, "Krol'Dok", "", 45, 52}, {29, "Hall of Thanes", "", 20, 28}, {30, "Ruins of Lordaeron", "", 40, 48},
  {31, "The Shaper's Terrace", "", 58, 60},
  {40, "Molten Core", "MC", 60, 60}, {41, "Onyxia's Lair", "Ony", 60, 60}, {42, "Zul'Gurub", "ZG", 60, 60},
  {43, "Blackwing Lair", "BWL", 60, 60}, {44, "Ruins of Ahn'Qiraj", "AQ20", 60, 60},
}
local byId = {}
for _, a in ipairs(ACTS) do byId[a[1]] = { fullName = a[2], shortName = a[3], minLevelSuggestion = a[4], maxLevelSuggestion = a[5], categoryID = 2 } end
C_LFGList = {
  GetAvailableCategories = function() return { 2 } end,
  GetLfgCategoryInfo = function() return { name = "Dungeons" } end,
  GetAvailableActivities = function() local t = {} for _, a in ipairs(ACTS) do t[#t + 1] = a[1] end return t end,
  GetActivityInfoTable = function(id) return byId[id] end,
}
""")
for f in ["Proto.lua", "Activities.lua", "Nearby.lua"]: lua.execute(src[f])
lua.execute("OpenGroup_Activities.load()")
judge = lua.eval(r"""
function(kind, act, roles, size, line)
  local N, A = OpenGroup_Nearby, OpenGroup_Activities
  local p = N.parse(line)
  local function said(p)
    if not p then return "nothing" end
    local r = (p.need % 2 >= 1 and "t" or "") .. (p.need % 4 >= 2 and "h" or "") .. (p.need % 8 >= 4 and "d" or "")
    return ("%s %s %s %s"):format(p.kind == "group" and "g" or "p", p.acts[1] and A.name(p.acts[1]) or "-", r ~= "" and r or "-", tostring(p.size))
  end
  if kind == "none" then return p == nil, said(p) end
  if not p then return false, "nothing" end
  if (kind == "g") ~= (p.kind == "group") then return false, said(p) end
  local name = p.acts[1] and A.name(p.acts[1]):lower() or nil
  if act == "-" then if name then return false, said(p) end
  elseif act ~= "*" then if not name or not name:find(act, 1, true) then return false, said(p) end end
  if roles ~= "*" then
    local want = 0
    if roles ~= "-" then
      if roles:find("t") then want = want + 1 end
      if roles:find("h") then want = want + 2 end
      if roles:find("d") then want = want + 4 end
    end
    if p.need ~= want then return false, said(p) end
  end
  if size ~= "*" and tonumber(size) ~= p.size then return false, said(p) end
  return true, said(p)
end
""")
total = hits = 0
misses = []
for raw in open(os.path.join(here, "chat_corpus.txt"), encoding="utf-8"):
    raw = raw.rstrip("\n")
    if not raw.strip() or raw.startswith("#"): continue
    expect, line = [s.strip() for s in raw.split("|", 1)]
    parts = expect.split()
    if parts[0] == "none": args = ("none", "", "", "")
    else:
        kind, size, roles = parts[0], parts[-1], parts[-2]
        act = " ".join(parts[1:-2])
        args = (kind, act, roles, size)
    ok, got = judge(*args, line)
    total += 1
    if ok: hits += 1
    else: misses.append((expect, line, got))
rate = 100.0 * hits / total
for e, l, g in misses if VERBOSE else []: print(f"MISS  want [{e}]  got [{g}]  :: {l}")
print(f"chat corpus: {hits}/{total} ({rate:.1f}%)")
assert rate >= MIN, f"chat corpus hit rate {rate:.1f}% is below {MIN}%"
