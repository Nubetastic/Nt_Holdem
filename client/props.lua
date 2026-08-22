HoldemProps = {
    table = {},
}

local currentTableId = nil
local currentDeckName = nil
local propsVersion = 0

local function newProp()
    return {
        shouldSpawn = false,
        isSpawn = false,
        object = nil,
        descriptor = nil,
        model = nil,
        origin = nil,
        attachPed = nil,
    }
end

local function loadModel(model)
    local hash = type(model) == "number" and model or GetHashKey(model)
    if not IsModelInCdimage(hash) and not IsModelValid(hash) then return nil end
    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do Wait(0) end
    return HasModelLoaded(hash) and hash or nil
end

local function deleteProp(object)
    if not object or not DoesEntityExist(object) then return true end
    if IsEntityAttached(object) then DetachEntity(object, true, true) end
    SetEntityAsMissionEntity(object, true, true)
    DeleteObject(object)
    if DoesEntityExist(object) then DeleteEntity(object) end
    return not DoesEntityExist(object)
end

local function worldFromOrigin(origin, offset)
    local heading = tonumber(origin.w) or 0.0
    local radians = math.rad(heading)
    local forward = tonumber(offset.x) or 0.0
    local right = tonumber(offset.y) or 0.0
    return {
        x = origin.x + right * math.cos(radians) - forward * math.sin(radians),
        y = origin.y + right * math.sin(radians) + forward * math.cos(radians),
        z = origin.z + (tonumber(offset.z) or 0.0),
        heading = heading,
    }
end

local function createProp(descriptor)
    local definition = descriptor.definition
    local hash = loadModel(definition.model)
    if not hash then return nil end
    local object

    if descriptor.attachPed and DoesEntityExist(descriptor.attachPed) then
        local coords = GetEntityCoords(descriptor.attachPed)
        object = CreateObjectNoOffset(hash, coords.x, coords.y, coords.z, false, false, false)
        local offset = definition.offset
        local boneIndex = GetEntityBoneIndexByName(descriptor.attachPed, definition.bone)
        if not object or object == 0 or not boneIndex or boneIndex == -1 then
            if object and object ~= 0 then DeleteObject(object) end
            SetModelAsNoLongerNeeded(hash)
            return nil
        end
        SetEntityAsMissionEntity(object, true, true)
        FreezeEntityPosition(object, false)
        SetEntityCollision(object, false, false)
        SetEntityCompletelyDisableCollision(object, true, true)
        AttachEntityToEntity(
            object,
            descriptor.attachPed,
            boneIndex,
            offset.x, offset.y, offset.z,
            offset.rx, offset.ry, offset.rz,
            true, true, false, true, 1, true
        )
        if not IsEntityAttachedToEntity(object, descriptor.attachPed) then
            DeleteObject(object)
            SetModelAsNoLongerNeeded(hash)
            return nil
        end
    else
        local offset = definition.offset or {}
        local position = worldFromOrigin(descriptor.origin, offset)
        object = CreateObjectNoOffset(hash, position.x, position.y, position.z, false, false, false)
        SetEntityRotation(
            object,
            tonumber(offset.rx) or 0.0,
            tonumber(offset.ry) or 0.0,
            position.heading + (tonumber(offset.rz) or tonumber(offset.h) or 0.0),
            2,
            true
        )
        FreezeEntityPosition(object, true)
        SetEntityCollision(object, false, false)
        SetEntityCompletelyDisableCollision(object, true, true)
        SetEntityAsMissionEntity(object, true, true)
    end

    SetModelAsNoLongerNeeded(hash)
    return object
end

local function cardModel(card, style)
    local ending = ConfigProps.Cards.cardEndings[style]
    if not ending then return nil end
    if not card or not card.isRevealed then return "p_crd_joker" .. ending end
    local royalty = tostring(card.royalty):lower()
    if royalty == "t" then royalty = "10" end
    return ConfigProps.Cards.cardHeader .. royalty .. "_" .. tostring(card.suit):lower() .. ending
end

local function seatedPed(player)
    if player.isSelf then return PlayerPedId() end
    if player.isNpc then return GetHoldemNpcPed and GetHoldemNpcPed(player.npcId) or nil end
    if type(player.source) ~= "number" then return nil end
    local playerIndex = GetPlayerFromServerId(player.source)
    if playerIndex == -1 then return nil end
    return GetPlayerPed(playerIndex)
end

local function worldCardDefinition(template, model, faceDown)
    local offset = template.offset
    return {
        model = model,
        offset = {
            x = offset.x, y = offset.y, z = offset.z,
            rx = offset.rx or 0.0,
            ry = (offset.ry or 0.0) + (faceDown and 180.0 or 0.0),
            rz = offset.rz or offset.h or 0.0,
        },
    }
end

local function heldCardDefinition(model, cardIndex, ped)
    local handCards = ConfigProps.HandCards[IsPedMale(ped) and "Male" or "Female"]
    local card = handCards[cardIndex]
    if not card then return nil end
    return {
        model = model,
        bone = handCards.Bone,
        offset = {
            x = card.x,
            y = card.y,
            z = card.z,
            rx = card.rx,
            ry = card.ry,
            rz = card.rz,
        },
    }
end

local function setProp(prop, shouldSpawn, definition, origin, attachPed)
    prop.shouldSpawn = shouldSpawn == true and definition ~= nil and definition.model ~= nil
        and (origin ~= nil or attachPed ~= nil)
    prop.descriptor = prop.shouldSpawn and {
        definition = definition,
        origin = origin,
        attachPed = attachPed,
    } or nil
end

local function updateProp(prop)
    local descriptor = prop.descriptor
    local missing = prop.isSpawn and (not prop.object or not DoesEntityExist(prop.object))
    local detached = prop.isSpawn and descriptor and descriptor.attachPed and not missing
        and not IsEntityAttachedToEntity(prop.object, descriptor.attachPed)
    local changed = prop.isSpawn and descriptor and (prop.model ~= descriptor.definition.model
        or prop.origin ~= descriptor.origin or prop.attachPed ~= descriptor.attachPed)

    if prop.isSpawn and (not prop.shouldSpawn or missing or detached or changed) then
        if deleteProp(prop.object) then
            prop.isSpawn = false
            prop.object = nil
            prop.model = nil
            prop.origin = nil
            prop.attachPed = nil
        end
    end

    if prop.shouldSpawn and not prop.isSpawn and descriptor then
        local object = createProp(descriptor)
        if object then
            prop.object = object
            prop.model = descriptor.definition.model
            prop.origin = descriptor.origin
            prop.attachPed = descriptor.attachPed
            prop.isSpawn = true
        end
    end
end

local function forEachProp(callback)
    if HoldemProps.table.pot then
        callback(HoldemProps.table.pot)
        callback(HoldemProps.table.deck)
        callback(HoldemProps.table.dealerDeck)
        for cardIndex = 1, 5 do callback(HoldemProps.table.communityCards[cardIndex]) end
    end
    for key, playerProps in pairs(HoldemProps) do
        if type(playerProps) == "table" and key:match("^player%d+$") then
            callback(playerProps.chips)
            callback(playerProps.ante)
            callback(playerProps.bet)
            for cardIndex = 1, 2 do
                callback(playerProps.cardsHeld[cardIndex])
                callback(playerProps.cardsTable[cardIndex])
            end
        end
    end
end

local function disableAllProps()
    forEachProp(function(prop)
        prop.shouldSpawn = false
        prop.descriptor = nil
    end)
end

local function setupProps(tableConfig)
    HoldemProps.table = {
        pot = newProp(),
        deck = newProp(),
        dealerDeck = newProp(),
        communityCards = {},
    }
    for cardIndex = 1, 5 do HoldemProps.table.communityCards[cardIndex] = newProp() end

    for key in pairs(HoldemProps) do
        if key:match("^player%d+$") then HoldemProps[key] = nil end
    end
    for seatIndex in pairs(tableConfig.Chairs) do
        HoldemProps["player" .. seatIndex] = {
            chips = newProp(),
            cardsHeld = { newProp(), newProp() },
            cardsTable = { newProp(), newProp() },
            bet = newProp(),
            ante = newProp(),
        }
    end
end

function HoldemProps:Stop()
    propsVersion = propsVersion + 1
    disableAllProps()
    for _ = 1, 10 do
        local propsRemaining = false
        forEachProp(function(prop)
            updateProp(prop)
            if prop.isSpawn then propsRemaining = true end
        end)
        if not propsRemaining then break end
    end
    currentTableId = nil
    currentDeckName = nil
end

function HoldemProps:Start(tableId)
    local tableConfig = ConfigTables.Loc[tableId]
    if not tableConfig then return end
    self:Stop()
    currentTableId = tableId
    currentDeckName = nil
    setupProps(tableConfig)
    local version = propsVersion

    CreateThread(function()
        while version == propsVersion and currentTableId == tableId do
            forEachProp(updateProp)
            Wait(100)
        end
    end)
end

function HoldemProps:UpdateGame(gameView)
    if not currentTableId or gameView.tableId ~= currentTableId then return end
    local tableConfig = ConfigTables.Loc[currentTableId]
    if not tableConfig then return end
    currentDeckName = gameView.deckName
    local definitions = ConfigProps.Props
    local dealerSeat = tableConfig.Chairs[tonumber(gameView.dealerSeat)]
    local dealerOrigin = dealerSeat and dealerSeat.Coords

    setProp(self.table.pot, gameView.potVisible, definitions.Pot, dealerOrigin)
    local deckEnding = ConfigProps.Cards.DeckEndings[gameView.deckName]
    setProp(self.table.deck, gameView.deckOnTable and deckEnding ~= nil, deckEnding and {
        model = ConfigProps.Cards.DeckHeader .. deckEnding,
        offset = definitions.Deck.offset,
    }, dealerOrigin)
    if gameView.deckOnTable then self:RemoveDealerDeck() end

    for cardIndex = 1, 5 do
        local card = gameView.communityCards and gameView.communityCards[cardIndex]
        local template = definitions["CommunityCard" .. cardIndex]
        setProp(self.table.communityCards[cardIndex], card ~= nil,
            card and worldCardDefinition(template, cardModel(card, gameView.deckName), false), dealerOrigin)
    end

    for key, playerProps in pairs(self) do
        if type(playerProps) == "table" and key:match("^player%d+$") then
            setProp(playerProps.chips, false)
            setProp(playerProps.ante, false)
            setProp(playerProps.bet, false)
            for cardIndex = 1, 2 do
                setProp(playerProps.cardsHeld[cardIndex], false)
                setProp(playerProps.cardsTable[cardIndex], false)
            end
        end
    end

    for _, player in ipairs(gameView.players or {}) do
        local playerProps = self["player" .. player.seatIndex]
        local chair = tableConfig.Chairs[player.seatIndex]
        local origin = chair and chair.Coords
        if playerProps and origin then
            setProp(playerProps.chips, player.visuals and player.visuals.showPlayerChips,
                definitions.PlayerChips, origin)
            setProp(playerProps.ante, player.anteVisible, definitions.Ante, origin)
            setProp(playerProps.bet, player.playerBet, definitions.PlayerBet, origin)

            if player.inHand then
                for cardIndex, card in ipairs(player.holeCards or {}) do
                    if cardIndex <= 2 and (player.cardState == "table_down" or player.cardState == "folded") then
                        local template = definitions[cardIndex == 1 and "PlayerCard1" or "PlayerCard2"]
                        setProp(playerProps.cardsTable[cardIndex], true,
                            worldCardDefinition(template, cardModel(nil, gameView.deckName), true), origin)
                    elseif cardIndex <= 2 and player.cardState == "shown" then
                        local template = definitions[cardIndex == 1 and "PlayerCard1" or "PlayerCard2"]
                        setProp(playerProps.cardsTable[cardIndex], true,
                            worldCardDefinition(template, cardModel(card, gameView.deckName), false), origin)
                    elseif cardIndex <= 2 and player.cardState == "held" then
                        local ped = seatedPed(player)
                        if ped then
                            setProp(playerProps.cardsHeld[cardIndex], true,
                                heldCardDefinition(cardModel(card, gameView.deckName), cardIndex, ped), nil, ped)
                        end
                    end
                end
            end
        end
    end
end

function HoldemProps:AttachDealerDeck(ped)
    if not ped or not DoesEntityExist(ped) then return end
    local definition = ConfigProps.DealerHand
    local attachment = definition and definition.attachment
    local deckEnding = ConfigProps.Cards.DeckEndings[currentDeckName]
    if not definition or not attachment or not deckEnding then return end
    setProp(self.table.dealerDeck, true, {
        model = ConfigProps.Cards.DeckHeader .. deckEnding,
        bone = attachment.bone,
        offset = {
            x = attachment.x,
            y = attachment.y,
            z = attachment.z,
            rx = attachment.rx,
            ry = attachment.ry,
            rz = attachment.rz,
        },
    }, nil, ped)
end

function HoldemProps:RemoveDealerDeck()
    if not self.table.dealerDeck then return end
    setProp(self.table.dealerDeck, false)
end

function HoldemProps:RemovePot()
    if not self.table.pot then return end
    setProp(self.table.pot, false)
end

function HoldemProps:CleanupBetting()
    for key, playerProps in pairs(self) do
        if type(playerProps) == "table" and key:match("^player%d+$") then
            setProp(playerProps.ante, false)
            setProp(playerProps.bet, false)
        end
    end
end

function HoldemProps:CleanupEnd()
    self:CleanupBetting()
    setProp(self.table.pot, false)
    setProp(self.table.deck, false)
    setProp(self.table.dealerDeck, false)
    for cardIndex = 1, 5 do setProp(self.table.communityCards[cardIndex], false) end
    for key, playerProps in pairs(self) do
        if type(playerProps) == "table" and key:match("^player%d+$") then
            for cardIndex = 1, 2 do
                setProp(playerProps.cardsHeld[cardIndex], false)
                setProp(playerProps.cardsTable[cardIndex], false)
            end
        end
    end
end

function HoldemProps:CleanupPlayer(seatIndex)
    local playerProps = self["player" .. seatIndex]
    if not playerProps then return end
    setProp(playerProps.chips, false)
    setProp(playerProps.ante, false)
    setProp(playerProps.bet, false)
    for cardIndex = 1, 2 do
        setProp(playerProps.cardsHeld[cardIndex], false)
        setProp(playerProps.cardsTable[cardIndex], false)
    end
end

function HoldemProps:CleanupAll()
    self:Stop()
end

RegisterNetEvent("nt_holdem:client:cleanupBettingProps", function(tableId)
    if tableId ~= currentTableId then return end
    HoldemProps:CleanupBetting()
end)

RegisterNetEvent("nt_holdem:client:cleanupEndProps", function(tableId)
    if tableId ~= currentTableId then return end
    HoldemProps:CleanupEnd()
end)

RegisterNetEvent("nt_holdem:client:cleanupPlayerProps", function(tableId, seatIndex)
    if tableId ~= currentTableId then return end
    HoldemProps:CleanupPlayer(seatIndex)
end)
