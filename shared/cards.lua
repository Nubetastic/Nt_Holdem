HoldemCards = {}

local suits = { "c", "d", "h", "s" }
local royalties = { "2", "3", "4", "5", "6", "7", "8", "9", "T", "J", "Q", "K", "A" }

function HoldemCards.newDeck()
    local deck = {}
    for _, suit in ipairs(suits) do
        for _, royalty in ipairs(royalties) do
            deck[#deck + 1] = { suit = suit, royalty = royalty }
        end
    end
    for index = #deck, 2, -1 do
        local swapIndex = math.random(index)
        deck[index], deck[swapIndex] = deck[swapIndex], deck[index]
    end
    return deck
end

function HoldemCards.draw(game)
    local card = game.deck and game.deck[game.nextCardIndex or 1]
    if not card then return nil end
    game.nextCardIndex = (game.nextCardIndex or 1) + 1
    return card
end

function HoldemCards.publicCard(card)
    return card and { suit = card.suit, royalty = card.royalty, isRevealed = true } or nil
end

local rankValues = { ["2"] = 2, ["3"] = 3, ["4"] = 4, ["5"] = 5, ["6"] = 6, ["7"] = 7,
    ["8"] = 8, ["9"] = 9, T = 10, J = 11, Q = 12, K = 13, A = 14 }

local function evaluateFive(cards)
    local values, counts = {}, {}
    local flush = true
    for index, card in ipairs(cards) do
        local value = rankValues[card.royalty]
        values[#values + 1] = value
        counts[value] = (counts[value] or 0) + 1
        if index > 1 and card.suit ~= cards[1].suit then flush = false end
    end
    table.sort(values, function(a, b) return a > b end)

    local unique = {}
    for _, value in ipairs(values) do
        if unique[#unique] ~= value then unique[#unique + 1] = value end
    end
    if unique[1] == 14 then unique[#unique + 1] = 1 end
    local straightHigh = nil
    for index = 1, #unique - 4 do
        if unique[index] - unique[index + 4] == 4 then straightHigh = unique[index] break end
    end

    local groups = {}
    for value, count in pairs(counts) do groups[#groups + 1] = { value = value, count = count } end
    table.sort(groups, function(a, b)
        if a.count == b.count then return a.value > b.value end
        return a.count > b.count
    end)

    if flush and straightHigh then return { 8, straightHigh }, "Straight Flush" end
    if groups[1].count == 4 then return { 7, groups[1].value, groups[2].value }, "Four of a Kind" end
    if groups[1].count == 3 and groups[2].count == 2 then return { 6, groups[1].value, groups[2].value }, "Full House" end
    if flush then return { 5, table.unpack(values) }, "Flush" end
    if straightHigh then return { 4, straightHigh }, "Straight" end
    if groups[1].count == 3 then
        local score = { 3, groups[1].value }
        for _, group in ipairs(groups) do if group.count == 1 then score[#score + 1] = group.value end end
        return score, "Three of a Kind"
    end
    if groups[1].count == 2 and groups[2].count == 2 then
        return { 2, groups[1].value, groups[2].value, groups[3].value }, "Two Pair"
    end
    if groups[1].count == 2 then
        local score = { 1, groups[1].value }
        for _, group in ipairs(groups) do if group.count == 1 then score[#score + 1] = group.value end end
        return score, "Pair"
    end
    return { 0, table.unpack(values) }, "High Card"
end

function HoldemCards.compare(left, right)
    for index = 1, math.max(#left, #right) do
        local difference = (left[index] or 0) - (right[index] or 0)
        if difference ~= 0 then return difference end
    end
    return 0
end

function HoldemCards.evaluate(holeCards, communityCards)
    local cards = {}
    for _, card in ipairs(holeCards or {}) do cards[#cards + 1] = card end
    for _, card in ipairs(communityCards or {}) do cards[#cards + 1] = card end
    if #cards < 5 then return nil, nil end

    local bestScore, bestName
    for a = 1, #cards - 4 do
        for b = a + 1, #cards - 3 do
            for c = b + 1, #cards - 2 do
                for d = c + 1, #cards - 1 do
                    for e = d + 1, #cards do
                        local score, name = evaluateFive({ cards[a], cards[b], cards[c], cards[d], cards[e] })
                        if not bestScore or HoldemCards.compare(score, bestScore) > 0 then
                            bestScore, bestName = score, name
                        end
                    end
                end
            end
        end
    end
    return bestScore, bestName
end
