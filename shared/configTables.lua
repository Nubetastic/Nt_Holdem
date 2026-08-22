ConfigTables = {}

ConfigTables.Offsets = {
    Male = { vector3(0.0, 0.0, -0.01) },
    Female = { vector3(0.0, 0.0, -0.01) },
}

ConfigTables.Loc={
    ["Smithfields"] = {
        Enabled = true,
        Label = "Poker Table",
        MaxPlayers = 6,
        Table = {
            Coords = vector3(-304.54, 801.14, 117.98),
            Heading = 313.9578, -- not real heading, first seat for table fixing.
        },
        Chairs = {
            [1] = { SpawnCoords = vector4(-303.6529, 801.9954, 118.4801, 135.0000), Coords = vector4(-303.6529, 801.9954, 118.4801, 135.0000) },
            [2] = { SpawnCoords = vector4(-303.3545, 800.7997, 118.4801, 75.0000), Coords = vector4(-303.3545, 800.7997, 118.4801, 75.0000) },
            [3] = { SpawnCoords = vector4(-304.2366, 799.9420, 118.4801, 15.0000), Coords = vector4(-304.2366, 799.9420, 118.4801, 15.0000)},
            [4] = { SpawnCoords = vector4(-305.4170, 800.2771, 118.4801, 315.0000), Coords = vector4(-305.4170, 800.2771, 118.4801, 315.0000) },
            [5] = { SpawnCoords = vector4(-305.7224, 801.4698, 118.4801, 254.9999), Coords = vector4(-305.7224, 801.4698, 118.4801, 254.9999) },
            [6] = { SpawnCoords = vector4(-304.8402, 802.3275, 118.4801, 194.9999), Coords = vector4(-304.8402, 802.3275, 118.4801, 194.9999) },
        },
        PolyZone = { -- scans this area for npcs players.
            vector3(-312.6921, 797.9561, 120.0023),
            vector3(-302.4669, 799.7999, 121.1553),
            vector3(-305.6823, 819.9424, 118.6657),
            vector3(-316.7649, 818.2871, 120.2610),
        }
    },
    ["Blackwater"] = {
        Enabled = true,
        Label = "Poker Table",
        MaxPlayers = 6,
        Table = {
            Coords = vector3(-813.21, -1316.55, 42.68),
            Heading = 118.6241,
        },
        Chairs = {
            [1] = { SpawnCoords = vector4(-814.3358, -1317.1656, 43.1788, 299.9999), Coords = vector4(-814.2917, -1317.1404, 43.1788, 299.6663) },
            [2] = { SpawnCoords = vector4(-814.3109, -1315.8859, 43.1787, 240.0000), Coords = vector4(-814.2633, -1315.9083, 43.1787, 239.6663)},
            [3] = { SpawnCoords = vector4(-813.1898, -1315.2673, 43.1788, 180.0000), Coords = vector4(-813.1858, -1315.3144, 43.1788, 179.6663)},
            [4] = { SpawnCoords = vector4(-812.0939, -1315.9291, 43.1787, 119.9999), Coords = vector4(-812.1360, -1315.9497, 43.1787, 119.6663) },
            [5] = { SpawnCoords = vector4(-812.1190, -1317.2091, 43.1788, 60.0000), Coords = vector4(-812.1569, -1317.1807, 43.1788, 59.6662) },
            [6] = { SpawnCoords = vector4(-813.2398, -1317.8274, 43.1787, 359.9999), Coords = vector4(-813.2345, -1317.7746, 43.1787, 359.6662) },
        },
        PolyZone = { -- scans this area for npcs players.
            vector3(-811.4205, -1312.4879, 45.0698),
            vector3(-808.8923, -1327.2257, 45.5134),
            vector3(-826.2944, -1312.0153, 47.5608),
            vector3(-826.0157, -1326.4695, 49.2345),
        }
    },
    ["Saint Denis Bastille"] = {
        Enabled = true,
        Label = "Poker Table",
        MaxPlayers = 6,
        Table = {
            Coords = vector3(2630.74, -1226.25, 52.38),
            Heading = 299.0557,
        },
        Chairs = {
            [1] = { SpawnCoords = vector4(2631.8235, -1225.6470, 52.8798, 119.9999), Coords = vector4(2631.8172, -1225.6515, 52.8798, 120.0980) },
            [2] = { SpawnCoords = vector4(2631.7974, -1226.8638, 52.8798, 60.0000), Coords = vector4(2631.7981, -1226.8837, 52.8798, 60.0980)},
            [3] = { SpawnCoords = vector4(2630.7217, -1227.4875, 52.8796, 359.9999), Coords = vector4(2630.7251, -1227.4857, 52.8796, 0.0980)},
            [4] = { SpawnCoords = vector4(2629.6584, -1226.8533, 52.8796, 299.9999), Coords = vector4(2629.6706, -1226.8583, 52.8796, 300.0980) },
            [5] = { SpawnCoords = vector4(2629.6760, -1225.6140, 52.8796, 240.0000), Coords = vector4(2629.6822, -1225.6272, 52.8796, 240.0979) },
            [6] = { SpawnCoords = vector4(2630.7512, -1225.0000, 52.8796, 179.7626), Coords = vector4(2630.7553, -1225.0252, 52.8796, 180.0979) },
        },
        PolyZone = { -- scans this area for npcs players.
            vector3(2627.5474, -1220.1134, 53.2774),
            vector3(2640.5872, -1220.5712, 55.1647),
            vector3(2627.9294, -1233.7814, 55.8251),
            vector3(2640.9797, -1233.8950, 59.1628),
        }
    },
    ["Tumbleweed"] = {
        Enabled = true,
        Label = "Poker Table",
        MaxPlayers = 6,
        Table = {
            Coords = vector3(-5510.39, -2913.76, 0.64),
            Heading = 211.5359,
        },
        Chairs = {
            [1] = { SpawnCoords = vector4(-5509.6938, -2914.8286, 1.1376, 37.9798), Coords = vector4(-5509.7454, -2914.8103, 1.1376, 32.5782)},
            [2] = { SpawnCoords = vector4(-5511.0015, -2914.8103, 1.1376, 342.3668), Coords = vector4(-5510.9773, -2914.8445, 1.1376, 332.5782)},
            [3] = { SpawnCoords = vector4(-5511.6489, -2913.8337, 1.1376, 286.1479), Coords = vector4(-5511.6252, -2913.7986, 1.1376, 272.5782)},
            [4] = { SpawnCoords = vector4(-5511.0366, -2912.7029, 1.1376, 212.5796), Coords = vector4(-5511.0441, -2912.7179, 1.1376, 212.5782)},
            [5] = { SpawnCoords = vector4(-5509.7773, -2912.7224, 1.1376, 161.3521), Coords = vector4(-5509.8136, -2912.6762, 1.1376, 152.5781)},
            [6] = { SpawnCoords = vector4(-5509.0625, -2913.6824, 1.1376, 102.5991), Coords = vector4(-5509.1657, -2913.7223, 1.1376, 92.5781)},
        },
        PolyZone = { -- scans this area for npcs players.
            vector3(-5507.1401, -2914.4001, -0.1980),
            vector3(-5514.6724, -2918.0398, -0.5146),
            vector3(-5521.5605, -2906.9294, 6.7257),
            vector3(-5515.6392, -2903.3599, 0.2961),
        }
    },
}
