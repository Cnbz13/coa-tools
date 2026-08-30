-- Warmane Icecrown / WotLK 3.3.5a loot profiles.
-- The engine uses stable class tokens and talent-tab indexes so it remains
-- independent from the client locale. Values are conservative EP-style
-- priorities intended for comparison, not a simulation of a complete BiS set.

CoALootProfiles = {
    edition = "warmane-wotlk",
    source = "WotLK 3.3.5 class mechanics and Icecrown itemisation",
    sourceDate = "2026-08-30",

    specs = {
        WARRIOR = {
            { name="Arms", role="DAMAGE", primaryStats={"Strength"} },
            { name="Fury", role="DAMAGE", primaryStats={"Strength"} },
            { name="Protection", role="TANK", primaryStats={"Strength"} }
        },
        PALADIN = {
            { name="Holy", role="HEALER", primaryStats={"Intellect"} },
            { name="Protection", role="TANK", primaryStats={"Strength"} },
            { name="Retribution", role="DAMAGE", primaryStats={"Strength"} }
        },
        HUNTER = {
            { name="Beast Mastery", role="DAMAGE", primaryStats={"Agility"} },
            { name="Marksmanship", role="DAMAGE", primaryStats={"Agility"} },
            { name="Survival", role="DAMAGE", primaryStats={"Agility"} }
        },
        ROGUE = {
            { name="Assassination", role="DAMAGE", primaryStats={"Agility"} },
            { name="Combat", role="DAMAGE", primaryStats={"Agility"} },
            { name="Subtlety", role="DAMAGE", primaryStats={"Agility"} }
        },
        PRIEST = {
            { name="Discipline", role="HEALER", primaryStats={"Intellect", "Spirit"} },
            { name="Holy", role="HEALER", primaryStats={"Intellect", "Spirit"} },
            { name="Shadow", role="DAMAGE", primaryStats={"Intellect", "Spirit"} }
        },
        DEATHKNIGHT = {
            { name="Blood Tank", role="TANK", primaryStats={"Strength"}, variant="blood" },
            { name="Frost", role="DAMAGE", primaryStats={"Strength"} },
            { name="Unholy", role="DAMAGE", primaryStats={"Strength"} }
        },
        SHAMAN = {
            { name="Elemental", role="DAMAGE", primaryStats={"Intellect"} },
            { name="Enhancement", role="DAMAGE", primaryStats={"Agility", "Intellect"} },
            { name="Restoration", role="HEALER", primaryStats={"Intellect"} }
        },
        MAGE = {
            { name="Arcane", role="DAMAGE", primaryStats={"Intellect", "Spirit"} },
            { name="Fire", role="DAMAGE", primaryStats={"Intellect", "Spirit"} },
            { name="Frost", role="DAMAGE", primaryStats={"Intellect"} }
        },
        WARLOCK = {
            { name="Affliction", role="DAMAGE", primaryStats={"Intellect", "Spirit"} },
            { name="Demonology", role="DAMAGE", primaryStats={"Intellect", "Spirit"} },
            { name="Destruction", role="DAMAGE", primaryStats={"Intellect", "Spirit"} }
        },
        DRUID = {
            { name="Balance", role="DAMAGE", primaryStats={"Intellect", "Spirit"} },
            { name="Feral Cat", role="DAMAGE", primaryStats={"Agility"}, variant="feral" },
            { name="Restoration", role="HEALER", primaryStats={"Intellect", "Spirit"} }
        }
    },

    weights = {
        ["WARRIOR:Arms"] = { str=2.1, ap=1, crit=0.75, hit=0.85, expertise=0.75, arp=1.05, haste=0.35, wdps=14 },
        ["WARRIOR:Fury"] = { str=2.0, ap=1, crit=0.80, hit=0.90, expertise=0.80, arp=1.00, haste=0.50, wdps=14 },
        ["WARRIOR:Protection"] = { str=1.0, sta=2.1, ap=0.35, hit=0.35, expertise=0.55, defense=2.0, dodge=1.25, parry=1.15, block=0.80, blockvalue=0.70, armor=0.45, wdps=5 },

        ["PALADIN:Holy"] = { int=1.35, sp=1, heal=1, crit=0.65, haste=0.80, mp5=0.75 },
        ["PALADIN:Protection"] = { str=0.8, sta=2.0, sp=0.25, defense=2.0, dodge=1.20, parry=1.10, block=0.90, blockvalue=0.65, armor=0.45, hit=0.35, expertise=0.50, wdps=4 },
        ["PALADIN:Retribution"] = { str=2.25, ap=1, crit=0.80, hit=0.85, expertise=0.80, haste=0.55, arp=0.25, wdps=14 },

        ["HUNTER:Beast Mastery"] = { agi=1.8, int=0.30, ap=0.45, rap=1, crit=0.70, hit=1.0, haste=0.55, arp=0.35, rdps=14 },
        ["HUNTER:Marksmanship"] = { agi=2.0, int=0.25, rap=1, crit=0.75, hit=1.0, haste=0.45, arp=1.0, rdps=14 },
        ["HUNTER:Survival"] = { agi=2.2, int=0.35, rap=1, crit=0.80, hit=1.0, haste=0.40, arp=0.35, rdps=14 },

        ["ROGUE:Assassination"] = { agi=2.0, ap=1, crit=0.75, hit=1.0, expertise=0.80, haste=0.85, arp=0.25, wdps=12 },
        ["ROGUE:Combat"] = { agi=1.9, ap=1, crit=0.75, hit=0.95, expertise=0.85, haste=0.70, arp=1.0, wdps=14 },
        ["ROGUE:Subtlety"] = { agi=2.1, ap=1, crit=0.85, hit=0.85, expertise=0.70, haste=0.45, arp=0.75, wdps=14 },

        ["PRIEST:Discipline"] = { int=1.1, spi=0.45, sp=1, heal=1, crit=0.55, haste=0.75, mp5=0.55 },
        ["PRIEST:Holy"] = { int=1.0, spi=0.80, sp=1, heal=1, crit=0.55, haste=0.80, mp5=0.60 },
        ["PRIEST:Shadow"] = { int=0.35, spi=0.55, sp=1, hit=1.15, haste=0.95, crit=0.60, spellpen=0.01 },

        ["DEATHKNIGHT:Blood Tank"] = { str=1.0, sta=2.2, ap=0.35, hit=0.40, expertise=0.60, defense=2.0, dodge=1.25, parry=1.20, armor=0.50, wdps=6 },
        ["DEATHKNIGHT:Blood DPS"] = { str=2.2, ap=1, crit=0.70, hit=0.85, expertise=0.80, arp=0.90, haste=0.40, wdps=14 },
        ["DEATHKNIGHT:Frost"] = { str=2.1, ap=1, crit=0.75, hit=0.90, expertise=0.80, arp=0.65, haste=0.55, wdps=13 },
        ["DEATHKNIGHT:Unholy"] = { str=2.15, ap=1, crit=0.70, hit=0.90, expertise=0.75, haste=0.65, arp=0.35, wdps=13 },

        ["SHAMAN:Elemental"] = { int=0.35, sp=1, hit=1.15, haste=1.0, crit=0.65, mp5=0.20, spellpen=0.01 },
        ["SHAMAN:Enhancement"] = { agi=1.8, int=0.35, ap=1, sp=0.35, hit=1.0, expertise=0.85, crit=0.75, haste=0.75, arp=0.20, wdps=13 },
        ["SHAMAN:Restoration"] = { int=1.0, sp=1, heal=1, haste=0.95, crit=0.55, mp5=0.80 },

        ["MAGE:Arcane"] = { int=0.65, spi=0.45, sp=1, hit=1.15, haste=1.0, crit=0.60, spellpen=0.01 },
        ["MAGE:Fire"] = { int=0.35, spi=0.40, sp=1, hit=1.15, haste=0.85, crit=0.90, spellpen=0.01 },
        ["MAGE:Frost"] = { int=0.35, sp=1, hit=1.15, haste=0.90, crit=0.70, spellpen=0.01 },

        ["WARLOCK:Affliction"] = { int=0.30, spi=0.45, sp=1, hit=1.15, haste=1.0, crit=0.45, spellpen=0.01 },
        ["WARLOCK:Demonology"] = { int=0.35, spi=0.65, sp=1, hit=1.15, haste=0.85, crit=0.60, spellpen=0.01 },
        ["WARLOCK:Destruction"] = { int=0.35, spi=0.45, sp=1, hit=1.15, haste=0.90, crit=0.80, spellpen=0.01 },

        ["DRUID:Balance"] = { int=0.35, spi=0.45, sp=1, hit=1.15, haste=0.95, crit=0.70, spellpen=0.01 },
        ["DRUID:Feral Cat"] = { agi=2.1, str=1.5, ap=1, crit=0.80, hit=0.80, expertise=0.80, arp=1.0, haste=0.45, wdps=4 },
        ["DRUID:Feral Bear"] = { agi=1.3, sta=2.1, str=0.8, ap=0.35, defense=0, dodge=1.4, armor=0.65, hit=0.35, expertise=0.55, wdps=3 },
        ["DRUID:Restoration"] = { int=0.85, spi=0.85, sp=1, heal=1, haste=0.95, crit=0.40, mp5=0.65 }
    },

    armorSource = "WotLK 3.3.5 class armor progression",
    armorSourceDate = "2026-08-30",
    armorRules = {
        WARRIOR={ allowed={4}, levelingAllowed={3}, label="PLATE", levelingLabel="MAILLE" },
        PALADIN={ allowed={4}, levelingAllowed={3}, label="PLATE", levelingLabel="MAILLE" },
        DEATHKNIGHT={ allowed={4}, label="PLATE" },
        HUNTER={ allowed={3}, levelingAllowed={2}, label="MAILLE", levelingLabel="CUIR" },
        SHAMAN={ allowed={3}, levelingAllowed={2}, label="MAILLE", levelingLabel="CUIR" },
        ROGUE={ allowed={2}, label="CUIR" }, DRUID={ allowed={2}, label="CUIR" },
        PRIEST={ allowed={1}, label="TISSU" }, MAGE={ allowed={1}, label="TISSU" },
        WARLOCK={ allowed={1}, label="TISSU" }
    },
    armorBySpec = {},
    weaponRules = {
        ["WARRIOR:Arms"]={ preferTwoHand=true, speed="slow", speedWeight=9 },
        ["PALADIN:Retribution"]={ preferTwoHand=true, speed="slow", speedWeight=9 },
        ["DEATHKNIGHT:Blood DPS"]={ preferTwoHand=true, speed="slow", speedWeight=8 },
        ["DEATHKNIGHT:Unholy"]={ preferTwoHand=true, speed="slow", speedWeight=7 },
        ["ROGUE:Assassination"]={ speed="fast", speedWeight=5 }
    }
}
