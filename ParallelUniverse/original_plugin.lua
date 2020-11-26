--things may or may not work in this

--Stars and Bunnies [Hard] is good for testing, no LNs
LAYER_INCREMENT = 1000000
SV_INCREMENT = .125

hidelayers = false

debug = "hi"

function draw()
    imgui.Begin("Parallel Universe")

    imgui.Text(debug)

    --[[if map.EditorLayers[#map.EditorLayers].Name != "ignore" then
        actions.CreateLayer(utils.CreateEditorLayer("ignore"))
    end]]

    state.IsWindowHovered = imgui.IsWindowHovered()

    if #state.SelectedHitObjects > 0 then
        local sv = map.GetScrollVelocityAt(state.SelectedHitObjects[1].StartTime)
        imgui.Text("SV: " .. (sv and sv.Multiplier or 1))
        imgui.Text("Layer: " .. state.SelectedHitObjects[1].EditorLayer)
        imgui.Text("Universe: " .. getPositionFromTime(state.SelectedHitObjects[1].StartTime) / (LAYER_INCREMENT * 100)) --"universe" of the note
    end

    if hidelayers then
        --TODO: optimize
        local universe = math.floor(getUniverse(state.SongTime))

        if universe != 0 then
            for i, layer in pairs(map.EditorLayers) do
                setLayerHidden(layer, i != universe and i != #map.EditorLayers)
            end
            setLayerHidden(map.DefaultLayer, true)
        else
            for i, layer in pairs(map.EditorLayers) do
                setLayerHidden(layer, true and i != #map.EditorLayers)
            end
            setLayerHidden(map.DefaultLayer, false)
        end
    end

    if imgui.Button("Hide Layer") then
        hideLayer(state.CurrentLayer)
    end

    if imgui.Button("Unhide Layer") then
        unhideLayer(state.CurrentLayer)
    end

    if imgui.Button("Teleport Backward") then
        teleport(state.SelectedHitObjects[1].StartTime, -1)
    end

    if imgui.Button("Teleport Forward") then
        teleport(state.SelectedHitObjects[1].StartTime, 1)
    end

    if imgui.Button("Increase SV by .5") then
        increaseSV(math.floor(state.SongTime), .5)
    end

    _, hidelayers = imgui.Checkbox("Hide Layers", hidelayers)

    imgui.End()
end

function increaseSV(time, multiplier)
    local sv = map.GetScrollVelocityAt(time)
    local newsv = utils.CreateScrollVelocity(time, sv.Multiplier + multiplier)
    local svs = map.ScrollVelocities

    if sv.StartTime == time then
        actions.RemoveScrollVelocity(sv)
        actions.PlaceScrollVelocity(newsv)

        for i = 1, #svs do
            if svs[i].StartTime == newsv.StartTime then
                local nextsv = svs[i + 1]
                local prevsv = svs[i - 1]
                if nextsv and nextsv.Multiplier == newsv.Multiplier then
                    actions.RemoveScrollVelocity(nextsv)
                end
                if prevsv and prevsv.Multiplier == newsv.Multiplier then
                    actions.RemoveScrollVelocity(newsv)
                end
                break
            end
        end
    else
        actions.PlaceScrollVelocity(newsv)

        for _, nextsv in pairs(svs) do
            if nextsv.StartTime > time then
                if nextsv.Multiplier == newsv.Multiplier then
                    actions.RemoveScrollVelocity(nextsv)
                end
                break
            end
        end
    end
end

function getUniverse(time)
    return getPositionFromTime(time) / (LAYER_INCREMENT * 100)
end

function setLayerHidden(layer, hidden)
    if layer.Hidden != hidden then actions.ToggleLayerVisibility(layer) end
end

function teleport(time, diff) --TODO: implement teleporting without having to show note
    local multiplier = diff * LAYER_INCREMENT / SV_INCREMENT
    local svs = {}
    local sv = function (time, multiplier) table.insert(svs, utils.CreateScrollVelocity(time, multiplier)) end

    local origsv = map.GetScrollVelocityAt(time)
    local rate = origsv and origsv.Multiplier or 1

    sv(time, rate + multiplier)
    sv(time + SV_INCREMENT, rate)

    actions.PlaceScrollVelocityBatch(svs)

    local notes = {}
    for _, note in pairs(map.HitObjects) do
        if note.StartTime == time then
            table.insert(notes, note)
        end
    end

    actions.MoveHitObjectsToLayer(map.EditorLayers[#map.EditorLayers], notes)
end

function hideLayer(layer)
    local notes = getNotesInLayer(layer)
    local svs = {}
    local sv = function (time, multiplier) table.insert(svs, utils.CreateScrollVelocity(time, multiplier)) end
    local layerindex = getLayerIndex(layer)

    unhideLayer(layer)

    for _, note in pairs(notes) do
        local universe = math.floor(getPositionFromTime(note.StartTime) / (LAYER_INCREMENT * 100))
        local distance = (layerindex - universe) * LAYER_INCREMENT * 100
        local multiplier = distance / 100 / SV_INCREMENT

        local origsv = map.GetScrollVelocityAt(note.StartTime)
        local rate = origsv and origsv.Multiplier or 1

        if distance != 0 then
            --[[actions.PlaceScrollVelocity(utils.CreateScrollVelocity(note.StartTime + SV_INCREMENT, rate))
            increaseSV(note.StartTime, -1 * multiplier)
            increaseSV(note.StartTime - SV_INCREMENT, multiplier)]]

            sv(note.StartTime - SV_INCREMENT, multiplier)
            sv(note.StartTime, -1 * multiplier + 2 * rate)
            sv(note.StartTime + SV_INCREMENT, rate)
        end
    end

    actions.PlaceScrollVelocityBatch(svs)
end

function unhideLayer(layer)
    local notes = getNotesInLayer(layer)
    local svs = {}

    for _, note in pairs(notes) do
        table.insert(svs, getScrollVelocityAtExactly(note.StartTime - SV_INCREMENT))
        table.insert(svs, getScrollVelocityAtExactly(note.StartTime))
        table.insert(svs, getScrollVelocityAtExactly(note.StartTime + SV_INCREMENT))
    end

    actions.RemoveScrollVelocityBatch(svs)
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

function getLayerIndex(layer)
    local layers = map.EditorLayers

    if layer == map.DefaultLayer then
        return 0
    end

    for i = 1, #layers do
        if layer == layers[i] then
            return i
        end
    end
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

function getScrollVelocityAtExactly(time)
    local currentsv = map.GetScrollVelocityAt(time)
    if not currentsv then return end
    if currentsv.StartTime == time then
        return currentsv
    end
end