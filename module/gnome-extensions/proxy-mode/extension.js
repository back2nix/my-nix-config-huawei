// Independent consumer routes and host VPN switches in a dedicated panel menu.
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import GObject from 'gi://GObject';
import St from 'gi://St';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';

const ROUTE = '@vpnRoute@';
const PROXY_MODE = '@proxyMode@';
const SYSTEMCTL = '@systemctl@';
const MODES = [
    {id: 'usa', label: 'USA (Сеул)'},
    {id: 'casino', label: 'USA через Casino'},
    {id: 'fra', label: 'FRA (Франкфурт)'},
    {id: 'kz', label: 'KZ (Astana)'},
];
const VPNS = [
    {label: 'WinJoy VPN', unit: 'amneziawg-egg.service'},
    {label: 'Personal VPN', unit: 'amneziawg-personal.service'},
];


const VpnMenu = GObject.registerClass(
class VpnMenu extends PanelMenu.Button {
    _init() {
        super._init(0.0, 'VPN и маршруты');
        this.add_child(new St.Icon({icon_name: 'network-vpn-symbolic', style_class: 'system-status-icon'}));
        this._alive = true;
        this._processes = new Set();
        this._cancellable = new Gio.Cancellable();
        this._routes = [];
        this._vpns = [];
        this._applying = false;
        for (const vpn of VPNS) {
            const item = new PopupMenu.PopupSwitchMenuItem(vpn.label, false);
            item.setSensitive(false);
            item.connect('toggled', (_, enabled) => {
                if (this._applying)
                    return;
                const entry = this._vpns.find(v => v.item === item);
                entry.changing = true;
                item.setSensitive(false);
                this._run([SYSTEMCTL, '--no-ask-password', enabled ? 'start' : 'stop', vpn.unit])
                    .then(result => {
                        if (!this._alive)
                            return;
                        entry.changing = false;
                        if (!result.ok)
                            Main.notifyError(vpn.label, result.stderr || 'Не удалось переключить VPN');
                        this._refresh();
                    });
            });
            this.menu.addMenuItem(item);
            this._vpns.push({...vpn, item});
        }
        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        for (const group of [
            {id: 'claude', label: 'Claude', direct: false},
            {id: 'codex', label: 'Codex', direct: false},
            {id: 'telegram', label: 'Telegram', direct: false},
            {id: 'nix', label: 'Nix / Cachix', direct: true},
            {id: 'browser-usa', label: 'Браузер USA (1110/1111)', direct: true},
            {id: 'browser-fra', label: 'Браузер FRA (1112/1113)', direct: true},
            {id: 'browser-kz', label: 'Браузер KZ (1114/1115)', direct: true},
        ]) {
            const modes = group.direct ? [...MODES, {id: 'direct', label: 'Direct'}] : [...MODES, {id: 'isp-kz', label: 'ISP Казахстан'}];
            this._addRoute(group.label, [ROUTE, group.id], modes, false);
        }
        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        const legacyHeading = new PopupMenu.PopupMenuItem('Общие прокси — другие программы', {reactive: false});
        this.menu.addMenuItem(legacyHeading);
        const legacyModes = [
            {id: 'seoul', label: 'USA (Сеул)'},
            {id: 'frankfurt', label: 'FRA (Франкфурт)'},
            {id: 'astana', label: 'KZ (Astana)'},
            {id: 'casino', label: 'Через Casino'},
            {id: 'direct', label: 'Direct'},
        ];
        for (const port of [1082, 1088, 1090]) {
            this._addRoute(`${port}/${port + 1}`, [PROXY_MODE, ...(port === 1082 ? [] : [`--${port}`])], legacyModes, true);
        }
        this.menu.connect('open-state-changed', (_, open) => {
            if (open)
                this._refresh();
        });
        this._pollId = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 10, () => {
            this._refresh();
            return GLib.SOURCE_CONTINUE;
        });
        this._refresh();
    }

    _addRoute(label, command, modes, legacy, menu = this.menu) {
        const item = new PopupMenu.PopupSubMenuMenuItem(`${label}: проверка…`);
        const choices = new Map();
        const route = {label, command, modes, legacy, item, choices, changing: false};
        for (const mode of modes) {
            const choice = new PopupMenu.PopupMenuItem(mode.label);
            choice.connect('activate', async () => {
                route.changing = true;
                item.setSensitive(false);
                const result = await this._run([...command, mode.id]);
                if (!this._alive)
                    return;
                route.changing = false;
                if (!result.ok)
                    Main.notifyError(label, result.stderr || 'Не удалось изменить маршрут');
                await this._refresh();
            });
            item.menu.addMenuItem(choice);
            choices.set(mode.id, choice);
        }
        item.setSensitive(false);
        menu.addMenuItem(item);
        this._routes.push(route);
    }

    _run(argv) {
        return new Promise(resolve => {
            let proc;
            try {
                proc = Gio.Subprocess.new(argv, Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_PIPE);
                this._processes.add(proc);
                proc.communicate_utf8_async(null, this._cancellable, (source, result) => {
                    this._processes.delete(proc);
                    try {
                        const [, stdout, stderr] = source.communicate_utf8_finish(result);
                        resolve({ok: source.get_successful(), stdout: (stdout || '').trim(), stderr: (stderr || '').trim()});
                    } catch (error) {
                        resolve({ok: false, stdout: '', stderr: error.message});
                    }
                });
            } catch (error) {
                resolve({ok: false, stdout: '', stderr: error.message});
            }
        });
    }

    async _refresh() {
        if (!this._alive)
            return;
        if (this._refreshing) {
            this._refreshAgain = true;
            return;
        }
        this._refreshing = true;
        try {
            await Promise.all([
                ...this._routes.map(async route => {
                    if (route.changing)
                        return;
                    const result = await this._run([...route.command, 'status']);
                    if (!this._alive || route.changing)
                        return;
                    const id = route.legacy ? result.stdout.toLowerCase() : result.stdout;
                    const mode = result.ok ? route.modes.find(m => m.id === id) : null;
                    route.item.label.text = `${route.label}: ${mode ? mode.label : 'недоступен'}`;
                    route.item.setSensitive(!!mode);
                    for (const [modeId, choice] of route.choices) {
                        choice.setOrnament(mode && modeId === mode.id ? PopupMenu.Ornament.CHECK : PopupMenu.Ornament.NO_DOT);
                    }
                }),
                ...this._vpns.map(async vpn => {
                    if (vpn.changing)
                        return;
                    const result = await this._run([SYSTEMCTL, 'is-active', vpn.unit]);
                    if (!this._alive || vpn.changing)
                        return;
                    this._applying = true;
                    vpn.item.setToggleState(result.ok && result.stdout === 'active');
                    this._applying = false;
                    vpn.item.setSensitive(['active', 'inactive', 'failed'].includes(result.stdout));
                }),
            ]);
        } finally {
            this._refreshing = false;
            if (this._refreshAgain && this._alive) {
                this._refreshAgain = false;
                this._refresh();
            }
        }
    }

    destroy() {
        this._alive = false;
        if (this._pollId)
            GLib.Source.remove(this._pollId);
        this._pollId = null;
        this._cancellable.cancel();
        for (const proc of this._processes)
            proc.force_exit();
        this._processes.clear();
        super.destroy();
    }
});

export default class ProxyModeExtension extends Extension {
    enable() {
        this._indicator = new VpnMenu();
        Main.panel.addToStatusArea(this.uuid, this._indicator);
    }

    disable() {
        this._indicator?.destroy();
        this._indicator = null;
    }
}
