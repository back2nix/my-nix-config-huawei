// Точка входа: три независимые доработки экранной клавиатуры GNOME.
//
//   lib/oskLayouts.js  — ru-extended.json для полей ввода TERMINAL;
//   lib/globeCycle.js  — глобус переключает раскладку без меню;
//   lib/swipe/         — ввод слов ведением пальца по клавиатуре.
//
// Каждая живёт своим модулем и включается независимо; здесь только сборка
// и проброс настроек.

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

import * as Log from './lib/log.js';

import {GlobeCycle} from './lib/globeCycle.js';
import {KeyboardWatcher} from './lib/keyboardWatcher.js';
import {OskLayouts} from './lib/oskLayouts.js';
import {SwipeTyping} from './lib/swipe/swipeTyping.js';

export default class OskGlobeCycleExtension extends Extension {
    enable() {
        this._settings = this.getSettings();

        this._layouts = new OskLayouts(this.path);
        this._layouts.enable();

        this._globeCycle = new GlobeCycle();
        this._globeCycle.enable();

        this._swipeTyping = null;
        this._watcher = new KeyboardWatcher(
            keyboard => this._swipeTyping?.attach(keyboard));

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
            this._watcher.start();
        } else {
            this._watcher.stop();
            this._swipeTyping.destroy();
            this._swipeTyping = null;
        }
    }
}
