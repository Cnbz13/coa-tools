CoAEventAlertModules = CoAEventAlertModules or {}

CoAEventAlertModules.NecromancerAnimation = {
    classNames = { "Necromancer", "Nécromancien", "Necromancien" },
    specializationHints = { "Animation", "Animate", "Undead", "Skeletal", "Scourge", "Grave", "Crypt" },
    spells = {
        ["Animate: Skeletal Archer"] = { kind = "summon", priority = 3 },
        ["Bone Ward"] = { kind = "buff", priority = 2 },
        ["Call of The Scourge"] = { kind = "proc", priority = 3 },
        ["Command: Undead"] = { kind = "cooldown", priority = 2 },
        ["Corpse Explosion"] = { kind = "cooldown", priority = 2 },
        ["Crypt Swarm"] = { kind = "debuff", priority = 2 },
        ["Foul Mandate"] = { kind = "proc", priority = 3 },
        ["Grave March"] = { kind = "buff", priority = 2 },
        ["Harvest Plague"] = { kind = "debuff", priority = 2 },
        ["Lichfrost"] = { kind = "debuff", priority = 2 },
        ["March of the Dead"] = { kind = "summon", priority = 3 },
        ["Raise: Abomination"] = { kind = "summon", priority = 3 },
        ["Raise: Crypt Fiend"] = { kind = "summon", priority = 2 },
        ["Raise: Greater Skeletal Warrior"] = { kind = "summon", priority = 2 },
        ["Razorice"] = { kind = "buff", priority = 2 },
        ["Runic Harvest"] = { kind = "proc", priority = 3 }
    }
}
