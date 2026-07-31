// Точка входа: доработки экранной клавиатуры GNOME.
//
//   lib/oskLayouts.js  — ru-extended.json для полей ввода TERMINAL;
//   lib/globeCycle.js  — глобус переключает раскладку без меню;
//   lib/swipe/         — ввод слов ведением пальца по клавиатуре;
//   lib/floating.js    — плавающее окно вместо полосы во всю ширину,
//                        перетаскивание и масштабирование щипком;
//   lib/toolbar.js     — кнопки режимов над клавишами;
//   lib/kbdLock.js     — замок физической клавиатуры (EVIOCGRAB).
//
// Каждая живёт своим модулем и включается независимо; здесь только сборка
// и проброс настроек.

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

import * as Log from './lib/log.js';

import {Floating} from './lib/floating.js';
import {GlobeCycle} from './lib/globeCycle.js';
import {KbdLock} from './lib/kbdLock.js';
import {KeyboardWatcher} from './lib/keyboardWatcher.js';
import {OskLayouts} from './lib/oskLayouts.js';
import {SwipeTyping} from './lib/swipe/swipeTyping.js';
import {Toolbar} from './lib/toolbar.js';

export default class OskGlobeCycleExtension extends Extension {
    enable() {
        this._settings = this.getSettings();

        this._layouts = new OskLayouts(this.path);
        this._layouts.enable();

        this._globeCycle = new GlobeCycle();
        this._globeCycle.enable();

        // Панель создаётся первой: и Floating, и KbdLock сообщают в неё
        // состояние, причём KbdLock может сделать это уже из enable().
        this._toolbar = new Toolbar({
            onMove: () => this._floating.toggleMove(),
            onResize: () => this._floating.toggleResize(),
            onLock: () => this._kbdLock.toggle(),
        });

        this._floating = new Floating(this._settings,
            state => this._toolbar.setState(state));
        this._floating.enable();

        this._kbdLock = new KbdLock(this._settings, this.path,
            locked => this._toolbar.setState({locked}));
        this._kbdLock.enable();

        this._swipeTyping = null;

        // Watcher теперь общий: от «клавиатура создана» зависят и свайп,
        // и панель кнопок, и геометрия. Поэтому он живёт всё время работы
        // расширения, а не только при включённом свайпе.
        this._watcher = new KeyboardWatcher(keyboard => {
            this._floating.attach(keyboard);
            this._toolbar.attach(keyboard);
            // Панель строится заново на каждую клавиатуру, поэтому и ссылку
            // на её актёр обновляем здесь же.
            this._floating.setToolbar(this._toolbar.actor);
            this._toolbar.setState({
                move: this._floating.isMoveMode,
                resize: this._floating.isResizeMode,
                locked: this._kbdLock.isLocked,
            });
            this._swipeTyping?.attach(keyboard);
        });
        this._watcher.start();

        this._settings.connectObject(
            'changed::debug', () => this._syncDebug(),
            'changed::swipe-typing', () => this._syncSwipeTyping(),
            this);

        this._syncDebug();
        this._syncSwipeTyping();
    }

    disable() {
        this._settings.disconnectObject(this);
        this._settings = null;

        this._watcher.stop();
        this._watcher = null;

        this._swipeTyping?.destroy();
        this._swipeTyping = null;

        this._toolbar.destroy();
        this._toolbar = null;

        // Замок снимаем раньше остального: оставить физическую клавиатуру
        // захваченной после выключения расширения — значит запереть себя.
        this._kbdLock.disable();
        this._kbdLock = null;

        this._floating.disable();
        this._floating = null;

        this._globeCycle.disable();
        this._globeCycle = null;

        this._layouts.disable();
        this._layouts = null;
    }

    _syncDebug() {
        Log.setDebug(this._settings.get_boolean('debug'));
    }

    _syncSwipeTyping() {
        const enabled = this._settings.get_boolean('swipe-typing');

        if (enabled === !!this._swipeTyping)
            return;

        if (enabled) {
            this._swipeTyping = new SwipeTyping(`${this.path}/dictionaries`);
            // Клавиатура могла быть создана до включения свайпа.
            const existing = this._watcher.currentKeyboard;
            if (existing)
                this._swipeTyping.attach(existing);
        } else {
            this._swipeTyping.destroy();
            this._swipeTyping = null;
        }
    }
}
