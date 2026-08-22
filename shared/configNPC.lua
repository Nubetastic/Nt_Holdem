ConfigNPC = {}

-- NPC appearances are selected from networked ambient peds by one client.
-- Every table client then spawns its own local copy at the assigned seat.
ConfigNPC.MaxAtTable = 4
ConfigNPC.MaxJoinPerHand = 2
ConfigNPC.ActionDelayMs = { Min = 1200, Max = 3000 }
ConfigNPC.Name = {
    Male = {
        "Arthur", "Benjamin", "Caleb", "Charles", "Daniel", "Elias", "Emmett", "Ezra",
        "Franklin", "George", "Henry", "Isaac", "Jasper", "Jesse", "Levi", "Nathaniel",
        "Samuel", "Silas", "Theodore", "Walter",
    },
    Female = {
        "Abigail", "Alice", "Beatrice", "Caroline", "Clara", "Edith", "Eleanor", "Elizabeth",
        "Emma", "Esther", "Florence", "Grace", "Josephine", "Louisa", "Margaret", "Martha",
        "Matilda", "Rose", "Sarah", "Violet",
    },
}

ConfigNPC.PersonalityNames = { "tight", "balanced", "loose", "aggressive" }
ConfigNPC.Personalities = {
    tight = {
        CallConfidence = 42,
        RaiseConfidence = 72,
        AllInConfidence = 90,
        RaiseChance = 70,
        BluffChance = 2,
        SlowPlayChance = 15,
        RaisePot = { Min = 0.40, Max = 0.65 },
        CutLossEarly = { Chance = 35, Amount = 0.60 },
        LeaveWithWinnings = { Chance = 45, Amount = 1.40 },
    },
    balanced = {
        CallConfidence = 36,
        RaiseConfidence = 64,
        AllInConfidence = 86,
        RaiseChance = 75,
        BluffChance = 5,
        SlowPlayChance = 10,
        RaisePot = { Min = 0.40, Max = 0.75 },
        CutLossEarly = { Chance = 20, Amount = 0.45 },
        LeaveWithWinnings = { Chance = 30, Amount = 1.75 },
    },
    loose = {
        CallConfidence = 30,
        RaiseConfidence = 58,
        AllInConfidence = 82,
        RaiseChance = 65,
        BluffChance = 9,
        SlowPlayChance = 8,
        RaisePot = { Min = 0.30, Max = 0.70 },
        CutLossEarly = { Chance = 10, Amount = 0.30 },
        LeaveWithWinnings = { Chance = 20, Amount = 2.00 },
    },
    aggressive = {
        CallConfidence = 34,
        RaiseConfidence = 54,
        AllInConfidence = 78,
        RaiseChance = 88,
        BluffChance = 14,
        SlowPlayChance = 4,
        RaisePot = { Min = 0.55, Max = 1.00 },
        CutLossEarly = { Chance = 5, Amount = 0.20 },
        LeaveWithWinnings = { Chance = 15, Amount = 2.50 },
    },
}

ConfigNPC.Confidence = {
    Baseline = 5,
    CardValues = {
        ["2"] = 2,
        ["3"] = 3,
        ["4"] = 4,
        ["5"] = 5,
        ["6"] = 6,
        ["7"] = 7,
        ["8"] = 8,
        ["9"] = 9,
        T = 10,
        J = 11,
        Q = 12,
        K = 13,
        A = 14,
    },
    Preflop = {
        RankWeight = 20,
        Pair = 28,
        PairRankWeight = 18,
        Suited = 7,
        Connected = 8,
        OneGap = 4,
        BothHigh = 10,
        Ace = 5,
    },
    MadeHands = {
        ["Straight Flush"] = 95,
        ["Four of a Kind"] = 90,
        ["Full House"] = 82,
        Flush = 75,
        Straight = 68,
        ["Three of a Kind"] = 58,
        ["Two Pair"] = 48,
        Pair = 30,
        ["High Card"] = 0,
    },
    HighCardMaxBonus = 8,
    BoardOnlyPenalty = -24,
    HoleCardImprovementBonus = 8,
    DrawChanceWeight = {
        Flush = 1.00,
        Straight = 0.90,
        ThreeOfKind = 0.50,
    },
    BoardThreat = {
        SuitCount = {
            [3] = -6,
            [4] = -18,
            [5] = -25,
        },
        ConnectedCount = {
            [3] = -4,
            [4] = -14,
            [5] = -20,
        },
        Paired = -5,
        TwoPair = -10,
        ThreeOfKind = -16,
    },
    BlockerBonus = {
        A = 12,
        K = 7,
        Q = 4,
    },
    PerOpponent = -2,
    Position = {
        Early = -2,
        Late = 4,
    },
    RandomVariation = 4,
    WagerChance = {
        BigBlind = 100,
        HalfAllIn = 50,
        AllIn = 25,
    },
    PotOdds = {
        Free = 4,
        VeryGood = 12,
        Good = 7,
        Fair = 0,
        Poor = -10,
        VeryPoor = -20,
    },
    StackPressure = {
        Half = -4,
        ThreeQuarter = -9,
        AllIn = -16,
    },
    Minimum = 0,
    Maximum = 100,
}
