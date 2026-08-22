CreateThread(function()
    while ServerRunning do
        for locationID, game in pairs(ServerData.Games) do
            if ServerData.Games[locationID] == game then
                ProcessGameTimers(game)
            end

            if ServerData.Games[locationID] == game then
                ProcessGameCommands(game)
            end

            if ServerData.Games[locationID] == game then
                ProcessGameState(game)
            end
        end

        Wait(100)
    end
end)
