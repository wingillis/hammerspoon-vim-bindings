-- example of how to load the vim-bindings file into your hammerspoon init

-- put vim_bindings.lua in your ~/.hammerspoon/ directory
Vim = require('vim_bindings')

local v = Vim:new()
-- v:setDebug(true) -- uncomment this if you want some things printed to the hammerspoon console
v:start()

transferMap = {
  q='s',
  w='i',
  e='a',
  r='e',
  c=hs.keycodes.map["space"],
  n='.',
  u='t',
  i='o',
  o='n',
  p='h',
  ui=hs.keycodes.map['delete'],
  qn='b',
  ow='c',
  nc='d',
  nr='f',
  pr='g',
  pc='j',
  co='k',
  ie='l',
  uc='m',
  ro='p',
  ir='q',
  ru='r',
  oe='u',
  ci='v',
  eu='w',
  en='v',
  wp='y',
  ep='z',
  re=hs.keycodes.map['return'],
  op=hs.keycodes.map['forwarddelete'],
  nw='?'
}

local newMap = {}

for k,v in pairs(transferMap) do
  local key = {}
  k:gsub(".", function(c) table.insert(key, c) end)
  table.sort(key)
  newMap[table.concat(key, '')] = v
end

newBoardStarted = false
transferMap = newMap
currChar = nil

keysDown = {
  q=false, w=false, e=false, r=false, c=false,
  n=false, u=false, i=false, o=false, p=false
}
keysToAdd = {}
typing = false

typingTimer = hs.timer.delayed.new(0.002, function ()
  typing = false
  currChar = nil
end)

keyNotifyTimer = hs.timer.delayed.new(0.08, function ()
  if next(keysToAdd) ~= nil then
  	local keys = {}
  	for k, v in pairs(keysToAdd) do
  		table.insert(keys, k)
		end
    table.sort(keys)
    local keycombo = table.concat(keys, '')
    local result = transferMap[keycombo]
    if result ~= nil then
      typing = true
      typingTimer:start()
      currChar = result
      hs.eventtap.keyStroke({}, result, 1000);
    elseif keycombo == 'pq' then
    	typing = true
      hs.eventtap.keyStroke({'ctrl', 'alt'}, 'Space', 1000)
    end
  end
  keysToAdd = {}
  timerOn = false
end)


timerOn = false

tapWatcher = hs.eventtap.new({hs.eventtap.event.types.keyDown}, function(evt)
  local evtChar = evt:getCharacters()
  if typing then
    return false
  else
    if keysDown[evtChar] ~= nil then
      keysDown[evtChar] = true
      if keysToAdd[evtChar] == nil then
      	keysToAdd[evtChar] = true
			end
    end
    if timerOn == false then
      timerOn = true
      keyNotifyTimer:start()
      for k, v in pairs(keysDown) do
      	if v and keysToAdd[k] == nil then
      		keysToAdd[k] = true
				end
			end
    end
    return true
  end
end)

tapUpWatcher = hs.eventtap.new({hs.eventtap.event.types.keyUp}, function(evt)
  local evtChar = evt:getCharacters()
  if keysDown[evtChar] ~= nil and currChar ~= evtChar then
    keysDown[evtChar] = false
  end
  return false
end)

hs.hotkey.bind({"ctrl", "alt"}, "Space", function()
  if newBoardStarted then
    tapWatcher:stop()
	  tapUpWatcher:stop()
  else
  	tapWatcher:start()
  	tapUpWatcher:start()
  end
end)
