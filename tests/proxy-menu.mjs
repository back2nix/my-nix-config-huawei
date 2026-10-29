// GNOME menu behavior with mocked shell widgets/processes; no desktop changes.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {execFileSync} from 'node:child_process';

// Evaluate the real menu data without evaluating or building the whole system.
const config = JSON.parse(JSON.parse(execFileSync('nix', ['eval', '--impure', '--json', '--expr', `
    (import ./module/proxy-mode.nix { pkgs = {
        writeShellScriptBin = name: text: "@proxyMode@";
        vpn-route = "@vpnRoute@"; systemd = "@systemctl@"; curl = "@curl@";
    }; }).environment.etc."proxy-mode/menu.json".text
`], {encoding: 'utf8'})));
config.proxyMode = '@proxyMode@';
config.vpnRoute = '@vpnRoute@';
config.systemctl = '@systemctl@';
config.statusCommand[0] = '@curl@';
// The behavior tests exercise every mode independently of the production allowlist.
config.groups.find(g => g.id === 'claude').only = null;

class Menu {
    constructor() { this.items = []; this.signals = new Map(); }
    removeAll() { this.items = []; }
    addMenuItem(item) { this.items.push(item); }
    connect(name, callback) { this.signals.set(name, callback); }
}
class Item {
    constructor(label) { this.label = {text: label}; this.menu = new Menu(); this.signals = new Map(); }
    connect(name, callback) { this.signals.set(name, callback); }
    setSensitive(value) { this.sensitive = value; }
    setOrnament(value) { this.ornament = value; }
    setToggleState(value) { this.state = value; this.signals.get('toggled')?.(this, value); }
    activate() { return this.signals.get('activate')?.(); }
}
class Panel {
    constructor() { this._init(); }
    _init() { this.menu = new Menu(); }
    add_child() {}
    destroy() { this.destroyed = true; }
}
const state = {antigravity: 'usa', claude: 'kz', codex: 'usa', telegram: 'kz', git: 'usa', nix: 'usa', voicestudio: 'usa', 'browser-usa': 'usa', 'browser-fra': 'fra', 'browser-kz': 'kz', 'fra-deploy': 'direct'};
const units = {'amneziawg-egg.service': 'active', 'amneziawg-personal.service': 'inactive', 'webrtc-google-block.service': 'active', 'webrtc-udp-block.service': 'inactive'};
const calls = [], errors = [], removed = [];
let scheduled, now = 1000000, configReads = 0, fileId = 1;
let failNext = false, apiFailure = false, invalidJson = false;
class Process {
    static new(argv) { calls.push(argv); return new Process(argv); }
    constructor(argv) {
        this.stdout = ''; this.stderr = ''; this.ok = true;
        if (argv[0] === '@curl@') {
            const tags = Object.fromEntries(Object.entries(config.outboundModes).map(([tag, id]) => [id, tag]));
            const proxies = Object.fromEntries(Object.entries(state).map(([group, mode]) => [`${group}-select`, {now: tags[mode]}]));
            for (const selector of Object.values(config.legacySelectors)) proxies[selector] = {now: tags.usa};
            this.stdout = invalidJson ? '{' : JSON.stringify({proxies});
            this.ok = !apiFailure;
        } else if (argv[0] === '@vpnRoute@') {
            const [, group, mode] = argv;
            if (mode === 'status') this.stdout = state[group];
            else if (failNext) { failNext = false; this.ok = false; this.stderr = 'test failure'; }
            else state[group] = mode;
        } else if (argv[0] === '@proxyMode@') this.stdout = 'SEOUL';
        else if (argv[0] === '@systemctl@') {
            const unit = argv.at(-1);
            if (argv[1] === 'show') this.stdout = argv.slice(3).map(unit => `Id=${unit}\nActiveState=${units[unit] || 'inactive'}`).join('\n\n');
            else units[unit] = argv.includes('start') ? 'active' : 'inactive';
        }
    }
    communicate_utf8_async(input, cancellable, callback) { queueMicrotask(() => callback(this, {})); }
    communicate_utf8_finish() { return [true, this.stdout, this.stderr]; }
    get_successful() { return this.ok; }
    force_exit() { this.killed = true; }
}
let registered;
const sandbox = {
    Gio: {Subprocess: Process, SubprocessFlags: {NONE: 0, STDOUT_PIPE: 1, STDERR_PIPE: 2},
          FileQueryInfoFlags: {NONE: 0},
          File: {new_for_path: () => ({query_info: () => ({get_attribute_as_string: () => String(fileId)})})},
          Cancellable: class {cancel() { this.cancelled = true; }}},
    TextDecoder,
    GLib: {file_get_contents: () => { configReads++; return [true, new TextEncoder().encode(JSON.stringify(config))]; }, PRIORITY_DEFAULT: 0, SOURCE_CONTINUE: true, get_monotonic_time: () => now, SOURCE_REMOVE: false,
           timeout_add: (priority, ms, callback) => { scheduled = callback; return 42; },
           Source: {remove: id => removed.push(id)}},
    GObject: {registerClass: cls => cls}, St: {Icon: class {}},
    Extension: class {constructor() { this.uuid = 'test-vpn'; }},
    Main: {panel: {addToStatusArea: (uuid, indicator) => {registered = indicator;}},
           notifyError: (...args) => errors.push(args)},
    PanelMenu: {Button: Panel},
    PopupMenu: {PopupSwitchMenuItem: Item, PopupMenuItem: Item,
                PopupSubMenuMenuItem: Item, PopupSeparatorMenuItem: Item,
                Ornament: {CHECK: 'check', NO_DOT: 'none'}},
};
const source = fs.readFileSync('module/gnome-extensions/proxy-mode/extension.js', 'utf8')
    .replace(/^import .*;\n/gm, '')
    .replace('export default class ProxyModeExtension', 'globalThis.TestExtension = class ProxyModeExtension');
vm.runInNewContext(source, sandbox);
const extension = new sandbox.TestExtension();
extension.enable();
const settle = async () => { for (let i = 0; i < 5; i++) await new Promise(r => setImmediate(r)); };
await settle();
assert.equal(calls.length, 0, 'Enabling the indicator must not spawn status processes');
// PopupSubMenu.open() refuses empty submenus, so choices must exist before opening.
assert.ok(registered._routes.every(r => r.choices.size > 0), 'Submenu choices must exist before opening');
registered.menu.isOpen = true;
registered.menu.signals.get('open-state-changed')(registered.menu, true);
assert.equal(calls.length, 0, 'Opening must render before spawning processes');
assert.equal(configReads, 1, 'Unchanged config must not be reread');
scheduled();
await settle();
assert.equal(calls.length, 2, 'Opening the menu needs exactly one API call and one systemd call');
registered.menu.signals.get('open-state-changed')(registered.menu, true);
await settle();
assert.equal(calls.length, 2, 'Repeated opening must use cached state');
fileId++;
registered._build();
assert.equal(configReads, 2, 'A new store file must be read even with an unchanged mtime');
await registered._refresh();
assert.equal(registered._routes.length, config.groups.length + config.legacyPorts.length);
for (const route of registered._routes) {
    assert.ok(registered.menu.items.includes(route.item), 'Each route must appear directly in the panel menu');
}
assert.equal(registered._vpns[0].item.state, true);
assert.equal(registered._vpns[1].item.state, false);
assert.equal(calls.filter(a => a[0] === '@systemctl@' && a.includes('start')).length, 0,
             'Refresh must not change a VPN service');
const antigravity = registered._routes.find(r => r.label === 'Antigravity CLI');
assert.equal(antigravity.choices.has('direct'), false);
assert.equal(antigravity.choices.has('isp-kz'), true);
await antigravity.choices.get('fra').activate();
await settle();
assert.equal(state.antigravity, 'fra');
assert.equal(state.claude, 'kz');
assert.equal(state.codex, 'usa');
assert.equal(antigravity.choices.get('fra').ornament, 'check');
const claude = registered._routes.find(r => r.label === 'Claude');
const codex = registered._routes.find(r => r.label === 'Codex');
assert.equal(claude.choices.has('direct'), false);
assert.equal(codex.choices.has('direct'), false);
assert.equal(registered._routes.find(r => r.label === 'Nix / Cachix').choices.has('direct'), true);
await claude.choices.get('ps-kz').activate();
assert.equal(state.claude, 'ps-kz');
assert.equal(state.codex, 'usa');
assert.equal(claude.choices.get('ps-kz').ornament, 'check');
await claude.choices.get('casino').activate();
await settle();
assert.equal(state.claude, 'casino');
assert.equal(state.codex, 'usa');
assert.equal(claude.choices.get('casino').ornament, 'check');
await claude.choices.get('isp-kz').activate();
await settle();
assert.equal(state.claude, 'isp-kz');
assert.equal(state.codex, 'usa');
assert.equal(claude.choices.get('isp-kz').ornament, 'check');
assert.equal(registered._routes.find(r => r.label === 'Nix / Cachix').choices.has('isp-kz'), false);
const git = registered._routes.find(r => r.label === 'Git');
assert.equal(git.choices.has('direct'), true);
assert.equal(git.choices.has('isp-kz'), false);
await git.choices.get('fra').activate();
await settle();
assert.equal(state.git, 'fra');
assert.equal(state.nix, 'usa');
assert.equal(state.telegram, 'kz');
assert.equal(git.choices.get('fra').ornament, 'check');
const telegram = registered._routes.find(r => r.label === 'Telegram (SOCKS5: 1106)');
assert.equal(telegram.item.label.text, 'Telegram (SOCKS5: 1106): KZ (Astana)');
assert.equal(telegram.choices.has('direct'), false);
await telegram.choices.get('fra').activate();
await settle();
assert.equal(state.telegram, 'fra');
assert.equal(state.claude, 'isp-kz');
assert.equal(state.codex, 'usa');
assert.equal(telegram.choices.get('fra').ornament, 'check');
for (const group of ['browser-usa', 'browser-fra', 'browser-kz']) {
    const browser = registered._routes.find(r => r.command[1] === group);
    assert.ok(browser.choices.has('direct'));
    await browser.choices.get('casino').activate();
    await settle();
    assert.equal(state[group], 'casino');
    assert.equal(browser.choices.get('casino').ornament, 'check');
    assert.equal(state.claude, 'isp-kz');
    assert.equal(state.telegram, 'fra');
}
failNext = true;
await codex.choices.get('fra').activate();
await settle();
assert.equal(state.codex, 'usa');
assert.equal(codex.choices.get('usa').ornament, 'check');
assert.equal(errors.length, 1);
const vpn = registered._vpns[1];
vpn.item.signals.get('toggled')(vpn.item, true);
await settle();
assert.equal(units[vpn.unit], 'active');
const google = registered._vpns.find(v => v.unit === 'webrtc-google-block.service');
const udp = registered._vpns.find(v => v.unit === 'webrtc-udp-block.service');
assert.equal(google.item.state, true);
assert.equal(udp.item.state, false);
udp.item.signals.get('toggled')(udp.item, true);
await settle();
assert.equal(units[udp.unit], 'active');
assert.equal(units[google.unit], 'active');
google.item.signals.get('toggled')(google.item, false);
await settle();
assert.equal(units[google.unit], 'inactive');
assert.equal(units[udp.unit], 'active');
// API failure and malformed responses must not disable independent VPN controls.
apiFailure = true;
await registered._refresh();
assert.ok(registered._routes.every(r => !r.item.sensitive));
assert.equal(registered._vpns[0].item.sensitive, true);
apiFailure = false;
invalidJson = true;
await registered._refresh();
assert.ok(registered._routes.every(r => !r.item.sensitive));
invalidJson = false;
await registered._refresh();
assert.ok(registered._routes.every(r => r.item.sensitive));
// Expired status refresh is deferred; repeated open events share one timer.
now += 11000000;
const cachedCalls = calls.length;
registered.menu.signals.get('open-state-changed')(registered.menu, true);
assert.ok(registered._refreshSource);
registered.menu.signals.get('open-state-changed')(registered.menu, true);
assert.equal(calls.length, cachedCalls);
scheduled();
await settle();
assert.equal(calls.length - cachedCalls, 2);
const before = calls.length;
await registered._refresh();
assert.equal(calls.length - before, 2);
extension.disable();
assert.equal(registered.destroyed, true);
assert.equal(registered._cancellable.cancelled, true);
assert.deepEqual(removed, []);
console.log('PASS: cached config/status, deferred refresh (2 processes), lazy submenus, independent choices, API failure recovery and cleanup');
