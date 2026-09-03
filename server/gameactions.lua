local beginHand
local beginBettingRound
local advanceAfterAction
local resolveSingleWinner
local requestNpcPlayers
local processWaitingPlayers
local removeGame

local function steps(milliseconds)
    milliseconds = tonumber(milliseconds) or 0
    if milliseconds <= 0 then return 0 end
    return math.max(1, math.ceil(milliseconds / 100))
end

local function notify(source, message, kind)
    TriggerClientEvent("nt_holdem:client:notify", source, {
        description = message,
        type = kind or "inform",
    })
end

local function playerCash(player)
    if player.isNpc then return player.cash end
    return tonumber(Framework.getCash(player.source)) or 0
end

local function orderedPlayers(game, inHandOnly)
    local players = {}
    for _, player in pairs(game.players) do
        if not inHandOnly or player.inHand then
            players[#players + 1] = player
        end
    end
    table.sort(players, function(a, b) return a.seatIndex < b.seatIndex end)
    return players
end

local function activePlayers(game)
    local players = {}
    for _, player in ipairs(orderedPlayers(game, true)) do
        if not player.folded then players[#players + 1] = player end
    end
    return players
end

local function findPlayer(game, source)
    return game and game.players[tostring(source)] or nil
end

local function playerAtSeat(game, seatIndex)
    local playerKey = game.seats[seatIndex]
    return playerKey and game.players[playerKey] or nil
end

local function nextOccupiedSeat(game, seatIndex, inHandOnly)
    local players = orderedPlayers(game, inHandOnly)
    for _, player in ipairs(players) do
        if player.seatIndex > (tonumber(seatIndex) or 0) then return player.seatIndex end
    end
    return players[1] and players[1].seatIndex or nil
end

local function nextActivePlayer(game, seatIndex)
    local players = activePlayers(game)
    for _, player in ipairs(players) do
        if player.seatIndex > (tonumber(seatIndex) or 0) then return player end
    end
    return players[1]
end

local function nextActionPlayer(game, seatIndex)
    local players = activePlayers(game)
    for _, player in ipairs(players) do
        if not player.allIn and player.seatIndex > (tonumber(seatIndex) or 0) then return player end
    end
    for _, player in ipairs(players) do
        if not player.allIn then return player end
    end
end

local function validPlayerCoords(game, playerCoords)
    if type(playerCoords) ~= "table" then return false end
    local x = tonumber(playerCoords.x)
    local y = tonumber(playerCoords.y)
    local z = tonumber(playerCoords.z)
    if not x or not y or not z then return false end

    local tableCoords = game.config.Table.Coords
    local maximumDistance = Config.InteractionDistance + 3.0
    local xDistance = x - tableCoords.x
    local yDistance = y - tableCoords.y
    local zDistance = z - tableCoords.z
    return xDistance * xDistance + yDistance * yDistance + zDistance * zDistance
        <= maximumDistance * maximumDistance
end

local function closestFreeSeat(game, playerCoords)
    local closestSeat
    local closestDistance
    local x = tonumber(playerCoords.x)
    local y = tonumber(playerCoords.y)
    local z = tonumber(playerCoords.z)

    for seatIndex, chair in pairs(game.config.Chairs) do
        if seatIndex <= (game.config.MaxPlayers or 6) and not game.seats[seatIndex] then
            local xDistance = x - chair.Coords.x
            local yDistance = y - chair.Coords.y
            local zDistance = z - chair.Coords.z
            local distance = xDistance * xDistance + yDistance * yDistance + zDistance * zDistance
            if not closestDistance or distance < closestDistance then
                closestSeat = seatIndex
                closestDistance = distance
            end
        end
    end
    return closestSeat
end

local function randomFreeSeat(game)
    local openSeats = {}
    for seatIndex in pairs(game.config.Chairs) do
        if seatIndex <= (game.config.MaxPlayers or 6) and not game.seats[seatIndex] then
            openSeats[#openSeats + 1] = seatIndex
        end
    end
    if #openSeats == 0 then return nil end
    return openSeats[math.random(1, #openSeats)]
end

local function offerCount(game)
    local count = 0
    for _ in pairs(game.joinOffers) do count = count + 1 end
    return count
end

local function cardsRemaining(game)
    return math.max(0, #game.deck - game.nextCardIndex + 1)
end

local function isNearTable(source, locationID)
    local location = ConfigTables.Loc[locationID]
    local ped = GetPlayerPed(source)
    if not location or not location.Table or ped == 0 then return false end
    return #(GetEntityCoords(ped) - location.Table.Coords) <= Config.InteractionDistance + 3.0
end

local function gameRules(game)
    local stake = Config.Stakes[game.stakeName]
    if not stake then return nil end
    return {
        smallBlind = stake.smallBlind,
        bigBlind = stake.bigBlind,
        betIncrement = stake.betIncrement,
        allIn = stake.allIn,
    }
end

local function allowedActions(game, player)
    local actions = {}
    if not player or player.actionLocked then return actions end
    if game.currentPlayerKey == player.key and game.state:match("^BET_") then
        local amountToCall = math.max(0, game.currentBet - player.streetBet)
        local maximumAmount = math.min(
            math.max(0, Config.Stakes[game.stakeName].allIn - player.totalBet),
            playerCash(player)
        )
        local callAmount = math.min(amountToCall, maximumAmount)
        actions.fold = true
        actions.check = amountToCall == 0
        actions.call = amountToCall > 0 and callAmount > 0
        actions.callAmount = callAmount
        actions.callAllIn = callAmount > 0 and callAmount == maximumAmount
        actions.raise = maximumAmount > amountToCall
        actions.maximumAmount = maximumAmount
        actions.maximumAllIn = maximumAmount > 0
    end
    return actions
end

local function buildGameView(game, source)
    local selfPlayer = findPlayer(game, source)
    local players = {}
    local selfHoleCards = {}

    for _, player in ipairs(orderedPlayers(game)) do
        local holeCards = {}
        if player.inHand and #player.holeCards > 0 then
            if player.source == source or player.cardState == "shown" then
                for _, card in ipairs(player.holeCards) do
                    holeCards[#holeCards + 1] = HoldemCards.publicCard(card)
                end
            else
                for _ = 1, #player.holeCards do
                    holeCards[#holeCards + 1] = { isRevealed = false }
                end
            end
        end

        players[#players + 1] = {
            source = player.source,
            name = player.name,
            seatIndex = player.seatIndex,
            isNpc = player.isNpc,
            npcId = player.npcId,
            npcAppearance = player.npcAppearance,
            gender = player.gender,
            cash = player.cash,
            personality = player.personality,
            isSelf = player.source == source,
            waiting = player.waiting,
            inHand = player.inHand,
            allIn = player.allIn,
            folded = player.folded,
            visuals = player.visuals,
            cardState = player.cardState,
            anteVisible = player.anteVisible,
            playerBet = player.playerBet,
            streetBet = player.streetBet,
            totalBet = player.totalBet,
            holeCards = holeCards,
            result = player.result,
            isCurrent = game.currentPlayerKey == player.key,
            isDealer = game.dealerSeat == player.seatIndex,
            isSmallBlind = game.smallBlindSeat == player.seatIndex,
            isBigBlind = game.bigBlindSeat == player.seatIndex,
        }

        if player.source == source then selfHoleCards = holeCards end
    end

    local communityCards = {}
    for _, card in ipairs(game.communityCards) do
        communityCards[#communityCards + 1] = HoldemCards.publicCard(card)
    end

    local currentPlayer = game.currentPlayerKey and game.players[game.currentPlayerKey] or nil
    return {
        tableId = game.locationID,
        tableLabel = game.config.Label or game.locationID,
        stakeName = game.stakeName,
        stakeLabel = Config.Stakes[game.stakeName].label,
        deckName = game.deckName,
        allowNpcs = game.allowNpcs,
        state = game.state,
        handId = game.handID,
        dealerSeat = game.dealerSeat,
        smallBlindSeat = game.smallBlindSeat,
        bigBlindSeat = game.bigBlindSeat,
        currentSource = currentPlayer and currentPlayer.source or nil,
        currentName = currentPlayer and currentPlayer.name or nil,
        isMyTurn = currentPlayer and currentPlayer.source == source or false,
        deadline = game.deadline,
        pot = game.pot,
        potVisible = game.potVisible,
        deckOnTable = game.deckOnTable,
        visuals = game.visuals,
        currentBet = game.currentBet,
        cardsRemaining = cardsRemaining(game),
        communityCards = communityCards,
        players = players,
        rules = gameRules(game),
        self = selfPlayer and {
            source = selfPlayer.source,
            name = selfPlayer.name,
            cash = Framework.getCash(source),
            waiting = selfPlayer.waiting,
            holeCards = selfHoleCards,
        } or nil,
        allowedActions = allowedActions(game, selfPlayer),
        winners = game.winners,
    }
end

local function forEachGameClient(game, callback)
    for _, player in pairs(game.players) do
        if not player.isNpc then callback(player.source) end
    end
    for viewerSource in pairs(game.viewers) do callback(viewerSource) end
end

function SetGameViewer(source, locationID, dropped)
    local previousLocationID = ServerData.ViewerLocations[source]
    if previousLocationID then
        local previousGame = ServerData.Games[previousLocationID]
        if previousGame then previousGame.viewers[source] = nil end
        ServerData.ViewerLocations[source] = nil
        if not dropped then TriggerClientEvent("nt_holdem:client:stopGameView", source, previousLocationID) end
    end

    if not locationID or ServerData.PlayerLocations[source] then return end
    local game = ServerData.Games[locationID]
    local location = ConfigTables.Loc[locationID]
    local ped = GetPlayerPed(source)
    if not game or not game.stakeName or not location or location.Enabled == false or ped == 0
        or #(GetEntityCoords(ped) - location.Table.Coords) > Config.SpectatorDistance then
        TriggerClientEvent("nt_holdem:client:gameViewUnavailable", source, locationID)
        return
    end

    game.viewers[source] = true
    ServerData.ViewerLocations[source] = locationID
    TriggerClientEvent("nt_holdem:client:startGameView", source, locationID, buildGameView(game))
end

function PublicTables()
    local locations = {}
    for locationID, location in pairs(ConfigTables.Loc) do
        local game = ServerData.Games[locationID]
        locations[locationID] = {
            label = location.Label or locationID,
            state = game and (game.state == "SETUP" and "CONFIGURING" or game.state) or "EMPTY",
            playerCount = game and game.playerCount or 0,
            canJoin = location.Enabled ~= false,
        }
    end
    return locations
end

function BroadcastTables(target)
    TriggerClientEvent("nt_holdem:client:updateTables", target or -1, PublicTables())
end

function BroadcastGame(game)
    if not game.stakeName then return end
    for _, player in pairs(game.players) do
        if not player.isNpc then
            TriggerClientEvent("nt_holdem:client:updateGame", player.source, buildGameView(game, player.source))
        end
    end
    for viewerSource in pairs(game.viewers) do
        TriggerClientEvent("nt_holdem:client:updateGame", viewerSource, buildGameView(game))
    end
    BroadcastTables()
end

local function broadcastPlayerAnimation(game, player, action, animationName)
    if not player then return end
    forEachGameClient(game, function(observerSource)
        TriggerClientEvent("nt_holdem:client:playerAnimation", observerSource, game.locationID,
            player.source, player.gender, action, animationName)
    end)
end

local function cleanupPlayerProps(game, seatIndex)
    forEachGameClient(game, function(observerSource)
        TriggerClientEvent("nt_holdem:client:cleanupPlayerProps", observerSource, game.locationID, seatIndex)
    end)
end

local function tableSettings(game)
    return {
        tableId = game.locationID,
        tableLabel = game.config.Label or game.locationID,
        stakeName = game.stakeName,
        stake = Config.Stakes[game.stakeName],
        deckName = game.deckName,
        allowNpcs = game.allowNpcs,
    }
end

local function removeEntryPlayer(game, source)
    game.waitingPlayers[source] = nil
    game.joinOffers[source] = nil
    if ServerData.EntryLocations[source] == game.locationID then
        ServerData.EntryLocations[source] = nil
    end
end

local function addWaitingPlayer(game, source)
    if game.waitingPlayers[source] or game.joinOffers[source] then return end
    game.nextQueueOrder = game.nextQueueOrder + 1
    game.waitingPlayers[source] = {
        source = source,
        order = game.nextQueueOrder,
    }
end

processWaitingPlayers = function(game)
    if not game.stakeName then return end

    local available = (game.config.MaxPlayers or 6) - game.playerCount - offerCount(game)
    while available > 0 do
        local nextSource
        local nextOrder
        for source, waiting in pairs(game.waitingPlayers) do
            if not nextOrder or waiting.order < nextOrder then
                nextSource = source
                nextOrder = waiting.order
            end
        end
        if not nextSource then return end

        game.waitingPlayers[nextSource] = nil
        if GetPlayerPed(nextSource) ~= 0 and not ServerData.PlayerLocations[nextSource] then
            game.joinOffers[nextSource] = true
            TriggerClientEvent("nt_holdem:client:joinDetails", nextSource, tableSettings(game))
            available = available - 1
        else
            ServerData.EntryLocations[nextSource] = nil
        end
    end
end

local function scheduleHand(game, delayMilliseconds)
    if game.state ~= "WAITING" or game.realPlayerCount == 0 or game.playerCount < 2 then return end
    game.startSteps = steps(delayMilliseconds or 1500)
end

local function seatPlayer(game, source, playerCoords, isMale)
    local seatIndex = closestFreeSeat(game, playerCoords)
    if not seatIndex then return false end

    SetGameViewer(source, nil)
    removeEntryPlayer(game, source)
    local playerKey = tostring(source)
    local player = {
        key = playerKey,
        source = source,
        name = Framework.getName(source),
        seatIndex = seatIndex,
        gender = isMale and "Male" or "Female",
        isNpc = false,
        waiting = game.state ~= "WAITING",
        inHand = false,
        allIn = false,
        folded = false,
        holeCards = {},
        streetBet = 0,
        totalBet = 0,
        cardState = "none",
        visuals = { showPlayerChips = false },
    }

    game.players[playerKey] = player
    game.seats[seatIndex] = playerKey
    game.playerCount = game.playerCount + 1
    game.realPlayerCount = game.realPlayerCount + 1
    ServerData.PlayerLocations[source] = game.locationID

    TriggerClientEvent("nt_holdem:client:joined", source, game.locationID, seatIndex)
    BroadcastGame(game)

    player.joinStartSteps = steps(ConfigAnim.Actions[player.gender].join.StartDelay)
    return true
end

local function removeNpcForWaitingPlayer(game)
    for playerKey, player in pairs(game.players) do
        if player.isNpc and not player.leaveAfterHand then
            if game.state ~= "WAITING" then
                player.leaveAfterHand = true
                return true
            end
            game.players[playerKey] = nil
            game.seats[player.seatIndex] = nil
            game.playerCount = game.playerCount - 1
            game.npcCount = game.npcCount - 1
            cleanupPlayerProps(game, player.seatIndex)
            BroadcastGame(game)
            processWaitingPlayers(game)
            return true
        end
    end
    return false
end

local function openSetup(game, source)
    local decks = {}
    for deckName in pairs(ConfigProps.Cards.cardEndings) do
        if ConfigProps.Cards.DeckEndings[deckName] then decks[#decks + 1] = deckName end
    end
    table.sort(decks, function(a, b)
        return ConfigProps.Cards.NUIOrder[a] < ConfigProps.Cards.NUIOrder[b]
    end)

    game.setupSource = source
    game.setupSteps = steps((Config.TableSetupTimeoutSeconds * 1000) + Config.TableSetupLatencyMs)
    TriggerClientEvent("nt_holdem:client:setupTable", source, {
        tableId = game.locationID,
        tableLabel = game.config.Label or game.locationID,
        stakes = Config.Stakes,
        decks = decks,
        enableNPC = Config.EnableNPC,
        forceNPC = Config.ForceNPC,
        timeoutSeconds = Config.TableSetupTimeoutSeconds,
    })
    BroadcastTables()
end

removeGame = function(game, message)
    if ServerData.Games[game.locationID] ~= game then return end

    if game.setupSource then
        TriggerClientEvent("nt_holdem:client:entryClosed", game.setupSource, message)
    end
    for source in pairs(game.waitingPlayers) do
        TriggerClientEvent("nt_holdem:client:entryClosed", source, message)
    end
    for source in pairs(game.joinOffers) do
        TriggerClientEvent("nt_holdem:client:entryClosed", source, message)
    end
    for viewerSource in pairs(game.viewers) do
        ServerData.ViewerLocations[viewerSource] = nil
        TriggerClientEvent("nt_holdem:client:stopGameView", viewerSource, game.locationID)
    end
    game.viewers = {}

    RemoveGameData(game.locationID, game)
    BroadcastTables()
end

requestNpcPlayers = function(game)
    if game.state ~= "WAITING" or not game.allowNpcs or game.npcRequestID or game.realPlayerCount == 0
        or next(game.waitingPlayers) or next(game.joinOffers) then return end

    local target = math.min(tonumber(ConfigNPC.MaxAtTable) or 4,
        (game.config.MaxPlayers or 6) - game.realPlayerCount)
    local remainingThisRound = (tonumber(ConfigNPC.MaxJoinPerHand) or 2) - game.npcJoinsThisRound
    local needed = math.min(target - game.npcCount, remainingThisRound)
    if needed <= 0 then return end

    local realPlayers = {}
    local usedCombinations = {}
    for _, player in pairs(game.players) do
        if player.isNpc then
            usedCombinations[#usedCombinations + 1] = player.npcAppearance
        else
            realPlayers[#realPlayers + 1] = player.source
        end
    end
    if #realPlayers == 0 then return end

    local requestSource = realPlayers[math.random(1, #realPlayers)]
    ServerData.NextNpcID = ServerData.NextNpcID + 1
    local requestID = ("%s:%d"):format(game.locationID, ServerData.NextNpcID)
    ServerData.PendingNpcRequests[requestID] = {
        locationID = game.locationID,
        game = game,
        requestedFrom = requestSource,
    }
    game.npcRequestID = requestID

    TriggerClientEvent("nt_holdem:client:requestNpcAppearances", requestSource, requestID,
        game.locationID, game.config.PolyZone, needed, usedCombinations)
end

local function takeMoney(game, player, amount, reason)
    if not player or game.players[player.key] ~= player then return false end
    if player.isNpc then
        if player.cash < amount then return false end
        player.cash = player.cash - amount
        return true
    end
    return Framework.removeMoney(player.source, amount, reason)
end

local function awardMoney(game, player, amount)
    if not player or game.players[player.key] ~= player then return false end
    if player.isNpc then
        player.cash = player.cash + amount
        return true
    end
    return Framework.addMoney(player.source, amount, "holdem-payout")
end

function QueueGameCommand(game, command)
    if not game or ServerData.Games[game.locationID] ~= game or type(command) ~= "table" then return false end
    command.game = game
    command.player = command.source and findPlayer(game, command.source) or nil
    game.commands[#game.commands + 1] = command
    return true
end

local function handleJoinTable(game, command)
    local source = command.source
    if ServerData.EntryLocations[source] ~= game.locationID or ServerData.PlayerLocations[source]
        or not isNearTable(source, game.locationID) or not validPlayerCoords(game, command.playerCoords) then
        ServerData.EntryLocations[source] = nil
        if game.realPlayerCount == 0 and not game.stakeName then
            removeGame(game, "You cannot join this table.")
        else
            TriggerClientEvent("nt_holdem:client:entryClosed", source, "You cannot join this table.")
        end
        return
    end

    if game.state == "SETUP" then
        if game.setupSource == source then
            openSetup(game, source)
        else
            ServerData.EntryLocations[source] = nil
            TriggerClientEvent("nt_holdem:client:entryClosed", source,
                "Table not ready. A player is currently choosing the table settings.")
        end
        return
    end

    if game.joinOffers[source] then
        TriggerClientEvent("nt_holdem:client:joinDetails", source, tableSettings(game))
        return
    end
    if game.waitingPlayers[source] then
        TriggerClientEvent("nt_holdem:client:tableFull", source, {
            tableId = game.locationID,
            tableLabel = game.config.Label or game.locationID,
        })
        return
    end

    local available = (game.config.MaxPlayers or 6) - game.playerCount - offerCount(game)
    if available > 0 then
        game.joinOffers[source] = true
        TriggerClientEvent("nt_holdem:client:joinDetails", source, tableSettings(game))
        return
    end

    addWaitingPlayer(game, source)
    removeNpcForWaitingPlayer(game)
    if not game.joinOffers[source] then
        TriggerClientEvent("nt_holdem:client:tableFull", source, {
            tableId = game.locationID,
            tableLabel = game.config.Label or game.locationID,
        })
    end
end

local function handleConfigureTable(game, command)
    local source = command.source
    if game.state ~= "SETUP" or game.setupSource ~= source or ServerData.EntryLocations[source] ~= game.locationID
        or ServerData.PlayerLocations[source] then return end

    if not Config.Stakes[command.stakeName] or not ConfigProps.Cards.cardEndings[command.deckName]
        or not ConfigProps.Cards.DeckEndings[command.deckName] then
        removeGame(game, "Invalid table settings. Hold Join to try again.")
        return
    end

    if not isNearTable(source, game.locationID) or not validPlayerCoords(game, command.playerCoords) then
        removeGame(game, "You moved too far away from the table.")
        return
    end

    game.stakeName = command.stakeName
    game.deckName = command.deckName
    game.allowNpcs = Config.ForceNPC or (Config.EnableNPC and command.allowNpcs)
    game.setupSource = nil
    game.setupSteps = nil
    game.state = "WAITING"

    if not seatPlayer(game, source, command.playerCoords, command.isMale) then
        removeGame(game, "The table could not be started.")
        return
    end
    requestNpcPlayers(game)
end

local function handleConfirmJoin(game, command)
    local source = command.source
    if ServerData.PlayerLocations[source] or ServerData.EntryLocations[source] ~= game.locationID
        or not game.stakeName or not game.joinOffers[source] then return end

    if not isNearTable(source, game.locationID) or not validPlayerCoords(game, command.playerCoords) then
        removeEntryPlayer(game, source)
        TriggerClientEvent("nt_holdem:client:entryClosed", source, "You moved too far away from the table.")
        processWaitingPlayers(game)
        return
    end

    if not seatPlayer(game, source, command.playerCoords, command.isMale) then
        game.joinOffers[source] = nil
        addWaitingPlayer(game, source)
        TriggerClientEvent("nt_holdem:client:tableFull", source, {
            tableId = game.locationID,
            tableLabel = game.config.Label or game.locationID,
        })
    end
    processWaitingPlayers(game)
end

local function handleCancelEntry(game, command)
    local source = command.source
    if game.state == "SETUP" and game.setupSource == source then
        removeGame(game)
        return
    end

    removeEntryPlayer(game, source)
    processWaitingPlayers(game)
    requestNpcPlayers(game)
end

local function handleNpcAppearances(game, command)
    local pending = ServerData.PendingNpcRequests[command.requestID]
    if not pending or pending.game ~= game or pending.requestedFrom ~= command.source
        or game.npcRequestID ~= command.requestID then return end

    ServerData.PendingNpcRequests[command.requestID] = nil
    game.npcRequestID = nil
    if game.state ~= "WAITING" or not game.allowNpcs or game.realPlayerCount == 0
        or next(game.waitingPlayers) or next(game.joinOffers) then return end

    local used = {}
    for _, player in pairs(game.players) do
        if player.isNpc and player.npcAppearance then
            used[tostring(player.npcAppearance.model) .. ":" .. tostring(player.npcAppearance.outfit)] = true
        end
    end

    local target = math.min(game.npcCount + (tonumber(ConfigNPC.MaxJoinPerHand) or 2) - game.npcJoinsThisRound,
        tonumber(ConfigNPC.MaxAtTable) or 4,
        (game.config.MaxPlayers or 6) - game.realPlayerCount)

    for _, appearance in ipairs(command.appearances) do
        if game.npcCount >= target then break end
        local model = tonumber(appearance.model)
        local outfit = tonumber(appearance.outfit)
        local gender = appearance.gender
        local combination = tostring(model) .. ":" .. tostring(outfit)
        local seatIndex = randomFreeSeat(game)
        local namePool = {}
        for _, name in ipairs(ConfigNPC.Name[gender] or {}) do
            local nameUsed = false
            for _, player in pairs(game.players) do
                if player.isNpc and player.gender == gender and player.name == name then
                    nameUsed = true
                    break
                end
            end
            if not nameUsed then namePool[#namePool + 1] = name end
        end

        if model and outfit and outfit >= 0 and #namePool > 0 and seatIndex and not used[combination] then
            used[combination] = true
            ServerData.NextNpcID = ServerData.NextNpcID + 1
            local playerKey = ("npc:%s:%d"):format(game.locationID, ServerData.NextNpcID)
            local startingCash = Config.Stakes[game.stakeName].allIn * math.random(1, 3)
            local player = {
                key = playerKey,
                source = playerKey,
                npcId = playerKey,
                npcAppearance = { model = model, outfit = outfit, gender = gender },
                gender = gender,
                name = namePool[math.random(1, #namePool)],
                personality = ConfigNPC.PersonalityNames[math.random(1, #ConfigNPC.PersonalityNames)],
                cash = startingCash,
                startingCash = startingCash,
                seatIndex = seatIndex,
                isNpc = true,
                waiting = false,
                inHand = false,
                allIn = false,
                folded = false,
                holeCards = {},
                streetBet = 0,
                totalBet = 0,
                cardState = "none",
                visuals = { showPlayerChips = true },
            }
            game.players[playerKey] = player
            game.seats[seatIndex] = playerKey
            game.playerCount = game.playerCount + 1
            game.npcCount = game.npcCount + 1
            game.npcJoinsThisRound = game.npcJoinsThisRound + 1
        end
    end

    BroadcastGame(game)
end

local function currentAction(game, command)
    local player = command.player
    if not player or game.players[player.key] ~= player or player.actionLocked
        or game.handID ~= command.handID or game.currentPlayerKey ~= player.key
        or not game.state:match("^BET_") then return nil end
    return player
end

local function startPlayerAction(game, player, actionName, showBetAfter)
    player.actionLocked = true
    game.actionToken = game.actionToken + 1
    game.actionSteps = nil
    game.deadline = nil
    game.flow = "PLAYER_ACTION_FINISH"
    game.flowPlayerKey = player.key
    game.flowPlayer = player
    game.flowShowBet = showBetAfter == true
    broadcastPlayerAnimation(game, player, actionName)
    game.waitSteps = steps(ConfigAnim.Actions[player.gender][actionName].Duration)
end

local function handleCheck(game, command)
    local player = currentAction(game, command)
    if not player or player.streetBet ~= game.currentBet then return end
    player.acted = true
    BroadcastGame(game)
    startPlayerAction(game, player, "check", false)
end

local function handleCall(game, command)
    local player = currentAction(game, command)
    if not player then return end
    local amount = math.min(
        math.max(0, game.currentBet - player.streetBet),
        Config.Stakes[game.stakeName].allIn - player.totalBet,
        playerCash(player)
    )
    if amount <= 0 or not takeMoney(game, player, amount, "holdem-call") then return end

    player.streetBet = player.streetBet + amount
    player.totalBet = player.totalBet + amount
    player.allIn = player.totalBet >= Config.Stakes[game.stakeName].allIn or playerCash(player) <= 0
    player.acted = true
    game.betAboveAnte = true
    game.pot = game.pot + amount
    BroadcastGame(game)
    startPlayerAction(game, player, player.allIn and "allin" or "bet", true)
end

local function handleRaise(game, command)
    local player = currentAction(game, command)
    if not player then return end

    local amount = command.amount
    local amountToCall = math.max(0, game.currentBet - player.streetBet)
    local increment = Config.Stakes[game.stakeName].betIncrement
    local maximumAmount = math.min(
        math.max(0, Config.Stakes[game.stakeName].allIn - player.totalBet),
        playerCash(player)
    )
    local incrementCount = amount and (amount - amountToCall) / increment or 0
    local regularRaise = amount and amount >= amountToCall + increment
        and math.abs(incrementCount - math.floor(incrementCount + 0.5)) <= 0.0001
    local finalAllIn = amount and amount == maximumAmount and amount > amountToCall
    if not amount or amount > maximumAmount or (not regularRaise and not finalAllIn)
        or not takeMoney(game, player, amount, "holdem-raise") then return end

    player.streetBet = player.streetBet + amount
    player.totalBet = player.totalBet + amount
    player.allIn = player.totalBet >= Config.Stakes[game.stakeName].allIn or playerCash(player) <= 0
    player.acted = true
    game.currentBet = player.streetBet
    game.betAboveAnte = true
    game.pot = game.pot + amount
    for _, other in ipairs(activePlayers(game)) do
        if other.key ~= player.key then other.acted = false end
    end
    BroadcastGame(game)
    startPlayerAction(game, player, player.allIn and "allin" or "bet", true)
end

local function handleFold(game, command)
    local player = currentAction(game, command)
    if not player then return end
    player.folded = true
    player.cardState = "folded"
    player.acted = true
    BroadcastGame(game)
    startPlayerAction(game, player, "fold", false)
end

local function removePlayer(game, player, dropped)
    local seatIndex = player.seatIndex
    local wasCurrent = game.currentPlayerKey == player.key
    local wasInHand = player.inHand and not player.folded

    if game.npcRequestID then
        local pending = ServerData.PendingNpcRequests[game.npcRequestID]
        if pending and pending.requestedFrom == player.source then
            ServerData.PendingNpcRequests[game.npcRequestID] = nil
            game.npcRequestID = nil
        end
    end

    if wasInHand then player.folded = true end
    game.actionToken = game.actionToken + 1
    game.players[player.key] = nil
    game.seats[seatIndex] = nil
    game.playerCount = game.playerCount - 1
    game.realPlayerCount = game.realPlayerCount - 1
    ServerData.PlayerLocations[player.source] = nil

    local interruptedPlayerAction = game.flow == "PLAYER_ACTION_FINISH" and game.flowPlayer == player
    if interruptedPlayerAction then
        game.flow = nil
        game.flowPlayer = nil
        game.flowPlayerKey = nil
        game.waitSteps = 0
    end
    if wasCurrent then
        game.currentPlayerKey = nil
        game.currentSeat = nil
        game.actionSteps = nil
        game.deadline = nil
    end

    if not dropped then TriggerClientEvent("nt_holdem:client:leftTable", player.source) end
    cleanupPlayerProps(game, seatIndex)

    if game.realPlayerCount == 0 then
        removeGame(game, "The table was closed.")
        return
    end

    BroadcastGame(game)
    processWaitingPlayers(game)
    requestNpcPlayers(game)

    if game.state:match("^BET_") and (wasInHand or wasCurrent) then
        if #activePlayers(game) == 1 then
            resolveSingleWinner(game)
        elseif wasCurrent or interruptedPlayerAction then
            advanceAfterAction(game, seatIndex, true)
        end
    elseif wasInHand and #activePlayers(game) == 1 then
        resolveSingleWinner(game)
    end
end

local function handleLeave(game, command)
    local player = command.player
    if player and game.players[player.key] == player then
        removePlayer(game, player, command.dropped)
        return
    end

    removeEntryPlayer(game, command.source)
    if game.state == "SETUP" and game.setupSource == command.source then
        removeGame(game)
    else
        processWaitingPlayers(game)
        requestNpcPlayers(game)
    end
end

function ProcessGameCommands(game)
    while game.commands[1] and ServerData.Games[game.locationID] == game do
        local command = table.remove(game.commands, 1)
        if command.game == game then
            if command.type == "joinTable" then
                handleJoinTable(game, command)
            elseif command.type == "configureTable" then
                handleConfigureTable(game, command)
            elseif command.type == "confirmJoin" then
                handleConfirmJoin(game, command)
            elseif command.type == "cancelEntry" then
                handleCancelEntry(game, command)
            elseif command.type == "npcAppearances" then
                handleNpcAppearances(game, command)
            elseif command.type == "check" then
                handleCheck(game, command)
            elseif command.type == "call" then
                handleCall(game, command)
            elseif command.type == "raise" then
                handleRaise(game, command)
            elseif command.type == "fold" then
                handleFold(game, command)
            elseif command.type == "leave" then
                handleLeave(game, command)
            end
        end
    end
end

function ProcessGameTimers(game)
    if game.waitSteps and game.waitSteps > 0 then game.waitSteps = game.waitSteps - 1 end
    if game.setupSteps and game.setupSteps > 0 then game.setupSteps = game.setupSteps - 1 end
    if game.startSteps and game.startSteps > 0 then game.startSteps = game.startSteps - 1 end
    if game.actionSteps and game.actionSteps > 0 then game.actionSteps = game.actionSteps - 1 end

    for _, player in pairs(game.players) do
        if player.joinStartSteps and player.joinStartSteps > 0 then
            player.joinStartSteps = player.joinStartSteps - 1
            if player.joinStartSteps == 0 and game.players[player.key] == player then
                player.joinStartSteps = nil
                broadcastPlayerAnimation(game, player, "join")
                player.joinVisualSteps = steps(ConfigAnim.Actions[player.gender].join.Duration * 0.80)
                player.joinFinishSteps = steps(ConfigAnim.Actions[player.gender].join.Duration)
            end
        end
        if player.joinVisualSteps and player.joinVisualSteps > 0 then
            player.joinVisualSteps = player.joinVisualSteps - 1
            if player.joinVisualSteps == 0 then
                player.joinVisualSteps = nil
                player.visuals.showPlayerChips = true
                BroadcastGame(game)
            end
        end
        if player.joinFinishSteps and player.joinFinishSteps > 0 then
            player.joinFinishSteps = player.joinFinishSteps - 1
            if player.joinFinishSteps == 0 then
                player.joinFinishSteps = nil
                scheduleHand(game)
            end
        end
    end
end

local function collectBets(game)
    for _, player in ipairs(orderedPlayers(game, true)) do
        player.anteVisible = false
        player.playerBet = false
    end
    forEachGameClient(game, function(observerSource)
        TriggerClientEvent("nt_holdem:client:cleanupBettingProps", observerSource, game.locationID)
    end)
    game.potVisible = game.pot > 0
    BroadcastGame(game)
end

local function bettingComplete(game)
    for _, player in ipairs(activePlayers(game)) do
        if not player.allIn and (not player.acted or player.streetBet ~= game.currentBet) then return false end
    end
    return true
end

local function allPlayersAllIn(game)
    local players = activePlayers(game)
    if #players < 2 then return false end
    for _, player in ipairs(players) do
        if not player.allIn then return false end
    end
    return true
end

local function startActionTimer(game, player)
    game.actionToken = game.actionToken + 1
    if player.isNpc then
        game.actionSteps = steps(math.random(ConfigNPC.ActionDelayMs.Min, ConfigNPC.ActionDelayMs.Max))
        game.deadline = nil
    else
        game.actionSteps = steps(Config.ActionTimeoutSeconds * 1000)
        game.deadline = os.time() + Config.ActionTimeoutSeconds
    end
end

beginBettingRound = function(game, street)
    game.state = "BET_" .. street
    game.currentBet = street == "PREFLOP" and Config.Stakes[game.stakeName].bigBlind or 0
    for _, player in ipairs(activePlayers(game)) do
        if street ~= "PREFLOP" then player.streetBet = 0 end
        player.acted = false
        player.actionLocked = false
    end

    local firstPlayer = nextActionPlayer(game, street == "PREFLOP" and game.bigBlindSeat or game.dealerSeat)
    game.currentPlayerKey = firstPlayer and firstPlayer.key or nil
    game.currentSeat = firstPlayer and firstPlayer.seatIndex or nil
    game.flow = nil
    game.waitSteps = 0
    BroadcastGame(game)
    if firstPlayer then
        startActionTimer(game, firstPlayer)
    else
        advanceAfterAction(game, game.dealerSeat, true)
    end
end

local function finishHand(game)
    for _, player in pairs(game.players) do
        if player.isNpc then
            if player.cash <= 0 then
                player.leaveAfterHand = true
            else
                local personality = ConfigNPC.Personalities[player.personality]
                if player.cash <= player.startingCash * personality.CutLossEarly.Amount
                    and math.random(1, 100) <= personality.CutLossEarly.Chance then
                    player.leaveAfterHand = true
                elseif player.cash >= player.startingCash * personality.LeaveWithWinnings.Amount
                    and math.random(1, 100) <= personality.LeaveWithWinnings.Chance then
                    player.leaveAfterHand = true
                end
            end
        end
    end

    game.actionToken = game.actionToken + 1
    game.currentPlayerKey = nil
    game.currentSeat = nil
    game.actionSteps = nil
    game.deadline = nil
    game.state = "BETWEEN_HANDS"
    game.flow = "HAND_CLEANUP"
    game.waitSteps = steps(Config.BetweenHandsWaitMs)
end

local function settleShowdown(game)
    game.state = "SHOWDOWN"
    game.currentPlayerKey = nil
    game.currentSeat = nil
    game.actionSteps = nil
    game.deadline = nil

    local contenders = activePlayers(game)
    local winners = {}
    local bestScore
    for _, player in ipairs(contenders) do
        local score, name = HoldemCards.evaluate(player.holeCards, game.communityCards)
        player.result = name
        player.cardState = "shown"
        local comparison = bestScore and HoldemCards.compare(score, bestScore) or 1
        if comparison > 0 then
            winners = { player }
            bestScore = score
        elseif comparison == 0 then
            winners[#winners + 1] = player
        end
    end

    local share = #winners > 0 and game.pot / #winners or 0
    game.winners = {}
    game.flowWinners = {}
    for _, winner in ipairs(winners) do
        awardMoney(game, winner, share)
        local handName = winner.result or "Winner"
        winner.result = handName .. (" - wins $%g"):format(share)
        game.winners[#game.winners + 1] = {
            source = winner.source,
            name = winner.name,
            amount = share,
            hand = handName,
        }
        game.flowWinners[#game.flowWinners + 1] = winner.key
    end

    game.pot = 0
    game.potVisible = true
    BroadcastGame(game)
    for _, player in ipairs(contenders) do
        broadcastPlayerAnimation(game, player, "reveal")
    end
    game.flow = "SHOWDOWN_WIN"
    game.waitSteps = steps(ConfigAnim.Actions[contenders[1].gender].reveal.Duration + Config.ShowWinDelay)
end

resolveSingleWinner = function(game)
    local contenders = activePlayers(game)
    if #contenders ~= 1 then return false end

    collectBets(game)
    local winner = contenders[1]
    local amount = game.pot
    awardMoney(game, winner, amount)
    winner.result = ("Wins $%g"):format(amount)
    game.winners = { { source = winner.source, name = winner.name, amount = amount } }
    game.pot = 0
    game.potVisible = true
    game.state = "SHOWDOWN"
    game.currentPlayerKey = nil
    game.currentSeat = nil
    game.actionSteps = nil
    game.deadline = nil
    BroadcastGame(game)
    broadcastPlayerAnimation(game, winner, "win")
    finishHand(game)
    return true
end

local function startCommunityCards(game, street, count, animationName)
    collectBets(game)
    game.state = street
    game.flowStreet = street
    game.flowCardCount = count
    game.flowCardIndex = 1
    game.flowAnimation = animationName
    game.flowDealer = playerAtSeat(game, game.dealerSeat)
    game.flowDealerHeldCards = game.flowDealer and game.flowDealer.cardState == "held" or false

    if game.flowDealerHeldCards then
        game.flowDealer.cardState = "table_down"
        BroadcastGame(game)
    end

    HoldemCards.draw(game)
    game.deckOnTable = false
    BroadcastGame(game)
    broadcastPlayerAnimation(game, game.flowDealer, animationName)

    local action = ConfigAnim.Actions[game.flowDealer.gender][animationName]
    game.flowElapsedMilliseconds = math.floor(action.Duration * action.DealCardsAt[1])
    game.flow = "COMMUNITY_DRAW"
    game.waitSteps = steps(game.flowElapsedMilliseconds)
end

local function advanceStreet(game)
    if game.state == "BET_PREFLOP" then
        startCommunityCards(game, "FLOP", 3, "flop")
    elseif game.state == "BET_FLOP" or (game.allInRunout and game.state == "FLOP") then
        startCommunityCards(game, "TURN", 1, "turn")
    elseif game.state == "BET_TURN" or (game.allInRunout and game.state == "TURN") then
        startCommunityCards(game, "RIVER", 1, "river")
    else
        collectBets(game)
        settleShowdown(game)
    end
end

advanceAfterAction = function(game, seatIndex, forceAdvance)
    game.actionToken = game.actionToken + 1
    game.actionSteps = nil
    game.deadline = nil

    if resolveSingleWinner(game) then return end
    if allPlayersAllIn(game) then
        game.allInRunout = true
        for _, player in ipairs(activePlayers(game)) do player.cardState = "shown" end
        BroadcastGame(game)
        advanceStreet(game)
        return
    end
    if bettingComplete(game) then
        advanceStreet(game)
        return
    end

    if not forceAdvance and game.currentPlayerKey and game.players[game.currentPlayerKey] then
        BroadcastGame(game)
        return
    end

    local nextPlayer = nextActionPlayer(game, seatIndex)
    if not nextPlayer then return end
    game.currentPlayerKey = nextPlayer.key
    game.currentSeat = nextPlayer.seatIndex
    startActionTimer(game, nextPlayer)
    BroadcastGame(game)
end

local function cancelHand(game, message)
    for _, player in ipairs(orderedPlayers(game, true)) do
        if player.totalBet > 0 then awardMoney(game, player, player.totalBet) end
        player.result = message
    end
    game.pot = 0
    BroadcastGame(game)
    finishHand(game)
end

beginHand = function(game)
    game.handID = game.handID + 1
    game.deck = HoldemCards.newDeck()
    game.nextCardIndex = 1
    game.communityCards = {}
    game.pot = 0
    game.potVisible = false
    game.betAboveAnte = false
    game.allInRunout = false
    game.deckOnTable = false
    game.currentBet = 0
    game.currentPlayerKey = nil
    game.currentSeat = nil
    game.winners = nil
    game.actionToken = game.actionToken + 1
    game.smallBlindSeat = nil
    game.bigBlindSeat = nil
    game.state = "BLINDS"
    game.deadline = nil
    game.startSteps = nil

    for _, player in ipairs(orderedPlayers(game)) do
        player.waiting = false
        player.inHand = true
        player.folded = false
        player.anteVisible = false
        player.playerBet = false
        player.cardState = "none"
        player.holeCards = {}
        player.streetBet = 0
        player.totalBet = 0
        player.acted = false
        player.allIn = false
        player.actionLocked = false
        player.result = nil
        player.npcConfidence = nil
        player.npcConfidenceDetails = nil
    end

    local bigBlind = Config.Stakes[game.stakeName].bigBlind
    for _, player in ipairs(orderedPlayers(game, true)) do
        if player.isNpc and player.cash < bigBlind then
            player.inHand = false
            player.leaveAfterHand = true
            player.result = "Cannot afford the big blind"
        elseif not player.isNpc and not Framework.hasMoney(player.source, bigBlind) then
            player.inHand = false
            player.result = "Cannot afford the big blind"
            notify(player.source, "You cannot afford the big blind.", "error")
        end
    end

    if #orderedPlayers(game, true) < 2 then
        cancelHand(game, "Hand cancelled")
        return
    end

    game.dealerSeat = nextOccupiedSeat(game, game.lastDealerSeat, true)
    game.lastDealerSeat = game.dealerSeat
    if #activePlayers(game) == 2 then
        game.smallBlindSeat = game.dealerSeat
    else
        game.smallBlindSeat = nextActivePlayer(game, game.dealerSeat).seatIndex
    end
    game.bigBlindSeat = nextActivePlayer(game, game.smallBlindSeat).seatIndex
    BroadcastGame(game)
    game.flow = "SMALL_BLIND_START"
    game.waitSteps = 0
end

local function startAutomaticAction(game)
    local player = game.currentPlayerKey and game.players[game.currentPlayerKey] or nil
    if not player or player.actionLocked or not game.state:match("^BET_") then return end

    local amount = math.max(0, game.currentBet - player.streetBet)
    if player.isNpc then
        local confidence, details = NPCConfidence.calculate(game, player)
        local personality = ConfigNPC.Personalities[player.personality]
        local actions = allowedActions(game, player)
        player.npcConfidence = confidence
        player.npcConfidenceDetails = details

        local wantsRaise = false
        if confidence >= personality.RaiseConfidence then
            wantsRaise = math.random(1, 100) <= personality.RaiseChance
                and math.random(1, 100) > personality.SlowPlayChance
        elseif confidence < personality.CallConfidence then
            wantsRaise = math.random(1, 100) <= personality.BluffChance
        end

        local raised = false
        if wantsRaise and actions.raise then
            local increment = Config.Stakes[game.stakeName].betIncrement
            local potPercent = math.random(
                math.floor(personality.RaisePot.Min * 100),
                math.floor(personality.RaisePot.Max * 100)
            ) / 100
            local raiseExtra = math.max(increment,
                math.floor(game.pot * potPercent / increment + 0.5) * increment)
            local raiseAmount = amount + raiseExtra
            raiseAmount = math.min(raiseAmount, actions.maximumAmount)

            if raiseAmount >= actions.maximumAmount and confidence < personality.AllInConfidence then
                local availableIncrements = math.floor((actions.maximumAmount - amount) / increment)
                if availableIncrements >= 2 then
                    raiseAmount = amount + (availableIncrements - 1) * increment
                else
                    raiseAmount = nil
                end
            end

            if raiseAmount then
                handleRaise(game, {
                    player = player,
                    handID = game.handID,
                    amount = raiseAmount,
                })
                raised = true
            end
        end

        if not raised then
            local callChance = math.max(0, math.min(100,
                details.wagerChance + confidence - personality.CallConfidence))
            player.npcConfidenceDetails.callChance = callChance
            if amount > 0 and actions.call and math.random(1, 100) <= callChance then
                handleCall(game, { player = player, handID = game.handID })
            elseif amount == 0 then
                handleCheck(game, { player = player, handID = game.handID })
            else
                handleFold(game, { player = player, handID = game.handID })
            end
        end
    elseif amount == 0 then
        player.acted = true
        startPlayerAction(game, player, "check", false)
    else
        player.folded = true
        player.cardState = "folded"
        player.acted = true
        BroadcastGame(game)
        startPlayerAction(game, player, "fold", false)
        notify(player.source, "You folded when the action timer expired.", "error")
    end
end

local function cleanupHand(game)
    local removedSeats = {}
    for playerKey, player in pairs(game.players) do
        if player.isNpc and player.leaveAfterHand then
            removedSeats[#removedSeats + 1] = player.seatIndex
            game.players[playerKey] = nil
            game.seats[player.seatIndex] = nil
            game.playerCount = game.playerCount - 1
            game.npcCount = game.npcCount - 1
        end
    end
    for _, seatIndex in ipairs(removedSeats) do cleanupPlayerProps(game, seatIndex) end

    forEachGameClient(game, function(observerSource)
        TriggerClientEvent("nt_holdem:client:cleanupEndProps", observerSource, game.locationID)
    end)

    game.state = "WAITING"
    game.communityCards = {}
    game.deck = {}
    game.nextCardIndex = 1
    game.deckOnTable = false
    game.potVisible = false
    game.betAboveAnte = false
    game.allInRunout = false
    game.winners = nil
    game.flowWinners = nil
    game.npcJoinsThisRound = 0
    game.flow = nil
    game.waitSteps = 0

    for _, player in pairs(game.players) do
        player.waiting = false
        player.inHand = false
        player.folded = false
        player.holeCards = {}
        player.anteVisible = false
        player.playerBet = false
        player.cardState = "none"
        player.streetBet = 0
        player.totalBet = 0
        player.actionLocked = false
        player.allIn = false
        player.result = nil
        player.npcConfidence = nil
        player.npcConfidenceDetails = nil
        broadcastPlayerAnimation(game, player, "reset")
    end

    BroadcastGame(game)
    processWaitingPlayers(game)
    requestNpcPlayers(game)
    scheduleHand(game)
end

function ProcessGameState(game)
    if game.waitSteps and game.waitSteps > 0 then return end

    if game.state == "SETUP" then
        if game.setupSteps == 0 then
            removeGame(game, "Table setup timed out. Hold Join to try again.")
        end
        return
    end

    if game.flow == "SMALL_BLIND_START" then
        local player = playerAtSeat(game, game.smallBlindSeat)
        local amount = Config.Stakes[game.stakeName].smallBlind
        if not takeMoney(game, player, amount, "holdem-small-blind") then
            if player and not player.isNpc then
                notify(player.source, "You cannot afford the small blind.", "error")
            end
            cancelHand(game, "Hand cancelled")
            return
        end
        player.streetBet = amount
        player.totalBet = amount
        player.allIn = player.totalBet >= Config.Stakes[game.stakeName].allIn or playerCash(player) <= 0
        game.pot = game.pot + amount
        BroadcastGame(game)
        broadcastPlayerAnimation(game, player, "blind")
        game.flow = "SMALL_BLIND_FINISH"
        game.waitSteps = steps(ConfigAnim.Actions[player.gender].blind.Duration)
        return
    end

    if game.flow == "SMALL_BLIND_FINISH" then
        local player = playerAtSeat(game, game.smallBlindSeat)
        if player then
            player.anteVisible = true
            BroadcastGame(game)
        end
        game.flow = "BIG_BLIND_START"
        return
    end

    if game.flow == "BIG_BLIND_START" then
        local player = playerAtSeat(game, game.bigBlindSeat)
        local amount = Config.Stakes[game.stakeName].bigBlind
        if not takeMoney(game, player, amount, "holdem-big-blind") then
            if player and not player.isNpc then
                notify(player.source, "You cannot afford the big blind.", "error")
            end
            cancelHand(game, "Hand cancelled")
            return
        end
        player.streetBet = amount
        player.totalBet = amount
        player.allIn = player.totalBet >= Config.Stakes[game.stakeName].allIn or playerCash(player) <= 0
        game.pot = game.pot + amount
        BroadcastGame(game)
        broadcastPlayerAnimation(game, player, "blind")
        game.flow = "BIG_BLIND_FINISH"
        game.waitSteps = steps(ConfigAnim.Actions[player.gender].blind.Duration)
        return
    end

    if game.flow == "BIG_BLIND_FINISH" then
        local player = playerAtSeat(game, game.bigBlindSeat)
        if player then player.anteVisible = true end
        game.state = "DEALING"
        BroadcastGame(game)
        local dealer = playerAtSeat(game, game.dealerSeat)
        broadcastPlayerAnimation(game, dealer, "shuffle")
        game.flow = "DEAL_OPENING_START"
        game.waitSteps = steps(ConfigAnim.Actions[dealer.gender].shuffle.Duration)
        return
    end

    if game.flow == "DEAL_OPENING_START" then
        game.flowCardRound = 1
        game.flowCardsDealt = 0
        game.flowSeat = game.dealerSeat
        game.flow = "DEAL_CARD_START"
        return
    end

    if game.flow == "DEAL_CARD_START" then
        local player = nextActivePlayer(game, game.flowSeat)
        if not player then
            cancelHand(game, "Hand cancelled")
            return
        end
        game.flowPlayer = player
        game.flowSeat = player.seatIndex
        local dealer = playerAtSeat(game, game.dealerSeat)
        if player.seatIndex ~= game.dealerSeat then
            local animationName = ("%sto%s"):format(game.dealerSeat, player.seatIndex)
            broadcastPlayerAnimation(game, dealer, "deal", animationName)
        end
        game.flow = "DEAL_CARD_DRAW"
        game.waitSteps = steps(ConfigAnim.Actions[dealer.gender].deal.Duration
            * ConfigAnim.Actions[dealer.gender].deal.DealCardAt)
        return
    end

    if game.flow == "DEAL_CARD_DRAW" then
        local player = game.flowPlayer
        if not player or game.players[player.key] ~= player or not player.inHand then
            game.flow = "DEAL_CARD_START"
            return
        end
        player.holeCards[#player.holeCards + 1] = HoldemCards.draw(game)
        player.cardState = "table_down"
        BroadcastGame(game)
        game.flow = "DEAL_CARD_FINISH"
        local dealer = playerAtSeat(game, game.dealerSeat)
        game.waitSteps = steps(ConfigAnim.Actions[dealer.gender].deal.Duration
            * (1.0 - ConfigAnim.Actions[dealer.gender].deal.DealCardAt))
        return
    end

    if game.flow == "DEAL_CARD_FINISH" then
        game.flowCardsDealt = game.flowCardsDealt + 1
        if game.flowCardsDealt >= #activePlayers(game) then
            if game.flowCardRound == 1 then
                game.flowCardRound = 2
                game.flowCardsDealt = 0
                game.flowSeat = game.dealerSeat
                game.flow = "DEAL_CARD_START"
            else
                game.deckOnTable = true
                BroadcastGame(game)
                local playerSources = {}
                for _, player in ipairs(activePlayers(game)) do
                    playerSources[#playerSources + 1] = player.source
                end
                forEachGameClient(game, function(observerSource)
                    TriggerClientEvent("nt_holdem:client:pickupAnimations", observerSource,
                        game.locationID, playerSources)
                end)
                game.flowPickupPlayer = activePlayers(game)[1]
                game.flow = "OPENING_PICKUP_ATTACH"
                game.waitSteps = steps(ConfigAnim.Actions[game.flowPickupPlayer.gender].pickup.Duration
                    * ConfigAnim.Actions[game.flowPickupPlayer.gender].pickup.AttachCardsAt)
            end
        else
            game.flow = "DEAL_CARD_START"
        end
        return
    end

    if game.flow == "OPENING_PICKUP_ATTACH" then
        for _, player in ipairs(activePlayers(game)) do player.cardState = "held" end
        BroadcastGame(game)
        game.flow = "OPENING_PICKUP_FINISH"
        game.waitSteps = steps(ConfigAnim.Actions[game.flowPickupPlayer.gender].pickup.Duration
            * (1.0 - ConfigAnim.Actions[game.flowPickupPlayer.gender].pickup.AttachCardsAt))
        return
    end

    if game.flow == "OPENING_PICKUP_FINISH" then
        game.flowPickupPlayer = nil
        beginBettingRound(game, "PREFLOP")
        return
    end

    if game.flow == "PLAYER_ACTION_FINISH" then
        local player = game.flowPlayer
        local seatIndex = player and player.seatIndex or game.currentSeat
        if player and game.players[player.key] == player then
            if game.flowShowBet then
                player.playerBet = true
                BroadcastGame(game)
            end
            player.actionLocked = false
        end
        game.flow = nil
        game.flowPlayer = nil
        game.flowPlayerKey = nil
        game.flowShowBet = nil
        advanceAfterAction(game, seatIndex, true)
        return
    end

    if game.flow == "COMMUNITY_DRAW" then
        game.communityCards[#game.communityCards + 1] = HoldemCards.draw(game)
        BroadcastGame(game)

        local action = ConfigAnim.Actions[game.flowDealer.gender][game.flowAnimation]
        local currentMarker = action.DealCardsAt[game.flowCardIndex]
        game.flowCardIndex = game.flowCardIndex + 1
        if game.flowCardIndex <= game.flowCardCount then
            local nextMarker = action.DealCardsAt[game.flowCardIndex]
            game.flow = "COMMUNITY_DRAW"
            game.waitSteps = steps(action.Duration * (nextMarker - currentMarker))
        else
            game.flow = "COMMUNITY_FINISH"
            game.waitSteps = steps(action.Duration * (1.0 - currentMarker))
        end
        return
    end

    if game.flow == "COMMUNITY_FINISH" then
        game.deckOnTable = true
        BroadcastGame(game)
        if game.flowDealerHeldCards and game.flowDealer and game.players[game.flowDealer.key] == game.flowDealer then
            broadcastPlayerAnimation(game, game.flowDealer, "pickup")
            game.flow = "COMMUNITY_PICKUP_ATTACH"
            game.waitSteps = steps(ConfigAnim.Actions[game.flowDealer.gender].pickup.Duration
                * ConfigAnim.Actions[game.flowDealer.gender].pickup.AttachCardsAt)
        elseif game.allInRunout then
            advanceStreet(game)
        else
            beginBettingRound(game, game.flowStreet)
        end
        return
    end

    if game.flow == "COMMUNITY_PICKUP_ATTACH" then
        if game.flowDealer and game.players[game.flowDealer.key] == game.flowDealer then
            game.flowDealer.cardState = "held"
            BroadcastGame(game)
        end
        game.flow = "COMMUNITY_PICKUP_FINISH"
        game.waitSteps = steps(ConfigAnim.Actions[game.flowDealer.gender].pickup.Duration
            * (1.0 - ConfigAnim.Actions[game.flowDealer.gender].pickup.AttachCardsAt))
        return
    end

    if game.flow == "COMMUNITY_PICKUP_FINISH" then
        if game.allInRunout then
            advanceStreet(game)
        else
            beginBettingRound(game, game.flowStreet)
        end
        return
    end

    if game.flow == "SHOWDOWN_WIN" then
        for _, playerKey in ipairs(game.flowWinners or {}) do
            local winner = game.players[playerKey]
            if winner then broadcastPlayerAnimation(game, winner, "win") end
        end
        local winner = game.players[game.flowWinners[1]]
        finishHand(game)
        return
    end

    if game.flow == "HAND_CLEANUP" then
        cleanupHand(game)
        return
    end

    if game.state == "WAITING" then
        processWaitingPlayers(game)
        requestNpcPlayers(game)

        if game.startSteps == 0 then
            beginHand(game)
            return
        end

        if not game.startSteps and game.realPlayerCount > 0 and game.playerCount >= 2 then
            local playerJoining = false
            for _, player in pairs(game.players) do
                if player.joinStartSteps or player.joinFinishSteps then
                    playerJoining = true
                    break
                end
            end
            if not playerJoining then scheduleHand(game) end
        end
        return
    end

    if game.state:match("^BET_") and not game.flow and game.actionSteps == 0 then
        startAutomaticAction(game)
    end
end
