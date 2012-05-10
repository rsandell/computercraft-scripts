--
-- The MIT License
--
-- Copyright 2012 Robert Sandell. All rights reserved.
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.
--

--
-- This nice little program allows you to control several machines over wireless rednet.
--


--Global Vars
TYPES = {MASTER=0,SLAVE=1,ROUTER=2}
machineOn = false
machineStatusChanged = "None"
currentLocalMessageId = 0
configFileName = "buildnet.cfg"

computerConfig = {label = nil, type = nil}


--API/Utility Functions

--Reads the locally stored config file to get the computerConfig table.
local function readConfigFile() 
	if fs.exists(configFileName) then
		local h = fs.open(configFileName, "r")
		local configTxt = h.readAll()
		--print(configTxt)
		if configTxt ~= nil then
			local conf = textutils.unserialize(configTxt)
			if conf ~= nil and not(conf["label"] == nil or conf["type"] == nil) then				
				computerConfig = conf
			end
		end
		h.close()
	end
end

local function writeConfigFile()
	local h = fs.open(configFileName, "w")
	h.write(textutils.serialize(computerConfig))
	h.close()
end

--Parses a buildnet message
local function parseMessage(_message)
  local messageId, generation, from, to, internalMessage = string.match(_message, "(%d+):(%d+):(%d+):(%d+):(.+)")
  local m = {id = messageId, gen = generation, from = from, to = to, m = internalMessage}
  return m
end

--Creates a new (Generation 0) buildnet message
local function newMessage(to, message)
  local messageId = os.computerID()..""..currentLocalMessageId
  local format = messageId..":0:"..os.computerID()..":"..to..":"..message
  currentLocalMessageId = currentLocalMessageId + 1
  return format
end

--Fraw a static menu on the screen
local function drawMenu(title, table, selectedValue)
	term.clear()
    term.setCursorPos(2,1)
    print(title)
    local row = 3
	for key,value in pairs(table) do
		term.setCursorPos(2, row)
		local prefix = "  [ ] "
		if value == selectedValue then
			prefix = "  [X] "
		end
		print(prefix..key)
    	row = row + 1
	end
	--print(selectedValue)
end

--Gives the index of the value of the key value pairs
local function getIndexOfValue(table, val)
	local i = 0
	for key,value in pairs(table) do
		if value == val then
			return i
		end
		i = i + 1
	end
end

--Gives the value of the key value pair at the index
local function getValueOfIndex(table, index)
	local i = 0
	for key,value in pairs(table) do
		if i == index then
			return value
		end
		i = i + 1
	end
end

local function getTableLength(table)
	local i = 0
	for key,value in pairs(table) do		
		i = i + 1
	end
	return i
end

local function getMenuSelection(title, table, selectedValue)
	local currentValue = selectedValue
	local selectedIndex = getIndexOfValue(table, currentValue)
	local tableLength = getTableLength(table)
	while true do
		drawMenu(title, table, currentValue)
		local a, b= os.pullEventRaw()
		--print(a)
		--print(b)
		--print("Tableleth: "..tableLength)
		if a == "key" then
			if b==200 then
				--print("Going up")
				if selectedIndex > 0 then
					selectedIndex = selectedIndex - 1				
				else
					selectedIndex = tableLength - 1
				end				
				currentValue = getValueOfIndex(table, selectedIndex) 
			end
			if b==208 then
				if selectedIndex < (tableLength - 1) then
					--print("Going Down") 
					selectedIndex = selectedIndex + 1
				else
					selectedIndex = 0
				end
				currentValue = getValueOfIndex(table, selectedIndex)
			end
			if b==28 then 
				return currentValue 
			end
		end
	end	
end

local function readSettings()
	readConfigFile()
	--Did the file contain any settings?
	if computerConfig == nil or (computerConfig["label"] == nil or computerConfig["type"] == nil) then		
		print("Please Provide a BuildNet label: ")
		local name = io.read()
		local sel = getMenuSelection("Select what type of BuildNet computer", TYPES, 1)
		computerConfig = {label = name, type = sel}
		writeConfigFile()
	end	
end

--Main Threads

--Reads the redstone status from the back whenever a redstone event occurs.
local function readStatus()
  while true do
    local event = os.pullEvent("redstone")
    local on = redstone.getInput("back")
    if on ~= machineOn then
      machineOn = on
      machineStatusChanged = os.time()
    end
  end
end

--Prints the redstone status on the screen each second.
local function printStatus()
  while true do
    term.clear()
    term.setCursorPos(2,2)
    if machineOn then
      print("  Status: ON @"..machineStatusChanged)
    else
      print("  Status: OFF @"..machineStatusChanged)
    end
    term.setCursorPos(2,4)
    print("Press [x] to exit.")
    os.sleep(1)
  end
end

--Waits for the x key and then exits terminating the program.
local function waitForTheKey()
  local theKey = "B"
  while (theKey ~= "x" and theKey ~= "X") do
    local event, param1 = os.pullEvent("char")
    theKey = param1
  end
end

local function rednetProbe()
	rednet.open("top")
	print("Rednet open on Computer #"..os.computerID())
	while true do
	  senderId, message, distance = rednet.receive()
	  print("#"..senderId..": "..message)
	  print("                           Press X To Exit")	  
	end
end

--MAIN


readSettings()

print("Label: "..computerConfig.label)
print("Type: "..computerConfig.type)
if computerConfig.type == TYPES.SLAVE then
	parallel.waitForAny(readStatus, printStatus, waitForTheKey)

elseif computerConfig.type == TYPES.ROUTER then
	print("I Am supposed to be a router, please implement that fully")
	parallel.waitForAny(rednetProbe, waitForTheKey)

elseif computerConfig.type == TYPES.MASTER then
	print("I Am supposed to be a master of the universe, implement that NOW!")

else
	print("Configuration Error! Unknown BuildNode computer type: "..computerConfig.type)
	print("Exiting horribly and detonating the nuclear reactors!")
end

--- END of MAIN
