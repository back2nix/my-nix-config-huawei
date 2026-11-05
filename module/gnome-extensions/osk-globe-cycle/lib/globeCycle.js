// Кнопка-глобус переключает раскладку напрямую, без меню выбора языка.
//
// Штатный _popupLanguageMenu() показывает LanguageSelectionPopup, который
// добавляется через Main.layoutManager.addTopChrome. В модальных диалогах
// (Alt+F2, экран блокировки, polkit) Main.pushModal делает
// global.stage.grab(dialog) — захват ограничен поддеревом диалога, и попап,
// лежащий вне его, не получает событий касания. Сами клавиши OSK при этом
// работают, поэтому переключаем раскладку прямо в обработчике клавиши.
//
// Логика цикла повторяет InputSourceManager._modifiersSwitcher()
// из ui/status/keyboard.js.

import {Keyboard} from 'resource:///org/gnome/shell/ui/keyboard.js';
import * as InputSourceManager from 'resource:///org/gnome/shell/ui/status/keyboard.js';

/**
 * Следующий источник ввода по кругу.
 *
 * @param {object} manager InputSourceManager
 * @returns {object|null}
 */
function nextInputSource(manager) {
    const indexes = Object.keys(manager.inputSources);
    if (indexes.length < 2)
        return null;

    const current = manager.currentSource ?? manager.inputSources[indexes[0]];
    const last = indexes[indexes.length - 1];

    let index = current.index + 1;
    if (index > last)
        index = 0;

    // Индексы источников не обязаны идти подряд: удалённая раскладка
    // оставляет дыру в нумерации.
    let source;
    while (!(source = manager.inputSources[index]))
        index += 1;

    return source;
}

export class GlobeCycle {
    constructor() {
        this._originalPopup = null;
    }

    enable() {
        if (this._originalPopup)
            return;

        this._originalPopup = Keyboard.prototype._popupLanguageMenu;

        Keyboard.prototype._popupLanguageMenu = function () {
            nextInputSource(InputSourceManager.getInputSourceManager())?.activate(true);
        };
    }

    disable() {
        if (!this._originalPopup)
            return;

        Keyboard.prototype._popupLanguageMenu = this._originalPopup;
        this._originalPopup = null;
    }
}
