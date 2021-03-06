--[[
ReaScript name: js_MIDI Inspector.lua
Version: 0.95
Author: juliansader
Screenshot: http://stash.reaper.fm/28295/js_MIDI%20Inspector.jpeg
Website: http://forum.cockos.com/showthread.php?t=176878
About:
  # Description
  This script opens a GUI that shows important information about the active MIDI take, 
  selected notes, and selected CCs.
  
  The script improves on REAPER's native Properties windows in several ways:
  
  * The GUI is continuously updated and does not interfere with MIDI editing.  
  
  * If multiple events are selected, value ranges are shown.
  
  * Note, CC and take information are all shown simultaneously.
  
  * Note and CC positions can be displayed in any of REAPER's time formats.  
  
  * In Measure:Beat:Ticks format, script can display fractional tick values.
  
  * The GUI can be docked.
  
  In addition, the script clearly shows the take's default insert channel, and allows 
  the user to change the channel.  (From REAPER v2.54 onward, this crucial setting will
  also be available by default in the MIDI editor itself.)
  
  # Instructions
  Click on any of the highlighted values to open a Properties window or a dropdown menu 
  in which the values can be changed.
  
  The default colors of the GUI, as well as the default size, can be customized in the script's USER AREA.

  # WARNING!
  Prior to REAPER v5.24, the actions for changing the default channel for new events 
  ("Set channel for new events to 1 [...16]") are buggy and may inappropriately activate 
  the MIDI editor's event filter (as set in the Filter window).  Changing the default 
  channel via this script (or by running the actions directly) may therefore make 
  some notes of CCs invisible.
  
  # Website
  http://forum.cockos.com/showthread.php?t=176878
]]
 
--[[
  Changelog:
  * v0.90 (2016-08-20)
    + Initial beta release
  * v0.91 (2016-08-20)
    + Improved header info
  * v0.92 (2016-08-20)
    + When default channel is changed, GUI will immediately update
    + WARNING: In REAPER v5.2x, the actions for changing the default channel for new events 
      ("Set channel for new events to 1 [...16]") are buggy and may inappropriately activate 
      the MIDI editor's event filter (as set in the Filter window).  Changing the default 
      channel via this script (or by running the actions directly) may therefore make 
      some notes of CCs invisible.
  * v0.93 (2016-08-25)
    + In REAPER itself, the aforementioned bug (setting channel for new events activates 
      event filter) has been fixed in v2.54.
    + In the MIDI Inspector, the GUI will immediately update if the channel for new events
      is changed via the action list or via the MIDI editor's own new channel features.  
  * v0.94 (2016-09-10)
    + If user clicks in CC area, the script will ask whether all notes, text and sysex events 
      should deselected before opening REAPER's Event Properties, to avoid opening the
      Note Properties or Text/Sysex windows instead.
    + New position formats: Ticks, and Measure:Beat:Ticks 
      (the latter is similar to how the MIDI editor's Event Properties displays position).
  * v0.95 (2016-09-13)
    + In Measure:Beat:Ticks format, script will display fractional tick values if the MIDI item's
      ticks are not precisely aligned with the project beats.  (As discussed in t=181211.)
]]

-- USER AREA
-- Settings that the user can customize

defaultTimeFormat = 6 -- Refer to tableTimeFormats below for description of the formats

fontFace = "Ariel"
fontSize = 14
textColor = {1,1,1,0.7}
highlightColor = {1,1,0,1}
backgroundColor = {0.18, 0.18, 0.18, 1}
shadowColor = {0,0,0,1}

-- If the initialization dimensions are not specified, the script
--    will calculate appropriate values based on font size
initWidth = 209
initHeight = 408

-- End of USER AREA

-----------------------------------------------------------------
-----------------------------------------------------------------

tableTimeFormats = {[-1] = "Project default",
                    [0] = "Time",
                    [1] = "Measures.Beats.Time",
                    [2] = "Measures.Beats",
                    [3] = "Seconds",
                    [4] = "Samples",
                    [5] = "h:m:s:frames",
                    [6] = "Measures:Beats:Ticks", -- This is how the MIDI editor's Properties window displays position (exept with . instead of :)
                    [7] = "Ticks"}
    
tableCCTypes = {[8] = "Note on",
                [9] = "Note off",
                [11] = "CC",
                [12] = "Program select",
                [13] = "Channel pressure",
                [14] = "Pitch wheel"}

tableCCLanes = {[0] = "Bank Select MSB",
                [1] = "Mod Wheel MSB",
                [2] = "Breath MSB",
                [4] = "Foot Pedal MSB",
                [5] = "Portamento MSB",
                [6] = "Data Entry MSB",
                [7] = "Volume MSB",
                [8] = "Balance MSB",
                [10] = "Pan MSB",
                [11] = "Expression MSB",
                [12] = "Control 1 MSB",
                [13] = "Control 2 MSB",
                [32] = "Bank Select LSB",
                [33] = "Mod Wheel LSB",
                [34] = "Breath LSB",
                [36] = "Foot Pedal LSB",
                [37] = "Portamento LSB",
                [38] = "Data Entry LSB",
                [39] = "Volume LSB",
                [40] = "Balance LSB",
                [42] = "Pan LSB",
                [43] = "Expression LSB",
                [64] = "Sustain Pedal (on/off)",
                [65] = "Portamento (on/off)",
                [66] = "Sostenuto (on/off)",
                [67] = "Soft Pedal (on/off)",
                [68] = "Legato Pedal (on/off)",
                [69] = "Hold Pedal 2 (on/off)",
                [70] = "Sound Variation",
                [71] = "Timbre Content",
                [72] = "Release Time",
                [73] = "Attack Time",
                [74] = "Brightness",
                [84] = "Portamento Control",
                [91] = "External FX Depth",
                [92] = "Tremolo Depth",
                [93] = "Chorus Depth",
                [94] = "Detune Depth",
                [95] = "Phaser Depth",
                [96] = "Data Increment",
                [97] = "Data Decrement"}
                
---------------
function exit()
    gfx.quit()
    _, _, sectionID, ownCommandID, _, _, _ = reaper.get_action_context()
    if not (sectionID == nil or ownCommandID == nil or sectionID == -1 or ownCommandID == -1) then
        reaper.SetToggleCommandState(sectionID, ownCommandID, 0)
        reaper.RefreshToolbar2(sectionID, ownCommandID)
    end
end -- function exit

-----------------------------
function setColor(colorTable)
    gfx.r = colorTable[1]
    gfx.g = colorTable[2]
    gfx.b = colorTable[3]
    gfx.a = colorTable[4]
end -- function setColor

-------------------------
function drawWhiteBlock()
    local r = gfx.r; g = gfx.g; b = gfx.b; a = gfx.a
    setColor(blockColor) --{1,1,1,1})
    --gfx.x = gfx.x - 2
    --gfx.y = gfx.y - 2
    gfx.rect(gfx.x-2, gfx.y-2, blockWidth, strHeight+4, true)
    setColor({r,g,b,a})
end -- function drawWhiteBlock

---------------------------
function pitchString(pitch)
    local pitchNames = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
    return tostring(pitchNames[(pitch%12)+1])..tostring(pitch//12 - 1)
end -- function pitchString

-------------------
function timeStr(take, ppq, format)
    -- format_timestr_pos returns strings that are not in the same format as 
    --    how the MIDI editor's Properties window displays position.
    -- Therefore extra format options were added.
    if format <= 5 then
        return reaper.format_timestr_pos(reaper.MIDI_GetProjTimeFromPPQPos(take, ppq), "", format)
    elseif format == 6 then -- Custom format measure:beat:ticks
        local measureBeatTime = reaper.format_timestr_pos(reaper.MIDI_GetProjTimeFromPPQPos(take, ppq), "", 1)
        local measureStr, beatStr = measureBeatTime:match("(%d+)%.(%d+)%.%d+")
        -- When displayed, measure and beat is counted from 1 instead of 0, so subtract 1
        local measure = tonumber(measureStr)-1
        local beat = tonumber(beatStr)-1
        local beatTime = reaper.TimeMap2_beatsToTime(0, beat, measure)
        local beatPPQ  = reaper.MIDI_GetPPQPosFromProjTime(take, beatTime)
        -- In measure.beat.time format, the position may be rounded *up* to nearest beat.
        -- In measure:beat:ticks, must never round up.  So must check:
        if beatPPQ > ppq then
            beat = beat - 1
            beatTime = reaper.TimeMap2_beatsToTime(0, beat, measure)
            measureBeatTime = reaper.format_timestr_pos(beatTime, "", 1)
            measureStr, beatStr = measureBeatTime:match("(%d+)%.(%d+)%.%d+")
            measure = tonumber(measureStr)-1
            beat = tonumber(beatStr)-1
            beatPPQ  = reaper.MIDI_GetPPQPosFromProjTime(take, beatTime)
        end
        -- If the start of the MIDI item is not precisely aligned with the grid, or if
        --    the items is stretched, the event may be a fractional tick away from the 
        --    measure:beat position.
        -- Note that beatPPQ may be fractional, whereas a MIDI event's ppq is always an integer.
        local ticksStr
        if (ppq - beatPPQ)%1 == 0 then -- integer, so can format nicely without decimal point
            ticksStr = tostring(ppq - beatPPQ):gsub("%.%d+", "")
            ticksStr = string.format("%03d", ticksStr)
        else -- Not integer, so display exact displacement
            ticksStr = tostring(ppq - beatPPQ)
            ticksStr = string.format("%.3f", ticksStr)
        end
        return (measureStr .. ":" .. beatStr .. ":" .. ticksStr)
    else
        return (tostring(ppq):gsub("%.%d+", ""))
    end
end


--------------------
function updateGUI()
    -- Updates the GUI - assuming that all the strings have already been given 
    --    their correct values by loopMIDIInspector
    
    local tabLong = tabLong
    local tabShort = tabShort
    
    lineHeight = math.max(strHeight, gfx.h / 25)
    setColor(backgroundColor)
    gfx.rect(1, 1, gfx.w-2, gfx.h-2, true)
    gfx.r=gfx.r*2; gfx.g=gfx.g*2; gfx.b=gfx.b*2; gfx.a = 1
    gfx.line(0, 0, gfx.w-1, 0)
    gfx.line(0, 1, 0, gfx.h-1)
    setColor(shadowColor)
    gfx.line(gfx.w-1, gfx.h-1, 0, gfx.h-1)
    gfx.line(gfx.w-1, gfx.h-1, gfx.w-1, 0)
    
    local midX = gfx.w/2
    
    ---------------------------------------------------------------
    -- Draw take stuff
    setColor(backgroundColor)
    gfx.r=gfx.r*2; gfx.g=gfx.g*2; gfx.b=gfx.b*2; gfx.a = 1
    gfx.rect(6, 1+lineHeight*0.85, gfx.w-11, lineHeight*5, false)
    setColor(shadowColor)
    gfx.rect(5, lineHeight*0.85, gfx.w-11, lineHeight*5, false)
        
    setColor(backgroundColor)
    --gfx.rect(9, lineHeight * 0.5, strWidth["Active take"], strHeight, true)
    gfx.rect(9, lineHeight * 0.5, strWidth["ACTIVE TAKE"], strHeight, true)
    setColor(textColor)
    --gfx.r=gfx.r*1.5; gfx.g=gfx.g*1.5; gfx.b=gfx.b*1.5; gfx.a = gfx.a*1.5
    gfx.x = 13
    gfx.y = lineHeight * 0.5
    --gfx.drawstr("Active take")
    gfx.drawstr("ACTIVE TAKE")
    
    --setColor(textColor)
    gfx.x = tabLong - strWidth["Total notes"]
    gfx.y = lineHeight * 1.5
    gfx.drawstr("Total notes: ")
    gfx.x = tabLong
    gfx.drawstr(numNotes)
    gfx.x = tabLong - strWidth["Total CCs"]
    gfx.y = lineHeight * 2.5
    gfx.drawstr("Total CCs: ")
    gfx.x = tabLong
    gfx.drawstr(numCCs)
    gfx.x = tabLong - strWidth["Default channel"]
    gfx.y = lineHeight * 3.5
    gfx.drawstr("Default channel: ")
    gfx.x = tabLong
    setColor(highlightColor)
    gfx.drawstr(defaultChannel)
    gfx.x = tabLong - strWidth["Default velocity"]
    gfx.y = lineHeight * 4.5
    setColor(textColor)
    gfx.drawstr("Default velocity: ")
    gfx.x = tabLong
    gfx.drawstr(defaultVelocity)
    
    --------------------------------------------------------------
    -- Draw note stuff
    setColor(backgroundColor)
    gfx.r=gfx.r*2; gfx.g=gfx.g*2; gfx.b=gfx.b*2; gfx.a = 1
    gfx.rect(6, 1+lineHeight*6.85, gfx.w-11, lineHeight*7, false)
    setColor(shadowColor)
    gfx.rect(5, lineHeight*6.85, gfx.w-11, lineHeight*7, false)
    
    setColor(backgroundColor)
    --gfx.rect(9, lineHeight * 6.5, strWidth["Selected notes"], strHeight, true)
    gfx.rect(9, lineHeight * 6.5, strWidth["SELECTED NOTES"], strHeight, true)
    setColor(textColor)
    gfx.x = 13
    gfx.y = lineHeight * 6.5
    --gfx.drawstr("Selected notes")
    gfx.drawstr("SELECTED NOTES")
    
    gfx.x = tabShort - strWidth["Count"]
    gfx.y = gfx.y + lineHeight
    setColor(textColor)
    gfx.drawstr("Count: ")
    gfx.x = tabShort
    gfx.drawstr(countSelNotes)        
    
    gfx.x = tabShort - strWidth["Pitch"]
    gfx.y = gfx.y + lineHeight
    setColor(textColor)
    gfx.drawstr("Pitch: ")
    gfx.x = tabShort
    setColor(highlightColor)
    gfx.drawstr(notePitchString)
    
    gfx.x = tabShort - strWidth["Channel"]
    gfx.y = gfx.y + lineHeight
    setColor(textColor)
    gfx.drawstr("Channel: ")
    gfx.x = tabShort
    setColor(highlightColor)
    gfx.drawstr(noteChannelString)
    
    gfx.x = tabShort - strWidth["Velocity"]
    gfx.y = gfx.y + lineHeight
    setColor(textColor)
    gfx.drawstr("Velocity: ")
    gfx.x = tabShort
    setColor(highlightColor)
    gfx.drawstr(noteVelocityString)
    
    gfx.x = tabShort - strWidth["Length"]
    gfx.y = gfx.y + lineHeight
    setColor(textColor)
    gfx.drawstr("Length: ")
    gfx.x = tabShort
    setColor(highlightColor)
    gfx.drawstr(noteLengthString)
    
    gfx.x = tabShort - strWidth["Start pos"]
    gfx.y = gfx.y + lineHeight
    setColor(textColor)
    gfx.drawstr("Start pos: ")
    gfx.x = tabShort
    setColor(highlightColor)
    gfx.drawstr(notePositionString)
    
    ---------------------------------------------------------------
    -- Draw CC stuff
    setColor(backgroundColor)
    gfx.r=gfx.r*2; gfx.g=gfx.g*2; gfx.b=gfx.b*2; gfx.a = 1
    gfx.rect(6, 1+lineHeight*14.85, gfx.w-11, lineHeight*7, false)
    setColor(shadowColor)
    gfx.rect(5, lineHeight*14.85, gfx.w-11, lineHeight*7, false)
    
    setColor(backgroundColor)
    --gfx.rect(9, lineHeight * 13.5, strWidth["Selected CCs"], strHeight, true)
    gfx.rect(9, lineHeight * 14.5, strWidth["SELECTED CCs"], strHeight, true)
    setColor(textColor)
    gfx.x = 13
    gfx.y = lineHeight * 14.5
    --gfx.drawstr("Selected CCs")
    gfx.drawstr("SELECTED CCs")
    
    gfx.x = tabShort - strWidth["Count"]
    gfx.y = gfx.y + lineHeight
    gfx.drawstr("Count: ")
    gfx.x = tabShort
    gfx.drawstr(countSelCCs)
    
    gfx.x = tabShort - strWidth["Type"]
    gfx.y = gfx.y + lineHeight
    setColor(textColor)
    gfx.drawstr("Type: ")
    gfx.x = tabShort
    setColor(highlightColor)
    gfx.drawstr(ccTypeString)    
    
    gfx.x = tabShort - strWidth["CC lane"]
    gfx.y = gfx.y + lineHeight
    setColor(textColor)
    gfx.drawstr("CC lane: ")
    gfx.x = tabShort
    setColor(highlightColor)
    gfx.drawstr(ccLaneString) 
    
    gfx.x = tabShort - strWidth["Channel"]
    gfx.y = gfx.y + lineHeight
    setColor(textColor)
    gfx.drawstr("Channel: ")
    gfx.x = tabShort
    setColor(highlightColor)
    gfx.drawstr(ccChannelString) 
    
    gfx.x = tabShort - strWidth["Value"]
    gfx.y = gfx.y + lineHeight
    setColor(textColor)
    gfx.drawstr("Value: ")
    gfx.x = tabShort
    setColor(highlightColor)
    gfx.drawstr(ccValueString)   
    
    gfx.x = tabShort - strWidth["Position"]
    gfx.y = gfx.y + lineHeight
    setColor(textColor)
    gfx.drawstr("Position: ")
    gfx.x = tabShort
    setColor(highlightColor)
    gfx.drawstr(ccPositionString)
    
    -- Draw position/time format
    gfx.x = 11 --tabShort - strWidth["Format"]
    gfx.y = lineHeight*22.3
    setColor(textColor)
    gfx.drawstr("Time format: ")
    --gfx.x = tabShort
    setColor(highlightColor)
    gfx.drawstr(tableTimeFormats[timeFormat])
    
    
    -- Draw Pause radio button
    setColor(backgroundColor)
    gfx.r=gfx.r*2; gfx.g=gfx.g*2; gfx.b=gfx.b*2; gfx.a = 1
    gfx.rect(11, 2+lineHeight*23.5, strHeight-2, strHeight-2, false)
    setColor(shadowColor)
    gfx.rect(10, 1+lineHeight*23.5, strHeight-2, strHeight-2, false)
    setColor(textColor) --{0.7,0.7,0.7,1})
    gfx.a = gfx.a*0.5
    gfx.rect(12, 3+lineHeight*23.5, strHeight-5, strHeight-5, true)
    setColor(textColor)
    gfx.x = 15 + strHeight
    gfx.y = lineHeight * 23.5
    gfx.drawstr("Pause")
    
    if paused == true then
        setColor(shadowColor)
        gfx.x = 13
        --gfx.y = lineHeight * 19.5
        gfx.drawstr("X")
        gfx.x = 13
        gfx.y = gfx.y + 1
        gfx.drawstr("X")
    end
    
    -- Draw Dock radio button
    setColor(backgroundColor)
    gfx.r=gfx.r*2; gfx.g=gfx.g*2; gfx.b=gfx.b*2; gfx.a = 1
    gfx.rect(midX+1, 2+lineHeight*23.5, strHeight-2, strHeight-2, false)
    setColor(shadowColor)
    gfx.rect(midX, 1+lineHeight*23.5, strHeight-2, strHeight-2, false)
    setColor(textColor) --{0.7,0.7,0.7,1})
    gfx.a = gfx.a*0.5
    gfx.rect(midX+2, 3+lineHeight*23.5, strHeight-5, strHeight-5, true)
    setColor(textColor)
    gfx.x = midX + 5 + strHeight
    gfx.y = lineHeight * 23.5
    gfx.drawstr("Dock")
    
    if gfx.dock(-1) ~= 0 then
        setColor(shadowColor)
        gfx.x = midX + 3
        --gfx.y = lineHeight * 19.5
        gfx.drawstr("X")
        gfx.x = midX + 3
        gfx.y = gfx.y + 1
        gfx.drawstr("X")
    end
        
    -- In order to do as little per cycle (so as not to waste REAPER's resources)
    --    this call to gfx.update has been commented out.  Only one call will be done 
    --    per cycle - right at the beginning of the loop.
    --gfx.update()
    
end -- function updateGUI

----------------------------
function loopMIDIInspector()

    -- Apparently gfx.update must be called in order to update gfx.w, gfx.mouse_x and other gfx variables
    gfx.update()
    
    -- Quit script if GUI has been closed
    local char = gfx.getchar()
    if char<0 then return(0) end         
    
    -- Or if there is no active MIDI editor
    editor = reaper.MIDIEditor_GetActive()
    if editor == nil then return(0) end
        
    -- If paused, GUI size will update and mouseclicks will be intercepted, but no MIDI updates
    if paused == false then    
           
        
        -- (GetTake is buggy and sometimes returns an invalid, deleted take, so must validate take.)
        local take = reaper.MIDIEditor_GetTake(editor)
        if reaper.ValidatePtr(take, "MediaItem_Take*") then
        
            -- Only do all the time-consuming GetNote and GetCC stuff if there were in fact changes in MIDI,
            --    or if active take has switched.
            -- Changes in MIDI can be monitored by getting the take's hash, but not changes in default 
            --    channel or velocity, so these settings are monitored separately.
            defaultVelocity = reaper.MIDIEditor_GetSetting_int(editor, "default_note_vel")
            -- Some of REAPER's MIDI function work with channel range 0-15, others with 1-16
            defaultChannel  = 1 + reaper.MIDIEditor_GetSetting_int(editor, "default_note_chan")  
        
            hashOK, takeHash = reaper.MIDI_GetHash(take, false, "")
            if take ~= prevTake or (hashOK and takeHash ~= prevHash) then
                prevTake = take
                prevHash = takeHash

                countOK, numNotes, numCCs, numSysex = reaper.MIDI_CountEvts(take)
                --[[if countOK ~= true then
                    numNotes = "?"
                    numCCs = "?"
                    numSysex = "?"
                end]]
                
                ------------------------------------------------------------
                -- Now get all the info of the selected NOTES in active take
                -- Note: For later versions: use MIDI_GetHash limited to notes to check whether this section can be skipped
                local noteLowPPQ = math.huge
                local noteHighPPQ = -1
                local noteLowChannel = 17
                local noteHighChannel = -1
                local noteLowPitch = 200
                local noteHighPitch = -1
                local noteLowVelocity = 200
                local noteHighVelocity = -1
                local noteHighLength = -1
                local noteLowLength = math.huge

                local noteIndex = reaper.MIDI_EnumSelNotes(take, -1)
                countSelNotes = 0
                while noteIndex > -1 do
                    local noteOK, _, _, startPPQ, endPPQ, channel, pitch, velocity = reaper.MIDI_GetNote(take, noteIndex)
                    if noteOK == true then
                        countSelNotes = countSelNotes + 1
                        local length = endPPQ - startPPQ
                        if length < noteLowLength then noteLowLength = length end
                        if length > noteHighLength then noteHighLength = length end
                        if startPPQ < noteLowPPQ then noteLowPPQ = startPPQ end
                        if startPPQ > noteHighPPQ then noteHighPPQ = startPPQ end
                        if channel < noteLowChannel then noteLowChannel = channel end
                        if channel > noteHighChannel then noteHighChannel = channel end
                        if pitch < noteLowPitch then noteLowPitch = pitch end
                        if pitch > noteHighPitch then noteHighPitch = pitch end
                        if velocity < noteLowVelocity then noteLowVelocity = velocity end
                        if velocity > noteHighVelocity then noteHighVelocity = velocity end
                    end
                    noteIndex = reaper.MIDI_EnumSelNotes(take, noteIndex)
                end -- while noteIndex > -1
                
                if noteLowPPQ > noteHighPPQ then notePositionString = ""
                else
                    if noteLowPPQ == noteHighPPQ then
                        notePositionString = timeStr(take, noteLowPPQ, timeFormat)
                    else 
                        notePositionString = timeStr(take, noteLowPPQ, timeFormat) 
                                             .. " - " 
                                             .. timeStr(take, noteHighPPQ, timeFormat)
                    end
                end
                
                if noteLowChannel > noteHighChannel then noteChannelString = ""
                elseif noteLowChannel == noteHighChannel then 
                    noteChannelString = tostring(noteLowChannel+1)
                else 
                    noteChannelString = tostring(noteLowChannel+1) 
                                     .. " - " 
                                     .. tostring(noteHighChannel+1)
                end
                
                if noteLowPitch > noteHighPitch then notePitchString = ""
                elseif noteLowPitch == noteHighPitch then 
                    notePitchString = pitchString(noteLowPitch)
                else 
                    notePitchString = pitchString(noteLowPitch) 
                                     .. " - " 
                                     .. pitchString(noteHighPitch)
                end
                            
                if noteLowVelocity > noteHighVelocity then noteVelocityString = ""
                elseif noteLowVelocity == noteHighVelocity then 
                    noteVelocityString = tostring(noteLowVelocity)
                else 
                    noteVelocityString = tostring(noteLowVelocity) 
                                     .. " - " 
                                     .. tostring(noteHighVelocity)
                end
                
                if noteLowLength > noteHighLength then noteLengthString = ""
                elseif noteLowLength == noteHighLength then 
                    noteLengthString = tostring(noteLowLength):match("[%d]+") .. " ticks"
                else 
                    noteLengthString = tostring(noteLowLength):match("[%d]+")
                                     .. " - " 
                                     .. tostring(noteHighLength):match("[%d]+")
                                     .. " ticks"
                end
                            
                --if type(ccPositionString) == "string" then updateGUI() end
                
                ----------------------------------------------------------
                -- Now get all the info of the selected CCs in active take
                local ccLowPPQ = math.huge
                local ccHighPPQ = -1
                local ccLowChannel = 17
                local ccHighChannel = -1
                local ccLowValue = math.huge
                local ccHighValue = -1
                local ccHighLane = -1
                local ccLowLane = math.huge
                local ccHighType = -1 -- Actually, other 'types' are not CCs at all
                local ccLowType = math.huge
                --local value, ccType
                
                local ccIndex = reaper.MIDI_EnumSelCC(take, -1)
                countSelCCs = 0
                while ccIndex > -1 do
                    ccOK, _, _, PPQpos, chanmsg, channel, msg2, msg3 = reaper.MIDI_GetCC(take, ccIndex)
                    
                    if ccOK == true then 
                        countSelCCs = countSelCCs + 1
                        
                        ccType = chanmsg>>4
                        if ccType < ccLowType then ccLowType = ccType end
                        if ccType > ccHighType then ccHighType = ccType end
                                                    
                        if ccType == 14 then value = (msg3<<7) + msg2 -- pitch
                        elseif ccType == 13 then value = msg2 -- channel pressure
                        else value = msg3
                        end
                        if value < ccLowValue then ccLowValue = value end
                        if value > ccHighValue then ccHighValue = value end

                        if ccType == 11 then -- CC
                            if msg2 < ccLowLane then ccLowLane = msg2 end
                            if msg2 > ccHighLane then ccHighLane = msg2 end
                        end
                                            
                        if PPQpos < ccLowPPQ then ccLowPPQ = PPQpos end
                        if PPQpos > ccHighPPQ then ccHighPPQ = PPQpos end
                        if channel < ccLowChannel then ccLowChannel = channel end
                        if channel > ccHighChannel then ccHighChannel = channel end
                    end
                    ccIndex = reaper.MIDI_EnumSelCC(take, ccIndex)
                end -- while ccIndex > -1
                
                if ccHighType == -1 then ccTypeString = "" -- no CCs selected
                elseif ccLowType ~= ccHighType then ccTypeString = "Multiple"
                else ccTypeString = tableCCTypes[ccLowType]
                end
                     
                -- CC lane will be calculated in ccType == 11, actual CC
                if ccLowType == ccHighType and ccLowType == 11 then
                    if ccLowLane > ccHighLane then ccLaneString = ""    
                    elseif ccLowLane == ccHighLane then 
                        ccLaneString = tostring(ccLowLane)
                        if tableCCLanes[ccLowLane] ~= nil then
                            ccLaneString = ccLaneString .. " (" .. tableCCLanes[ccLowLane] .. ")"
                        end
                    else 
                       ccLaneString = tostring(ccLowLane) .. " - " .. tostring(ccHighLane)
                    end
                else
                    ccLaneString = ""
                end
                            
                if ccLowValue > ccHighValue then ccValueString = ""
                elseif ccLowValue == ccHighValue then 
                    ccValueString = tostring(ccLowValue)
                else 
                    ccValueString = tostring(ccLowValue) .. " - " .. tostring(ccHighValue)
                end
                
                if ccLowPPQ > ccHighPPQ then ccPositionString = ""
                elseif ccLowPPQ == ccHighPPQ then 
                    ccPositionString = timeStr(take, ccLowPPQ, timeFormat)
                else 
                    ccPositionString = timeStr(take, ccLowPPQ, timeFormat)
                                     .. " - " 
                                     .. timeStr(take, ccHighPPQ, timeFormat)
                end
                
                if ccLowChannel > ccHighChannel then ccChannelString = ""
                elseif ccLowChannel == ccHighChannel then 
                    ccChannelString = tostring(ccLowChannel+1)
                else 
                    ccChannelString = tostring(ccLowChannel+1) .. " - " .. tostring(ccHighChannel+1)
                end
                                        
                if ccLowValue > ccHighValue then ccValueString = ""
                elseif ccLowValue == ccHighValue then 
                    ccValueString = tostring(ccLowValue)
                else 
                    ccValueString = tostring(ccLowValue) .. " - " .. tostring(ccHighValue)
                end
            end -- if takeHash ~= prevHash: get new note and CC info
        end -- if take ~= nil: get new default channel and velocity
    end -- if paused == false
    
    -------------------------------------
    -- Now check if any mouse interaction
    -- gfx.update()
                
    if gfx.mouse_cap == 0 then mouseAlreadyClicked = false end
    
    -- Select new default channel for new events
    if gfx.mouse_cap == 1 and mouseAlreadyClicked == false 
    and gfx.mouse_y > lineHeight*3.5 and gfx.mouse_y < lineHeight*4.5 
    then
        mouseAlreadyClicked = true
        
        if type(defaultChannel) == "number" 
        and defaultChannel%1 == 0 
        and defaultChannel <= 16
        and defaultChannel >= 1
        then
            gfx.x = tabLong
            gfx.y = lineHeight * 4.5
            local channelString = "#Channel|1|2|3|4|5|6|7|8|9|10|11|12|13|14|15|16"
            local checkPos = channelString:find(tostring(defaultChannel))
            channelString = channelString:sub(1,checkPos-1) .. "!" .. channelString:sub(checkPos, nil)
            local menuChoice = gfx.showmenu(channelString)
            if menuChoice > 0 then
                reaper.MIDIEditor_OnCommand(editor, 40482+menuChoice-2) -- Set channel for new events to 0+channel
                prevHash = nil -- This just to force GUI to update in next loop
            end
        end -- type(defaultChannel) == "number" 
    end -- if gfx.mouse_cap == 1
    
    
    -- Pause / Unpause
    if gfx.mouse_cap == 1 and mouseAlreadyClicked == false 
    and gfx.mouse_y > lineHeight*23.5 and gfx.mouse_y < lineHeight*24.5 
    and gfx.mouse_x > 0 and gfx.mouse_x < gfx.w/2
    then
        mouseAlreadyClicked = true
        paused = not paused
    end
    
    -- Dock / Undock
    if gfx.mouse_cap == 1 and mouseAlreadyClicked == false 
    and gfx.mouse_y > lineHeight*23.5 and gfx.mouse_y < lineHeight*24.5 
    and gfx.mouse_x > gfx.w/2 and gfx.mouse_x < gfx.w
    then
        mouseAlreadyClicked = true
        if gfx.dock(-1) ~= 0 then
            gfx.dock(0)
        else
            gfx.dock(1)
        end
    end
    
    -- Select time format
    if (gfx.mouse_cap == 2 or gfx.mouse_cap == 1)
    and mouseAlreadyClicked == false 
    and gfx.mouse_y > lineHeight*22.3 and gfx.mouse_y < lineHeight*23.3 
    --and gfx.mouse_x > gfx.w/2 and gfx.mouse_x < gfx.w
    then
        mouseAlreadyClicked = true
        gfx.x = 11+strWidth["Time format"] --tabShort
        gfx.y = lineHeight*23.3 
        local menuString = "#Display position as|"
        -- Time format ranges from -1 (default) to 5
        for i = -1, #tableTimeFormats do
            menuString = menuString .. "|"
            if i == timeFormat then menuString = menuString .. "!" end
            menuString = menuString .. tableTimeFormats[i]
        end
        local menuChoice = gfx.showmenu(menuString)
        if menuChoice > 1 then 
            timeFormat = menuChoice-3 
            prevHash = nil -- This just to force GUI to update in next loop    
        end
    end
    
    -- Click in notes area, open REAPER's Properties window (which defaults to Note Properties if notes as well as CCs are selected)
    if gfx.mouse_cap == 1 and mouseAlreadyClicked == false 
    and (  (gfx.mouse_y > lineHeight*8.5 and gfx.mouse_y < lineHeight*13.5)
        --or (gfx.mouse_y > lineHeight*16.5 and gfx.mouse_y < lineHeight*21.5)
        )
    then
        mouseAlreadyClicked = true
        reaper.MIDIEditor_OnCommand(editor, 40004)
    end
    
    -- Click in CC area, first ask user whether all notes should be deselected, then call Event Properties
    --    If notes are not deselected, REAPER will automatically open the Notes Properties window instead
    if gfx.mouse_cap == 1 and mouseAlreadyClicked == false 
    and (gfx.mouse_y > lineHeight*16.5 and gfx.mouse_y < lineHeight*21.5)
    then
        mouseAlreadyClicked = true
        
        -- Check whether there are any selected notes. If there are, get user input.
        local take = reaper.MIDIEditor_GetTake(editor)
        if reaper.ValidatePtr(take, "MediaItem_Take*") 
        and (reaper.MIDI_EnumSelNotes(take, -1) ~= -1 or reaper.MIDI_EnumSelTextSysexEvts(take, -1) ~= -1)
        then
            inputOK, userInput = reaper.GetUserInputs("CC properties", 1, "Deselect notes and text/sysex?", "y")
            if inputOK and (userInput == "y" or userInput == "Y") then
                reaper.MIDI_Sort(take)
                -- Quickly deselect all notes
                reaper.MIDIEditor_OnCommand(editor, 40501) -- Invert selection in active take
                reaper.MIDIEditor_OnCommand(editor, 40003) -- Select all notes in active take
                reaper.MIDIEditor_OnCommand(editor, 40501) -- Invert again
                
                -- No such quick trick for text/sysex events
                local evtIndex = reaper.MIDI_EnumSelTextSysexEvts(take, -1)
                while evtIndex ~= -1 do
                    reaper.MIDI_SetTextSysexEvt(take, evtIndex, false, nil, nil, nil, "", true)
                    evtIndex = reaper.MIDI_EnumSelTextSysexEvts(take, evtIndex)
                end
                
                --[[ And now find and deselect all bank/program select events
                local ccIndex = reaper.MIDI_EnumSelCC(take, -1)
                while ccIndex ~= -1 do
                    local ccOK, _, _, _, chanmsg, _, msg2, msg3 = reaper.MIDI_GetCC(take, ccIndex)
                    if ((chanmsg>>4) == 12)
                    --or ((chanmsg>>4) == 11 and (msg2 == 0 or msg2 == 32)) 
                    then
                        reaper.MIDI_SetCC(take, ccIndex, false, nil, nil, nil, nil, nil, nil, true)
                    end
                    ccIndex = reaper.MIDI_EnumSelCC(take, ccIndex)
                end
                ]]
                reaper.MIDI_Sort(take)
            end
        end
        
        reaper.MIDIEditor_OnCommand(editor, 40004) -- Call Event Properties
    end
    
    updateGUI()
    
    reaper.runloop(loopMIDIInspector)
end -- function loop GetSetChannel

--------------------------------------------------------------------
-- Here the code execution starts
--------------------------------------------------------------------
-- function main()

reaper.atexit(exit)

_, _, sectionID, ownCommandID, _, _, _ = reaper.get_action_context()
if not (sectionID == nil or ownCommandID == nil or sectionID == -1 or ownCommandID == -1) then
    reaper.SetToggleCommandState(sectionID, ownCommandID, 1)
    reaper.RefreshToolbar2(sectionID, ownCommandID)
end

gfx.init("MIDI Inspector", 200, 400)
gfx.setfont(1, fontFace, fontSize, 'b')
strWidth = {}
strWidth["ACTIVE TAKE"] = gfx.measurestr(" ACTIVE TAKE ")
strWidth["Active take"] = gfx.measurestr(" Active take ")
strWidth["Total notes"] = gfx.measurestr("Total notes:  ")
strWidth["Total CCs"] = gfx.measurestr("Total CCs:  ")
strWidth["Default channel"] = gfx.measurestr("Default channel:  ")
strWidth["Default velocity"] = gfx.measurestr("Default velocity:  ")

strWidth["SELECTED NOTES"] = gfx.measurestr(" SELECTED NOTES ")
strWidth["Selected notes"] = gfx.measurestr(" Selected notes ")
strWidth["Count"] = gfx.measurestr("Count:  ")
strWidth["Start pos"] = gfx.measurestr("Start pos:  ")
strWidth["Position"] = gfx.measurestr("Position:  ")
strWidth["Channel"] = gfx.measurestr("Channel:  ")
strWidth["Pitch"] = gfx.measurestr("Pitch:  ")
strWidth["Velocity"] = gfx.measurestr("Velocity:  ")

strWidth["SELECTED CCs"] = gfx.measurestr(" SELECTED CCs ")
strWidth["Selected CCs"] = gfx.measurestr(" Selected CCs ")
strWidth["CC type"] = gfx.measurestr("CC type:  ")
strWidth["Type"] = gfx.measurestr("Type:  ")
strWidth["Value"] = gfx.measurestr("Value:  ")
strWidth["CC lane"] = gfx.measurestr("CC lane:  ")

strWidth["Time format"] = gfx.measurestr("Time format:  ")
strWidth["Length"] = gfx.measurestr("Length:  ")
strWidth["Long time format"], strHeight = gfx.measurestr("0:00:00:00 - 0:00:00:00")
strWidthDock = gfx.measurestr("Dock")
--[[
strWidthCutoff = 2 * math.max(gfx.measurestr("Channel:  15-16 "), 
                          gfx.measurestr("Pitch:  G#8 - G#8 "),
                          gfx.measurestr("Count:  0000000 "),
                          gfx.measurestr("velocity:  127 - 128 "))
                          ]]

--blockWidth, _ = gfx.measurestr("00000 - 00000") + 4
tabLong  = 20 + math.max(strWidth["Default channel"], 
                         gfx.measurestr("Default velocity:  "))
tabShort = 20 + math.max(gfx.measurestr("Position:  "), 
                         gfx.measurestr("Channel:  "), 
                         gfx.measurestr("Velocity:  "), 
                         gfx.measurestr("Start pos:  "))
lineHeight = math.max(strHeight, gfx.h / 21)
gfx.quit()

paused = false
timeFormat = defaultTimeFormat

if type(initWidth) ~= "number" then initWidth = strWidth["Long time format"]+tabShort+15 end
if type(initHeight) ~= "number" then initHeight = (strHeight+3)*24 end
gfx.init("MIDI Inspector", initWidth, initHeight)
gfx.setfont(1, fontFace, fontSize, 'b')
gfx.update()

reaper.runloop(loopMIDIInspector)
