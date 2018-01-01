local Vim = {}

local states = {
	normal='normal',
	insert='insert',
	ex='ex',
	visual='visual'
}

function Vim:new()
	-- create new Vim object, initialize some default variables
	local newObj = {
		state=states.normal,
		number_modifier=0, -- how many times to repeat a command
		command_modifier=nil,
		events=0,
		tap_watcher=nil,
		modal=nil,
		menubar=nil,
		chooser=nil,
		ex_input=nil
	}
	self.__index = self
	return setmetatable(newObj, self)
end

function Vim:setDebug(bool)
	self.debug = bool
end

function Vim:start()
	-- initialize the event watchers and keybindings
	local self_pointer = self
	self.tap_watcher = hs.eventtap.new({hs.eventtap.event.types.keyDown},
		function(event)
			-- returns true or false, to signify if event should be
			-- further processed
			return self_pointer:eventWatcher(event)
		end)
	-- create a modal (which triggers the key press event watcher
	local modal = hs.hotkey.modal.new({'alt'}, 'escape')

	function modal:entered()
		self_pointer:setState(states.normal)
		self_pointer.tap_watcher:start()
	end

	function modal:exited()
		self_pointer.tap_watcher:stop()
		self_pointer:setState(states.insert)
		-- self_pointer:reset()
	end

	local chooser = hs.chooser.new(function(input)
		self_pointer:exListener()
	end)
	-- chooser:queryChangedCallback(function
	chooser:bgDark(false)

	-- set up in insert mode and create menu bar
	self.menubar = hs.menubar.new()
	self.modal = modal
	self.chooser = chooser
	self:setState(states.insert)
end

function Vim:setState(state)
	self.state = state
	-- TODO: add rest
	if state == states.normal then
		-- normal initializations
		-- 
	elseif state == states.insert then
		-- insert inits
	elseif state == states.ex then
		-- initialize ex mode
		self.chooser:show()
	elseif state == states.visual then
		-- visual inits
	end
end

function Vim:exListener()
	-- executes the input from ex mode
	local query = self.chooser:query()
	print(query)

	self:setState(states.normal)
end

function Vim:eventWatcher(event)
	local silent = false
	local char = event:getCharacters()

	if char == ';' then
		silent = true
		self:setState(states.ex)
	elseif char == 'i' and self.state == states.normal then
		self.modal:exit()
	end

	return silent -- true or false
end

return Vim
