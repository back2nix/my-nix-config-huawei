// Русская раскладка для полей ввода с purpose = TERMINAL.
//
// _updateLayout() ищет раскладку "<группа>-extended". В gnome-shell есть
// только at/de/us/za-extended, поэтому для русского всегда срабатывал фолбэк
// на us-extended — в консоли клавиатура оставалась английской при любой
// выбранной раскладке. Регистрируем собственный GResource с ru-extended.json:
// KeyboardModel грузит раскладки обычным resource:// URI, так что патчить
// код не нужно.

import Gio from 'gi://Gio';

export class OskLayouts {
    /**
     * @param {string} path каталог расширения
     */
    constructor(path) {
        this._path = path;
        this._resource = null;
    }

    enable() {
        if (this._resource)
            return;

        this._resource = Gio.Resource.load(`${this._path}/osk-layouts.gresource`);
        Gio.resources_register(this._resource);
    }

    disable() {
        if (!this._resource)
            return;

        Gio.resources_unregister(this._resource);
        this._resource = null;
    }
}
