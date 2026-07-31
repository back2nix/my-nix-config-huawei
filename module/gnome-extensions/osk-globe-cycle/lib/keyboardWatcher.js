// Доступ к экземплярам Keyboard.
//
// KeyboardManager пересоздаёт Keyboard при каждом включении экранной
// клавиатуры (смена устройства ввода, переключение touch-mode) и наружу
// ссылку не отдаёт. Публичного сигнала «клавиатура создана» тоже нет,
// поэтому оборачиваем _init прототипа — так уведомление приходит до того,
// как клавиатура успевает построить раскладку.

import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import {Keyboard} from 'resource:///org/gnome/shell/ui/keyboard.js';

export class KeyboardWatcher {
    /**
     * @param {(keyboard: object) => void} onKeyboard вызывается для каждой клавиатуры
     */
    constructor(onKeyboard) {
        this._onKeyboard = onKeyboard;
        this._originalInit = null;
    }

    start() {
        if (this._originalInit)
            return;

        const notify = this._onKeyboard;
        const original = Keyboard.prototype._init;
        this._originalInit = original;

        Keyboard.prototype._init = function (...args) {
            original.apply(this, args);
            notify(this);
        };

        // Клавиатура могла быть создана до включения расширения.
        const existing = Main.keyboard?._keyboard;
        if (existing)
            notify(existing);
    }

    stop() {
        if (!this._originalInit)
            return;

        Keyboard.prototype._init = this._originalInit;
        this._originalInit = null;
    }
}
