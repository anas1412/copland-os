-- Copland OS layers: open each app on the workspace you chose for it.
-- The choices live in ~/.config/copland-os/layers.conf; edit them with `copland-layers`.
-- Only normal app windows are placed; dialogs, menus and the panel are left alone.

if get_window_type() ~= "WINDOW_TYPE_NORMAL" then return end

local cls = string.lower((get_class_instance_name() or "") .. " " .. (get_window_class() or ""))

-- Things that should always appear wherever you are.
local stay = { "xfce4-panel", "wrapper", "xfdesktop", "xfce4-notifyd", "xfce4-appfinder",
               "xfce4-screenshooter", "whiskermenu", "xfce4-session", "xfsm", "polkit" }
for _, p in ipairs(stay) do
  if cls:find(p, 1, true) then return end
end

local follow, default, rules = true, 0, {}
local conf = io.open((os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/copland-os/layers.conf", "r")
if conf then
  for line in conf:lines() do
    local k, v = line:match("^%s*([^#=]-)%s*=%s*(.-)%s*$")
    if k and k ~= "" then
      if k == "follow" then
        follow = (v == "true")
      elseif k == "default" then
        default = tonumber(v) or 0
      elseif tonumber(v) then
        rules[#rules + 1] = { string.lower(k), tonumber(v) }
      end
    end
  end
  conf:close()
end

local layer = default
for _, r in ipairs(rules) do
  if cls:find(r[1], 1, true) then layer = r[2]; break end
end

if layer and layer >= 1 then
  set_window_workspace(layer)
  if follow then change_workspace(layer) end
end
