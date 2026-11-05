// Ввод и замена слова через KeyboardController.
//
// Замена делается забоями, а не Main.inputMethod.delete_surrounding(): текст
// вокруг курсора отдают далеко не все приложения (в частности X11-клиенты без
// IM-фокуса), а BackSpace понимают все. Цена — N событий клавиатуры на одну
// замену, что для слова из десятка букв незаметно.

import Clutter from 'gi://Clutter';

/** Слово всегда вводится с завершающим пробелом, как на телефоне. */
const TRAILING = ' ';

export class WordWriter {
    /**
     * @param {object} keyboard экземпляр gnome-shell Keyboard
     */
    constructor(keyboard) {
        this._keyboard = keyboard;
        this._written = null;
    }

    /** @returns {string|null} последнее введённое свайпом слово, если его ещё можно заменить */
    get lastWritten() {
        return this._written;
    }

    /** Забывает последнее слово: дальше заменять нечего (пользователь печатал сам). */
    forget() {
        this._written = null;
    }

    /**
     * @param {string} word
     * @returns {Promise<void>}
     */
    async write(word) {
        const text = this._applyShift(word) + TRAILING;

        await this._controller.commit(text);
        this._written = text;

        // Штатное поведение после ввода: снять Shift и пересчитать уровень
        // по подсказкам поля ввода.
        this._keyboard._updateLevelFromHints?.(true);
    }

    /**
     * @param {string} word
     * @returns {Promise<void>}
     */
    async replace(word) {
        if (this._written === null) {
            await this.write(word);
            return;
        }

        const written = this._written;
        this._written = null;

        for (let i = 0; i < [...written].length; i++)
            this._pressBackspace();

        await this.write(word);
    }

    /** @returns {object} KeyboardController текущей клавиатуры */
    get _controller() {
        return this._keyboard._keyboardController;
    }

    _pressBackspace() {
        this._controller.keyvalPress(Clutter.KEY_BackSpace);
        this._controller.keyvalRelease(Clutter.KEY_BackSpace);
    }

    /**
     * Свайп по клавиатуре в верхнем регистре означает слово с большой буквы:
     * весь текст капсом свайпом всё равно не набирают.
     *
     * @param {string} word
     * @returns {string}
     */
    _applyShift(word) {
        const shiftLayer = this._keyboard._layers?.shift;
        if (!shiftLayer || this._keyboard._currentPage !== shiftLayer)
            return word;

        return word.charAt(0).toUpperCase() + word.slice(1);
    }
}
