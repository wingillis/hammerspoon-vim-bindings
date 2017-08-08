function mergeArrays(ar1, ar2)
	-- add each array value to a table, and send the iteration at the end
	local tmp = {}
	for _, v in ipairs(ar1) do
		tmp[v] = true
	end
	for _, v2 in ipairs(ar2) do
		tmp[v2] = true
	end
	local output = {}
	for k, v in pairs(tmp) do
		table.insert(output, k)
	end
	return output
end

function mergeTables(t1, t2)
	local output = {}
	for k, v in pairs(t1) do
		if t2[k] == nil then
			output[k] = v
		else
			outpu[k] = t2[k]
		end
	end

	for k, v in pairs(t2) do
		if output[k] == nil then
			output[k] = v
		end
	end
	return output
end

function delayedKeyPress(mod, char, delay)
	-- if needed you can do a delayed keypress by `delay` seconds
	return hs.timer.delayed.new(delay, function ()
		keyPress(mod, char)
	end)
end

function keyPress(mod, char)
	-- press a key for 20ms
	hs.eventtap.keyStroke(mod, char, 10000)
end

function keyPressFactory(mod, char)
	-- return a function to press a certain key for 20ms
	return function () keyPress(mod, char) end
end

function complexKeyPressFactory(mods, keys)
	-- mods and keys are arrays and have to be the same length
	return function ()
		for i, v in ipairs(keys) do
			keyPress(mods[i], keys[i])
		end
	end
end

local Vim = {}

function Vim:new()
	newObj = {state = 'normal',
						keyMods = {}, -- these are like cmd, alt, shift, etc...
						commandMods = nil, -- these are like d, y, c in normal mode
						numberMods = 0, -- for # times to do an action
						debug = false,
						events = 0 -- flag for # events to let by the event mngr
					}

	self.__index = self
	return setmetatable(newObj, self)
end

function Vim:setDebug(val)
	self.debug = val
end

function Vim:start()
	local selfPointer = self
	self.tapWatcher = hs.eventtap.new({hs.eventtap.event.types.keyDown}, function(evt)
		return self:eventWatcher(evt)
	end)
	self.modal = hs.hotkey.modal.new({"alt"}, "escape")
	function self.modal:entered()
		-- reset to the normal mode
		selfPointer.tapWatcher:start()
		hs.alert('vim mode')
	end
	function self.modal:exited()
		selfPointer.tapWatcher:stop()
		selfPointer:setMode('normal')
		selfPointer:resetEvents()
	end

end

function Vim:handleKeyEvent(char)
	-- check for text modifiers
	local modifiers = 'dcyr'
	local stop_event = true -- stop event from propagating
	local keyMods = self.keyMods
	if self.commandMods ~= nil and string.find('dcy', self.commandMods) ~= nil then
		-- using shift to delete and select things even in visual mode
		keyMods = mergeArrays(keyMods, {'shift'})
	end
	-- allows for visual mode too
	local movements = {
		j = keyPressFactory(keyMods, 'down'),
		k = keyPressFactory(keyMods, 'up'),
		h = keyPressFactory(keyMods, 'left'),
		l = keyPressFactory(keyMods, 'right'),
		['0'] = keyPressFactory(mergeArrays(keyMods, {'cmd'}), 'left'),
		['$'] = keyPressFactory(mergeArrays(keyMods, {'cmd'}), 'right'),
		b = keyPressFactory(mergeArrays(keyMods, {'alt'}), 'left'),
		e = keyPressFactory(mergeArrays(keyMods, {'alt'}), 'right'),
		w = complexKeyPressFactory({mergeArrays(keyMods, {'alt'}), keyMods}, {'right', 'right'}),
		x = complexKeyPressFactory({{'shift'}, {'cmd'}, {}}, {'left', 'c', 'delete'})
	} -- movements to make

	local modifierKeys = {
		d = complexKeyPressFactory({{'cmd'}, {}}, {'c', 'delete'}),
		c = complexKeyPressFactory({{'cmd'}, {}, {}}, {'c', 'delete', 'i'}),
		y = complexKeyPressFactory({{'cmd'}, {}}, {'c', 'right'}),
		r = complexKeyPressFactory({{}, {}}, {'delete', char})
	} -- keypresses for the modifiers after the movement

	local numEvents = {
		j = 1,
		k = 1,
		h = 1,
		l = 1,
		['0'] = 1,
		['$'] = 1,
		b = 1,
		e = 1,
		x = 3,
		w = 2,
		d = 2,
		c = 2,
		y = 2,
		r = 2
	} -- table of events the system has to let past for this

	if movements[char] ~= nil and self.commandMods ~= 'r' then
		-- do movement commands, but state-dependent
		self.events = numEvents[char]
		movements[char]()
		stop_event = true
	elseif modifiers:find(char) ~= nil and self.commandMods == nil then
		if self.debug then
			print('Modifier character: ' .. char)
		end
		self.commandMods = char
		stop_event = true
	end

	if self.commandMods ~= nil and modifiers:find(self.commandMods) ~= nil then
		-- do something related to modifiers
		-- run this block only after movement-related code
		if modifiers:find(char) == nil then
			self.events = self.events + numEvents[self.commandMods]
			modifierKeys[self.commandMods]()
			self.commandMods = nil
			-- reset
			self:setMode('normal')
		elseif char ~= 'r' and self.state == 'visual' then
			self.events = self.events + numEvents[self.commandMods]
			modifierKeys[self.commandMods]()
			self.commandMods = nil
			self:setMode('normal')
		end
	end

	if self.state == 'insert' then
		stop_event = false
	end
	return stop_event
end

function Vim:eventWatcher(evt)
	-- stop an event from propagating through the event system
	local stop_event = true
	local evtChar = evt:getCharacters()
	if self.debug then
		print('in eventWatcher: pressed ' .. evtChar)
	end
	local insertEvents = 'iIsaAoO'
	-- this function mostly handles the state-dependent events
	if self.events > 0 then
		if self.debug then
			print('an event is occurring ' .. self.events)
		end
		stop_event = false
		self.events = self.events - 1
	elseif evtChar == 'v' then
		-- if v key is hit, then go into visual mode
		self:setMode('visual')
		return stop_event
	elseif evtChar == ':' then
		-- do nothing for now because no ex mode
		self:setMode('ex')
		-- TODO: implement ex mode
	elseif evt:getKeyCode() == hs.keycodes.map['escape'] then
		-- get out of visual mode
		self:setMode('normal')
	elseif evtChar == 'u' then
		-- special undo key
		self.events = 1
		keyPress({'cmd'}, 'z')
	elseif evtChar == 'p' then
		self.events = 1
		keyPress({'cmd'}, 'v')
		self:setMode('normal')
	elseif insertEvents:find(evtChar, 1, true) ~= nil and self.state == 'normal' then
		-- do the insert
		self:insert(evtChar)
	else
		-- anything else, literally
		if self.debug then
			print('handling key press event for movement')
		end
		stop_event = self:handleKeyEvent(evtChar)
	end
	return stop_event
end

function Vim:insert(char)
	-- if is an insert event then do something
	-- ...
	self.events = 1
	if char == 's' then
		-- delete character and exit
		keyPress('', 'forwarddelete')
	elseif char == 'a' then
		keyPress('', 'right')
	elseif char == 'A' then
		keyPress({'cmd'}, 'right')
	elseif char == 'I' then
		keyPress({'cmd'}, 'left')
	elseif char == 'o' then
		self.events = 2
		complexKeyPressFactory({{'cmd'}, {}}, {'right', 'return'})()
	elseif char == 'O' then
		self.events = 3
		complexKeyPressFactory({{'cmd'}, {}, {}}, {'left', 'up', 'return'})()
	end
	-- TODO: implement o and O

	local selfRef = self
	hs.timer.delayed.new(0.01*self.events + 0.001, function ()
		selfRef:exitModal()
	end):start()
end

function Vim:exitModal()
	self.modal:exit()
end

function Vim:resetEvents()
	self.events = 0
end

function Vim:setMode(val)
	self.state = val
	-- TODO: change any other flags that are important for visual mode changes
	if val == 'visual' then
		self.keyMods = {'shift'}
		self.commandMods = nil
		self.numberMods = 0
		self.moving = false
	elseif val == 'normal' then
		self.keyMods = {}
		self.commandMods = nil
		self.numberMods = 0
		self.moving = false
	elseif val == 'ex' then
		-- do nothing because this is not implemented
	elseif val == 'insert' then
		-- do nothing because this is a placeholder
		-- insert mode is mainly for pasting characters or eventually applying
		-- recordings
		-- TODO: implement the recording feature
	end
end

-- what are the characters that end visual mode? y, p, x, d, esc

-- TODO: future implementations could use composition instead
-- TODO: add an ex mode into the Vim class using the chooser API

return Vim
