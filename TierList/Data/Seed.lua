-- Lists created once on first load (account wide). Edit or delete them freely in game.
local _, TL = ...

TL.Seeds = {
    {
        -- wowsims/forever: ui/specs/paladin/retribution/gear_sets/holy_shock.gear.siml (2026-11-25)
        name = "Shockadin",
        class = "PALADIN",
        build = "Holy Shock, wowsims preset",
        source = "wowsims/forever holy_shock.gear.siml, 2026-11-25",
        fill = "shockadin", -- then GearQuest's other picks per slot (A/B/C)
        spec = "shockadin", -- main spec while in the Holy tree (0.7.0)
        tiers = {
            S = {
                250599, -- Stalwart Helm
                22403,  -- Nacreous Shell Necklace
                226969, -- Soulforge Spaulders
                272411, -- Arcanoweave Cloak
                226973, -- Soulforge Breastplate
                226970, -- Soulforge Bracers
                226975, -- Soulforge Gauntlets
                226971, -- Soulforge Belt
                252606, -- Pristine Scorpid Leggings
                226974, -- Soulforge Warboots
                272406, -- Channeler's Ring
                19325,  -- Don Julio's Band
                13213,  -- Smolderweb's Eye
                22321,  -- Heart of Wyrmthalak
                647,    -- Destiny
                23203,  -- Libram of Fervor
            },
        },
    },
}
