-- Abilities.lua: per-class list of instant, enemy-targeted abilities for the
-- "Attack" picker. Pure data + lookups; no WoW API calls here.
--
-- id   = Classic rank 1 spell ID. Core resolves the localized name from it
--        (C_Spell.GetSpellName), and /cast with the bare name uses your
--        highest known rank. Verify IDs in-game with /dump C_Spell.GetSpellName(id).
-- name = English fallback if the client can't resolve the ID.
-- note = shown in the menu tooltip (form/stance/talent requirements).
-- toggle = auto-repeat ability; the macro uses "/cast !Name" so a second
--        press doesn't switch it off.

local _, ns = ...

local Abilities = {}
ns.Abilities = Abilities

Abilities.BY_CLASS = {
    WARRIOR = {
        { id = 100,   name = "Charge", note = "Battle Stance, out of combat" },
        { id = 20252, name = "Intercept", note = "Berserker Stance" },
        { id = 772,   name = "Rend" },
        { id = 7386,  name = "Sunder Armor" },
        { id = 1715,  name = "Hamstring" },
        { id = 7384,  name = "Overpower", note = "Battle Stance, after a dodge" },
        { id = 6572,  name = "Revenge", note = "Defensive Stance, after a block/dodge/parry" },
        { id = 5308,  name = "Execute", note = "Target below 20% health" },
        { id = 355,   name = "Taunt", note = "Defensive Stance" },
        { id = 694,   name = "Mocking Blow", note = "Battle Stance" },
        { id = 72,    name = "Shield Bash", note = "Needs a shield" },
        { id = 6552,  name = "Pummel", note = "Berserker Stance" },
        { id = 676,   name = "Disarm", note = "Defensive Stance" },
        { id = 12294, name = "Mortal Strike", note = "Arms talent" },
        { id = 23881, name = "Bloodthirst", note = "Fury talent" },
        { id = 23922, name = "Shield Slam", note = "Protection talent" },
    },
    PALADIN = {
        { id = 20271, name = "Judgement", note = "Needs an active Seal" },
        { id = 853,   name = "Hammer of Justice" },
        { id = 879,   name = "Exorcism", note = "Undead and Demons only" },
        { id = 20473, name = "Holy Shock", note = "Holy talent" },
    },
    HUNTER = {
        { id = 75,    name = "Auto Shot", toggle = true },
        { id = 1130,  name = "Hunter's Mark" },
        { id = 3044,  name = "Arcane Shot" },
        { id = 1978,  name = "Serpent Sting" },
        { id = 5116,  name = "Concussive Shot" },
        { id = 2643,  name = "Multi-Shot" },
        { id = 3034,  name = "Viper Sting" },
        { id = 3043,  name = "Scorpid Sting" },
        { id = 20736, name = "Distracting Shot" },
        { id = 19503, name = "Scatter Shot", note = "Marksmanship talent" },
        { id = 19386, name = "Wyvern Sting", note = "Survival talent, out of combat" },
        { id = 2974,  name = "Wing Clip", note = "Melee range" },
        { id = 1495,  name = "Mongoose Bite", note = "Melee range, after a dodge" },
        { id = 19306, name = "Counterattack", note = "Survival talent, after a parry" },
    },
    ROGUE = {
        { id = 1752,  name = "Sinister Strike" },
        { id = 53,    name = "Backstab", note = "Dagger, from behind" },
        { id = 2098,  name = "Eviscerate", note = "Finisher" },
        { id = 1943,  name = "Rupture", note = "Finisher" },
        { id = 408,   name = "Kidney Shot", note = "Finisher" },
        { id = 8647,  name = "Expose Armor", note = "Finisher" },
        { id = 1776,  name = "Gouge" },
        { id = 1766,  name = "Kick" },
        { id = 2094,  name = "Blind" },
        { id = 6770,  name = "Sap", note = "Stealth, out of combat target" },
        { id = 1833,  name = "Cheap Shot", note = "Stealth" },
        { id = 703,   name = "Garrote", note = "Stealth, from behind" },
        { id = 8676,  name = "Ambush", note = "Stealth, dagger, from behind" },
        { id = 14278, name = "Ghostly Strike", note = "Subtlety talent" },
        { id = 16511, name = "Hemorrhage", note = "Subtlety talent" },
        { id = 14251, name = "Riposte", note = "Combat talent, after a parry" },
    },
    PRIEST = {
        { id = 589,   name = "Shadow Word: Pain" },
        { id = 5019,  name = "Shoot", note = "Wand", toggle = true },
        { id = 527,   name = "Dispel Magic", note = "Removes an enemy buff" },
        { id = 15487, name = "Silence", note = "Shadow talent" },
        { id = 15286, name = "Vampiric Embrace", note = "Shadow talent" },
        { id = 2944,  name = "Devouring Plague", note = "Undead racial" },
        { id = 9035,  name = "Hex of Weakness", note = "Troll racial" },
    },
    SHAMAN = {
        { id = 8050,  name = "Flame Shock" },
        { id = 8042,  name = "Earth Shock" },
        { id = 8056,  name = "Frost Shock" },
        { id = 370,   name = "Purge" },
        { id = 17364, name = "Stormstrike", note = "Enhancement talent" },
    },
    MAGE = {
        { id = 2136,  name = "Fire Blast" },
        { id = 2139,  name = "Counterspell" },
        { id = 5019,  name = "Shoot", note = "Wand", toggle = true },
        { id = 2855,  name = "Detect Magic" },
    },
    WARLOCK = {
        { id = 980,   name = "Curse of Agony" },
        { id = 702,   name = "Curse of Weakness" },
        { id = 704,   name = "Curse of Recklessness" },
        { id = 1714,  name = "Curse of Tongues" },
        { id = 1490,  name = "Curse of the Elements" },
        { id = 17862, name = "Curse of Shadow" },
        { id = 603,   name = "Curse of Doom" },
        { id = 18223, name = "Curse of Exhaustion", note = "Affliction talent" },
        { id = 5019,  name = "Shoot", note = "Wand", toggle = true },
        { id = 6789,  name = "Death Coil" },
        { id = 172,   name = "Corruption", note = "Instant only with 5/5 Improved Corruption" },
        { id = 18265, name = "Siphon Life", note = "Affliction talent" },
        { id = 17877, name = "Shadowburn", note = "Destruction talent" },
        { id = 17962, name = "Conflagrate", note = "Destruction talent, needs Immolate" },
    },
    DRUID = {
        { id = 8921,  name = "Moonfire", note = "Caster form" },
        { id = 770,   name = "Faerie Fire", note = "Caster form" },
        { id = 5570,  name = "Insect Swarm", note = "Balance talent" },
        { id = 16857, name = "Faerie Fire (Feral)", note = "Cat/Bear, Feral talent" },
        { id = 1082,  name = "Claw", note = "Cat Form" },
        { id = 1822,  name = "Rake", note = "Cat Form" },
        { id = 5221,  name = "Shred", note = "Cat Form, from behind" },
        { id = 1079,  name = "Rip", note = "Cat Form, finisher" },
        { id = 22568, name = "Ferocious Bite", note = "Cat Form, finisher" },
        { id = 9005,  name = "Pounce", note = "Cat Form, prowling" },
        { id = 6785,  name = "Ravage", note = "Cat Form, prowling, from behind" },
        { id = 6795,  name = "Growl", note = "Bear Form" },
        { id = 5211,  name = "Bash", note = "Bear Form" },
        { id = 16979, name = "Feral Charge", note = "Bear Form, Feral talent" },
    },
}

-- Returns the class list, or an empty table for an unknown class.
function Abilities.ForClass(classFile)
    return Abilities.BY_CLASS[classFile] or {}
end

-- Returns the entry with this spell ID in the class list, or nil.
function Abilities.Find(classFile, id)
    for _, entry in ipairs(Abilities.ForClass(classFile)) do
        if entry.id == id then
            return entry
        end
    end
    return nil
end

return Abilities
