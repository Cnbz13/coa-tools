-- CoA Essential Assistant - banque de mecanismes hors ligne.
-- Cette banque ne contient aucune rotation. Elle sert uniquement a reconnaitre
-- des procs, charges, ressources et fenetres importantes effectivement vues en jeu.

CoAEssentialData = {
    schema = 1,
    sourceDate = "2026-08-26",
    officialPatchThrough = "2026-08-25",
    themes = {},
    profiles = {},
    aliases = {},
    procSemantics = {
        "your next", "next spell", "next ability", "next attack", "becomes instant",
        "cast instantly", "instant cast", "free of cost", "costs no", "no mana cost",
        "cooldown is reset", "cooldown reset", "may now be used", "can now be used",
        "maximum stacks", "at full stacks", "empowered", "overcharged", "surge",
        "votre prochain", "prochain sort", "prochaine attaque", "devient instantane",
        "lance instantanement", "sans cout", "ne coute", "recharge est reinitialisee",
        "peut maintenant etre utilise", "charges maximales", "renforce", "surcharge"
    },
    noise = {
        "keeper's scroll", "keeper scroll", "parchemin du gardien", "well fed", "bien nourri",
        "food", "drink", "flask", "elixir", "tracking", "find herbs", "find minerals",
        "mount", "mounted", "bonus xp", "experience bonus", "rested", "guild perk",
        "gathering speed", "crafting", "ascension", "world buff", "pve mode", "pvp mode"
    }
}

local DATA = CoAEssentialData

local function Theme(className, layout, color, accent, texture, resource, powerType, classAliases)
    DATA.themes[className] = {
        className = className,
        layout = layout,
        color = color,
        accent = accent,
        texture = texture,
        resource = resource,
        powerType = powerType,
        aliases = classAliases or {}
    }
end

-- Les dispositions alternent volontairement : ligne, colonne, arc, runes et noyau.
Theme("Barbarian", "ROW", {0.30,0.04,0.02}, {1.00,0.32,0.08}, "Interface\\Icons\\Ability_Warrior_BattleShout", "Rage", 1, {"Rage", "Frenzy", "Reprisal", "Glory"})
Theme("Witch Doctor", "TOTEM", {0.05,0.16,0.08}, {0.35,1.00,0.48}, "Interface\\Icons\\Spell_Nature_SpiritWolf", "Mana", 0, {"Voodoo", "Brew", "Ward", "Spirit", "Concoction"})
Theme("Felsworn", "ARC", {0.05,0.14,0.03}, {0.45,1.00,0.10}, "Interface\\Icons\\Spell_Shadow_FelArmour", "Felfury", nil, {"Felfury", "Fel Fury", "Demonic Fury", "Slayer", "Infernal"})
Theme("Witch Hunter", "COLUMN", {0.16,0.04,0.03}, {1.00,0.52,0.18}, "Interface\\Icons\\Ability_Hunter_SniperShot", "Focus", 2, {"Purity", "Wickedness", "Hound", "Inquisition", "Deflection"})
Theme("Stormbringer", "STORM", {0.01,0.10,0.22}, {0.18,0.86,1.00}, "Interface\\Icons\\Spell_Nature_Lightning", "Static", nil, {"Static", "Charge", "Stormcharge", "Conductive", "Thunder Orb", "Aftershock"})
Theme("Knight of Xoroth", "ARC", {0.18,0.02,0.04}, {1.00,0.20,0.22}, "Interface\\Icons\\Spell_Shadow_RainOfFire", "Deathfire", nil, {"Hellfire", "Deathfire", "Defiance", "Infernal Blade"})
Theme("Guardian", "BANNER", {0.05,0.12,0.23}, {0.30,0.72,1.00}, "Interface\\Icons\\Ability_Warrior_RallyingCry", "Glory", nil, {"Glory", "Reprisal", "Inspiration", "Vanguard", "Banner", "Ballad"})
Theme("Templar", "RUNES", {0.20,0.14,0.02}, {1.00,0.84,0.20}, "Interface\\Icons\\Spell_Holy_RighteousFury", "Runes sacrees", nil, {"Holy Rune", "Sacred Rune", "Divine Purpose", "Oath", "Zeal"})
Theme("Bloodmage", "BLOOD", {0.22,0.01,0.04}, {1.00,0.12,0.32}, "Interface\\Icons\\Spell_Shadow_LifeDrain02_Purple", "Sang", nil, {"Blood", "Sanguine", "Ironfur", "Flesh", "Accursed"})
Theme("Ranger", "ROW", {0.04,0.16,0.07}, {0.42,0.92,0.30}, "Interface\\Icons\\Ability_Hunter_CriticalShot", "Focus", 2, {"Aim", "Precision", "Hunt", "Farstrider", "Brigand"})
Theme("Chronomancer", "CLOCK", {0.07,0.08,0.22}, {0.55,0.62,1.00}, "Interface\\Icons\\Spell_Arcane_PortalDalaran", "Flux", nil, {"Aeon", "Chaos", "Order", "Time", "Temporal", "Paradox"})
Theme("Necromancer", "RUNES", {0.03,0.12,0.10}, {0.20,0.95,0.70}, "Interface\\Icons\\Spell_Shadow_AnimateDead", "Puissance runique", 6, {"Runic Power", "Lichfrost", "Blight", "Rime", "Animation"})
Theme("Pyromancer", "ARC", {0.24,0.05,0.00}, {1.00,0.42,0.05}, "Interface\\Icons\\Spell_Fire_Fire", "Mana", 0, {"Heating Up", "Hot Streak", "Incineration", "Draconic", "Flameweaving"})
Theme("Cultist", "VOID", {0.12,0.02,0.18}, {0.76,0.28,1.00}, "Interface\\Icons\\Spell_Shadow_ShadowWordPain", "Sanity", nil, {"Mental Expansion", "Black Blood", "Malevolent Power", "Insanity", "Void"})
Theme("Starcaller", "CELESTIAL", {0.02,0.08,0.20}, {0.44,0.72,1.00}, "Interface\\Icons\\Spell_Arcane_StarFire", "Mana", 0, {"Moon", "Lunar", "Star", "Eclipse", "Warden"})
Theme("Sun Cleric", "SUN", {0.24,0.16,0.01}, {1.00,0.86,0.24}, "Interface\\Icons\\Spell_Holy_SearingLight", "Puissance solaire", nil, {"Dawn", "Dawnfall", "Solar Power", "Radiance", "Guidance"})
Theme("Tinker", "TECH", {0.08,0.13,0.15}, {0.25,0.92,1.00}, "Interface\\Icons\\INV_Gizmo_02", "Ferraille", nil, {"Scrap", "Mechsuit", "Overclock", "Nanobot", "Ammunition"})
Theme("Venomancer", "VENOM", {0.05,0.18,0.03}, {0.55,1.00,0.14}, "Interface\\Icons\\Ability_Creature_Poison_03", "Venin", nil, {"Venom", "Poison", "Shadra", "Exoskeleton", "Scorpid"})
Theme("Reaper", "SOUL", {0.08,0.02,0.12}, {0.68,0.30,1.00}, "Interface\\Icons\\Spell_Shadow_SoulLeech_3", "Ames", nil, {"Soul", "Harvest", "Reap", "Domination"})
Theme("Primalist", "TOTEM", {0.12,0.07,0.02}, {0.94,0.62,0.20}, "Interface\\Icons\\Spell_Nature_Earthquake", "Rage", 1, {"Aftershock", "Wild Rage", "Earthshaping", "Primal", "Totem"})
Theme("Runemaster", "GLYPH", {0.02,0.11,0.20}, {0.24,0.82,1.00}, "Interface\\Icons\\Spell_Arcane_Arcane01", "Pulse", nil, {"Pulse", "Runic Brand", "Glyph", "Rune", "Genesis", "Zenith"})

local function Profile(className, specName, role, mechanic, aliases)
    DATA.profiles[className .. ":" .. specName] = {
        className = className,
        specName = specName,
        role = role,
        mechanic = mechanic,
        aliases = aliases or {}
    }
end

Profile("Barbarian", "Brutality", "DAMAGE", "Frenesie et riposte", {"Reprisal", "Frenzy", "Blood Rage"})
Profile("Barbarian", "Headhunting", "DAMAGE", "Fenetres de lancer", {"Spearhead", "Headhunting", "Marked Prey"})
Profile("Barbarian", "Ancestry", "SUPPORT", "Esprits ancestraux", {"Ancestral Spirit", "Ancestor", "War Spirit"})
Profile("Witch Doctor", "Shadowhunting", "DAMAGE", "Familier et wards", {"Shadowhunt", "Spirit Ward", "Companion Frenzy"})
Profile("Witch Doctor", "Voodoo", "DAMAGE", "Maledictions amplifiees", {"Voodoo", "Hex", "Curse"})
Profile("Witch Doctor", "Brewing", "HEALER", "Melanges prets", {"Brew", "Concoction", "Perfect Mixture"})
Profile("Felsworn", "Infernal", "DAMAGE", "Felfury", {"Felfury", "Fel Surge", "Infernal Power"})
Profile("Felsworn", "Slayer", "DAMAGE", "Chaine de glaives", {"Slayer", "Glaive", "Momentum"})
Profile("Felsworn", "Tyrant", "TANK", "Armure demoniaque", {"Tyrant", "Demonic Bulwark", "Fel Armor"})
Profile("Witch Hunter", "Boltslinger", "DAMAGE", "Tirs renforces", {"Boltslinger", "Quick Reload", "Deadeye"})
Profile("Witch Hunter", "Houndmaster", "DAMAGE", "Fenetres de la meute", {"Hound", "Pack", "Bestial Fury"})
Profile("Witch Hunter", "Inquisition", "DAMAGE", "Purete et malveillance", {"Purity", "Wickedness", "Inquisition"})
Profile("Witch Hunter", "Black Knight", "TANK", "Deflection et drain", {"Deflection", "Black Guard", "Drain"})
Profile("Stormbringer", "Wind", "DAMAGE", "Orbes et invocations", {"Thunder Orb", "Wind Servant", "Air Elemental"})
Profile("Stormbringer", "Maelstrom", "DAMAGE", "Conductive et Static", {"Conductive", "Torrential Rage", "Stormcloud"})
Profile("Stormbringer", "Lightning", "DAMAGE", "Surcharge de Static", {"Charge", "Stormcharge", "Supercharged", "Body of Lightning"})
Profile("Knight of Xoroth", "Hellfire", "DAMAGE", "Hellfire", {"Hellfire", "Infernal Blade", "Fel Blaze"})
Profile("Knight of Xoroth", "Defiance", "TANK", "Defiance demoniaque", {"Defiance", "Demon Guard", "Xoroth Bulwark"})
Profile("Knight of Xoroth", "War", "DAMAGE", "Deathfire", {"Deathfire", "Warbringer", "Xoroth Fury"})
Profile("Guardian", "Gladiator", "DAMAGE", "Glory et Reprisal", {"Glory", "Reprisal", "Centurion"})
Profile("Guardian", "Inspiration", "SUPPORT", "Bannieres et ballades", {"Inspiration", "Banner", "Ballad"})
Profile("Guardian", "Vanguard", "TANK", "Blocages reactifs", {"Vanguard", "Perfect Block", "Shield Counter"})
Profile("Templar", "Oathkeeper", "TANK", "Runes defensives", {"Holy Rune", "Oath", "Sacred Guard"})
Profile("Templar", "Zealot", "DAMAGE", "Chaine de zele", {"Zeal", "Divine Purpose", "Judgement"})
Profile("Templar", "Crusader", "DAMAGE", "Runes offensives", {"Holy Rune", "Crusade", "Divine Purpose"})
Profile("Bloodmage", "Fleshweaver", "HEALER", "Vie convertie en soins", {"Fleshweaving", "Blood Offering", "Crimson Mend"})
Profile("Bloodmage", "Sanguine", "DAMAGE", "Sang et siphon", {"Sanguine", "Blood Surge", "Siphon"})
Profile("Bloodmage", "Accursed", "DAMAGE", "Forme maudite", {"Accursed", "Blood Form", "Curseform"})
Profile("Bloodmage", "Eternal", "TANK", "Ironfur et regeneration", {"Ironfur", "Eternal Blood", "Blood Armor"})
Profile("Ranger", "Archery", "DAMAGE", "Precision", {"Precision", "Deadeye", "Perfect Aim"})
Profile("Ranger", "Farstrider", "SUPPORT", "Soutien de groupe", {"Farstrider", "Trailblazer", "Rallying Shot"})
Profile("Ranger", "Brigand", "DAMAGE", "Ouvertures de chasse", {"Brigand", "Marked Prey", "Ambush"})
Profile("Chronomancer", "Time", "HEALER", "Aeons et retours temporels", {"Aeon", "Time Reversal", "Temporal Echo"})
Profile("Chronomancer", "Infinite", "DAMAGE", "Chaos et Order", {"Chaos", "Order", "Infinite Power"})
Profile("Chronomancer", "Artificer", "DAMAGE", "Fenetre technomagique", {"Artificer", "Overclock", "Temporal Device"})
Profile("Necromancer", "Death", "DAMAGE", "Maladies amplifiees", {"Death", "Plague", "Soul Drain"})
Profile("Necromancer", "Animation", "DAMAGE", "Armee et puissance runique", {"Runic Power", "Lichfrost", "March of the Dead"})
Profile("Necromancer", "Rime", "DAMAGE", "Froid accumule", {"Rime", "Lichfrost", "Frozen Power"})
Profile("Pyromancer", "Flameweaving", "HEALER", "Soins de feu amplifies", {"Flameweaving", "Phoenix", "Burning Remedy"})
Profile("Pyromancer", "Incineration", "DAMAGE", "Procs d'incineration", {"Heating Up", "Hot Streak", "Incineration"})
Profile("Pyromancer", "Draconic", "DAMAGE", "Puissance draconique", {"Draconic Power", "Dragon Soul", "Dragonfire"})
Profile("Cultist", "Heretic", "HEALER", "Soin instantane et Sang noir", {"Mental Expansion", "Black Blood", "Malevolent Power"})
Profile("Cultist", "Corruption", "DAMAGE", "Insanity et tentacules", {"Insanity", "Corruption", "Tentacle"})
Profile("Cultist", "Godblade", "DAMAGE", "Lame du vide chargee", {"Godblade", "Void Blade", "Eldritch Edge"})
Profile("Cultist", "Dreadnought", "TANK", "Absorptions du vide", {"Dreadnought", "Void Shield", "Eldritch Bulwark"})
Profile("Starcaller", "Moon Priest", "HEALER", "Fenetres lunaires", {"Moon Priest", "Lunar Grace", "Moonlight"})
Profile("Starcaller", "Sentinel", "DAMAGE", "Tirs stellaires", {"Sentinel", "Starshot", "Lunar Aim"})
Profile("Starcaller", "Warden", "DAMAGE", "Influence lunaire", {"Warden", "Lunar Influence", "Moonblade"})
Profile("Starcaller", "Moon Guard", "TANK", "Bouclier lunaire", {"Moon Guard", "Lunar Shield", "Moon Armor"})
Profile("Sun Cleric", "Piety", "DAMAGE", "Puissance solaire", {"Solar Power", "Piety", "Sunfire"})
Profile("Sun Cleric", "Valkyrie", "DAMAGE", "Fenetre Dawn", {"Dawn", "Dawnfall", "Champion of the Sun"})
Profile("Sun Cleric", "Seraphim", "TANK", "Bouclier solaire", {"Seraphim", "Solar Shield", "Sun Armor"})
Profile("Sun Cleric", "Blessings", "HEALER", "Guidance et benedictions", {"Guidance", "Blessing", "Divine Grace"})
Profile("Tinker", "Demolition", "DAMAGE", "Munitions chargees", {"Ammunition", "Loaded", "Demolition"})
Profile("Tinker", "Mechanics", "DAMAGE", "Scrap et Mechsuit", {"Scrap", "Mechsuit", "Overclock"})
Profile("Tinker", "Invention", "HEALER", "Nanobots et beacons", {"Nanobot", "Beacon", "Invention"})
Profile("Venomancer", "Fortitude", "TANK", "Exosquelette", {"Exoskeleton", "Scorpid", "Fortitude"})
Profile("Venomancer", "Stalking", "DAMAGE", "Ouverture venimeuse", {"Stalking", "Venom", "Predator"})
Profile("Venomancer", "Rotweaver", "DAMAGE", "Poisons accumules", {"Rotweaver", "Rot", "Venom"})
Profile("Venomancer", "Vizier", "HEALER", "Grace de Shadra", {"Shadra", "Vizier", "Venomous Grace"})
Profile("Reaper", "Soul", "DAMAGE", "Ames disponibles", {"Soul", "Soul Reap", "Soul Surge"})
Profile("Reaper", "Harvest", "DAMAGE", "Fenetre de recolte", {"Harvest", "Reaping", "Death Harvest"})
Profile("Reaper", "Domination", "TANK", "Controle des ames", {"Domination", "Soul Guard", "Dominating Presence"})
Profile("Primalist", "Grovekeeper", "HEALER", "Aftershock et esprits", {"Aftershock", "Grovekeeper", "Life Spirit"})
Profile("Primalist", "Wildwalker", "DAMAGE", "Wild Rage et esprit animal", {"Wild Rage", "Wildwalker", "Primal Spirit"})
Profile("Primalist", "Mountain King", "TANK", "Rage et ancrage", {"Mountain King", "Stone Guard", "Unshakable"})
Profile("Primalist", "Geomancy", "DAMAGE", "Earthshaping", {"Earthshaping", "Aftershock", "Terrasurge"})
Profile("Runemaster", "Engravement", "DAMAGE", "Gravures et Pulse", {"Pulse", "Runic Brand", "Engravement"})
Profile("Runemaster", "Glyphic", "DAMAGE", "Glyphes charges", {"Pulse", "Glyphic", "Glyphic Ruin"})
Profile("Runemaster", "Riftblade", "DAMAGE", "Runes elementaires", {"Pulse", "Genesis", "Elemental Rune"})

-- Alias observes dans des variantes de noms de talents/API Ascension.
DATA.aliases["Primalist:Primal"] = "Primalist:Wildwalker"
DATA.aliases["Primalist:Life"] = "Primalist:Grovekeeper"
DATA.aliases["Primalist:Earth"] = "Primalist:Geomancy"
DATA.aliases["Runemaster:Engraving"] = "Runemaster:Engravement"
DATA.aliases["Cultist:Hérétique"] = "Cultist:Heretic"
