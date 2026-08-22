local publicTables = {}
local seatedTableId = nil
local viewingTableId = nil
local requestedViewingTableId = nil
seatedSeat = nil
local joinPrompt = nil
local promptGroup = math.random(0, 0xFFFFFF)
local joinDebounceUntil = 0
local preTablePosition = nil
local tableBlips = {}
local animationVersions = {}
local npcPeds = {}
local lockedTableChairs = {}
local lockedTableId = nil

local function freezeTableChairs(tableId)
    local tableConfig = ConfigTables.Loc[tableId]
    if not tableConfig then return end

    if lockedTableId ~= tableId then
        lockedTableChairs = {}
        lockedTableId = tableId
    end

    local objects = GetGamePool("CObject")
    for seatIndex, chair in pairs(tableConfig.Chairs) do
        local lockedChair = lockedTableChairs[seatIndex]
        if not lockedChair or not DoesEntityExist(lockedChair.handle) then
            local closestObject = nil
            local closestDistance = 0.75
            for _, object in ipairs(objects) do
                local objectCoords = GetEntityCoords(object)
                local x = objectCoords.x - chair.SpawnCoords.x
                local y = objectCoords.y - chair.SpawnCoords.y
                local distance = math.sqrt(x * x + y * y)
                if distance < closestDistance then
                    closestObject = object
                    closestDistance = distance
                end
            end

            if closestObject then
                lockedChair = {
                    handle = closestObject,
                    coords = GetEntityCoords(closestObject),
                    rotation = GetEntityRotation(closestObject),
                }
                lockedTableChairs[seatIndex] = lockedChair
            end
        end

        if lockedChair and DoesEntityExist(lockedChair.handle) then
            SetEntityCoords(lockedChair.handle, chair.Coords.x, chair.Coords.y, lockedChair.coords.z,
                false, false, false, false)
            SetEntityRotation(lockedChair.handle, lockedChair.rotation.x, lockedChair.rotation.y,
                (chair.Coords.w + 180.0) % 360.0, 2, true)
            FreezeEntityPosition(lockedChair.handle, true)
        end
    end
end

local function notify(message, kind)
    if lib and lib.notify then
        lib.notify({ title = "Texas Hold'em", description = tostring(message), type = kind or "inform" })
    else
        print(("[Nt_Holdem] %s"):format(tostring(message)))
    end
end

local function createPrompt()
    local prompt = PromptRegisterBegin()
    PromptSetControlAction(prompt, GetHashKey(Config.Keys.Join))
    PromptSetText(prompt, CreateVarString(10, "LITERAL_STRING", "Join Hold'em"))
    PromptSetEnabled(prompt, false)
    PromptSetVisible(prompt, false)
    PromptSetHoldMode(prompt, true)
    PromptSetGroup(prompt, promptGroup, 0)
    PromptRegisterEnd(prompt)
    return prompt
end

local function togglePrompt(enabled)
    if not joinPrompt then return end
    PromptSetEnabled(joinPrompt, enabled)
    PromptSetVisible(joinPrompt, enabled)
end

local function loadAnimation(dictionary)
    RequestAnimDict(dictionary)
    local timeout = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dictionary) and GetGameTimer() < timeout do Wait(0) end
    return HasAnimDictLoaded(dictionary)
end

local function loadPedModel(model)
    local hash = type(model) == "number" and model or tonumber(model) or GetHashKey(model)
    if not IsModelInCdimage(hash) and not IsModelValid(hash) then return nil end
    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do Wait(0) end
    return HasModelLoaded(hash) and hash or nil
end

local function pointInPoly2D(point, poly)
    if type(poly) ~= "table" or #poly < 3 then return false end
    local inside = false
    local j = #poly
    for i = 1, #poly do
        local a = poly[i]
        local b = poly[j]
        if ((a.y > point.y) ~= (b.y > point.y))
            and (point.x < (b.x - a.x) * (point.y - a.y) / ((b.y - a.y) + 0.000001) + a.x) then
            inside = not inside
        end
        j = i
    end
    return inside
end

local function scanNpcAppearances(scanArea, count, usedCombinations)
    local combinations = {}
    local seenModels = {}
    local used = {}
    for _, combination in ipairs(usedCombinations or {}) do
        used[tostring(combination.model) .. ":" .. tostring(combination.outfit)] = true
    end

    for _, ped in ipairs(GetGamePool and GetGamePool("CPed") or {}) do
        local populationType = DoesEntityExist(ped) and GetEntityPopulationType(ped) or 0
        if ped ~= PlayerPedId() and DoesEntityExist(ped) and not IsEntityDead(ped)
            and not IsPedAPlayer(ped) and IsPedHuman(ped) and not IsEntityAMissionEntity(ped)
            and NetworkGetEntityIsNetworked(ped) and populationType >= 1 and populationType <= 6
            and pointInPoly2D(GetEntityCoords(ped), scanArea) and not seenModels[GetEntityModel(ped)] then
            local model = GetEntityModel(ped)
            seenModels[model] = true
            local outfitCount = GetNumMetaPedOutfits(ped) or 0
            for outfit = 0, outfitCount - 1 do
                local key = tostring(model) .. ":" .. tostring(outfit)
                if not used[key] then
                    combinations[#combinations + 1] = {
                        model = model,
                        outfit = outfit,
                        gender = IsPedMale(ped) and "Male" or "Female",
                    }
                end
            end
        end
    end

    local selected = {}
    for _ = 1, math.min(tonumber(count) or 0, #combinations) do
        local index = math.random(1, #combinations)
        selected[#selected + 1] = table.remove(combinations, index)
    end
    return selected
end

local function deleteNpc(npcId)
    local ped = npcPeds[npcId]
    if ped and DoesEntityExist(ped) then DeletePed(ped) end
    npcPeds[npcId] = nil
    animationVersions[npcId] = nil
end

local function spawnNpc(player)
    local tableConfig = ConfigTables.Loc[viewingTableId]
    local chair = tableConfig and tableConfig.Chairs[tonumber(player.seatIndex)]
    local appearance = player.npcAppearance or {}
    if not chair or not chair.Coords or not appearance.model then return end
    local hash = loadPedModel(appearance.model)
    if not hash then return end
    local coords = chair.Coords
    local ped = CreatePed(hash, coords.x, coords.y, coords.z, coords.w, false, false, true, true)
    if not ped or ped == 0 then SetModelAsNoLongerNeeded(hash) return end
    local offset = ConfigTables.Offsets[IsPedMale(ped) and "Male" or "Female"][1]

    SetEntityHeading(ped, coords.w)
    SetEntityCollision(ped, false, false)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetEntityAsMissionEntity(ped, true, true)
    local outfit = tonumber(appearance.outfit)
    if outfit and outfit >= 0 then Citizen.InvokeNative(0x77FF8D35EEC6BBC4, ped, outfit, false) end
    Citizen.InvokeNative(0x283978A15512B2FE, ped, true)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, 0, 1, 1, 1, false)
    ClearPedTasksImmediately(ped)
    TaskStartScenarioAtPosition(ped, GetHashKey("GENERIC_SEAT_CHAIR_TABLE_SCENARIO"),
        coords.x + offset.x, coords.y + offset.y, coords.z + offset.z, coords.w, -1, false, true)
    npcPeds[player.npcId] = ped
    SetModelAsNoLongerNeeded(hash)
end

local function updateNpcs(gameView)
    local desired = {}
    for _, player in ipairs(gameView.players or {}) do
        if player.isNpc and player.npcId then desired[player.npcId] = player end
    end
    for npcId in pairs(npcPeds) do if not desired[npcId] then deleteNpc(npcId) end end
    for npcId, player in pairs(desired) do
        if not npcPeds[npcId] or not DoesEntityExist(npcPeds[npcId]) then spawnNpc(player) end
    end
end

function GetHoldemNpcPed(npcId)
    return npcPeds[npcId]
end

local function playerPed(serverSource)
    if type(serverSource) ~= "number" then return npcPeds[serverSource] end
    if tonumber(serverSource) == GetPlayerServerId(PlayerId()) then return PlayerPedId() end
    local playerIndex = GetPlayerFromServerId(tonumber(serverSource) or -1)
    if playerIndex == -1 then return nil end
    return GetPlayerPed(playerIndex)
end

local function playerHoldsCards(serverSource)
    for _, player in ipairs(CurrentHoldemGame and CurrentHoldemGame.players or {}) do
        if tostring(player.source) == tostring(serverSource) then return player.cardState == "held" end
    end
    return false
end

function PlayHoldemAnimation(actionName, serverSource, gender, animationName, playRemote)
    local ped = playerPed(serverSource)
    if not ped or not DoesEntityExist(ped) or not viewingTableId then return end
    local isLocalPlayer = tonumber(serverSource) == GetPlayerServerId(PlayerId())
    if actionName == "reset" then
        HoldemProps:RemoveDealerDeck()
        if (isLocalPlayer or type(serverSource) ~= "number") and loadAnimation(ConfigAnim.Dict) then
            TaskPlayAnim(ped, ConfigAnim.Dict, ConfigAnim.SeatedIdle, 1.0, 1.0, -1, 25, 1.0, true, 0, false, 0, false)
        end
        return
    end
    local action = ConfigAnim.Actions[gender][actionName]
    local dictionary = action and (action.Dict or ConfigAnim.Dict)
    if not action or not loadAnimation(dictionary) then return end
    local animationKey = tostring(serverSource)
    animationVersions[animationKey] = (animationVersions[animationKey] or 0) + 1
    local version = animationVersions[animationKey]
    if action.HasDeck then
        HoldemProps:AttachDealerDeck(ped)
    end
    if not isLocalPlayer and not playRemote then return end
    local flags = action.Body == "full" and 1 or 25
    local speed = action.Speed or 1.0
    local duration = math.floor(action.Duration / speed)
    TaskPlayAnim(ped, dictionary, animationName or action.Name, 8.0, 1.0, duration, flags, speed, true, 0, false, 0, false)
    CreateThread(function()
        Wait(duration)
        if version == animationVersions[animationKey] and viewingTableId then
            if action.HasDeck and not action.KeepDeck then HoldemProps:RemoveDealerDeck() end
            local idle = action.NextIdle or (playerHoldsCards(serverSource) and ConfigAnim.HoldingIdle or ConfigAnim.SeatedIdle)
            if loadAnimation(ConfigAnim.Dict) then
                local blendIn = idle == ConfigAnim.HoldingIdle and 8.0 or 1.0
                TaskPlayAnim(ped, ConfigAnim.Dict, idle, blendIn, 1.0, -1, 25, 1.0, true, 0, false, 0, false)
            end
        end
    end)
end

local function sitAtTable(tableId, seatIndex)
    local chair = ConfigTables.Loc[tableId] and ConfigTables.Loc[tableId].Chairs[seatIndex]
    if not chair then return end
    local coords = chair.Coords
    local ped = PlayerPedId()
    local offset = ConfigTables.Offsets[IsPedMale(ped) and "Male" or "Female"][1]
    ClearPedTasksImmediately(ped)
    FreezeEntityPosition(ped, true)
    TaskStartScenarioAtPosition(ped, GetHashKey("GENERIC_SEAT_CHAIR_TABLE_SCENARIO"),
        coords.x + offset.x, coords.y + offset.y, coords.z + offset.z, coords.w, -1, false, true)
end

local function cleanupGameView(tableId)
    if tableId and viewingTableId ~= tableId then return end
    animationVersions = {}
    if requestedViewingTableId == tableId then requestedViewingTableId = nil end
    viewingTableId = nil
    CurrentHoldemGame = nil
    HoldemProps:Stop()
    for npcId in pairs(npcPeds) do deleteNpc(npcId) end
end

local function cleanup()
    cleanupGameView(seatedTableId)
    seatedTableId = nil
    seatedSeat = nil
    HoldemUI:Close()
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    ClearPedTasksImmediately(ped)
    if preTablePosition then
        SetEntityCoords(ped, preTablePosition.x, preTablePosition.y, preTablePosition.z, false, false, false, false)
        SetEntityHeading(ped, preTablePosition.h)
        preTablePosition = nil
    end
end

local function createBlips()
    if not Config.Blip.Enabled then return end
    for _, tableConfig in pairs(ConfigTables.Loc) do
        if tableConfig.Enabled and tableConfig.Table then
            local coords = tableConfig.Table.Coords
            local blip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, coords.x, coords.y, coords.z)
            SetBlipSprite(blip, GetHashKey(Config.Blip.Sprite), true)
            SetBlipScale(blip, Config.Blip.Scale)
            Citizen.InvokeNative(0x9CB1A1623062F402, blip, Config.Blip.Label)
            tableBlips[#tableBlips + 1] = blip
        end
    end
end

CreateThread(function()
    while true do
        local playerCoords = GetEntityCoords(PlayerPedId())
        local nearbyTableId = nil
        local closestTableDistance = nil
        for tableId, tableConfig in pairs(ConfigTables.Loc) do
            local tableCoords = tableConfig.Table.Coords
            local x = playerCoords.x - tableCoords.x
            local y = playerCoords.y - tableCoords.y
            local distance = math.sqrt(x * x + y * y)
            if tableConfig.Enabled and (not closestTableDistance or distance < closestTableDistance) then
                closestTableDistance = distance
                if distance <= Config.SpawnDistance then
                    nearbyTableId = tableId
                else
                    nearbyTableId = nil
                end
            end
        end

        if nearbyTableId then
            freezeTableChairs(nearbyTableId)
        elseif lockedTableId then
            lockedTableChairs = {}
            lockedTableId = nil
        end

        if closestTableDistance and closestTableDistance < 50.0 then
            Wait(1000)
        elseif closestTableDistance and closestTableDistance <= 200.0 then
            Wait(10000)
        else
            Wait(30000)
        end
    end
end)

CreateThread(function()
    while true do
        if seatedTableId then
            Wait(1000)
        else
            local coords = GetEntityCoords(PlayerPedId())
            local closestDistance = nil
            local closestActiveTableId = nil
            local closestActiveDistance = nil

            for tableId, tableConfig in pairs(ConfigTables.Loc) do
                if tableConfig.Enabled and tableConfig.Table then
                    local distance = #(coords - tableConfig.Table.Coords)
                    if not closestDistance or distance < closestDistance then
                        closestDistance = distance
                    end
                    local status = publicTables[tableId]
                    if status and status.state ~= "EMPTY" and status.state ~= "CONFIGURING"
                        and (not closestActiveDistance or distance < closestActiveDistance) then
                        closestActiveTableId = tableId
                        closestActiveDistance = distance
                    end
                end
            end

            local desiredTableId = nil
            if closestActiveDistance and closestActiveDistance <= Config.SpectatorDistance then
                desiredTableId = closestActiveTableId
            end

            if desiredTableId and desiredTableId ~= viewingTableId
                and desiredTableId ~= requestedViewingTableId then
                if viewingTableId then cleanupGameView(viewingTableId) end
                requestedViewingTableId = desiredTableId
                TriggerServerEvent("nt_holdem:server:setGameView", desiredTableId)
            elseif not desiredTableId and (viewingTableId or requestedViewingTableId) then
                if viewingTableId then cleanupGameView(viewingTableId) end
                requestedViewingTableId = nil
                TriggerServerEvent("nt_holdem:server:setGameView")
            end

            if not closestDistance or closestDistance > 200.0 then
                Wait(30000)
            elseif closestDistance >= 50.0 then
                Wait(10000)
            else
                Wait(1000)
            end
        end
    end
end)

CreateThread(function()
    joinPrompt = createPrompt()
    createBlips()
    TriggerServerEvent("nt_holdem:server:requestTables")
    while true do
        local sleep = 750
        togglePrompt(false)
        if not seatedTableId then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            for tableId, tableConfig in pairs(ConfigTables.Loc) do
                if tableConfig.Enabled and #(coords - tableConfig.Table.Coords) <= Config.InteractionDistance then
                    sleep = 0
                    local status = publicTables[tableId]
                    if not status or status.canJoin ~= false then
                        togglePrompt(true)
                        PromptSetActiveGroupThisFrame(promptGroup, CreateVarString(10, "LITERAL_STRING", tableConfig.Label))
                        if PromptHasHoldModeCompleted(joinPrompt) and GetGameTimer() >= joinDebounceUntil then
                            joinDebounceUntil = GetGameTimer() + 3000
                            local playerCoords = GetEntityCoords(PlayerPedId())
                            TriggerServerEvent("nt_holdem:server:joinTable", tableId, {
                                x = playerCoords.x,
                                y = playerCoords.y,
                                z = playerCoords.z,
                            }, IsPedMale(PlayerPedId()))
                        end
                    end
                    break
                end
            end
        end
        Wait(sleep)
    end
end)

RegisterNetEvent("nt_holdem:client:updateTables", function(tables) publicTables = tables or {} end)
RegisterNetEvent("nt_holdem:client:notify", function(data) notify(data.description or data, data.type) end)

RegisterNetEvent("nt_holdem:client:setupTable", function(data)
    HoldemUI:OpenSetup(data)
end)

RegisterNetEvent("nt_holdem:client:joinDetails", function(data)
    HoldemUI:OpenJoin(data)
end)

RegisterNetEvent("nt_holdem:client:tableFull", function(data)
    HoldemUI:OpenFull(data)
end)

RegisterNetEvent("nt_holdem:client:entryClosed", function(message)
    HoldemUI:CloseEntry()
    if message then notify(message) end
end)

RegisterNetEvent("nt_holdem:client:joined", function(tableId, seatIndex)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    preTablePosition = { x = coords.x, y = coords.y, z = coords.z - 1.0, h = GetEntityHeading(ped) }
    if viewingTableId and viewingTableId ~= tableId then cleanupGameView(viewingTableId) end
    local startProps = viewingTableId ~= tableId
    seatedTableId = tableId
    viewingTableId = tableId
    requestedViewingTableId = nil
    seatedSeat = seatIndex
    sitAtTable(tableId, seatIndex)
    if startProps then HoldemProps:Start(tableId) end
    HoldemUI:Open(tableId)
end)

RegisterNetEvent("nt_holdem:client:startGameView", function(tableId, gameView)
    if seatedTableId or requestedViewingTableId ~= tableId then return end
    if viewingTableId and viewingTableId ~= tableId then cleanupGameView(viewingTableId) end
    viewingTableId = tableId
    requestedViewingTableId = nil
    HoldemProps:Start(tableId)
    CurrentHoldemGame = gameView
    updateNpcs(gameView)
    HoldemProps:UpdateGame(gameView)
end)

RegisterNetEvent("nt_holdem:client:stopGameView", function(tableId)
    if viewingTableId == tableId and not seatedTableId then cleanupGameView(tableId) end
end)

RegisterNetEvent("nt_holdem:client:gameViewUnavailable", function(tableId)
    if requestedViewingTableId == tableId then requestedViewingTableId = nil end
end)

RegisterNetEvent("nt_holdem:client:updateGame", function(gameView)
    if not viewingTableId or gameView.tableId ~= viewingTableId then return end
    CurrentHoldemGame = gameView
    if seatedTableId == gameView.tableId then HoldemUI:Update(gameView) end
    updateNpcs(gameView)
    HoldemProps:UpdateGame(gameView)
end)

RegisterNetEvent("nt_holdem:client:playerAnimation", function(tableId, serverSource, gender, action, animationName)
    if viewingTableId == tableId then
        PlayHoldemAnimation(action, serverSource, gender, animationName, type(serverSource) ~= "number")
    end
end)

RegisterNetEvent("nt_holdem:client:requestNpcAppearances", function(requestId, tableId, scanArea, count, usedCombinations)
    if seatedTableId ~= tableId then return end
    TriggerServerEvent("nt_holdem:server:npcAppearances", requestId,
        scanNpcAppearances(scanArea, count, usedCombinations))
end)

RegisterNetEvent("nt_holdem:client:pickupAnimations", function(tableId, playerSources)
    if viewingTableId ~= tableId then return end
    for _, serverSource in ipairs(playerSources) do
        for _, player in ipairs(CurrentHoldemGame and CurrentHoldemGame.players or {}) do
            if tostring(player.source) == tostring(serverSource) then
                PlayHoldemAnimation("pickup", serverSource, player.gender, nil, true)
                break
            end
        end
    end
end)

RegisterNetEvent("nt_holdem:client:leftTable", function()
    cleanup()
    --notify("You left the Hold'em table.")
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    togglePrompt(false)
    for _, blip in ipairs(tableBlips) do if DoesBlipExist(blip) then RemoveBlip(blip) end end
    cleanup()
end)
