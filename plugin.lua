--Stars and Bunnies [Hard] is good for testing, no LNs
LAYER_INCREMENT = 1000000 --each layer represents 1 universe of 1000000 ms
SV_INCREMENT = .125 --the distance between SVs will be .125 ms

tpearly = false --false: teleport starts at time, true: teleport ends at time
hidelayers = false --setting for hiding notes of non-current universes

--debug = "hi"

function draw()
    imgui.Begin("Parallel Universe")
    resetQueue()

    --imgui.Text(debug)

    state.IsWindowHovered = imgui.IsWindowHovered()

    if #state.SelectedHitObjects > 0 then
        local sv = map.GetScrollVelocityAt(state.SelectedHitObjects[1].StartTime)
        imgui.Text("SV: " .. (sv and sv.Multiplier or 1))
        imgui.Text("Layer: " .. state.SelectedHitObjects[1].EditorLayer)
        imgui.Text("Universe: " .. getUniverse(state.SelectedHitObjects[1].StartTime)) --"universe" of the note
    end

    if imgui.Button("Update Layer") then
        hideLayer(state.CurrentLayer)
    end
    tooltip("Places/Updates SVs to move notes to their correct positions")

    if imgui.Button("Update All") then
        hideAll()
    end
    tooltip("Places/Updates SVs to move notes to their correct positions")

    if imgui.Button("Restore Layer") then
        unhideLayer(state.CurrentLayer)
    end
    tooltip("Removes/Updates SVs to restore notes to their original positions")

    if imgui.Button("Restore All") then
        unhideAll()
    end
    tooltip("Removes/Updates SVs to restore notes to their original positions")

    if imgui.Button("Teleport Backward") then
        local time = state.SelectedHitObjects[1].StartTime
        if tpearly then time = time - SV_INCREMENT end
        teleport(time, -1)
    end
    tooltip("Teleports backward one universe at time of selected note")

    if imgui.Button("Teleport Forward") then
        local time = state.SelectedHitObjects[1].StartTime
        if tpearly then time = time - SV_INCREMENT end
        teleport(time, 1)
    end
    tooltip("Teleports forward one universe at time of selected note")

    if imgui.Button("Clean SVs") then
        cleanSV()
    end
    tooltip("Removes redundant SVs")

    --[[if imgui.Button("Increase SV") then
        increaseSV(state.SongTime, 0.5)
    end]]--

    _, tpearly = imgui.Checkbox("Place Teleport Earlier", tpearly)
    tooltip("Unchecked: Teleport starts at selected note\nChecked: Teleport ends at selected note")

    _, hidelayers = imgui.Checkbox("Adjust Layer Visibility", hidelayers)
    if imgui.IsItemDeactivated() then showAllLayers() end
    tooltip("Only notes that can be seen by the player are visible in editor\nMay cause lag")

    if hidelayers then adjustLayerVisibility() end

    if utils.IsKeyPressed(87) then
        local notes = state.SelectedHitObjects
        actions.MoveHitObjectsToLayer(state.CurrentLayer, notes)
    end
    if utils.IsKeyPressed(69) then
        local notes = state.SelectedHitObjects
        teleport(state.SelectedHitObjects[1].StartTime, -1)
    end
    if utils.IsKeyPressed(82) then
        local notes = state.SelectedHitObjects
        teleport(state.SelectedHitObjects[1].StartTime, 1)
    end

    performQueue()
    imgui.End()
end

function tooltip(text)
    if imgui.IsItemHovered() then
        imgui.BeginTooltip()
        imgui.Text(text)
        imgui.EndTooltip()
    end
end

function queue(type, arg1, arg2, arg3, arg4)
    arg1 = arg1 or nil
    arg2 = arg2 or nil
    arg3 = arg3 or nil
    arg4 = arg4 or nil

    local action = utils.CreateEditorAction(type, arg1, arg2, arg3, arg4)
    table.insert(action_queue, action)
end

function resetQueue()
    action_queue = {}
    add_sv_queue = {}
end

function performQueue()
    if #add_sv_queue > 0 then queue(action_type.AddScrollVelocityBatch, add_sv_queue) end
    if #action_queue > 0 then actions.PerformBatch(action_queue) end
end

function setLayerHidden(layer, hidden)
    if layer.Hidden != hidden then actions.ToggleLayerVisibility(layer) end
end

function showAllLayers()
    for _, layer in pairs(map.EditorLayers) do
        setLayerHidden(layer, false)
    end
    setLayerHidden(map.DefaultLayer, false)
end

function adjustLayerVisibility()
    local universe = math.floor(getUniverse(state.SongTime))

    for i, layer in pairs(map.EditorLayers) do
        setLayerHidden(layer, i != universe)
    end
    setLayerHidden(map.DefaultLayer, universe != 0)
end

function hideLayer(layer)
    local notes = getNotesInLayer(layer)
    local index = getLayerIndex(layer)

    for _, note in pairs(notes) do
        local time = note.StartTime
        --prevents adjusting the SVs of already hidden notes
        local universe = math.floor(getUniverse(time))
        local distance = (index - universe) * LAYER_INCREMENT * 100
        local multiplier = distance / 100 / SV_INCREMENT

        if distance != 0 then
            --actions aren't performed until end of frame,
            --so all three multipliers are based off of original SV
            increaseSV(time - SV_INCREMENT, multiplier)
            increaseSV(time, -1 * multiplier)
            increaseSV(time + SV_INCREMENT, 0)
        end
    end
end

function hideAll()
    for _, layer in pairs(map.EditorLayers) do
        hideLayer(layer)
    end
    hideLayer(map.DefaultLayer)
end

function unhideLayer(layer)
    local notes = getNotesInLayer(layer)

    for _, note in pairs(notes) do
        local time = note.StartTime
        local noteuniverse = math.floor(getUniverse(time))
        local universe = math.floor(getUniverse(time - 1))
        --assuming all notes' original positions are in the first universe
        local distance = -1 * (noteuniverse - universe) * LAYER_INCREMENT * 100
        local multiplier = distance / 100 / SV_INCREMENT

        if distance != 0 then
            increaseSV(time - SV_INCREMENT, multiplier)
            increaseSV(time, -1 * multiplier)
            --increaseSV(time + SV_INCREMENT, 0)
        end
    end
end

function unhideAll()
    for _, layer in pairs(map.EditorLayers) do
        unhideLayer(layer)
    end
    unhideLayer(map.DefaultLayer)
end

function increaseSV(time, multiplier)
    --assuming initial sv multiplier is 1
    local sv
    if map.ScrollVelocities[1] and time < map.ScrollVelocities[1].StartTime then sv = utils.CreateScrollVelocity(-1e309, 1)
    else sv = map.GetScrollVelocityAt(time) or utils.CreateScrollVelocity(-1e309, 1) end

    if sv.StartTime == time then
        queue(action_type.ChangeScrollVelocityMultiplierBatch, {sv}, sv.Multiplier + multiplier)
    else
        local newsv = utils.CreateScrollVelocity(time, sv.Multiplier + multiplier)
        table.insert(add_sv_queue, newsv)
    end
end

function cleanSV()
    local svs = map.ScrollVelocities
    local redundants = {}
    local prevmult = 1

    for _, sv in pairs(svs) do
        if sv.Multiplier == prevmult then
            table.insert(redundants, sv)
        end
        prevmult = sv.Multiplier
    end

    queue(action_type.RemoveScrollVelocityBatch, redundants)
end

function teleport(time, diff)
    increaseSV(time, diff * LAYER_INCREMENT / SV_INCREMENT)
    increaseSV(time + SV_INCREMENT, 0)
end

function getPositionFromTime(time)
    --[[
        if using this function multiple times in one frame,
        it may be faster to set ScrollVelocities = map.ScrollVelocities in draw()
        and then set local svs = ScrollVelocities inside this function
    ]]
    local svs = map.ScrollVelocities

    if #svs == 0 or time < svs[1].StartTime then
        return math.floor(time * 100)
    end

    local position = math.floor(svs[1].StartTime * 100)

    local i = 2

    while i <= #svs do
        if time < svs[i].StartTime then
            break
        else
            position = position + math.floor((svs[i].StartTime - svs[i - 1].StartTime) * svs[i - 1].Multiplier * 100)
        end

        i = i + 1
    end

    i = i - 1

    position = position + math.floor((time - svs[i].StartTime) * svs[i].Multiplier * 100)
    return position
end

function getUniverse(time)
    return getPositionFromTime(time) / (LAYER_INCREMENT * 100)
end

function getLayerIndex(layer)
    if layer == map.DefaultLayer then return 0 end

    for i, l in pairs(map.EditorLayers) do
        if l == layer then return i end
    end
end

function getNotesInLayer(layer)
    local notes = map.HitObjects
    local layernotes = {}
    local layerindex = getLayerIndex(layer)

    local lasttime = false
    for _, note in pairs(notes) do
        if note.EditorLayer == layerindex and note.StartTime != lasttime then
            table.insert(layernotes, note)
            lasttime = note.StartTime
        end
    end

    return layernotes
end