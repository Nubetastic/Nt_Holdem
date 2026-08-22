ServerRunning = true

ServerData = {
    Games = {},
    PlayerLocations = {},
    ViewerLocations = {},
    EntryLocations = {},
    PendingNpcRequests = {},
    NextNpcID = 0,
}

function CreateGameData(locationID, source)
    if ServerData.Games[locationID] or not ConfigTables.Loc[locationID] then return nil end

    local game = {
        locationID = locationID,
        config = ConfigTables.Loc[locationID],

        state = "SETUP",
        handID = 0,
        actionToken = 0,

        setupSource = source,
        setupSteps = 0,

        players = {},
        viewers = {},
        seats = {},
        playerCount = 0,
        realPlayerCount = 0,
        npcCount = 0,

        stakeName = nil,
        deckName = nil,
        allowNpcs = nil,

        dealerSeat = nil,
        smallBlindSeat = nil,
        bigBlindSeat = nil,
        lastDealerSeat = 0,

        deck = {},
        nextCardIndex = 1,
        communityCards = {},

        pot = 0,
        currentBet = 0,
        currentPlayerKey = nil,
        currentSeat = nil,
        actionSteps = nil,
        deadline = nil,

        potVisible = false,
        betAboveAnte = false,
        deckOnTable = false,
        winners = nil,
        visuals = {},

        waitingPlayers = {},
        joinOffers = {},
        commands = {},
        nextQueueOrder = 0,

        npcRequestID = nil,
        npcJoinsThisRound = 0,

        startSteps = nil,
        waitSteps = 0,
        flow = nil,
    }

    ServerData.Games[locationID] = game
    return game
end

function RemoveGameData(locationID, game)
    if ServerData.Games[locationID] ~= game then return false end

    game.actionToken = game.actionToken + 1

    if game.npcRequestID then
        ServerData.PendingNpcRequests[game.npcRequestID] = nil
    end

    for _, player in pairs(game.players) do
        if not player.isNpc then
            ServerData.PlayerLocations[player.source] = nil
        end
    end

    for viewerSource in pairs(game.viewers) do
        if ServerData.ViewerLocations[viewerSource] == locationID then
            ServerData.ViewerLocations[viewerSource] = nil
        end
    end

    for source, entryLocationID in pairs(ServerData.EntryLocations) do
        if entryLocationID == locationID then
            ServerData.EntryLocations[source] = nil
        end
    end

    game.players = {}
    game.viewers = {}
    game.seats = {}
    game.waitingPlayers = {}
    game.joinOffers = {}
    game.commands = {}
    game.flow = nil

    ServerData.Games[locationID] = nil
    return true
end

local function queueForPlayer(source, command)
    local locationID = ServerData.PlayerLocations[source] or ServerData.EntryLocations[source]
    local game = locationID and ServerData.Games[locationID]
    if not game then return false end

    command.source = source
    return QueueGameCommand(game, command)
end

RegisterNetEvent("nt_holdem:server:requestTables", function()
    BroadcastTables(source)
end)

RegisterNetEvent("nt_holdem:server:setGameView", function(locationID)
    SetGameViewer(source, locationID and tostring(locationID) or nil)
end)

RegisterNetEvent("nt_holdem:server:joinTable", function(locationID, playerCoords, isMale)
    local source = source
    locationID = tostring(locationID or "")

    if ServerData.PlayerLocations[source] then return end
    if ServerData.EntryLocations[source] and ServerData.EntryLocations[source] ~= locationID then return end

    local location = ConfigTables.Loc[locationID]
    if not location or location.Enabled == false then return end

    local game = ServerData.Games[locationID]
    if not game then
        game = CreateGameData(locationID, source)
        if not game then return end
    end

    ServerData.EntryLocations[source] = locationID
    QueueGameCommand(game, { type = "joinTable", source = source, playerCoords = playerCoords, isMale = isMale == true })
end)

RegisterNetEvent("nt_holdem:server:configureTable", function(data)
    local source = source
    if type(data) ~= "table" then return end

    local locationID = tostring(data.tableId or "")
    if ServerData.EntryLocations[source] ~= locationID then return end

    local game = ServerData.Games[locationID]
    if not game then return end

    QueueGameCommand(game, {
        type = "configureTable",
        source = source,
        stakeName = tostring(data.stakeName or ""),
        deckName = tostring(data.deckName or ""),
        allowNpcs = Config.ForceNPC or (Config.EnableNPC and data.allowNpcs == true),
        playerCoords = data.playerCoords,
        isMale = data.isMale == true,
    })
end)

RegisterNetEvent("nt_holdem:server:confirmJoin", function(locationID, playerCoords, isMale)
    local source = source
    locationID = tostring(locationID or "")
    if ServerData.EntryLocations[source] ~= locationID then return end

    local game = ServerData.Games[locationID]
    if game then
        QueueGameCommand(game, {
            type = "confirmJoin",
            source = source,
            playerCoords = playerCoords,
            isMale = isMale == true,
        })
    end
end)

RegisterNetEvent("nt_holdem:server:cancelEntry", function(locationID)
    local source = source
    locationID = tostring(locationID or "")
    if ServerData.EntryLocations[source] ~= locationID then return end

    local game = ServerData.Games[locationID]
    if game then QueueGameCommand(game, { type = "cancelEntry", source = source }) end
end)

RegisterNetEvent("nt_holdem:server:npcAppearances", function(requestID, appearances)
    local source = source
    requestID = tostring(requestID or "")
    local pending = ServerData.PendingNpcRequests[requestID]
    if not pending or pending.requestedFrom ~= source or pending.responded then return end
    if ServerData.Games[pending.locationID] ~= pending.game then return end

    pending.responded = true
    QueueGameCommand(pending.game, {
        type = "npcAppearances",
        source = source,
        requestID = requestID,
        appearances = type(appearances) == "table" and appearances or {},
    })
end)

RegisterNetEvent("nt_holdem:server:check", function(handID)
    queueForPlayer(source, { type = "check", handID = tonumber(handID) })
end)

RegisterNetEvent("nt_holdem:server:call", function(handID)
    queueForPlayer(source, { type = "call", handID = tonumber(handID) })
end)

RegisterNetEvent("nt_holdem:server:raise", function(handID, amount)
    queueForPlayer(source, { type = "raise", handID = tonumber(handID), amount = tonumber(amount) })
end)

RegisterNetEvent("nt_holdem:server:fold", function(handID)
    queueForPlayer(source, { type = "fold", handID = tonumber(handID) })
end)

RegisterNetEvent("nt_holdem:server:leaveTable", function()
    queueForPlayer(source, { type = "leave", dropped = false })
end)

AddEventHandler("playerDropped", function()
    SetGameViewer(source, nil, true)
    queueForPlayer(source, { type = "leave", dropped = true })
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    ServerRunning = false
    ServerData.Games = {}
    ServerData.PlayerLocations = {}
    ServerData.ViewerLocations = {}
    ServerData.EntryLocations = {}
    ServerData.PendingNpcRequests = {}
end)
