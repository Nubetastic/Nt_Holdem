NPCConfidence = {}

local function drawChance(workingCards, unseenCards)
    if workingCards <= 0 or unseenCards <= 0 then return 0 end
    return workingCards / unseenCards * 100
end

local function straightWorkingCards(cards)
    local present = {}
    local knownCounts = {}
    for _, card in ipairs(cards) do
        local value = ConfigNPC.Confidence.CardValues[card.royalty]
        present[value] = true
        knownCounts[value] = (knownCounts[value] or 0) + 1
        if value == 14 then present[1] = true end
    end

    local missingRanks = {}
    for high = 5, 14 do
        local found = 0
        local missing
        for value = high - 4, high do
            if present[value] then
                found = found + 1
            else
                missing = value == 1 and 14 or value
            end
        end
        if found == 4 then missingRanks[missing] = true end
    end

    local workingCards = 0
    for value in pairs(missingRanks) do
        workingCards = workingCards + 4 - (knownCounts[value] or 0)
    end
    return workingCards
end

local function preflopStrength(holeCards)
    local first = holeCards[1]
    local second = holeCards[2]
    if not first or not second then return 0 end

    local firstValue = ConfigNPC.Confidence.CardValues[first.royalty]
    local secondValue = ConfigNPC.Confidence.CardValues[second.royalty]
    local high = math.max(firstValue, secondValue)
    local low = math.min(firstValue, secondValue)
    local strength = (high + low - 4) / 24 * ConfigNPC.Confidence.Preflop.RankWeight

    if high == low then
        strength = strength + ConfigNPC.Confidence.Preflop.Pair
            + (high - 2) / 12 * ConfigNPC.Confidence.Preflop.PairRankWeight
    else
        if first.suit == second.suit then strength = strength + ConfigNPC.Confidence.Preflop.Suited end
        local gap = high - low
        if gap == 1 then
            strength = strength + ConfigNPC.Confidence.Preflop.Connected
        elseif gap == 2 then
            strength = strength + ConfigNPC.Confidence.Preflop.OneGap
        end
        if low >= 10 then strength = strength + ConfigNPC.Confidence.Preflop.BothHigh end
        if high == 14 then strength = strength + ConfigNPC.Confidence.Preflop.Ace end
    end
    return strength
end

local function holeCardsImproveBoard(holeCards, communityCards, handName, handScore)
    if not handScore or handScore[1] == 0 then return nil end

    local boardScore = HoldemCards.evaluate({}, communityCards)
    if boardScore then return HoldemCards.compare(handScore, boardScore) > 0 end

    local boardRanks = {}
    for _, card in ipairs(communityCards) do
        boardRanks[card.royalty] = (boardRanks[card.royalty] or 0) + 1
    end

    if handName == "Pair" or handName == "Two Pair" or handName == "Three of a Kind" then
        if holeCards[1] and holeCards[2] and holeCards[1].royalty == holeCards[2].royalty then return true end
        for _, card in ipairs(holeCards) do
            if boardRanks[card.royalty] then return true end
        end
        return false
    end
    return true
end

local function boardThreat(communityCards, handCategory)
    local suitCounts = {}
    local rankCounts = {}
    local boardRanks = {}
    local highestSuitCount = 0

    for _, card in ipairs(communityCards) do
        suitCounts[card.suit] = (suitCounts[card.suit] or 0) + 1
        highestSuitCount = math.max(highestSuitCount, suitCounts[card.suit])
        local value = ConfigNPC.Confidence.CardValues[card.royalty]
        rankCounts[value] = (rankCounts[value] or 0) + 1
        boardRanks[value] = true
        if value == 14 then boardRanks[1] = true end
    end

    local connectedCount = 0
    for high = 5, 14 do
        local count = 0
        for value = high - 4, high do
            if boardRanks[value] then count = count + 1 end
        end
        connectedCount = math.max(connectedCount, count)
    end

    local pairCount = 0
    local threeOfKind = false
    for _, count in pairs(rankCounts) do
        if count >= 3 then threeOfKind = true end
        if count == 2 then pairCount = pairCount + 1 end
    end

    local threat = 0
    if handCategory < 5 then
        threat = threat + (ConfigNPC.Confidence.BoardThreat.SuitCount[highestSuitCount] or 0)
    end
    if handCategory < 4 then
        threat = threat + (ConfigNPC.Confidence.BoardThreat.ConnectedCount[connectedCount] or 0)
    end
    if handCategory < 6 then
        if threeOfKind then
            threat = threat + ConfigNPC.Confidence.BoardThreat.ThreeOfKind
        elseif pairCount >= 2 then
            threat = threat + ConfigNPC.Confidence.BoardThreat.TwoPair
        elseif pairCount == 1 then
            threat = threat + ConfigNPC.Confidence.BoardThreat.Paired
        end
    end
    return threat, highestSuitCount, suitCounts
end

function NPCConfidence.calculate(game, player, includeVariation)
    local holeCards = player.holeCards or {}
    local communityCards = game.communityCards or {}
    local knownCards = {}
    for _, card in ipairs(holeCards) do knownCards[#knownCards + 1] = card end
    for _, card in ipairs(communityCards) do knownCards[#knownCards + 1] = card end

    local handScore, handName = HoldemCards.evaluate(holeCards, communityCards)
    local handCategory = handScore and handScore[1] or 0
    local handBonus = handName and ConfigNPC.Confidence.MadeHands[handName] or preflopStrength(holeCards)
    local holeContribution = holeCardsImproveBoard(holeCards, communityCards, handName, handScore)
    local contributionModifier = holeContribution == true and ConfigNPC.Confidence.HoleCardImprovementBonus
        or holeContribution == false and ConfigNPC.Confidence.BoardOnlyPenalty or 0

    local highCardValue = 0
    for _, card in ipairs(holeCards) do
        highCardValue = math.max(highCardValue, ConfigNPC.Confidence.CardValues[card.royalty])
    end
    local highCardBonus = math.max(0, highCardValue - 2) / 12 * ConfigNPC.Confidence.HighCardMaxBonus

    local unseenCards = 52 - #knownCards
    local draws = {}
    local drawBonus = 0

    if handCategory < 5 then
        local knownSuitCounts = {}
        for _, card in ipairs(knownCards) do
            knownSuitCounts[card.suit] = (knownSuitCounts[card.suit] or 0) + 1
        end
        for suit, count in pairs(knownSuitCounts) do
            if count == 4 then
                local workingCards = 13 - count
                local chance = drawChance(workingCards, unseenCards)
                draws.flush = { suit = suit, workingCards = workingCards, chance = chance }
                drawBonus = drawBonus + chance * ConfigNPC.Confidence.DrawChanceWeight.Flush
                break
            end
        end
    end

    if handCategory < 4 then
        local workingCards = straightWorkingCards(knownCards)
        if workingCards > 0 then
            local chance = drawChance(workingCards, unseenCards)
            draws.straight = { workingCards = workingCards, chance = chance }
            drawBonus = drawBonus + chance * ConfigNPC.Confidence.DrawChanceWeight.Straight
        end
    end

    if handCategory < 3 then
        local rankCounts = {}
        local holeRanks = {}
        for _, card in ipairs(knownCards) do
            rankCounts[card.royalty] = (rankCounts[card.royalty] or 0) + 1
        end
        for _, card in ipairs(holeCards) do holeRanks[card.royalty] = true end
        for royalty, count in pairs(rankCounts) do
            if count == 2 and holeRanks[royalty] then
                local chance = drawChance(2, unseenCards)
                draws.threeOfKind = { royalty = royalty, workingCards = 2, chance = chance }
                drawBonus = drawBonus + chance * ConfigNPC.Confidence.DrawChanceWeight.ThreeOfKind
                break
            end
        end
    end

    local threat, highestBoardSuitCount, boardSuitCounts = boardThreat(communityCards, handCategory)
    local blockerBonus = 0
    if handCategory < 5 and highestBoardSuitCount >= 3 then
        for _, card in ipairs(holeCards) do
            if boardSuitCounts[card.suit] == highestBoardSuitCount then
                blockerBonus = math.max(blockerBonus, ConfigNPC.Confidence.BlockerBonus[card.royalty] or 0)
            end
        end
    end

    local opponents = 0
    local opponentsActed = 0
    for _, other in pairs(game.players or {}) do
        if other ~= player and other.inHand and not other.folded then
            opponents = opponents + 1
            if other.acted then opponentsActed = opponentsActed + 1 end
        end
    end
    local opponentAdjustment = opponents * ConfigNPC.Confidence.PerOpponent
    local positionModifier = opponents > 0 and opponentsActed >= math.ceil(opponents / 2)
        and ConfigNPC.Confidence.Position.Late or ConfigNPC.Confidence.Position.Early

    local amountToCall = math.max(0, (game.currentBet or 0) - (player.streetBet or 0))
    local potOdds = amountToCall > 0 and amountToCall / math.max(1, game.pot + amountToCall) or 0
    local priceModifier
    if amountToCall == 0 then
        priceModifier = ConfigNPC.Confidence.PotOdds.Free
    elseif potOdds <= 0.10 then
        priceModifier = ConfigNPC.Confidence.PotOdds.VeryGood
    elseif potOdds <= 0.20 then
        priceModifier = ConfigNPC.Confidence.PotOdds.Good
    elseif potOdds <= 0.30 then
        priceModifier = ConfigNPC.Confidence.PotOdds.Fair
    elseif potOdds <= 0.45 then
        priceModifier = ConfigNPC.Confidence.PotOdds.Poor
    else
        priceModifier = ConfigNPC.Confidence.PotOdds.VeryPoor
    end

    local allInAmount = Config.Stakes[game.stakeName].allIn
    local bigBlind = Config.Stakes[game.stakeName].bigBlind
    local halfAllIn = allInAmount * 0.50
    local wagerAmount = math.min(allInAmount, (player.totalBet or 0) + amountToCall)
    local wagerChance
    if wagerAmount <= bigBlind then
        wagerChance = ConfigNPC.Confidence.WagerChance.BigBlind
    elseif wagerAmount <= halfAllIn then
        local progress = (wagerAmount - bigBlind) / math.max(0.01, halfAllIn - bigBlind)
        wagerChance = ConfigNPC.Confidence.WagerChance.BigBlind
            + (ConfigNPC.Confidence.WagerChance.HalfAllIn - ConfigNPC.Confidence.WagerChance.BigBlind) * progress
    else
        local progress = (wagerAmount - halfAllIn) / math.max(0.01, allInAmount - halfAllIn)
        wagerChance = ConfigNPC.Confidence.WagerChance.HalfAllIn
            + (ConfigNPC.Confidence.WagerChance.AllIn - ConfigNPC.Confidence.WagerChance.HalfAllIn) * progress
    end

    local remainingAllIn = math.max(0, Config.Stakes[game.stakeName].allIn - (player.totalBet or 0))
    local stackPressure = remainingAllIn > 0 and amountToCall / remainingAllIn or 1
    local stackModifier = 0
    if stackPressure >= 1 then
        stackModifier = ConfigNPC.Confidence.StackPressure.AllIn
    elseif stackPressure >= 0.75 then
        stackModifier = ConfigNPC.Confidence.StackPressure.ThreeQuarter
    elseif stackPressure >= 0.50 then
        stackModifier = ConfigNPC.Confidence.StackPressure.Half
    end

    local variation = includeVariation == false and 0
        or math.random(-ConfigNPC.Confidence.RandomVariation, ConfigNPC.Confidence.RandomVariation)
    local confidence = math.max(ConfigNPC.Confidence.Minimum, math.min(ConfigNPC.Confidence.Maximum,
        ConfigNPC.Confidence.Baseline + handBonus + contributionModifier + highCardBonus + drawBonus
        + threat + blockerBonus + opponentAdjustment + positionModifier
        + priceModifier + stackModifier + variation))

    return confidence, {
        handName = handName or "Preflop",
        handCategory = handCategory,
        handBonus = handBonus,
        holeContribution = holeContribution,
        contributionModifier = contributionModifier,
        highCardValue = highCardValue,
        highCardBonus = highCardBonus,
        draws = draws,
        drawBonus = drawBonus,
        boardThreat = threat,
        blockerBonus = blockerBonus,
        opponents = opponents,
        opponentsActed = opponentsActed,
        opponentAdjustment = opponentAdjustment,
        positionModifier = positionModifier,
        amountToCall = amountToCall,
        potOdds = potOdds,
        priceModifier = priceModifier,
        wagerAmount = wagerAmount,
        wagerChance = wagerChance,
        remainingAllIn = remainingAllIn,
        stackPressure = stackPressure,
        stackModifier = stackModifier,
        variation = variation,
    }
end
