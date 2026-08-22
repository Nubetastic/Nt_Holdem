HoldemUI = {}

local uiOpen = false
local entryTableId = nil
local firstPersonActive = false
local cameraLookActive = false
local cameraLookSawAim = false
local cursorX, cursorY = 0.5, 0.5
local INPUT_AIM = GetHashKey("INPUT_AIM")
local INPUT_ATTACK = GetHashKey("INPUT_ATTACK")
local INPUT_ATTACK2 = GetHashKey("INPUT_ATTACK2")
local INPUT_LOOK_LR = GetHashKey("INPUT_LOOK_LR")
local INPUT_LOOK_UD = GetHashKey("INPUT_LOOK_UD")

local function setCameraLook(active, data)
    active = active == true and uiOpen
    if active == cameraLookActive then return end
    cameraLookActive = active

    if active then
        cursorX = math.max(0.0, math.min(1.0, tonumber(data and data.x) or 0.5))
        cursorY = math.max(0.0, math.min(1.0, tonumber(data and data.y) or 0.5))
        cameraLookSawAim = false
        SetNuiFocus(true, false)
        if SetNuiFocusKeepInput then SetNuiFocusKeepInput(true) end
    elseif uiOpen then
        cameraLookSawAim = false
        if SetNuiFocusKeepInput then SetNuiFocusKeepInput(false) end
        SetNuiFocus(true, true)
        if SetCursorLocation then SetCursorLocation(cursorX, cursorY) end
        SendNUIMessage({ type = "cameraLook", active = false })
    else
        cameraLookSawAim = false
        if SetNuiFocusKeepInput then SetNuiFocusKeepInput(false) end
        SetNuiFocus(false, false)
    end
end

CreateThread(function()
    Wait(0)
    SendNUIMessage({ type = "close" })
    if SetNuiFocusKeepInput then SetNuiFocusKeepInput(false) end
    SetNuiFocus(false, false)
end)

function HoldemUI:Open(tableId)
    entryTableId = nil
    uiOpen = true
    SendNUIMessage({ type = "closeEntry" })
    SendNUIMessage({ type = "open", tableId = tableId })
    SetNuiFocus(true, true)
end

function HoldemUI:OpenSetup(data)
    entryTableId = data.tableId
    SendNUIMessage({ type = "setupTable", data = data })
    SetNuiFocus(true, true)
end

function HoldemUI:OpenJoin(data)
    entryTableId = data.tableId
    SendNUIMessage({ type = "joinDetails", data = data })
    SetNuiFocus(true, true)
end

function HoldemUI:OpenFull(data)
    entryTableId = data.tableId
    SendNUIMessage({ type = "tableFull", data = data })
    SetNuiFocus(true, true)
end

function HoldemUI:CloseEntry()
    entryTableId = nil
    SendNUIMessage({ type = "closeEntry" })
    if not uiOpen then SetNuiFocus(false, false) end
end

function HoldemUI:Update(gameView)
    if uiOpen then SendNUIMessage({ type = "state", game = gameView }) end
end

function HoldemUI:Close()
    uiOpen = false
    entryTableId = nil
    firstPersonActive = false
    setCameraLook(false)
    SendNUIMessage({ type = "close" })
    if SetNuiFocusKeepInput then SetNuiFocusKeepInput(false) end
    SetNuiFocus(false, false)
end

RegisterNUICallback("cameraLook", function(data, callback)
    setCameraLook(data and data.active == true, data)
    callback({ ok = true })
end)

RegisterNUICallback("toggleFirstPerson", function(_, callback)
    firstPersonActive = not firstPersonActive
    callback({ active = firstPersonActive })
end)

CreateThread(function()
    while true do
        if firstPersonActive and uiOpen then
            Citizen.InvokeNative(0x90DA5BA5C2635416)
            Wait(0)
        else
            Wait(100)
        end
    end
end)

CreateThread(function()
    while true do
        if cameraLookActive then
            DisableControlAction(0, INPUT_AIM, true)
            DisableControlAction(0, INPUT_ATTACK, true)
            DisableControlAction(0, INPUT_ATTACK2, true)
            EnableControlAction(0, INPUT_LOOK_LR, true)
            EnableControlAction(0, INPUT_LOOK_UD, true)
            local aimPressed = IsDisabledControlPressed(0, INPUT_AIM) or IsControlPressed(0, INPUT_AIM)
            if aimPressed then
                cameraLookSawAim = true
            elseif cameraLookSawAim then
                setCameraLook(false)
            end
            Wait(0)
        else
            Wait(100)
        end
    end
end)

local function action(name)
    RegisterNUICallback(name, function(data, callback)
        TriggerServerEvent("nt_holdem:server:" .. name, data and data.handId)
        callback({ ok = true, waitMs = 0 })
    end)
end

action("check")
action("call")
action("fold")

RegisterNUICallback("raise", function(data, callback)
    TriggerServerEvent("nt_holdem:server:raise", data and data.handId, data and data.amount)
    callback({ ok = true, waitMs = 0 })
end)

RegisterNUICallback("requestLeave", function(_, callback)
    TriggerServerEvent("nt_holdem:server:leaveTable")
    callback({ ok = true })
end)

RegisterNUICallback("configureTable", function(data, callback)
    local playerCoords = GetEntityCoords(PlayerPedId())
    data.playerCoords = {
        x = playerCoords.x,
        y = playerCoords.y,
        z = playerCoords.z,
    }
    data.isMale = IsPedMale(PlayerPedId())
    TriggerServerEvent("nt_holdem:server:configureTable", data)
    callback({ ok = true })
end)

RegisterNUICallback("confirmJoin", function(_, callback)
    local playerCoords = GetEntityCoords(PlayerPedId())
    TriggerServerEvent("nt_holdem:server:confirmJoin", entryTableId, {
        x = playerCoords.x,
        y = playerCoords.y,
        z = playerCoords.z,
    }, IsPedMale(PlayerPedId()))
    callback({ ok = true })
end)

RegisterNUICallback("cancelEntry", function(_, callback)
    if entryTableId then TriggerServerEvent("nt_holdem:server:cancelEntry", entryTableId) end
    HoldemUI:CloseEntry()
    callback({ ok = true })
end)
