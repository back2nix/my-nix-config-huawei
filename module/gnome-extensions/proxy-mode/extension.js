// Плитка «Прокси 1082» в Quick Settings: выбор маршрута для портов
// 1082/1083 из списка, а не тумблером.
//
// Почему своё расширение, а не custom-command-toggle (которым сделаны
// WinJoy VPN, Personal VPN и режим портфеля): то расширение умеет только
// QuickToggle — бинарную плитку. Вариантов здесь несколько, и раскладывать их
// по трём независимым тумблерам — врать глазу: состояния взаимоисключающие.
// Нужен QuickMenuToggle, а его custom-command-toggle не предоставляет.
//
// Вся логика переключения живёт в CLI proxy-mode (module/proxy-mode.nix),
// здесь только GUI: расширение ничего не знает ни про Clash-API, ни про
// теги outbound'ов sing-box. Обновить список режимов — значит поправить
// MODES здесь и case в скрипте, больше нигде.

import GLib from 'gi://GLib';
import Gio from 'gi://Gio';
import GObject from 'gi://GObject';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';
import {QuickMenuToggle, SystemIndicator} from 'resource:///org/gnome/shell/ui/quickSettings.js';

// Путь до CLI подставляется при сборке (module/proxy-mode.nix): PATH у
// gnome-shell наследуется от сессии и на «своё» из systemPackages
// полагаться нельзя — расширение молча переставало бы работать.
const PROXY_MODE = '@proxyMode@';

// Порядок здесь — порядок пунктов в меню. `id` совпадает с аргументом
// CLI, `status` — с тем, что печатает `proxy-mode status`.
const MODES = [
    {id: 'seoul',  status: 'SEOUL',  label: 'Через USA',    icon: 'network-vpn-symbolic'},
    {id: 'casino', status: 'CASINO', label: 'Через Casino', icon: 'network-vpn-symbolic'},
    {id: 'frankfurt', status: 'FRANKFURT', label: 'Через Frankfurt', icon: 'network-vpn-symbolic'},
    {id: 'direct', status: 'DIRECT', label: 'Без VPN',      icon: 'network-wired-symbolic'},
];

// Режим по умолчанию: он же то, что показываем при недоступном sing-box,
// и он же «нормальное» состояние, при котором индикатор в топ-баре молчит.
const DEFAULT_MODE = MODES[0];

const POLL_SECONDS = 10;

// Асинхронно, потому что синхронный spawn в gnome-shell — это фриз всего
// шелла на время работы команды, а curl тут с таймаутом до 3 секунд.
function runAsync(argv, onDone) {
    let proc;
    try {
        proc = Gio.Subprocess.new(argv, Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_SILENCE);
    } catch (e) {
        logError(e, 'proxy-mode: не удалось запустить ' + argv.join(' '));
        onDone(null);
        return;
    }

    proc.communicate_utf8_async(null, null, (source, result) => {
        try {
            const [, stdout] = source.communicate_utf8_finish(result);
            onDone(stdout ? stdout.trim() : '');
        } catch (e) {
            logError(e, 'proxy-mode: ' + argv.join(' '));
            onDone(null);
        }
    });
}

const ProxyModeToggle = GObject.registerClass({
    // Своим сигналом, а не notify::checked/icon-name: переход
    // casino -> seoul не меняет ни того, ни другого (оба «в тоннеле», иконка
    // одна), и индикатор в топ-баре так бы и висел от предыдущего режима.
    Signals: {'mode-changed': {}},
},
class ProxyModeToggle extends QuickMenuToggle {
    _init() {
        super._init({
            title: 'Прокси 1082',
            iconName: DEFAULT_MODE.icon,
            // Плитка — не выключатель: любой из режимов «включён», просто
            // разный. Поэтому клик по всему телу плитки открывает список,
            // а не переключает что-то втихую.
            toggleMode: false,
        });

        // При toggleMode: false клик по телу плитки сам по себе не делает
        // ничего — меню открывает только стрелка справа. Плитка тут вся
        // целиком про выбор, поэтому открываем список по любому клику.
        this.connect('clicked', () => this.menu.open());

        this.menu.setHeader('network-vpn-symbolic', 'Прокси 1082/1083',
            'Через что идёт трафик на портах 1082 и 1083');

        this._items = new Map();
        for (const mode of MODES) {
            const item = new PopupMenu.PopupMenuItem(mode.label);
            item.connect('activate', () => this._select(mode));
            this.menu.addMenuItem(item);
            this._items.set(mode.id, item);
        }

        // Реальное состояние живёт в sing-box, а не в памяти расширения:
        // режим могли сменить из терминала, а сам sing-box — рестартовать.
        // Поэтому опрашиваем, а не запоминаем свой последний клик.
        this.menu.connect('open-state-changed', (menu, isOpen) => {
            if (isOpen)
                this._refresh();
        });

        this._current = null;
        this._refresh();
        this._pollId = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, POLL_SECONDS, () => {
            this._refresh();
            return GLib.SOURCE_CONTINUE;
        });

        this.connect('destroy', () => {
            if (this._pollId) {
                GLib.Source.remove(this._pollId);
                this._pollId = null;
            }
        });
    }

    _select(mode) {
        // Показываем выбор сразу, не дожидаясь ответа: иначе пункт
        // подсвечивается только через секунду и кажется, что клик не прошёл.
        // Если переключение не удастся, ближайший опрос вернёт правду.
        this._apply(mode.id);
        runAsync([PROXY_MODE, mode.id], () => this._refresh());
    }

    _refresh() {
        runAsync([PROXY_MODE, 'status'], out => {
            const mode = MODES.find(m => m.status === out);
            // UNKNOWN (sing-box недоступен) и любой неизвестный ответ —
            // не режим, а поломка: не врём галочкой, снимаем все.
            this._apply(mode ? mode.id : null);
        });
    }

    _apply(id) {
        this._current = id;
        const mode = MODES.find(m => m.id === id);

        for (const [modeId, item] of this._items) {
            item.setOrnament(modeId === id
                ? PopupMenu.Ornament.CHECK
                : PopupMenu.Ornament.NO_DOT);
        }

        this.subtitle = mode ? mode.label : 'недоступен';
        this.iconName = mode ? mode.icon : 'network-offline-symbolic';
        // «Включено» = трафик в тоннеле. Режим без VPN и потерянный
        // sing-box гасят плитку — это и есть сигнал «идёшь не туда».
        this.checked = !!mode && mode.id !== 'direct';

        this.emit('mode-changed');
    }

    get currentMode() {
        return this._current;
    }
});

const ProxyModeIndicator = GObject.registerClass(
class ProxyModeIndicator extends SystemIndicator {
    _init() {
        super._init();

        this._toggle = new ProxyModeToggle();
        this.quickSettingsItems.push(this._toggle);

        // Индикатор в топ-баре — ради режима «без VPN»: забытым он
        // означает трафик мимо тоннеля, о котором не знаешь. На дефолтном
        // маршруте не мозолим глаза и прячемся.
        this._icon = this._addIndicator();
        this._toggle.connect('mode-changed', () => this._sync());
        this._sync();
    }

    _sync() {
        const mode = this._toggle.currentMode;
        this._icon.icon_name = this._toggle.iconName;
        this._icon.visible = mode !== DEFAULT_MODE.id;
    }
});

export default class ProxyModeExtension extends Extension {
    enable() {
        this._indicator = new ProxyModeIndicator();
        Main.panel.statusArea.quickSettings.addExternalIndicator(this._indicator);
    }

    disable() {
        this._indicator.quickSettingsItems.forEach(item => item.destroy());
        this._indicator.destroy();
        this._indicator = null;
    }
}
