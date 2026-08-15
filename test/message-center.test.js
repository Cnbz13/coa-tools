import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import luaparse from 'luaparse';

const tocPath = 'addons/CoAMessageCenter/CoAMessageCenter.toc';
const luaPath = 'addons/CoAMessageCenter/CoAMessageCenter.lua';

test('CoA Message Center targets Ascension 3.3.5 and parses as Lua 5.1', async () => {
  const toc = await readFile(tocPath, 'utf8');
  const lua = await readFile(luaPath, 'utf8');
  assert.match(toc, /^## Interface: 30300$/m);
  assert.match(toc, /^## Version: 0\.1\.0$/m);
  assert.match(toc, /^## SavedVariables: CoAMessageCenterDB$/m);
  assert.doesNotThrow(() => luaparse.parse(lua, { luaVersion: '5.1', comments: false, locations: true }));

  for (const retailApi of [
    'BackdropTemplate', 'SetShown', 'SetSize', 'C_Timer', 'C_AddOns',
    'CreateFromMixins', 'RegisterUnitEvent', 'ScrollBox'
  ]) assert.equal(lua.includes(retailApi), false, `forbidden Retail API: ${retailApi}`);
});

test('CoA Message Center captures only registered addon prefixes and leaves player chat alone', async () => {
  const lua = await readFile(luaPath, 'utf8');
  for (const required of [
    'DEFAULT_CHAT_FRAME.AddMessage = ChatInterceptor', 'originalChatAddMessage(frame, text, ...)',
    'DetectAddonMessage', 'RegisterPrefix', 'GetNumAddOns', 'GetAddOnInfo',
    'CoA Loot Decider', 'CoA Combat Assistant', 'CoA UI Manager', 'Grid CoA', 'EventAlert CoA',
    'CoA Analytics',
    'CoAMessageCenterDB.suppressChat', 'if CoAMessageCenterDB.suppressChat then return end'
  ]) assert.ok(lua.includes(required), `missing safe capture feature: ${required}`);
  assert.match(lua, /if prefixes\[normalized\] then return prefixes\[normalized\] end/,
    'an exact visible prefix must belong to a registered addon');
  assert.match(lua, /prefix \.\. " "/,
    'registered addons may append a submodule name to their prefix');
  assert.equal(lua.includes('ChatFrame_AddMessageEventFilter'), false,
    'event-level chat filters could suppress real player and group messages');
});

test('CoA Message Center provides a minimap inbox, unread badge, history and filters', async () => {
  const lua = await readFile(luaPath, 'utf8');
  for (const required of [
    'CoAMessageCenterMinimapButton', 'INV_Misc_Note_05', 'unreadText',
    'CoAMessageCenterFrame', 'ScrollingMessageFrame', 'HISTORY_LIMIT = 300',
    'CoAMessageCenterDB.history', 'CoAMessageCenterDB.unread', 'Tout vider',
    'Tous', 'Infos', 'Alertes', 'Erreurs', 'ScrollToBottom',
    'SLASH_COAMESSAGECENTER1 = "/cmc"', 'function API:AddMessage', 'function API:RegisterPrefix'
  ]) assert.ok(lua.includes(required), `missing message-center feature: ${required}`);
});
