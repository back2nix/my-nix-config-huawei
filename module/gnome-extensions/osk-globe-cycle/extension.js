// Две независимые проблемы экранной клавиатуры GNOME, обе чинятся здесь.
//
// 1. Кнопка-глобус открывает LanguageSelectionPopup (ui/keyboard.js), который
//    добавляется через Main.layoutManager.addTopChrome. В модальных диалогах
//    (Alt+F2, экран блокировки, polkit) Main.pushModal делает
//    global.stage.grab(dialog) — захват ограничен поддеревом диалога, и попап,
//    лежащий вне его, не получает событий касания. Клавиши самой OSK при этом
//    работают, поэтому переключаем раскладку прямо в обработчике клавиши,
//    не открывая меню. Логика цикла повторяет
//    InputSourceManager._modifiersSwitcher() из ui/status/keyboard.js.
//
// 2. В терминале (content purpose = TERMINAL) _updateLayout ищет раскладку
//    "<группа>-extended". В gnome-shell есть только at/de/us/za-extended,
//    поэтому для русского всегда срабатывал фолбэк на us-extended — в консоли
//    клавиатура оставалась английской при любой выбранной раскладке.
//    Регистрируем собственный GResource с ru-extended.json: KeyboardModel
//    грузит раскладки обычным resource:// URI, так что патчить код не нужно.

import Gio from 'gi://Gio';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import {Keyboard} from 'resource:///org/gnome/shell/ui/keyboard.js';
import * as InputSourceManager from 'resource:///org/gnome/shell/ui/status/keyboard.js';

export default class OskGlobeCycleExtension extends Extension {
    enable() {
        this._resource = Gio.Resource.load(`${this.path}/osk-layouts.gresource`);
        Gio.resources_register(this._resource);

        this._originalPopupLanguageMenu = Keyboard.prototype._popupLanguageMenu;

        Keyboard.prototype._popupLanguageMenu = function () {
            const manager = InputSourceManager.getInputSourceManager();
            const sourceIndexes = Object.keys(manager.inputSources);
            if (sourceIndexes.length < 2)
                return;

            const current = manager.currentSource ?? manager.inputSources[sourceIndexes[0]];

            let nextIndex = current.index + 1;
            if (nextIndex > sourceIndexes[sourceIndexes.length - 1])
                nextIndex = 0;

            let next;
            while (!(next = manager.inputSources[nextIndex]))
                nextIndex += 1;

            next.activate(true);
        };
    }

    disable() {
        Keyboard.prototype._popupLanguageMenu = this._originalPopupLanguageMenu;
        this._originalPopupLanguageMenu = null;

        Gio.resources_unregister(this._resource);
        this._resource = null;
    }
}
