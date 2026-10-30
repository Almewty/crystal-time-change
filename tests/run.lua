-- Run from a Gen1Recomp v0.3.98 source checkout:
-- luajit /path/to/crystal-time-change/tests/run.lua /path/to/crystal-time-change
local root = assert(arg[1], "Pass the mod checkout path")
package.path = "./?.lua;./?/init.lua;" .. package.path
love = require("tests.love_stub")
-- Deterministic host clock; no system clock or real save files are changed.
local hostMinute, hostDay = 10 * 60 + 15, 5
local realDate = os.date
os.date = function(format, ...)
  if format == "%H" then return tostring(math.floor(hostMinute / 60)) end
  if format == "%M" then return tostring(hostMinute % 60) end
  if format == "%w" then return tostring(hostDay) end
  return realDate(format, ...)
end
-- ASCII charmap only: headless draw coverage does not require copyrighted art.
local charmap = {}
for code = 32, 126 do charmap[#charmap + 1] = { seq = string.char(code), code = code } end
require("src.render.Font").load({ font = { charmap = charmap } })
local Clock = require("src.core.gen2.Clock")
local Save = require("src.core.gen2.Save")
local Screens = require("src.ui.Screens")
local Stack = require("src.core.StateStack")
local GameVersion = require("src.core.GameVersion")
GameVersion.set("crystal")
local function read(name)
  local file = assert(io.open(root .. "/" .. name, "rb"))
  local body = file:read("*a"); file:close(); return body
end
local files = {
  ["mods/crystal_time_change/manifest.json"] = read("manifest.json"),
  ["mods/crystal_time_change/main.lua"] = read("main.lua"),
}
local Loader = require("src.mods.Loader")
local data = { pokemon = {}, moves = {}, items = {}, maps = {} }
require("src.core.Version").engine = "0.3.98"
local loader = Loader.new({ fs = require("tests.modkit.sdk").memfs(files),
  generation = 2, version = "crystal", dev = true })
loader:load(data)
assert(#loader.errors == 0, table.concat(loader.errors, "\n"))
assert(loader.mods.crystal_time_change.state == "loaded", "Mod not loaded")
local factories = assert(data.screens)
local count = 0
local function test(name, fn)
  fn()
  count = count + 1
  print("PASS " .. name)
end
local function fixture(hasSave)
  Screens.invalidate()
  local pressed
  local stack = setmetatable({}, { __index = Stack })
  stack:init()
  local game = { data = { screens = factories }, stack = stack,
    input = { wasPressed = function(_, button)
      if pressed == button then pressed = nil return true end
      return false
    end } }
  local save = Save.newGame({ version = "crystal" })
  local menu = Screens.push(game, "Gen2MainMenu", {
    hasSave = hasSave, save = hasSave and save or nil,
  })
  local function press(button)
    pressed = button
    game.stack:top():update(0)
  end
  return game, menu, save, press
end
local function find(menu, label)
  for i, row in ipairs(menu.list.items) do
    if row.label == label then return row, i end
  end
end

test("CHANGE TIME appears before OPTION with an existing save", function()
  local _, menu = fixture(true)
  local row, index = find(menu, "CHANGE TIME")
  assert(row, "Missing CHANGE TIME entry")
  local _, option = find(menu, "OPTION")
  assert(index < option, "Clock entry should precede OPTION")
end)
test("menu opens an editable clock; B cancels without changing the save", function()
  local game, menu, save, press = fixture(true)
  local original = require("src.core.SaveSerializer").encode(save)
  local row = assert(find(menu, "CHANGE TIME"))
  menu:choose(row.value)
  local editor = game.stack:top()
  assert(editor ~= menu, "Clock editor did not open")
  assert(editor.hour == Clock.hour(save) and editor.minute == Clock.minute(save))
  press("right")
  assert(editor.hour == (Clock.hour(save) + 1) % 24)
  press("down")
  press("left")
  assert(editor.minute == (Clock.minute(save) + 59) % 60)
  press("down")
  press("right")
  assert(editor.day == (Clock.weekday(save) + 1) % 7)
  editor:draw()
  editor:drawWidescreen(1080, 2400)
  press("b")
  assert(game.stack:top() == menu, "B should return to the main menu")
  assert(require("src.core.SaveSerializer").encode(save) == original, "Cancel changed the save")
end)
test("SAVE CLOCK persists time and weekday and updates Continue's exact save", function()
  local game, menu, save, press = fixture(true)
  assert(Save.save(save))
  local before = require("src.core.SaveSerializer").encode(save)
  menu:choose(assert(find(menu, "CHANGE TIME")).value)
  local editor = game.stack:top()
  editor.hour, editor.minute, editor.day = 23, 59, 2
  editor.index = 4
  press("a")
  assert(game.stack:top() == menu, "Successful save should close the editor")
  assert(Clock.hour(menu.save) == 23 and Clock.minute(menu.save) == 59, "Live clock not updated")
  assert(Clock.weekday(menu.save) == 2, "Live weekday not updated")
  local loaded = assert(Save.load("crystal"))
  assert(Clock.hour(loaded) == 23 and Clock.minute(loaded) == 59, "Clock did not persist")
  assert(Clock.weekday(loaded) == 2, "Weekday did not persist")
  loaded.rtc, loaded.savedAt = save.rtc, save.savedAt
  assert(require("src.core.SaveSerializer").encode(loaded) == before, "Unrelated save data changed")
  local main, backup = Save.filenames("crystal")
  assert(love.filesystem.getInfo(main) and love.filesystem.getInfo(backup), "Missing engine save backup")
end)
test("write failures leave menu and disk clock untouched and display a retryable error", function()
  local game, menu, save, press = fixture(true)
  assert(Save.save(save))
  menu:choose(assert(find(menu, "CHANGE TIME")).value)
  local editor = game.stack:top()
  editor.hour, editor.index = (Clock.hour(save) + 7) % 24, 4
  local write = love.filesystem.write
  love.filesystem.write = function(path, bytes)
    if path:match("%.tmp$") then return false, "disk full" end
    return write(path, bytes)
  end
  press("a")
  love.filesystem.write = write
  assert(game.stack:top() == editor, "Failure closed the editor")
  assert(menu.save == save, "Failure adopted a modified save")
  assert(editor.error, "Failure not shown to user")
  assert(Clock.hour(assert(Save.load("crystal"))) == Clock.hour(save), "Failure changed persisted clock")
  editor:draw()
  press("a")
  assert(game.stack:top() == menu, "Retry did not succeed")
end)
test("no save means no clock entry", function()
  local _, menu = fixture(false)
  assert(not find(menu, "CHANGE TIME"))
end)
test("editing wraps all fields and both menu ends; A on CANCEL discards", function()
  local game, menu, _, press = fixture(true)
  menu:choose(assert(find(menu, "CHANGE TIME")).value)
  local editor = game.stack:top()
  for index, key in ipairs({ "hour", "minute", "day" }) do
    local limit = ({ 24, 60, 7 })[index]
    editor.index, editor[key] = index, 0
    press("left")
    assert(editor[key] == limit - 1)
    press("right")
    assert(editor[key] == 0)
  end
  editor.index = 1
  press("up")
  assert(editor.index == 5)
  press("down")
  assert(editor.index == 1)
  editor.index = 5
  press("a")
  assert(game.stack:top() == menu)
end)
test("Continue adopts the saved candidate, not a stale unsaved game.save", function()
  local game, menu, _, press = fixture(true)
  local stale = Save.newGame({ version = "crystal" })
  stale.money = 98765
  game.save = stale
  menu:choose(assert(find(menu, "CHANGE TIME")).value)
  local editor = game.stack:top()
  editor.hour, editor.minute, editor.day, editor.index = 7, 30, 6, 4
  press("a")
  assert(game.save == stale, "Clock edit replaced an unrelated game.save")
  assert(menu.save.money ~= stale.money, "Clock edit leaked unsaved game progress")
  local adopted
  menu.onContinue = function(candidate) adopted = candidate end
  menu:choose("continue")
  menu.confirmDelay = 0
  press("a")
  assert(adopted == menu.save and Clock.hour(adopted) == 7)
  hostMinute = hostMinute + 90
  assert(Clock.hour(adopted) == 9 and Clock.minute(adopted) == 0, "Clock did not keep running")
  hostMinute = hostMinute - 90
end)
test("original menu module stays unchanged and vanilla actions survive", function()
  local MainMenu = require("src.ui.gen2.MainMenu")
  local game, menu = fixture(true)
  assert(rawget(MainMenu, "choose") ~= rawget(menu, "choose"))
  local option, newGame, exit
  menu.onOption = function() option = true end
  menu.onNewGame = function() newGame = true end
  menu.onExit = function() exit = true end
  menu:choose("option"); menu:choose("new"); menu:choose("exit")
  assert(option and newGame and exit)
  local vanilla = MainMenu.new(game, { hasSave = true, save = menu.save })
  assert(not find(vanilla, "CHANGE TIME"), "Shared module was patched")
end)
print(string.format("%d tests passed", count))
