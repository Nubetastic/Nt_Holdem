ConfigProps = {}

ConfigProps.HandCards = {
    Male = {
        Bone = "SKEL_L_Finger13",
        [1] = { x = 0.0400, y = 0.000, z = 0.0019, rx = -95.0, ry = -20.0, rz = -150.0,  h = 30.25},
        [2] = { x = 0.0500, y = 0.0034, z = 0.0019, rx = -85.0, ry = 0.0, rz = -150.0,  h = 30.25},
    },
    Female = {
        Bone = "SKEL_L_Finger13",
        [1] = { x = 0.01, y = -0.014, z = 0.0019, rx = -95.0, ry = -20.0, rz = -150.0,  h = 30.25},
        [2] = { x = 0.015, y = -0.0174, z = 0.0019, rx = -85.0, ry = 0.0, rz = -150.0,  h = 30.25},
    }
}

ConfigProps.DealerHand = {
    attachment = {
        bone = "SKEL_L_Hand",
        x = 0.10,
        y = 0.02,
        z = 0.06,
        rx = -50.0,
        ry = -60.0,
        rz = 10.0,
    },
}

ConfigProps.Cards = {
    NUIOrder = {
        ["Blackwater"] = 1,
        ["Valentine"] = 2,
        ["Saint Denis"] = 3,
        ["Rhodes"] = 4,
        ["Camp"] = 5,
        ["Vanhorn"] = 6,
        ["RRS"] = 7,
        --["GK"] = 8, -- does not work
        ["New"] = 9,
    },
    cardHeader = "p_crd_",
    cardEndings = {
        ["Blackwater"] = "01x_bla",
        ["Valentine"] = "01x_val",
        ["Saint Denis"] = "01x_std_labastille",
        ["Rhodes"] = "01x_rho",
        ["Camp"] = "01x_camp",
        ["Vanhorn"] = "01x_van",
        ["RRS"] = "01x_rrs",
        --["GK"] = "01x_tgk",
        ["New"] = "01x_new",
    },
    DeckHeader = "p_cardssplit01x_",
    DeckEndings = {
        ["Blackwater"] = "bla",
        ["Valentine"] = "val",
        ["Saint Denis"] = "std_labastille",
        ["Rhodes"] = "rho",
        ["Camp"] = "camp",
        ["Vanhorn"] = "van",
        ["RRS"] = "rrs",
        --["GK"] = "tgk",
        ["New"] = "new",
    },
}

ConfigProps.Props = {
    PlayerChips = {
        model = "p_pokerchipavarage02x",
        offset = { x = .65, y = 0.25, z = 0.30373, h = 0.0, rx = 0.0, ry = 0.0, rz = 0.0 },
    },
    Ante = {
        model = "p_pokerchipwhite01x",
        offset = { x = .95, y = 0.0, z = 0.30373, h = 0.0 },
    },
    Pot = {
        model = "p_pokerchipante01x",
        offset = { x = 1.3, y = 0.0, z = 0.30373, h = 0.0 },
    },
    PlayerBet = {
        model = "p_crd_chipblue01x",
        offset = { x = .9, y = 0.01, z = 0.30373, h = -0.00003, rx = 0.00000, ry = 0.00000, rz = -0.00002 },
    },
    PlayerCard1 = {
        offset = { x = .7, y = -0.055, z = 0.30373, h = -8.0 },
    },
    PlayerCard2 = {
        offset = { x = .7, y = 0.055, z = 0.30473, h = 8.0 },
    },
    Deck = {
        offset = { x = 0.6, y = -0.3, z = 0.30373, h = -15.0 },
    },
    CommunityCard1 = { offset = { x = 1, y = -0.16, z = 0.30373, h = 0.0 } },
    CommunityCard2 = { offset = { x = 1, y = -0.08, z = 0.30373, h = 0.0 } },
    CommunityCard3 = { offset = { x = 1, y = 0.00, z = 0.30373, h = 0.0 } },
    CommunityCard4 = { offset = { x = 1, y = 0.08, z = 0.30373, h = 0.0 } },
    CommunityCard5 = { offset = { x = 1, y = 0.16, z = 0.30373, h = 0.0 } },
}
