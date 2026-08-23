import { readFile, writeFile } from 'node:fs/promises';

const SOURCE_REPOSITORY = 'srhinos/coa-datamine';
const SOURCE_REVISION = '8c051d20a1e999839a7783651c1c9d1cd3fbd477';
const SOURCE_CAPTURED_AT = '2026-08-06T10:49:00Z';
const INDEX_URL = `https://raw.githubusercontent.com/${SOURCE_REPOSITORY}/${SOURCE_REVISION}/data/talents/coa/index.json`;
const OUTPUT = new URL('../addons/CoALootDecider/CoALootTalentData.lua', import.meta.url);
const PROFILES = new URL('../addons/CoALootDecider/CoALootProfiles.lua', import.meta.url);

const CLASS_NAMES = {
  WitchDoctor: 'Witch Doctor',
  DemonHunter: 'Felsworn',
  WitchHunter: 'Witch Hunter',
  KnightOfXoroth: 'Knight of Xoroth',
  Monk: 'Templar',
  SonOfArugal: 'Bloodmage',
  SunCleric: 'Sun Cleric',
};

const SPEC_ALIASES = {
  'Barbarian:Headhunting': 'Tactics',
  'Witch Doctor:Shadowhunting': 'Shadowhunting',
  'Felsworn:Infernal': 'Felblood',
  'Felsworn:Slayer': 'Slaying',
  'Felsworn:Tyrant': 'Demonology',
  'Witch Hunter:Houndmaster': 'Darkness',
  'Guardian:Vanguard': 'Protection',
  'Templar:Oathkeeper': 'Discipline',
  'Templar:Zealot': 'Fighting',
  'Templar:Crusader': 'Runes',
  'Bloodmage:Sanguine': 'Blood',
  'Bloodmage:Accursed': 'Ferocity',
  'Bloodmage:Eternal': 'Packleader',
  'Ranger:Farstrider': 'Dueling',
  'Ranger:Brigand': 'Survival',
  'Chronomancer:Infinite': 'Duality',
  'Chronomancer:Artificer': 'Displacement',
  'Pyromancer:Flameweaving': 'Destruction',
  'Starcaller:Moon Priest': 'Tides',
  'Starcaller:Sentinel': 'Moonbow',
  'Starcaller:Moon Guard': 'Astral Warfare',
  'Tinker:Demolition': 'Firearms',
  'Venomancer:Rotweaver': 'Venom',
  'Reaper:Harvest': 'Reaping',
  'Primalist:Grovekeeper': 'Life',
  'Primalist:Wildwalker': 'Primal',
  'Runemaster:Engravement': 'Runic',
  'Runemaster:Glyphic': 'Arcane',
};

const RULES = {
  crit: {
    strong: [/critical strike rating/i, /crit rating/i, /based on (?:your )?critical/i],
    medium: [/when you critically strike/i, /after critically striking/i, /critical strikes? (?:with|from|now|have|grant|cause|reduce|restore|increase|extend|summon)/i, /critical hits? (?:with|from|now|have|grant|cause|reduce|restore|increase|extend|summon)/i],
  },
  haste: {
    strong: [/haste rating/i, /based on (?:your )?haste/i, /scales? with (?:your )?haste/i],
    medium: [/haste (?:now )?(?:reduces|increases|grants|causes)/i],
  },
  hit: { strong: [/hit rating/i, /based on (?:your )?hit chance/i] },
  expertise: { strong: [/expertise rating/i, /based on (?:your )?expertise/i] },
  arp: { strong: [/armor penetration rating/i, /armou?r penetration/i] },
  defense: { strong: [/defen[cs]e rating/i, /based on (?:your )?defen[cs]e/i] },
  dodge: { strong: [/dodge rating/i, /based on (?:your )?dodge/i], medium: [/when you dodge/i, /after dodging/i, /successful dodges?/i] },
  parry: { strong: [/parry rating/i, /based on (?:your )?parry/i], medium: [/when you parry/i, /after parrying/i, /successful parries/i] },
  block: { strong: [/block rating/i, /based on (?:your )?block/i, /equal to (?:your )?block/i], medium: [/when you block/i, /successful blocks?/i, /critical block/i] },
  blockvalue: { strong: [/block value/i] },
  armor: { strong: [/based on (?:your )?armou?r/i, /equal to (?:your )?armou?r/i], medium: [/bonus armou?r/i] },
  str: { strong: [/(?:attack power|spell power|damage|healing|health|armou?r|critical strike|block)[^.!?]{0,120}(?:of|based on|equal to) (?:your )?strength/i, /(?:your )?strength[^.!?]{0,120}(?:increases?|grants?|converted|equal)/i] },
  agi: { strong: [/(?:attack power|spell power|damage|healing|health|armou?r|critical strike|dodge)[^.!?]{0,120}(?:of|based on|equal to) (?:your )?agility/i, /(?:your )?agility[^.!?]{0,120}(?:increases?|grants?|converted|equal)/i] },
  int: { strong: [/(?:attack power|spell power|damage|healing|health|mana|critical strike)[^.!?]{0,120}(?:of|based on|equal to) (?:your )?intellect/i, /(?:your )?intellect[^.!?]{0,120}(?:increases?|grants?|converted|equal)/i] },
  spi: { strong: [/(?:spell power|damage|healing|health|mana regeneration|mana restored)[^.!?]{0,120}(?:of|based on|equal to) (?:your )?spirit\b(?!\s+spells?)/i, /(?:your )?spirit\b(?!\s+spells?)[^.!?]{0,120}(?:increases?|grants?|converted|equal)/i] },
  sta: { strong: [/(?:attack power|spell power|damage|healing|health|armou?r)[^.!?]{0,120}(?:of|based on|equal to) (?:your )?stamina/i, /(?:your )?stamina[^.!?]{0,120}(?:increases?|grants?|converted|equal)/i] },
  ap: { strong: [/based on (?:your )?attack power/i, /of (?:your )?attack power/i, /%\s*ap\b/i] },
  sp: { strong: [/based on (?:your )?spell power/i, /of (?:your )?spell power/i, /%\s*sp\b/i] },
  heal: { strong: [/healing power/i, /healing spell power/i] },
  mp5: { strong: [/mana (?:regeneration|every 5|per 5)/i] },
};

const WEAPON_RULES = {
  twoHand: [/two-handed weapon/i, /2-handed weapon/i],
  dualWield: [/dual wield/i, /two one-handed weapons/i],
  shield: [/shield equipped/i, /equipped shield/i, /requires? (?:a )?shield/i, /while wielding (?:a )?shield/i],
};

function cleanHtml(value = '') {
  return value
    .replace(/<br\s*\/?>/gi, ' ')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/&#39;/g, "'")
    .replace(/&quot;/gi, '"')
    .replace(/\s+/g, ' ')
    .trim();
}

function signalStrength(text, rules) {
  if ((rules.strong ?? []).some(rule => rule.test(text))) return 2;
  if ((rules.medium ?? []).some(rule => rule.test(text))) return 1;
  return 0;
}

function classify(node) {
  const descriptions = node.rankDescriptions?.length
    ? node.rankDescriptions.map(row => row.description)
    : [node.description];
  // Names such as "Brutal Spirit" describe a CoA mechanic, not necessarily
  // the Spirit equipment stat. Only the actual effect text may create a signal.
  const text = cleanHtml(descriptions.join(' '));
  const signals = {};
  for (const [stat, rules] of Object.entries(RULES)) {
    const strength = signalStrength(text, rules);
    if (strength) signals[stat] = strength;
  }
  const weapons = [];
  for (const [weapon, patterns] of Object.entries(WEAPON_RULES)) {
    if (patterns.some(pattern => pattern.test(text))) weapons.push(weapon);
  }
  return { signals, weapons };
}

function luaString(value) {
  return JSON.stringify(String(value ?? '')).replace(/\\u2028|\\u2029/g, ' ');
}

function luaTable(object) {
  const rows = Object.entries(object);
  if (!rows.length) return '{}';
  return `{ ${rows.map(([key, value]) => `${key}=${value}`).join(', ')} }`;
}

async function getJson(url) {
  const response = await fetch(url, { headers: { 'User-Agent': 'coa-tools-talent-generator' } });
  if (!response.ok) throw new Error(`${response.status} ${response.statusText}: ${url}`);
  return response.json();
}

const index = await getJson(INDEX_URL);
const classRows = [];
const availableTabs = {};
let totalNodes = 0;
let signalNodes = 0;

for (const classMeta of index.classes) {
  const url = `https://raw.githubusercontent.com/${SOURCE_REPOSITORY}/${SOURCE_REVISION}/data/talents/coa/${classMeta.file}`;
  const data = await getJson(url);
  const tabsById = Object.fromEntries((data.tabs ?? []).map(tab => [tab.tabId, tab.tabName]));
  const addonClass = CLASS_NAMES[data.class] ?? data.class;
  availableTabs[addonClass] = new Set(Object.values(tabsById));
  const nodeRows = [];

  for (const node of data.nodes ?? []) {
    const { signals, weapons } = classify(node);
    if (Object.keys(signals).length || weapons.length) signalNodes += 1;
    const spellIds = [...new Set([...(node.spellIds ?? []), node.spellId].filter(Number.isFinite))];
    const signalTable = luaTable(Object.fromEntries(Object.entries(signals).map(([key, value]) => [key, String(value)])));
    const weaponTable = weapons.length ? `{ ${weapons.map(value => `${value}=true`).join(', ')} }` : '{}';
    const ids = spellIds.length ? `{ ${spellIds.join(', ')} }` : '{}';
    const tabName = tabsById[node.tabId] ?? 'Unknown';
    nodeRows.push(`            { id=${node.id}, level=${Number(node.requiredLevel) || 0}, tab=${luaString(tabName)}, name=${luaString(node.name)}, spells=${ids}, signals=${signalTable}, weapons=${weaponTable} }`);
    totalNodes += 1;
  }

  classRows.push(`        [${luaString(addonClass)}] = { classID=${data.classId}, sourceClass=${luaString(data.class)}, nodes={\n${nodeRows.join(',\n')}\n        } }`);
}

const aliasRows = Object.entries(SPEC_ALIASES)
  .sort(([a], [b]) => a.localeCompare(b))
  .map(([key, value]) => `        [${luaString(key)}] = ${luaString(value)}`)
  .join(',\n');

const profilesSource = await readFile(PROFILES, 'utf8');
const profileKeys = [...profilesSource.matchAll(/^\s*\["([^"\r\n]+:[^"\r\n]+)"\]\s*=\s*\{([^\r\n]+)\},?$/gm)]
  .filter(([, , body]) => /\b(?:str|agi|int|spi|ap|sp|crit|sta)=/.test(body))
  .map(([, key]) => key);
if (profileKeys.length !== 70) throw new Error(`Expected 70 loot profiles, found ${profileKeys.length}`);
const profileTabs = {};
for (const profileKey of profileKeys) {
  const separator = profileKey.indexOf(':');
  const className = profileKey.slice(0, separator);
  const specName = profileKey.slice(separator + 1);
  const tabName = availableTabs[className]?.has(specName)
    ? specName
    : (SPEC_ALIASES[profileKey] ?? specName);
  if (!availableTabs[className]?.has(tabName)) {
    throw new Error(`No live talent tab for ${profileKey}; resolved tab ${tabName}; available: ${[...(availableTabs[className] ?? [])].join(', ')}`);
  }
  profileTabs[profileKey] = tabName;
}
const profileTabRows = Object.entries(profileTabs)
  .sort(([a], [b]) => a.localeCompare(b))
  .map(([key, value]) => `        [${luaString(key)}] = ${luaString(value)}`)
  .join(',\n');

const output = `-- Generated by scripts/generate-loot-talent-data.mjs. Do not edit by hand.\n-- Source: https://github.com/${SOURCE_REPOSITORY}/tree/${SOURCE_REVISION}/data/talents/coa\n-- Builder capture: ${SOURCE_CAPTURED_AT}; ${totalNodes} current CoA nodes; ${signalNodes} gear-relevant nodes.\n\nCoALootTalentData = {\n    schema = 1,\n    source = ${luaString(`${SOURCE_REPOSITORY}@${SOURCE_REVISION}`)},\n    sourceCapturedAt = ${luaString(SOURCE_CAPTURED_AT)},\n    nodeCount = ${totalNodes},\n    signalNodeCount = ${signalNodes},\n    specAliases = {\n${aliasRows}\n    },\n    profileTabs = {\n${profileTabRows}\n    },\n    classes = {\n${classRows.join(',\n')}\n    }\n}\n`;

await writeFile(OUTPUT, output, 'utf8');
console.log(`Generated ${totalNodes} nodes (${signalNodes} gear signals) in ${OUTPUT.pathname}`);
