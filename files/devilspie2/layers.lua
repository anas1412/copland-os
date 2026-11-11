-- Copland OS layers: each app opens on its own workspace.
--   Layer:01 Claude   Layer:02 browser   Layer:03 terminals   Layer:04 everything else
-- Only normal app windows are placed; dialogs, menus and the panel are left alone.

local FOLLOW = true   -- true: switch to the layer when an app opens there

if get_window_type() ~= "WINDOW_TYPE_NORMAL" then return end

local cls = string.lower((get_class_instance_name() or "") .. " " .. (get_window_class() or ""))

-- Things that should appear wherever you are.
local stay = { "xfce4%-panel", "wrapper", "xfdesktop", "xfce4%-notifyd", "xfce4%-appfinder",
               "xfce4%-screenshooter", "whiskermenu", "xfce4%-session", "xfsm", "polkit" }
for _, p in ipairs(stay) do
  if cls:find(p) then return end
end

local layer
if cls:find("claude") then
  layer = 1
elseif cls:find("brave") or cls:find("firefox") or cls:find("chromium") or cls:find("chrome") then
  layer = 2
elseif cls:find("terminal") or cls:find("xterm") or cls:find("alacritty") or cls:find("kitty") then
  layer = 3
else
  layer = 4
end

set_window_workspace(layer)
if FOLLOW then change_workspace(layer) end
