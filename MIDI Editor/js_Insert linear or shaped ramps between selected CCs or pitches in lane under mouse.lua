--[[
 * ReaScript Name:  Insert linear or shaped ramps between selected CCs or pitches in lane under mouse
 * Description:   Useful for quickly adding ramps between 'nodes'.
 *                Useful for smoothing transitions between CCs that were drawn at low resolution.
 *
 *      The script starts with a dialog box in which the user can set:
 *                - the CC density, 
 *                - the shape of the ramp (as a linear or power function),
 *                - whether the new events should be selected, and
 *                - whether redundant events (that would duplicate the value of previous event) should be skipped.
 *                (Any extraneous CCs/pitchbend between selected events are deleted)
 *
 * Instructions:  For faster one-click execution, the code for the user input dialog box can be commented out.
 *      Combine with warping script to easily insert all kinds of weird shapes.
 * Screenshot: 
 * Notes: 
 * Category: 
 * Author: juliansader
 * Licence: GPL v3
 * Forum Thread: 
 * Forum Thread URL: http://forum.cockos.com/showthread.php?t=176878
 * Version: 1.1
 * REAPER: 5.20
 * Extensions: SWS/S&M 2.8.3
]]
 

--[[
 Changelog:
 * v1.0 (2016-05-15)
    + Initial Release
 * v1.1 (2016-05-18)
    + Added compatibility with SWS versions other than 2.8.3 (still compatible with v2.8.3)
]] 

--------------------------------------------------------------------

function drawRamp7bitCC()  
          
    tableCC = {}
        
    eventIndex = reaper.MIDI_EnumSelCC(take, -1)
    startChannel = false
    while(eventIndex ~= -1) do
        _, _, mute, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, eventIndex)
        if (chanmsg>>4) == 11 and msg2 == mouseLane then
            if startChannel ~= false and startChannel ~= chan then
                reaper.ShowConsoleMsg("Error: All selected events should be in the same channel")
                return(0)
            else
            startChannel = chan
            table.insert(tableCC, {index = eventIndex, 
                                   PPQ = ppqpos, 
                                   value = msg3,
                                   muted = mute}) 
            end -- if startChannel ~= false and startChannel ~= chan
        end -- if (chanmsg>>4) == 11 and msg2 == mouseLane
        eventIndex = reaper.MIDI_EnumSelCC(take, eventIndex)            
    end -- while(eventIndex ~= -1)
    
    -- If no selected events in lane
    if #tableCC == 0 then return(0) end 

    -- Function to sort the table of events 
    -- (in case REAPER's MIDI_Sort is not reliable.
    function sortPPQ(a, b)
        if a.PPQ < b.PPQ then return true else return false end
    end  
    table.sort(tableCC, sortPPQ)
    
    ---------------------------------------------
    -- Delete all events between selected events, 
    -- but only if same type, channel and lane
    reaper.MIDI_Sort(take)
    _, _, ccevtcnt, _ = reaper.MIDI_CountEvts(take)
    for i = ccevtcnt-1, 0, -1 do     
        _, _, _, ppqpos, chanmsg, chan, msg2, _ = reaper.MIDI_GetCC(take, i)
        if ppqpos < tableCC[1].PPQ then break -- Once below range of selected events, no need to search further
        elseif ppqpos <= tableCC[#tableCC].PPQ
            and chan == startChannel -- same channel
            and msg2 == mouseLane -- in lane
            and chanmsg>>4 == 11 -- eventType is CC
            then
                reaper.MIDI_DeleteCC(take, i)
        end -- elseif
    end -- for i = ccevtcnt-1, 0, -1
    
    ----------------------------------------------------------------------------
    -- The main function that iterates through selected events and inserts ramps
    for i = 1, #tableCC-1 do

        if tableCC[i].PPQ ~= tableCC[i+1].PPQ then -- This is very weird, but can sometimes happen
        
            -- Calculate PPQ position of next grid beyond selected event
            eventQNpos = reaper.MIDI_GetProjQNFromPPQPos(take, tableCC[i].PPQ)
            nextGridQN = QNgrid*math.ceil(eventQNpos/QNgrid)
            nextGridPPQ = reaper.MIDI_GetPPQPosFromProjQN(take, nextGridQN) 
                  
            -- Insert the ramp of events
            prevCCvalue = tableCC[i].value
            for p = nextGridPPQ, tableCC[i+1].PPQ, PPgrid do
                -- REAPER will insert CCs on (rounded) integer PPQ values,
                --     so insertValue must be calculated at round(p).
                -- But lua does not have round function, so...
                pRound = math.floor(p+0.5)
                
                -- Calculate the interpolated CC values
                weight = ((pRound - tableCC[i].PPQ) / (tableCC[i+1].PPQ - tableCC[i].PPQ))^shape
                insertValue = math.floor(tableCC[i].value + (tableCC[i+1].value - tableCC[i].value)*weight)
                
                -- If redundant, skip insertion
                if not (skip == true and insertValue == prevCCvalue) then
                    reaper.MIDI_InsertCC(take, newSel, tableCC[i].muted, pRound, 11<<4, startChannel, mouseLane, insertValue)
                    prevCCvalue = insertValue
                end
                        
            end -- for p = nextGridPPQ, tableCC[i+1].PPQ, PPgrid
    
        end -- if tableCC[i].PPQ ~= tableCC[i+1].PPQ
            
    end -- for i = 1, #tableCC-1
  
    -- And finally, re-insert the original selected events
    for i = 1, #tableCC do
        reaper.MIDI_InsertCC(take, true, tableCC[i].muted, tableCC[i].PPQ, 176, startChannel, mouseLane, tableCC[i].value)
    end  
               
end -- function drawRamp7bitCC
------------------------------


--------------------------------------------------------------------

function drawRampChanPressure()  
          
    tableCC = {}
        
    eventIndex = reaper.MIDI_EnumSelCC(take, -1)
    startChannel = false
    while(eventIndex ~= -1) do
        _, _, mute, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, eventIndex)
        if (chanmsg>>4) == 13 then -- MIDI event type = channel pressure
            if startChannel ~= false and startChannel ~= chan then
                reaper.ShowConsoleMsg("Error: All selected events should be in the same channel")
                return(0)
            else
            startChannel = chan
            table.insert(tableCC, {index = eventIndex, 
                                   PPQ = ppqpos, 
                                   value = msg2,
                                   muted = mute}) 
            end -- if startChannel ~= false and startChannel ~= chan
        end -- if (chanmsg>>4) == 13
        eventIndex = reaper.MIDI_EnumSelCC(take, eventIndex)            
    end -- while(eventIndex ~= -1)
    
    -- If no selected events in lane
    if #tableCC == 0 then return(0) end 

    -- Function to sort the table of events 
    -- (in case REAPER's MIDI_Sort is not reliable.
    function sortPPQ(a, b)
        if a.PPQ < b.PPQ then return true else return false end
    end  
    table.sort(tableCC, sortPPQ)
    
    ---------------------------------------------
    -- Delete all events between selected events, 
    -- but only if same type, channel and lane
    reaper.MIDI_Sort(take)
    _, _, ccevtcnt, _ = reaper.MIDI_CountEvts(take)
    for i = ccevtcnt-1, 0, -1 do     
        _, _, _, ppqpos, chanmsg, chan, msg2, _ = reaper.MIDI_GetCC(take, i)
        if ppqpos < tableCC[1].PPQ then break -- Once below range of selected events, no need to search further
        elseif ppqpos <= tableCC[#tableCC].PPQ
            and chan == startChannel -- same channel
            and chanmsg>>4 == 13 -- eventType is Channel Pressure
            then
                reaper.MIDI_DeleteCC(take, i)
        end -- elseif
    end -- for i = ccevtcnt-1, 0, -1
    
    ----------------------------------------------------------------------------
    -- The main function that iterates through selected events and inserts ramps
    for i = 1, #tableCC-1 do

        if tableCC[i].PPQ ~= tableCC[i+1].PPQ then -- This is very weird, but can sometimes happen
        
            -- Calculate PPQ position of next grid beyond selected event
            eventQNpos = reaper.MIDI_GetProjQNFromPPQPos(take, tableCC[i].PPQ)
            nextGridQN = QNgrid*math.ceil(eventQNpos/QNgrid)
            nextGridPPQ = reaper.MIDI_GetPPQPosFromProjQN(take, nextGridQN) 
                  
            -- Insert the ramp of events
            prevCCvalue = tableCC[i].value
            for p = nextGridPPQ, tableCC[i+1].PPQ, PPgrid do
                -- REAPER will insert CCs on (rounded) integer PPQ values,
                --     so insertValue must be calculated at round(p).
                -- But lua does not have round function, so...
                pRound = math.floor(p+0.5)
                
                -- Calculate the interpolated CC values
                weight = ((pRound - tableCC[i].PPQ) / (tableCC[i+1].PPQ - tableCC[i].PPQ))^shape
                insertValue = math.floor(tableCC[i].value + (tableCC[i+1].value - tableCC[i].value)*weight)
                
                -- If redundant, skip insertion
                if not (skip == true and insertValue == prevCCvalue) then
                    reaper.MIDI_InsertCC(take, newSel, tableCC[i].muted, pRound, 13<<4, startChannel, insertValue, 0)
                    prevCCvalue = insertValue
                end
                        
            end -- for p = nextGridPPQ, tableCC[i+1].PPQ, PPgrid

        end -- if tableCC[i].PPQ ~= tableCC[i+1].PPQ
        
    end -- for i = 1, #tableCC-1
  
    -- And finally, re-insert the original selected events
    for i = 1, #tableCC do
        reaper.MIDI_InsertCC(take, true, tableCC[i].muted, tableCC[i].PPQ, 13<<4, startChannel, tableCC[i].value, 0)
    end  
               
end -- function drawRampChanPressure
------------------------------------


--------------------------------------------------------------------

function drawRampPitch()  
          
    tableCC = {}
        
    eventIndex = reaper.MIDI_EnumSelCC(take, -1)
    startChannel = false
    while(eventIndex ~= -1) do
        _, _, mute, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, eventIndex)
        if (chanmsg>>4) == 14 then
            if startChannel ~= false and startChannel ~= chan then
                reaper.ShowConsoleMsg("Error: All selected events should be in the same channel")
                return(0)
            else
            startChannel = chan
            table.insert(tableCC, {index = eventIndex, 
                                   PPQ = ppqpos, 
                                   value = msg3*128 + msg2,
                                   muted = mute}) 
            end -- if startChannel ~= false and startChannel ~= chan
        end -- if (chanmsg>>4) == 11 and msg2 == mouseLane
        eventIndex = reaper.MIDI_EnumSelCC(take, eventIndex)            
    end -- while(eventIndex ~= -1)
    
    -- If no selected events in lane
    if #tableCC == 0 then return(0) end 

    -- Function to sort the table of events 
    -- (in case REAPER's MIDI_Sort is not reliable.
    function sortPPQ(a, b)
        if a.PPQ < b.PPQ then return true else return false end
    end  
    table.sort(tableCC, sortPPQ)
    
    ---------------------------------------------
    -- Delete all events between selected events, 
    -- but only if same type, channel and lane
    reaper.MIDI_Sort(take)
    _, _, ccevtcnt, _ = reaper.MIDI_CountEvts(take)
    for i = ccevtcnt-1, 0, -1 do     
        _, _, _, ppqpos, chanmsg, chan, _, _ = reaper.MIDI_GetCC(take, i)
        if ppqpos < tableCC[1].PPQ then break -- Once below range of selected events, no need to search further
        elseif ppqpos <= tableCC[#tableCC].PPQ
            and chan == startChannel -- same channel
            and chanmsg>>4 == 14 -- eventType is pitchwheel
            then
                reaper.MIDI_DeleteCC(take, i)
        end -- elseif
    end -- for i = ccevtcnt-1, 0, -1
    
    ----------------------------------------------------------------------------
    -- The main function that iterates through selected events and inserts ramps
    for i = 1, #tableCC-1 do

        if tableCC[i].PPQ ~= tableCC[i+1].PPQ then -- This is very weird, but can sometimes happen
            -- Calculate PPQ position of next grid beyond selected event
            eventQNpos = reaper.MIDI_GetProjQNFromPPQPos(take, tableCC[i].PPQ)
            nextGridQN = QNgrid*math.ceil(eventQNpos/QNgrid)
            nextGridPPQ = reaper.MIDI_GetPPQPosFromProjQN(take, nextGridQN) 
                  
            -- Insert the ramp of events
            prevCCvalue = tableCC[i].value
            for p = nextGridPPQ, tableCC[i+1].PPQ, PPgrid do
                -- REAPER will insert CCs on (rounded) integer PPQ values,
                --     so insertValue must be calculated at round(p).
                -- But lua does not have round function, so...
                pRound = math.floor(p+0.5)
                
                -- Calculate the interpolated CC values
                weight = ((pRound - tableCC[i].PPQ) / (tableCC[i+1].PPQ - tableCC[i].PPQ))^shape
                insertValue = math.floor(tableCC[i].value + (tableCC[i+1].value - tableCC[i].value)*weight)
                
                -- If redundant, skip insertion
                if not (skip == true and insertValue == prevCCvalue) then
                    reaper.MIDI_InsertCC(take, newSel, tableCC[i].muted, pRound, 14<<4, startChannel, insertValue&127, insertValue>>7)
                    prevCCvalue = insertValue
                end
                              
            end -- for p = nextGridPPQ, tableCC[i+1].PPQ, PPgrid
        
        end -- if tableCC[i].PPQ ~= tableCC[i+1].PPQ
            
    end -- for i = 1, #tableCC-1
  
    -- And finally, re-insert the original selected events
    for i = 1, #tableCC do
        reaper.MIDI_InsertCC(take, true, tableCC[i].muted, tableCC[i].PPQ, 14<<4, startChannel, (tableCC[i].value)&127, (tableCC[i].value)>>7)
    end  
               
end -- function drawRampPitch
------------------------------


--------------------------------------------------------------------

function drawRamp14bitCC()  
          
    tableCC = {}
        
    -- All selected events in the MSB and LSB lanes will be stored in 
    --     separate temporary tables.  These tables will then be searched to
    --     find the LSB and MSB events that fall on the same ppq, 
    --     which means that they combine to form one 14-bit CC event.
    tempTableLSB = {}
    tempTableMSB = {}
    tableCC = {}
        
    eventIndex = reaper.MIDI_EnumSelCC(take, -1)
  
    while(eventIndex ~= -1) do
        _, _, mute, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, eventIndex)
        if (chanmsg>>4) == 11 and  msg2 == mouseLane-256 then -- 14bit MSB
            table.insert(tempTableMSB, {index = eventIndex, 
                                        PPQ = ppqpos, 
                                        value = msg3,
                                        channel = chan,
                                        muted = mute})
        elseif (chanmsg>>4) == 11 and msg2 == mouseLane-224 then -- 14bit LSB
            table.insert(tempTableLSB, {index = eventIndex, 
                                        PPQ = ppqpos, 
                                        value = msg3,
                                        channel = chan})
        end
        eventIndex = reaper.MIDI_EnumSelCC(take, eventIndex)            
    end -- while(eventIndex ~= -1)
    
    -- Now, find the LSB and MSB events that fall on the same ppq
    startChannel = false
    for l = 1, #tempTableLSB do
        for m = 1, #tempTableMSB do
            if tempTableLSB[l].PPQ == tempTableMSB[m].PPQ and tempTableLSB[l].channel == tempTableMSB[m].channel then
                if startChannel ~= false and startChannel ~= tempTableLSB[l].channel then
                    reaper.ShowConsoleMsg("Error: All selected events should be in the same channel")
                    return(0)
                else
                startChannel = tempTableLSB[l].channel
                table.insert(tableCC, {
                             PPQ = tempTableLSB[l].PPQ,
                             MSBindex = tempTableMSB[m].index,
                             LSBindex = tempTableLSB[l].index,
                             value = tempTableMSB[m].value*128 + tempTableLSB[l].value,
                             muted = tempTableMSB[m].muted})
                end -- if startChannel ~= false and startChannel ~= tempTableLSB[l].channel
            end -- if tempTableLSB[l].PPQ == tempTableMSB[m].PPQ
        end -- #tempTableMSB
    end -- #tempTableLSB
    
    -- If no selected events in lane
    if #tableCC == 0 then return(0) end 

    -- Function to sort the table of events 
    -- (in case REAPER's MIDI_Sort is not reliable.
    function sortPPQ(a, b)
        if a.PPQ < b.PPQ then return true else return false end
    end  
    table.sort(tableCC, sortPPQ)
    
    ---------------------------------------------
    -- Delete all events between selected events, 
    -- but only if same type, channel and lane
    reaper.MIDI_Sort(take)
    _, _, ccevtcnt, _ = reaper.MIDI_CountEvts(take)
    for i = ccevtcnt-1, 0, -1 do     
        _, _, _, ppqpos, chanmsg, chan, _, _ = reaper.MIDI_GetCC(take, i)
        if ppqpos < tableCC[1].PPQ then break -- Once below range of selected events, no need to search further
        elseif ppqpos <= tableCC[#tableCC].PPQ
            and chan == startChannel -- same channel
            and (msg2 == mouseLane-256 or msg2 == mouseLane-224) -- in either MSB or LSB lane
            and chanmsg>>4 == 11 -- eventType is CC
            then
                reaper.MIDI_DeleteCC(take, i)
        end -- elseif
    end -- for i = ccevtcnt-1, 0, -1
    
    ----------------------------------------------------------------------------
    -- The main function that iterates through selected events and inserts ramps
    for i = 1, #tableCC-1 do
        
        if tableCC[i].PPQ ~= tableCC[i+1].PPQ then -- This is very weird, but can sometimes happen
            -- Calculate PPQ position of next grid beyond selected event
            eventQNpos = reaper.MIDI_GetProjQNFromPPQPos(take, tableCC[i].PPQ)
            nextGridQN = QNgrid*math.ceil(eventQNpos/QNgrid)
            nextGridPPQ = reaper.MIDI_GetPPQPosFromProjQN(take, nextGridQN) 
                  
            -- Insert the ramp of events
            prevCCvalue = tableCC[i].value
            for p = nextGridPPQ, tableCC[i+1].PPQ, PPgrid do
                -- REAPER will insert CCs on (rounded) integer PPQ values,
                --     so insertValue must be calculated at round(p).
                -- But lua does not have round function, so...
                pRound = math.floor(p+0.5)
                
                -- Calculate the interpolated CC values
                weight = ((pRound - tableCC[i].PPQ) / (tableCC[i+1].PPQ - tableCC[i].PPQ))^shape
                insertValue = math.floor(tableCC[i].value + (tableCC[i+1].value - tableCC[i].value)*weight)
                
                -- If redundant, skip insertion
                if not (skip == true and insertValue == prevCCvalue) then
                    reaper.MIDI_InsertCC(take, newSel, tableCC[i].muted, pRound, 11<<4, startChannel, mouseLane-256, insertValue>>7)
                    reaper.MIDI_InsertCC(take, newSel, tableCC[i].muted, pRound, 11<<4, startChannel, mouseLane-224, insertValue&127)
                    prevCCvalue = insertValue
                end
                        
            end -- for p = nextGridPPQ, tableCC[i+1].PPQ, PPgrid
    
        end -- if tableCC[i].PPQ ~= tableCC[i+1].PPQ
        
    end -- for i = 1, #tableCC-1
  
    -- And finally, re-insert the original selected events
    for i = 1, #tableCC do
        reaper.MIDI_InsertCC(take, true, tableCC[i].muted, tableCC[i].PPQ, 11<<4, startChannel, mouseLane-256, (tableCC[i].value)>>7)
        reaper.MIDI_InsertCC(take, true, tableCC[i].muted, tableCC[i].PPQ, 11<<4, startChannel, mouseLane-224, (tableCC[i].value)&127)
   end  
               
end -- function drawRamp14bitCC
-------------------------------


---------------------------------------------------------------------
-- Here the code execustion starts
---------------------------------------------------------------------

-- Trying a trick to prevent creation of new undo state 
--     if code does not reach own Undo_BeginBlock
function noUndo()
end
reaper.defer(noUndo)

-- Test whether mouse is in MIDI editor
take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
if take == nil then return(0) end
_, _, details = reaper.BR_GetMouseCursorContext()
if details ~= "cc_lane" then return(0) end

-- SWS version 2.8.3 has a bug in the crucial function "BR_GetMouseCursorContext_MIDI()"
-- https://github.com/Jeff0S/sws/issues/783
-- For compatibility with 2.8.3 as well as other versions, the following lines test the SWS version for compatibility
_, testParam1, _, _, _, testParam2 = reaper.BR_GetMouseCursorContext_MIDI()
if type(testParam1) == "number" and testParam2 == nil then SWS283 = true else SWS283 = false end
if type(testParam1) == "boolean" and type(testParam2) == "number" then SWS283again = false else SWS283again = true end 
if SWS283 ~= SWS283again then
    reaper.ShowConsoleMsg("Error: Could not determine compatible SWS version")
    return(0)
end

if SWS283 == true then
    _, _, mouseLane, _, _ = reaper.BR_GetMouseCursorContext_MIDI()
else 
    _, _, _, mouseLane, _, _ = reaper.BR_GetMouseCursorContext_MIDI()
end

-- If mouse is not in lane that can be ramped, no need to ask user inputs,
--     so quit right here
if not ((0 <= mouseLane and mouseLane <= 127) 
     or (256 <= mouseLane and mouseLane <= 287)
     or mouseLane == 0x203 or mouseLane == 0x201)
     then return(0) end
      
density = reaper.SNM_GetIntConfigVar("midiCCdensity", 64) -- Get the default grid resolution as set in Preferences -> MIDI editor -> "Events per quarter note when drawing in CC"
shape = 1
skip = true
newSel = true

-------------------------------------------------------------
-- Get user inputs
-- If user inputs are not needed each time the script is run,
--     simply comment out this section.

descriptionsCSVstring = "Events per QN (integer):,Shape (>0, 1=linear):,Skip redundant CCs? (y/n),New CCs selected? (y/n)"
if skip then skipStr = "y" else skipStr = "n" end
if newSel then newSelStr = "y" else newSelStr = "n" end
defaultsCSVstring = tostring(density) .. "," .. tostring(shape) .. "," .. skipStr .. "," .. newSelStr

-- Repeat getUserInputs until we get usable inputs
gotUserInputs = false
while gotUserInputs == false do
    retval, userInputsCSV = reaper.GetUserInputs("Draw shaped ramps between selected CCs", 4, descriptionsCSVstring, defaultsCSVstring)
    if retval == false then
        return(0)
    else
        density, shape, skip, newSel = userInputsCSV:match("([^,]+),([^,]+),([^,]+),([^,]+)")
        
        gotUserInputs = true -- temporary, will be changed to fasle if anything is wrong
        
        density = tonumber(density) 
        if density == nil then gotUserInputs = false
        elseif density ~= math.floor(density) then gotUserInputs = false 
        end
        
        shape = tonumber(shape)
        if shape == nil then gotUserInputs = false 
        elseif shape <= 0 then gotUserInputs = false 
        end
        
        if skip == "y" or skip == "Y" then skip = true
        elseif skip == "n" or skip == "N" then skip = false
        else gotUserInputs = false
        end
        
        if newSel == "y" or newSel == "Y" then newSel = true
        elseif newSel == "n" or newSel == "N" then newSel = false
        else gotUserInputs = false
        end 
        
    end -- if retval == 
    
end -- while gotUserInputs == false

-- End of user inputs section
-----------------------------

-- Calculate this take's PP and PPQ per grid density
startQN = reaper.MIDI_GetProjQNFromPPQPos(take, 0)
PPQ = reaper.MIDI_GetPPQPosFromProjQN(take, startQN+1)
PPgrid = PPQ/density -- PPQ per event
QNgrid = 1/density -- Quarter notes per event
       
-- Since 7bit CC, 14bit CC, channel pressure, velocity and pitch all 
--     require somewhat different tweaks, the code is simpler to read 
--     if divided into separate functions.    
if 0 <= mouseLane and mouseLane <= 127 then -- CC, 7 bit (single lane)
    drawRamp7bitCC()
    reaper.MIDI_Sort(take)
    reaper.Undo_OnStateChange("Draw shaped ramps between selected events: 7-bit CC lane "
                              .. tostring(mouseLane))
elseif mouseLane == 0x203 then -- Channel pressure
    drawRampChanPressure()
    reaper.MIDI_Sort(take)
    reaper.Undo_OnStateChange("Draw shaped ramps between selected events: Channel pressure")
elseif 256 <= mouseLane and mouseLane <= 287 then -- CC, 14 bit (double lane)
    drawRamp14bitCC()
    reaper.MIDI_Sort(take)
    reaper.Undo_OnStateChange("Draw shaped ramps between selected events: 14-bit CC lanes "
                              .. tostring(mouseLane-256) .. "/" .. tostring(mouseLane-224))
elseif mouseLane == 0x201 then
    drawRampPitch()
    reaper.MIDI_Sort(take)
    reaper.Undo_OnStateChange("Draw shaped ramps between selected events: Pitchwheel")
end