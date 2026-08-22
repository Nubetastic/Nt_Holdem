ConfigAnim = {}

ConfigAnim.Dict = "mini_games@poker_mg@base"
ConfigAnim.SeatedIdle = "no_cards_idle_a"
ConfigAnim.HoldingIdle = "hold_cards_idle_a"

-- Half-body clips use the poker animation flags from the working prototypes.
-- Every action returns to the selected full-body seated idle when it finishes.
-- Tried to fix female card holding but fem versions also are broken.
ConfigAnim.Actions = {
    ["Male"] = {
        sit = { Name = "sit_enter_right", Body = "full", Duration = 4000 },
        join = {
            Name = "buy_in_a",
            Body = "half",
            Duration = 4000,
            StartDelay = 500,
            Timeline = {
                { At = 0.80, Scope = "player", Key = "showPlayerChips", Value = true },
            },
        },
        buyin = { Name = "buy_in_a", Body = "half", Duration = 4000 },
        check = { Name = "check_a", Body = "half", Duration = 1000 },
        bet = { Name = "bet_stack_a", Body = "half", Duration = 2000 },
        blind = { Name = "bet_blind_a", Body = "half", Duration = 1000 },
        allin = { Name = "bet_all", Body = "half", Duration = 3000 },
        fold = { Name = "fold", Body = "half", Duration = 1000 },
        reveal = { Name = "reveal", Body = "half", Duration = 1000, NextIdle = "no_cards_idle_a" },
        pickup = { Name = "peek_enter", Body = "half", Duration = 100, AttachCardsAt = 0.80, NextIdle = "hold_cards_idle_a" },
        peek = { Name = "peek_enter", Body = "half", Duration = 100, NextIdle = "peek_idle" },
        peekexit = { Name = "peek_exit", Body = "half", Duration = 200, NextIdle = "hold_cards_idle_a" },
        shuffle = {
            Dict = "mini_games@blackjack_mg@dealer@actions@shuffle",
            Name = "standard_shuffle",
            Body = "half",
            Duration = 2333,
            HasDeck = true,
            KeepDeck = true,
        },
        deal = {
            Dict = "mini_games@poker_mg@deal",
            Body = "half",
            Duration = 450,
            DealCardAt = 0.80,
            HasDeck = true,
            KeepDeck = true,
            NextIdle = "no_cards_idle_a",
        },
        receive = { Name = "receive_deck", Body = "half", Duration = 1000 },
        flop = { Name = "flop", Body = "half", Duration = 4000, HasDeck = true, DealCardsAt = { 0.35, 0.55, 0.75 } },
        turn = { Name = "turn_no_cards", Body = "half", Duration = 3500, HasDeck = true, DealCardsAt = { 0.70 } },
        river = { Name = "river_no_cards", Body = "half", Duration = 3500, HasDeck = true, DealCardsAt = { 0.70 } },
        win = {
            Dict = "mini_games@poker_mg@take_pot@base@a",
            Name = "take",
            Body = "half",
            Duration = 3000,
            Speed = 0.75,
            NextIdle = "no_cards_idle_a",
        },
    },
    ["Female"] = {
        sit = { Name = "sit_enter_right", Body = "full", Duration = 4000 },
        join = {
            Name = "buy_in_a",
            Body = "half",
            Duration = 4000,
            StartDelay = 500,
            Timeline = {
                { At = 0.80, Scope = "player", Key = "showPlayerChips", Value = true },
            },
        },
        buyin = { Name = "buy_in_a", Body = "half", Duration = 4000 },
        check = { Dict = "mini_games@poker_mg@fem_relaxed", Name = "check_a", Body = "half", Duration = 1500 },
        bet = { Dict = "mini_games@poker_mg@fem_relaxed", Name = "bet_stack_a", Body = "half", Duration = 2000 },
        blind = { Name = "bet_blind_a", Body = "half", Duration = 1000 },
        allin = { Dict = "mini_games@poker_mg@fem_relaxed", Name = "bet_all", Body = "half", Duration = 3000 },
        fold = { Dict = "mini_games@poker_mg@fem_relaxed", Name = "fold", Body = "half", Duration = 1000 },
        reveal = {
            Dict = "mini_games@poker_mg@fem_relaxed",
            Name = "reveal",
            Body = "half",
            Duration = 1000,
            NextIdle = "no_cards_idle_a",
        },
        pickup = {
            Dict = "mini_games@poker_mg@fem_relaxed",
            Name = "peek_enter",
            Body = "half",
            Duration = 100,
            AttachCardsAt = 0.80,
            NextIdle = "hold_cards_idle_a",
        },
        peek = {
            Dict = "mini_games@poker_mg@fem_focused",
            Name = "peek_enter",
            Body = "half",
            Duration = 100,
            NextIdle = "peek_idle",
        },
        peekexit = {
            Dict = "mini_games@poker_mg@fem_focused",
            Name = "peek_exit",
            Body = "half",
            Duration = 200,
            NextIdle = "hold_cards_idle_a",
        },
        shuffle = {
            Dict = "mini_games@blackjack_mg@dealer@actions@shuffle",
            Name = "standard_shuffle",
            Body = "half",
            Duration = 2333,
            HasDeck = true,
            KeepDeck = true,
        },
        deal = {
            Dict = "mini_games@poker_mg@deal",
            Body = "half",
            Duration = 450,
            DealCardAt = 0.80,
            HasDeck = true,
            KeepDeck = true,
            NextIdle = "no_cards_idle_a",
        },
        receive = { Name = "receive_deck", Body = "half", Duration = 1000 },
        flop = { Name = "flop", Body = "half", Duration = 4000, HasDeck = true, DealCardsAt = { 0.35, 0.55, 0.75 } },
        turn = { Name = "turn_no_cards", Body = "half", Duration = 3500, HasDeck = true, DealCardsAt = { 0.70 } },
        river = { Name = "river_no_cards", Body = "half", Duration = 3500, HasDeck = true, DealCardsAt = { 0.70 } },
        win = {
            Dict = "mini_games@poker_mg@take_pot@base@a",
            Name = "take",
            Body = "half",
            Duration = 3000,
            Speed = 0.75,
            NextIdle = "no_cards_idle_a",
        },
    },
}

ConfigAnim.MoveNetwork = "TaskMovePoker"
ConfigAnim.MoveStates = {
    NoCards = "NoCardsIdle",
    HoldCardsEnter = "HoldCardsEnter",
    HoldCards = "HoldCardsIdle",
}
