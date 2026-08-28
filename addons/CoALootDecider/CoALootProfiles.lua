-- CoA Loot Decider specialization profiles.
-- Source baseline: BisBeard CoA defaultWeights, collected 2026-08-22.
-- Cross-checked against current CoA Build Hub guides and Ascension tooltips.
-- Values are equivalence points; attack power is the 1.0 reference where relevant.

CoALootProfiles = {
    source = "BisBeard + CoA Build Hub + Ascension",
    sourceDate = "2026-08-22",
    aliases = {
        ["Venomancer:Venom"] = "Venomancer:Rotweaver",
        ["Primalist:Life"] = "Primalist:Grovekeeper",
        ["Primalist:Primal"] = "Primalist:Wildwalker",
        ["Runemaster:Runic"] = "Runemaster:Engravement",
        ["Runemaster:Arcane"] = "Runemaster:Glyphic"
    },
    weights = {
        ["Barbarian:Headhunting"] = { agi=1.473, ap=1, rap=1, crit=0.65, haste=0.6, arp=0.45, rdps=14 },
        ["Barbarian:Brutality"] = { str=2.188, agi=2.195, ap=1, crit=0.761, hit=0.5, haste=0.6, arp=0.45, expertise=0.5, wdps=14 },
        ["Barbarian:Ancestry"] = { str=1, agi=1.387, ap=1, crit=0.5, hit=0.5, haste=0.55, arp=0.25, expertise=0.5 },
        ["Witch Doctor:Shadowhunting"] = { agi=2, int=1.2, ap=1, rap=1, sp=0.2, crit=0.672, haste=0.5, rdps=14 },
        ["Witch Doctor:Voodoo"] = { int=0.173, spi=1.504, sp=1, crit=1.238, haste=0.6, spellpen=0.01 },
        ["Witch Doctor:Brewing"] = { int=0.07, spi=0.3, sp=1, heal=1, crit=0.5, haste=0.65 },
        ["Felsworn:Infernal"] = { int=0.414, spi=0.517, sp=1, crit=1.242, haste=0.6, spellpen=0.01 },
        ["Felsworn:Slayer"] = { str=1, agi=2.5, ap=1, crit=0.734, haste=0.6, arp=0.3, expertise=0.5, wdps=14 },
        ["Felsworn:Tyrant"] = { str=1.135, agi=2.817, sta=2, ap=1, crit=0.35, hit=0.5, haste=0.35, arp=0.15, expertise=0.5, defense=1.05, dodge=0.9, parry=0.9, armor=0.5, wdps=14 },
        ["Witch Hunter:Boltslinger"] = { agi=1.395, int=1.119, ap=1, rap=1, sp=0.5, crit=0.938, haste=0.6, arp=0.3, rdps=14 },
        ["Witch Hunter:Houndmaster"] = { agi=1.375, int=0.336, ap=1, rap=1, sp=0.5, crit=0.891, haste=0.6, arp=0.3, rdps=14 },
        ["Witch Hunter:Inquisition"] = { str=1, agi=1.745, int=1.082, ap=1, sp=0.75, crit=0.644, haste=0.6, arp=0.3, expertise=0.5, wdps=14 },
        ["Witch Hunter:Black Knight"] = { str=1.225, agi=3.326, sta=1, int=0.27, ap=1, sp=0.75, crit=0.35, hit=0.5, haste=0.35, arp=0.15, expertise=0.5, defense=1.05, dodge=0.9, parry=0.9, armor=0.4, wdps=14 },
        ["Stormbringer:Wind"] = { int=0.067, sp=1, crit=0.5, hit=0.5, haste=0.55 },
        ["Stormbringer:Maelstrom"] = { int=0.244, sp=1, crit=0.882, haste=0.6, spellpen=0.01 },
        ["Stormbringer:Lightning"] = { int=0.209, sp=1, crit=1.563, hit=0.5, haste=0.6, spellpen=0.01 },
        ["Knight of Xoroth:Hellfire"] = { str=2.2, agi=0.585, int=1.163, ap=0.75, sp=1, crit=0.831, hit=0.5, haste=0.6, arp=0.3, expertise=0.5, wdps=14 },
        ["Knight of Xoroth:Defiance"] = { str=2.549, agi=1.127, sta=1.06, int=0.064, ap=1, sp=0.75, crit=0.376, hit=0.5, haste=0.35, arp=0.15, expertise=0.5, defense=1.05, dodge=0.9, parry=0.9, block=0.75, blockvalue=0.26, shieldvalue=0.2, armor=0.2, wdps=14 },
        ["Knight of Xoroth:War"] = { str=2.398, agi=0.721, ap=1, crit=1.024, haste=0.6, arp=0.45, expertise=0.5, wdps=14 },
        ["Guardian:Gladiator"] = { str=2.464, agi=0.617, ap=1, crit=0.796, haste=0.6, arp=0.45, expertise=0.5, wdps=14 },
        ["Guardian:Inspiration"] = { str=2.16, agi=0.444, ap=1, crit=0.6, hit=0.5, haste=0.55, arp=0.25, expertise=0.5 },
        ["Guardian:Vanguard"] = { str=2, agi=1, sta=3, ap=1, crit=0.35, hit=0.5, haste=0.35, arp=0.15, expertise=0.5, defense=1.05, dodge=0.9, parry=0.9, block=0.75, blockvalue=0.33, shieldvalue=0.2, armor=0.325, wdps=14 },
        ["Templar:Oathkeeper"] = { str=1.333, agi=2.872, sta=1.05, int=0.2, ap=1, crit=0.35, hit=0.5, haste=0.35, arp=0.15, expertise=0.5, defense=1.05, dodge=0.9, parry=0.9, armor=0.4, wdps=14 },
        ["Templar:Zealot"] = { str=1.1, agi=1.4, int=0.7, ap=1, sp=0.7, crit=0.7, haste=0.5, arp=0.1, expertise=0.5, wdps=14 },
        ["Templar:Crusader"] = { str=1.05, agi=1.713, int=0.215, ap=1, sp=1, crit=0.739, haste=0.6, arp=0.3, expertise=0.5, wdps=14 },
        ["Bloodmage:Fleshweaver"] = { int=0.091, spi=0.621, sp=1, heal=1, crit=0.5, haste=0.6 },
        ["Bloodmage:Sanguine"] = { sta=0.27, int=0.165, spi=0.27, sp=1, crit=0.9, haste=0.6, spellpen=0.01 },
        ["Bloodmage:Accursed"] = { str=1.404, agi=1.947, int=0.119, ap=1, sp=0.75, crit=0.653, hit=0.5, haste=0.6, arp=0.3, expertise=0.5, wdps=14 },
        ["Bloodmage:Eternal"] = { str=1.177, agi=2.967, sta=1.08, int=0.067, ap=1, sp=0.25, crit=0.364, hit=0.5, haste=0.35, arp=0.15, expertise=0.5, defense=1.05, dodge=0.9, parry=0.9, armor=0.2, wdps=14 },
        ["Ranger:Archery"] = { agi=1.445, int=0.054, ap=1, rap=1, sp=0.15, crit=0.631, hit=0.5, haste=0.6, arp=0.3, rdps=14 },
        ["Ranger:Farstrider"] = { agi=1.39, ap=1, rap=1, crit=0.53, hit=0.5, haste=0.55, arp=0.2 },
        ["Ranger:Brigand"] = { str=1, agi=1.567, ap=1, crit=0.705, hit=0.5, haste=0.6, arp=0.45, expertise=0.5, wdps=14 },
        ["Chronomancer:Time"] = { int=0.064, spi=0.575, sp=1, heal=1, crit=0.5, haste=0.65 },
        ["Chronomancer:Infinite"] = { int=0.096, spi=0.46, sp=1, crit=0.75, haste=0.6, spellpen=0.01 },
        ["Chronomancer:Artificer"] = { agi=1.1, int=0.1, spi=1.5, ap=1, rap=1, sp=0.7, crit=0.7, haste=0.9, spellpen=0.5, rdps=14 },
        ["Necromancer:Death"] = { int=0.054, sp=1, crit=0.63, haste=0.6, spellpen=0.01 },
        ["Necromancer:Animation"] = { int=0.051, sp=1, crit=0.6, hit=0.5, haste=0.6, spellpen=0.01 },
        ["Necromancer:Rime"] = { int=0.415, sp=1, crit=0.9, haste=0.6, spellpen=0.01 },
        ["Pyromancer:Flameweaving"] = { int=0.129, spi=2.182, sp=1, heal=1, crit=0.9, haste=0.65 },
        ["Pyromancer:Incineration"] = { int=0.345, sp=1, crit=1.242, hit=0.5, haste=0.6, spellpen=0.01 },
        ["Pyromancer:Draconic"] = { int=0.218, sp=1, crit=1.614, hit=0.5, haste=0.6, spellpen=0.01 },
        ["Cultist:Heretic"] = { str=1, int=0.104, ap=1, sp=0.4, crit=3, haste=0.4, arp=0.2, wdps=14 },
        ["Cultist:Corruption"] = { int=0.507, sp=1, crit=0.9, haste=0.6, spellpen=0.01 },
        ["Cultist:Godblade"] = { str=2.268, int=1.271, ap=1, sp=0.25, crit=0.797, hit=0.5, haste=0.6, arp=0.3, expertise=0.5, wdps=14 },
        ["Cultist:Dreadnought"] = { str=2.531, sta=1.12, int=0.1, ap=1, sp=0.5, crit=0.35, hit=0.5, haste=0.35, arp=0.15, expertise=0.5, defense=1.05, dodge=0.9, parry=0.9, block=1.8, blockvalue=0.24, shieldvalue=0.2, armor=0.255, wdps=14 },
        ["Starcaller:Moon Priest"] = { int=1, sp=1, heal=1, crit=0.505, haste=0.65 },
        ["Starcaller:Sentinel"] = { agi=1.366, int=2.1, ap=1, rap=1, sp=0.25, crit=0.778, haste=0.1, arp=0.3, rdps=14 },
        ["Starcaller:Warden"] = { str=0.55, agi=0.829, int=2, ap=0.5, sp=1, crit=0.7, haste=0.6, arp=0.3, spellpen=0.3, wdps=14 },
        ["Starcaller:Moon Guard"] = { str=2.041, agi=2.147, sta=1.1, int=0.721, ap=0.75, sp=1, crit=0.354, hit=0.5, haste=0.35, arp=0.15, expertise=0.5, defense=1.05, dodge=0.9, parry=0.9, block=0.75, blockvalue=0.26, shieldvalue=0.2, armor=0.2, wdps=14 },
        ["Sun Cleric:Piety"] = { int=0.21, sp=1, crit=1, haste=0.6, spellpen=0.01 },
        ["Sun Cleric:Valkyrie"] = { str=3.36, agi=0.445, int=0.088, ap=1.25, sp=0.25, crit=0.625, haste=0.6, arp=0.3, expertise=0.5, wdps=14 },
        ["Sun Cleric:Seraphim"] = { str=3.053, agi=1.32, sta=1.15, int=1.089, ap=0.5, sp=1, crit=0.363, hit=0.5, haste=0.35, arp=0.15, expertise=0.5, defense=1.05, dodge=0.9, parry=0.9, block=0.75, blockvalue=0.2, shieldvalue=0.2, armor=0.256, wdps=14 },
        ["Sun Cleric:Blessings"] = { int=0.436, sp=1, heal=1, crit=0.5, haste=0.65 },
        ["Tinker:Demolition"] = { agi=1.878, int=1.205, ap=1, rap=1, sp=1, crit=0.644, haste=0.6, arp=0.3, rdps=14 },
        ["Tinker:Mechanics"] = { agi=1.375, int=1.219, ap=1, rap=1, sp=0.15, crit=0.705, haste=0.6, arp=0.3, rdps=14 },
        ["Tinker:Invention"] = { int=0.442, sp=1, heal=1, crit=0.5, haste=0.65, rdps=14 },
        ["Venomancer:Fortitude"] = { str=0.8, agi=2.529, sta=1, int=0.05, ap=0.5, sp=1, crit=0.357, haste=0.35, arp=0.15, defense=1.05, dodge=0.9, parry=0.9, armor=0.34, wdps=14 },
        ["Venomancer:Stalking"] = { agi=0.4, int=1, ap=0.2, sp=1, crit=1, haste=0.8, spellpen=0.5, expertise=0.5 },
        ["Venomancer:Rotweaver"] = { int=0.575, sp=1, crit=1.2, hit=0.5, haste=0.6, spellpen=0.01 },
        ["Venomancer:Vizier"] = { int=0.4, sp=1, heal=1, crit=0.5, haste=0.65 },
        ["Reaper:Soul"] = { str=2.2, agi=0.485, ap=1, crit=0.689, haste=0.6, arp=0.45, expertise=0.5, wdps=14 },
        ["Reaper:Harvest"] = { str=2.347, agi=0.471, ap=1, crit=0.67, hit=0.5, haste=0.6, arp=0.45, expertise=0.5, wdps=14 },
        ["Reaper:Domination"] = { str=2.596, agi=1.53, sta=1.2, ap=1, crit=0.35, hit=0.5, haste=0.35, arp=1.35, expertise=0.5, defense=1.05, dodge=0.9, parry=0.9, armor=0.37, wdps=14 },
        ["Primalist:Grovekeeper"] = { str=2.2, agi=0.374, int=0.093, ap=1, sp=0.25, heal=1, crit=0.5, haste=0.6, arp=0.2, wdps=14 },
        ["Primalist:Wildwalker"] = { str=2.2, agi=0.486, ap=1, crit=0.65, haste=0.6, arp=0.45, expertise=0.5, wdps=14 },
        ["Primalist:Mountain King"] = { str=4, agi=0.8, sta=2, ap=1, sp=0.5, crit=0.5, hit=1.1, haste=1.5, expertise=1.5, defense=1.5, dodge=1.2, parry=2, wdps=10 },
        ["Primalist:Geomancy"] = { int=0.397, sp=1, crit=0.654, hit=0.5, haste=0.6, arp=0.5, spellpen=0.01 },
        ["Runemaster:Engravement"] = { str=1.125, agi=1.429, int=0.109, ap=1, sp=0.5, crit=0.2, haste=0.6, expertise=0.5, wdps=14 },
        ["Runemaster:Glyphic"] = { int=0.239, spi=0.33, sp=1, crit=0.69, haste=0.6, spellpen=0.01 },
        ["Runemaster:Riftblade"] = { str=1, agi=1.643, int=0.144, ap=1, sp=0.25, crit=0.2, haste=0.6, expertise=0.5, wdps=14 }
    },
    -- Familles d'armure d'itemisation CoA.
    -- Les regles de classe couvrent les 21 classes. Les variantes par specialisation
    -- ne sont epinglees que lorsque la documentation actuelle distingue clairement
    -- la famille d'armure ; sinon l'addon reste sur la famille autorisee de la classe
    -- au lieu d'inventer une restriction.
    armorSource = "Ascension + CoA class references",
    armorSourceDate = "2026-08-28",
    armorRules = {
        ["Barbarian"] = { allowed={2}, label="CUIR" },
        ["Bloodmage"] = { allowed={2}, label="CUIR" },
        ["Chronomancer"] = { allowed={1}, label="TISSU" },
        ["Cultist"] = { allowed={1,4}, label="TISSU/PLAQUE" },
        ["Felsworn"] = { allowed={2}, label="CUIR" },
        ["Guardian"] = { allowed={4}, label="PLAQUE" },
        ["Knight of Xoroth"] = { allowed={4}, label="PLAQUE" },
        ["Necromancer"] = { allowed={1}, label="TISSU" },
        ["Primalist"] = { allowed={4}, label="PLAQUE" },
        ["Pyromancer"] = { allowed={1}, label="TISSU" },
        ["Ranger"] = { allowed={2}, label="CUIR" },
        ["Reaper"] = { allowed={4}, label="PLAQUE" },
        ["Runemaster"] = { allowed={1}, label="TISSU" },
        ["Starcaller"] = { allowed={3,4}, label="MAILLE/PLAQUE" },
        ["Stormbringer"] = { allowed={1}, label="TISSU" },
        ["Sun Cleric"] = { allowed={1,4}, label="TISSU/PLAQUE" },
        ["Templar"] = { allowed={3}, label="MAILLE" },
        ["Tinker"] = { allowed={2,3}, label="CUIR/MAILLE" },
        ["Venomancer"] = { allowed={2,3}, label="CUIR/MAILLE" },
        ["Witch Doctor"] = { allowed={2}, label="CUIR" },
        ["Witch Hunter"] = { allowed={3}, label="MAILLE" }
    },
    armorBySpec = {
        -- Sur les classes multi-armures, ces valeurs sont des preferences
        -- d'itemisation et non des interdictions : la famille autorisee de classe
        -- reste prioritaire pour eviter les faux negatifs sur des objets CoA hybrides.
        -- Sanguine avait deja une logique explicite cuir/tissu dans le moteur
        -- historique. On la conserve comme exception documentee afin que la
        -- nouvelle barriere universelle d'armure ne cree pas de regression.
        ["Bloodmage:Sanguine"] = { allowed={1,2}, label="TISSU/CUIR" },

        ["Cultist:Heretic"] = { preferred={4}, preferredLabel="PLAQUE" },
        ["Cultist:Godblade"] = { preferred={4}, preferredLabel="PLAQUE" },
        ["Cultist:Corruption"] = { preferred={1}, preferredLabel="TISSU" },
        ["Cultist:Dreadnought"] = { preferred={4}, preferredLabel="PLAQUE" },

        ["Sun Cleric:Piety"] = { preferred={1}, preferredLabel="TISSU" },
        ["Sun Cleric:Blessings"] = { preferred={1}, preferredLabel="TISSU" },
        ["Sun Cleric:Seraphim"] = { preferred={4}, preferredLabel="PLAQUE" },
        ["Sun Cleric:Valkyrie"] = { preferred={4}, preferredLabel="PLAQUE" },

        ["Tinker:Mechanics"] = { preferred={3}, preferredLabel="MAILLE" },
        ["Venomancer:Fortitude"] = { preferred={3}, preferredLabel="MAILLE" }
    },
    weaponRules = {
        ["Cultist:Heretic"] = { preferTwoHand = true, speed = "slow", speedWeight = 12 },
        ["Knight of Xoroth:Hellfire"] = { preferTwoHand = true, speed = "slow", speedWeight = 8 },
        ["Knight of Xoroth:War"] = { preferTwoHand = true, speed = "slow", speedWeight = 8 },
        ["Felsworn:Tyrant"] = { speed = "slow", speedWeight = 6 },
        ["Runemaster:Engravement"] = { speed = "fast", speedWeight = 7 }
    }
}
