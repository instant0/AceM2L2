--[[---------------------------------------------------------------------------------
  Core/Util.lua
  Defensive helpers, localized format parsing, and faction normalization.
------------------------------------------------------------------------------------]]

local AceM2L2 = AceM2L2
local Defaults = AceM2L2.Defaults
local Util = {}

local function IsSecretValue(value)
  return issecretvalue and issecretvalue(value) or false
end

local function SafeBoolean(value)
  if value == nil or IsSecretValue(value) then
    return nil
  end
  return value and true or false
end

local function SafeNumber(value)
  if value == nil or IsSecretValue(value) then
    return nil
  end
  if type(value) ~= "number" then
    return nil
  end
  return value
end

local function SafeString(value)
  if value == nil or IsSecretValue(value) then
    return nil
  end
  if type(value) ~= "string" then
    return nil
  end
  return value
end

local function Trim(text)
  local value = SafeString(text)
  if not value then
    return nil
  end
  return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function StripColorCodes(text)
  local value = SafeString(text)
  if not value then
    return nil
  end
  value = value:gsub("|c%x%x%x%x%x%x%x%x", "")
  value = value:gsub("|r", "")
  return value
end

local function SanitizeLabel(text)
  local value = SafeString(text)
  if not value then
    return nil
  end
  value = value:gsub("[\r\n\t]", " ")
  value = value:gsub("|c%x%x%x%x%x%x%x%x", "")
  value = value:gsub("|r", "")
  if #value > 120 then
    value = value:sub(1, 117) .. "..."
  end
  return value
end

local function SafeLower(text)
  local value = SafeString(text)
  if not value then
    return nil
  end
  local lower = strlower or string.lower
  local ok, result = pcall(lower, value)
  if not ok then
    return nil
  end
  return result
end

local function NormalizeNumber(value, kind)
  if type(value) == "number" then
    return SafeNumber(value)
  end
  local text = SafeString(value)
  if not text then
    return nil
  end
  if kind == "f" then
    text = text:gsub("%s", ""):gsub(",", ".")
    return tonumber(text)
  end
  text = text:gsub("[^%d%-]", "")
  if text == "" or text == "-" then
    return nil
  end
  return tonumber(text)
end

local function SafeCall(fn, ...)
  if type(fn) ~= "function" then
    return nil
  end
  local ok, a, b, c, d = pcall(fn, ...)
  if not ok then
    return nil
  end
  return a, b, c, d
end

local function GetSafeTime()
  return SafeNumber(SafeCall(GetTime)) or 0
end

local function GetUnitXP()
  return SafeNumber(SafeCall(UnitXP, "player"))
end

local function GetUnitXPMax()
  return SafeNumber(SafeCall(UnitXPMax, "player"))
end

local function GetUnitLevel()
  return SafeNumber(SafeCall(UnitLevel, "player"))
end

local function GetPlayerGuildName()
  return SafeString(SafeCall(GetGuildInfo, "player"))
end

local function AddChatMessage(text)
  local message = SafeString(text)
  if not message then
    return false
  end
  if #message > 1000 then
    message = message:sub(1, 1000)
  end
  local frame = DEFAULT_CHAT_FRAME
  if not frame or type(frame.AddMessage) ~= "function" then
    return false
  end
  return pcall(frame.AddMessage, frame, message)
end

local function SanitizeBoolean(value, defaultValue)
  if type(value) == "boolean" then
    return value
  end
  return defaultValue
end

local function SanitizeInteger(value, defaultValue, minValue, maxValue)
  local number = tonumber(value)
  if not number then
    return defaultValue
  end
  number = math.floor(number + 0.5)
  if minValue and number < minValue then
    number = minValue
  end
  if maxValue and number > maxValue then
    number = maxValue
  end
  return number
end

local function CopyDefaults(source)
  local copy = {}
  for key, value in pairs(source) do
    if type(value) == "table" then
      copy[key] = CopyDefaults(value)
    else
      copy[key] = value
    end
  end
  return copy
end

--[[--------------------------------------------------------------------------------
  Localized format-string -> Lua pattern conversion

  Handles %s, %d, %f, %% and positional forms such as %1$s / %2$d.  Captures are
  tracked by their original argument slot so reordered localizations still map
  back correctly.
------------------------------------------------------------------------------------]]

local PATTERN_MAGIC = "([%(%)%.%%%+%-%*%?%[%]%^%$])"

local function EscapePattern(text)
  return (text:gsub(PATTERN_MAGIC, "%%%1"))
end

local function FormatToPattern(fmt)
  if type(fmt) ~= "string" or IsSecretValue(fmt) then
    return nil
  end

  fmt = StripColorCodes(fmt) or fmt

  local parts = {}
  local tokens = {}
  local nextSlot = 1
  local i = 1

  local function addLiteral(text)
    if text and text ~= "" then
      parts[#parts + 1] = EscapePattern(text)
    end
  end

  while i <= #fmt do
    local percent = fmt:find("%", i, true)
    if not percent then
      addLiteral(fmt:sub(i))
      break
    end

    addLiteral(fmt:sub(i, percent - 1))

    local after = fmt:sub(percent + 1)
    local consumed = 0
    local position
    local rest = after
    local positional, remainder = after:match("^(%d+)%$(.*)$")
    if positional then
      position = positional
      consumed = #positional + 1
      rest = remainder
    end

    local flags = rest:match("^([%-%+0 #]*)") or ""
    consumed = consumed + #flags
    rest = rest:sub(#flags + 1)

    local width = rest:match("^(%d*)") or ""
    consumed = consumed + #width
    rest = rest:sub(#width + 1)

    local precision = rest:match("^(%.%d*)") or ""
    consumed = consumed + #precision
    rest = rest:sub(#precision + 1)

    local conversion = rest:sub(1, 1)
    if conversion == "%" then
      parts[#parts + 1] = "%%"
      i = percent + 2
    elseif conversion == "s" or conversion == "d" or conversion == "f" then
      local slot = tonumber(position)
      if slot then
        if slot >= nextSlot then
          nextSlot = slot + 1
        end
      else
        slot = nextSlot
        nextSlot = nextSlot + 1
      end

      if conversion == "s" then
        parts[#parts + 1] = "(.+)"
      else
        parts[#parts + 1] = "([%d%.,%s%-]+)"
      end
      tokens[#tokens + 1] = {
        slot = slot,
        kind = conversion,
      }
      i = percent + 1 + consumed + 1
    else
      addLiteral("%")
      i = percent + 1
    end
  end

  if #tokens == 0 then
    return nil
  end

  return "^" .. table.concat(parts) .. "$", tokens
end
local function SafeMatchN(message, pattern)
  if type(message) ~= "string" or IsSecretValue(message) then
    return nil
  end
  local ok, a, b, c, d, e, f, g, h, i, j, k, l = pcall(string.match, message, pattern)
  if not ok then
    return nil
  end
  return { a, b, c, d, e, f, g, h, i, j, k, l }
end

local function ParseFormatted(message, fmt)
  local pattern, tokens = FormatToPattern(fmt)
  if not pattern then
    return nil
  end
  local values = SafeMatchN(message, pattern)
  if not values then
    return nil
  end

  local slots = {}
  local ordered = {}
  for index, token in ipairs(tokens) do
    local value = values[index]
    if value ~= nil then
      local entry = {
        kind = token.kind,
        value = value,
        slot = token.slot,
      }
      slots[token.slot] = entry
      ordered[#ordered + 1] = entry
    end
  end

  if #ordered == 0 then
    return nil
  end
  return slots, ordered
end

--[[--------------------------------------------------------------------------------
  Faction data normalization

  Indexing a secret/forbidden table can error, so every field read happens inside
  a pcall and is copied to a plain table.
------------------------------------------------------------------------------------]]

local function NormalizeFaction(data)
  if type(data) ~= "table" then
    return nil
  end

  local ok, name, minVal, maxVal, curVal, factionID, isHeader, isHeaderWithRep, isChild, standingID = pcall(function()
    return data.name,
      data.currentReactionThreshold,
      data.nextReactionThreshold,
      data.currentStanding,
      data.factionID,
      data.isHeader,
      data.isHeaderWithRep,
      data.isChild,
      data.standingID
  end)
  if not ok then
    return nil
  end

  return {
    name = name,
    currentReactionThreshold = minVal,
    nextReactionThreshold = maxVal,
    currentStanding = curVal,
    factionID = factionID,
    isHeader = isHeader,
    isHeaderWithRep = isHeaderWithRep,
    isChild = isChild,
    standingID = standingID,
  }
end

AceM2L2.Util = Util

Util.IsSecretValue = IsSecretValue
Util.SafeBoolean = SafeBoolean
Util.SafeNumber = SafeNumber
Util.SafeString = SafeString
Util.Trim = Trim
Util.StripColorCodes = StripColorCodes
Util.SanitizeLabel = SanitizeLabel
Util.SafeLower = SafeLower
Util.NormalizeNumber = NormalizeNumber
Util.SafeCall = SafeCall
Util.GetSafeTime = GetSafeTime
Util.GetUnitXP = GetUnitXP
Util.GetUnitXPMax = GetUnitXPMax
Util.GetUnitLevel = GetUnitLevel
Util.GetPlayerGuildName = GetPlayerGuildName
Util.AddChatMessage = AddChatMessage
Util.SanitizeBoolean = SanitizeBoolean
Util.SanitizeInteger = SanitizeInteger
Util.CopyDefaults = CopyDefaults
Util.EscapePattern = EscapePattern
Util.FormatToPattern = FormatToPattern
Util.SafeMatchN = SafeMatchN
Util.ParseFormatted = ParseFormatted
Util.NormalizeFaction = NormalizeFaction

local CAMELOT_PROJECT_ID = Defaults.CAMELOT_PROJECT_ID
local MAINLINE_PROJECT_ID = Defaults.MAINLINE_PROJECT_ID

function AceM2L2:GetClientLabel()
  if WOW_PROJECT_ID == CAMELOT_PROJECT_ID then
    return "Forever"
  elseif WOW_PROJECT_ID == MAINLINE_PROJECT_ID then
    return "Midnight"
  end
  return "Unknown"
end

function AceM2L2:GetInterfaceVersion()
  local _, _, _, interfaceVersion = SafeCall(GetBuildInfo)
  return SafeNumber(interfaceVersion)
end

function AceM2L2:SafePrint(...)
  local ok = pcall(self.Print, self, ...)
  if not ok and type(print) == "function" then
    pcall(print, ...)
  end
end

function AceM2L2:ReportError(context, err)
  local message = tostring(context or "error") .. ": " .. tostring(err)
  if #message > 500 then
    message = message:sub(1, 500)
  end
  self.lastError = message
  if self.db and self.db.debug then
    self:SafePrint("|cffff5555" .. message .. "|r")
  end
end

function AceM2L2:SafeInvoke(context, method, ...)
  local fn = self[method]
  if type(fn) ~= "function" then
    self:ReportError(context, "missing method " .. tostring(method))
    return
  end
  local ok, err = pcall(fn, self, ...)
  if not ok then
    pcall(self.ReportError, self, context, err)
  end
end

function AceM2L2:SafeRegister(event, method)
  local ok, err = pcall(self.RegisterEvent, self, event, method)
  if not ok then
    self:ReportError("RegisterEvent " .. tostring(event), err)
  end
  return ok
end

function AceM2L2:SafeUnregister(event)
  pcall(self.UnregisterEvent, self, event)
end
