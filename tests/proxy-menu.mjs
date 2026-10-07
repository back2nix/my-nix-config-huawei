// GNOME menu behavior with mocked shell widgets/processes; no desktop changes.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

class Menu {
    constructor() { this.items = []; this.signals = new Map(); }
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
const state = {claude: 'kz', codex: 'usa', telegram: 'kz', git: 'usa', nix: 'usa', 'browser-usa': 'usa', 'browser-fra': 'fra', 'browser-kz': 'kz'};
const units = {'amneziawg-egg.service': 'active', 'amneziawg-personal.service': 'inactive'};
const calls = [], errors = [], removed = [];
let failNext = false;
class Process {
    static new(argv) { calls.push(argv); return new Process(argv); }
    constructor(argv) {
        this.stdout = ''; this.stderr = ''; this.ok = true;
        if (argv[0] === '@vpnRoute@') {
            const [, group, mode] = argv;
            if (mode === 'status') this.stdout = state[group];
            else if (failNext) { failNext = false; this.ok = false; this.stderr = 'test failure'; }
            else state[group] = mode;
        } else if (argv[0] === '@proxyMode@') this.stdout = 'SEOUL';
        else if (argv[0] === '@systemctl@') {
            const unit = argv.at(-1);
            if (argv[1] === 'is-active') { this.stdout = units[unit]; this.ok = this.stdout === 'active'; }
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
          Cancellable: class {cancel() { this.cancelled = true; }}},
    GLib: {PRIORITY_DEFAULT: 0, SOURCE_CONTINUE: true, timeout_add_seconds: () => 42,
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
assert.equal(registered._routes.length, 11);
for (const route of registered._routes) {
    assert.ok(registered.menu.items.includes(route.item), 'Each route must appear directly in the panel menu');
}
assert.equal(registered._vpns[0].item.state, true);
assert.equal(registered._vpns[1].item.state, false);
assert.equal(calls.filter(a => a[0] === '@systemctl@' && a.includes('start')).length, 0,
             'Refresh must not change a VPN service');
const claude = registered._routes.find(r => r.label === 'Claude');
const codex = registered._routes.find(r => r.label === 'Codex');
assert.equal(claude.choices.has('direct'), false);
assert.equal(codex.choices.has('direct'), false);
assert.equal(registered._routes.find(r => r.label === 'Nix / Cachix').choices.has('direct'), true);
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
const telegram = registered._routes.find(r => r.label === 'Telegram');
assert.equal(telegram.item.label.text, 'Telegram: KZ (Astana)');
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
extension.disable();
assert.equal(registered.destroyed, true);
assert.equal(registered._cancellable.cancelled, true);
assert.deepEqual(removed, [42]);
console.log('PASS: panel menu, independent choices, error recovery, VPN refresh and cleanup');
