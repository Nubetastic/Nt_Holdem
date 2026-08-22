Config = {}

Config.Debug = false
Config.Framework = "RSG"
Config.DisplayName = "account" -- "account" or "character"
Config.InteractionDistance = 2.5
Config.SpawnDistance = 40.0
Config.SpectatorDistance = 30.0
Config.ActionTimeoutSeconds = 60
Config.BetweenHandsWaitMs = 8000
Config.ShowWinDelay = 3000 -- milliseconds after cards are revealed
Config.TableSetupTimeoutSeconds = 120
Config.TableSetupLatencyMs = 500
Config.HouseCut = 0.05 -- 5% of the pot is taken by the house
Config.EnableNPC = true -- Enable NPCs button in nui.
Config.ForceNPC = true -- disabled the prompt in NUI and npcs will always join.

Config.Keys = {
    Join = "INPUT_CONTEXT_X",
}

Config.Blip = {
    Enabled = true,
    Sprite = "blip_mg_poker",
    Scale = 0.8,
    Label = "Texas Hold'em",
}

Config.Stakes = {
    ["low"] = {
        NUIOrder = 1,
        label = "Low Stakes",
        smallBlind = 1,
        bigBlind = 2,
        betIncrement = 1,
        allIn = 20,
    },
    ["medium"] = {
        NUIOrder = 2,
        label = "Medium Stakes",
        smallBlind = 2.5,
        bigBlind = 5,
        betIncrement = 5,
        allIn = 100,
    },
    ["high"] = {
        NUIOrder = 3,
        label = "High Stakes",
        smallBlind = 5,
        bigBlind = 10,
        betIncrement = 10,
        allIn = 200,
    },
}
