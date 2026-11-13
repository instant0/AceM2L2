-- Minimal real-library load smoke test.
-- Loads the embedded libraries in the same order as embeds.xml using only the
-- frame APIs they touch during load.

local function NewObject()
  local object = {}
  setmetatable(object, {
    __index = function(_, key)
      if key == "CreateTexture" or key == "CreateFontString" then
        return function()
          return NewObject()
        end
      end
      return function() end
    end,
  })
  return object
end

function CreateFrame()
  return NewObject()
end

UIParent = NewObject()
Minimap = NewObject()

dofile("Libs/LibStub/LibStub.lua")
dofile("Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua")
dofile("Libs/LibDataBroker-1.1/LibDataBroker-1.1.lua")
dofile("Libs/LibDBIcon-1.0/LibDBIcon-1.0.lua")
dofile("Libs/AceAddon-3.0/AceAddon-3.0.lua")
dofile("Libs/AceConsole-3.0/AceConsole-3.0.lua")
dofile("Libs/AceEvent-3.0/AceEvent-3.0.lua")

assert(LibStub, "LibStub did not load")
for _, name in ipairs({
  "CallbackHandler-1.0",
  "LibDataBroker-1.1",
  "LibDBIcon-1.0",
  "AceAddon-3.0",
  "AceConsole-3.0",
  "AceEvent-3.0",
}) do
  assert(LibStub(name, true), "library did not register: " .. name)
end

print("Embedded library smoke test passed")
