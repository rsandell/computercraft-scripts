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
BN_VERSION = "0.9"
TYPES = {MASTER=0,SLAVE=1,ROUTER=2}
MESSAGE_TYPES = {REDSTATUS = 0, REDTOGGLE = 1, PINGREQUEST = 2, PINGRESPONSE = 3}
SIDES = {left = "left", right = "right", top = "top", bottom = "bottom", back = "back", front = "front"}
machineOn = false
machineStatusChanged = "None"
currentLocalMessageId = 0
configFileName = "buildnet.cfg"

computerConfig = {label = nil, type = nil, indicatorSide = "back", modemSide = "top", controlSide = "left"}


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
  local messageId, generation, from, to, internalMessage = string.match(_message, "BN:(%d+):(%d+):(%d+):(.+):(.+)")
  if messageId == nil then
  	return nil
  else
  	local d = textutils.unserialize(internalMessage)
  	local m = {id = messageId, gen = generation, from = from, to = to, data = d}
  	return m
  end
end

--Creates a BuildNet message from the given table
local function toMessageString(m)
	local d = textutils.serialize(m.data)
	local format = "BN:"..m.id..":"..m.gen..":"..m.from..":"..m.to..":"..d
	return format
end

--Creates a new (Generation 0) buildnet message
local function newMessage(_to, _message)
  local messageId = os.computerID()..""..currentLocalMessageId
  currentLocalMessageId = currentLocalMessageId + 1
  return toMessageString({id = messageId, gen = 0, from = os.computerID(), to = _to, data = _message})  
end

--Sends the message as a rednet broadcast
local function sendMessage(_messageString)
	rednet.broadcast(_messageString)
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
		local selType = getMenuSelection("Select what type of BuildNet computer", TYPES, 1)
		local selModem = getMenuSelection("What side is the Modem?", SIDES, "top")
		local selControl = getMenuSelection("What side to send control signal?", SIDES, "left")
		local selIndicator = getMenuSelection("What side to read status?", SIDES, "back")
		computerConfig = {label = name, type = selType, indicatorSide = selIndicator, modemSide = selModem, controlSide = selControl}
		writeConfigFile()
	end	
end

local function isItForMe(_message)	
	if _message.to == "ALL" or _message.to == (""..os.computerID()) then		
		return true
	else
		return false
	end
end

local function toggleRedstoneSignal()
	local on = redstone.getOutput(computerConfig.controlSide);
	redstone.setOutput(computerConfig.controlSide, not on)
end

local function sendSlaveStatus()
	local message = {type = MESSAGE_TYPES.REDSTATUS, label = computerConfig.label, status = machineOn}
    local messageString = newMessage("ALL", message)
    sendMessage(messageString)
end

local function sendPingRequest(_to)
	local message = {type = MESSAGE_TYPES.PINGREQUEST}
    local messageString = newMessage(_to, message)
    sendMessage(messageString)
end

--Main Threads


local function slaveCommandListener()
	while true do
		local senderId, messageString, distance = rednet.receive()
		local message = parseMessage(messageString)
		if isItForMe(message) then
			if message.data.type == MESSAGE_TYPES.PINGREQUEST then
				sendSlaveStatus()
			elseif message.data.type == MESSAGE_TYPES.REDTOGGLE then
				toggleRedstoneSignal()
			end
		end --TODO echo message if not for me and haven't seen before
	end
end

--Reads the redstone status from the back whenever a redstone event occurs.
local function readSlaveStatus()
  while true do
    local event = os.pullEvent("redstone")
    local on = redstone.getInput(computerConfig.indicatorSide)
    if on ~= machineOn then
      machineOn = on
      machineStatusChanged = os.time()
      sendSlaveStatus()
    end
  end
end

--Prints the redstone status on the screen each second.
local function printSlaveStatus()
  while true do
    term.clear()
    term.setCursorPos(2,1)
    print("BuildNet v. "..BN_VERSION)
    term.setCursorPos(2,3)
    if machineOn then
      print(" "..computerConfig.label.."  Status: ON  @"..machineStatusChanged)
    else
      print(" "..computerConfig.label.."  Status: OFF @"..machineStatusChanged)
    end
    term.setCursorPos(2,5)
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
	print("Rednet open on Computer #"..os.computerID())
	while true do
	  senderId, message, distance = rednet.receive()
	  print("#"..senderId..": "..message)
	  print("                           Press X To Exit")	  
	end
end

--MESSAGE_TYPES = {REDSTATUS = 0, REDTOGGLE = 1, PINGREQUEST = 2, PINGRESPONSE = 3}
masterSlaveInfo = {}
selectedSlaveIndex = 0
maxSlavesDisplayed = 0

local function drawMasterScreen()
	term.clear()
    term.setCursorPos(1,1)
    print("BuildNet v. "..BN_VERSION.."  [Master] "..computerConfig.label)
    local startingRow = 3
    local width, height = term.getSize()    
    local i = 0
	for id,info in pairs(masterSlaveInfo) do
		local currentRow = startingRow + i
		term.setCursorPos(5, currentRow)
		if currentRow >= height - 1 then
			print("Too many machines online!")
			break
		else
			if i == selectedSlaveIndex then
				print(" > "..info.label)
			else
				print("   "..info.label)
			end
			term.setCursorPos(width - 12,startingRow + i)
			if info.status then
				print("ON")
			else
				print("OFF")
			end
		end
		i = i + 1
	end
	maxSlavesDisplayed = i
	term.setCursorPos(width - 12, height - 1)
	print("[x] to Exit")
end

local function masterSlaveInfoCleaner()
	while true do
		os.sleep(10)
		masterSlaveInfo = {}
		sendPingRequest("ALL")
	end
end


local function updateMasterSlaveInfo(_message)
	--{type = MESSAGE_TYPES.REDSTATUS, label = computerConfig.label, status = machineOn}
	local info = {label = _message.data.label, status = _message.data.status, computerId = _message.from}
	masterSlaveInfo["".._message.from] = info
	drawMasterScreen()
end

local function masterRednetListener()
	sendPingRequest("ALL")
	while true do
		local senderId, messageString, distance = rednet.receive()
		local message = parseMessage(messageString)
		if message ~= nil then
			if isItForMe(message) then
				if message.data.type == MESSAGE_TYPES.REDSTATUS then
					updateMasterSlaveInfo(message)
				elseif message.data.type == MESSAGE_TYPES.PINGRESPONSE then
					--TODO Something?
				end
			end --TODO echo message if not for me and haven't seen before
		else
			print("No parseable message!")
		end
	end
end

local function sendToggleRedstone()	
	local i = 0
	for id,info in pairs(masterSlaveInfo) do
		if i == selectedSlaveIndex then
			local message = {type = MESSAGE_TYPES.REDTOGGLE}
      		local messageString = newMessage(id, message)
      		sendMessage(messageString)
		end
		i = i + 1
	end
end

local function masterKeyListener()
	while true do
		local event, key = os.pullEvent("key")			
		if key==200 then --UP			
			if selectedSlaveIndex > 0 then
				selectedSlaveIndex = selectedSlaveIndex - 1				
			else
				selectedSlaveIndex = maxSlavesDisplayed - 1
			end
			drawMasterScreen()
		end
		if key==208 then --DOWN
			if selectedSlaveIndex < (maxSlavesDisplayed - 1) then				 
				selectedSlaveIndex = selectedSlaveIndex + 1
			else
				selectedSlaveIndex = 0
			end
			drawMasterScreen()
		end
		if key==28 then --ENTER
			sendToggleRedstone()
			drawMasterScreen() 
		end		
		if key==45 then --x
			return "X" 
		end		
	end
end

--MAIN


readSettings()

print("Label: "..computerConfig.label)
print("Type: "..computerConfig.type)

rednet.open(computerConfig.modemSide)

if computerConfig.type == TYPES.SLAVE then
	machineOn = redstone.getInput(computerConfig.indicatorSide)    
    machineStatusChanged = os.time()
    sendSlaveStatus()
	parallel.waitForAny(readSlaveStatus, printSlaveStatus, slaveCommandListener, waitForTheKey)

elseif computerConfig.type == TYPES.ROUTER then
	print("I Am supposed to be a router, please implement that fully")
	parallel.waitForAny(rednetProbe, waitForTheKey)

elseif computerConfig.type == TYPES.MASTER then
	drawMasterScreen()
	parallel.waitForAny(masterRednetListener, masterKeyListener, masterSlaveInfoCleaner)

else
	print("Configuration Error! Unknown BuildNode computer type: "..computerConfig.type)
	print("Exiting horribly and detonating the nuclear reactors!")
end

--- END of MAIN
