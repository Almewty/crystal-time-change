-- Crystal Time Change for Gen1Recomp v0.3.98 (mod API 2).
-- Decorate instances, never patch the shared MainMenu module.
local MainMenu = require("src.ui.gen2.MainMenu")
local Chrome = require("src.ui.gen2.Chrome")
local Clock = require("src.core.gen2.Clock")
local Save = require("src.core.gen2.Save")
local Serializer = require("src.core.SaveSerializer")
local ACTION = "crystal_time_change:open"
local Editor = {}
Editor.__index = Editor
Editor.isOpaque = true

function Editor.new(game, menu)
  return setmetatable({ game = game, menu = menu, index = 1,
    hour = Clock.hour(menu.save), minute = Clock.minute(menu.save),
    day = Clock.weekday(menu.save) }, Editor)
end

function Editor:update(_dt)
  local input = self.game.input
  if input:wasPressed("b") then
    self.game.stack:pop()
  elseif input:wasPressed("up") then
    self.index = (self.index + 3) % 5 + 1
  elseif input:wasPressed("down") then
    self.index = self.index % 5 + 1
  else
    local delta = input:wasPressed("left") and -1
      or (input:wasPressed("right") and 1 or 0)
    if self.index == 1 then self.hour = (self.hour + delta) % 24
    elseif self.index == 2 then self.minute = (self.minute + delta) % 60
    elseif self.index == 3 then self.day = (self.day + delta) % 7 end
    if input:wasPressed("a") then
      if self.index == 4 then self:saveClock()
      elseif self.index == 5 then self.game.stack:pop() end
    end
  end
end

function Editor:saveClock()
  -- The title menu owns the save Continue will adopt. game.save can still
  -- refer to an old, unsaved session: never write that object here.
  local completed, saved, candidate = pcall(function()
    local copy = Serializer.decode(Serializer.encode(self.menu.save))
    Clock.setTime(copy, self.hour, self.minute)
    Clock.setWeekday(copy, self.day)
    return Save.save(copy), copy
  end)
  if completed and saved then
    self.menu.save = candidate
    self.game.stack:pop()
  else
    self.error = true
  end
end

function Editor:drawPanel()
  Chrome.clear()
  Chrome.box(0, 0, 20, 18)
  Chrome.print("CHANGE TIME", 3, 1)
  Chrome.print(string.format("HOUR     %02d", self.hour), 3, 4)
  Chrome.print(string.format("MINUTE   %02d", self.minute), 3, 6)
  Chrome.print("DAY " .. Clock.weekdayName(self.day + 1), 3, 8)
  Chrome.print("SAVE CLOCK", 3, 10)
  Chrome.print("CANCEL", 3, 12)
  Chrome.cursor(1, 2 + self.index * 2)
  Chrome.print(self.error and "SAVE FAILED" or "LEFT/RIGHT: CHANGE", 1, 15)
  Chrome.print("A: SELECT B: BACK", 1, 16)
end

function Editor:draw() self:drawPanel() end
function Editor:wantsFillScale() return true end
function Editor:drawsWidescreen() return true end
function Editor:drawWidescreen(width, height)
  local g = love.graphics
  Chrome.letterbox(width, height, 1, 1, 1)
  local scale = Chrome.fitScale(width, height)
  g.push()
  g.translate(Chrome.fitOrigin(width, height, scale))
  g.scale(scale, scale)
  self:drawPanel()
  g.pop()
end

return function(mod)
  mod.content.screens:register("Gen2MainMenu", {
    new = function(game, opts)
      local menu = MainMenu.new(game, opts)
      if menu.hasSave and menu.save then
        local index = #menu.list.items + 1
        for i, item in ipairs(menu.list.items) do
          if item.value == "option" then index = i break end
        end
        table.insert(menu.list.items, index, { label = "CHANGE TIME", value = ACTION })
        -- Chrome.List snapshots its visible row count at construction time.
        menu.list.rows = #menu.list.items
        menu.list:ensureVisible()
        local choose = menu.choose
        menu.choose = function(self, value)
          if value == ACTION then
            game.stack:push(Editor.new(game, self))
          else
            return choose(self, value)
          end
        end
      end
      return menu
    end,
  })
end
