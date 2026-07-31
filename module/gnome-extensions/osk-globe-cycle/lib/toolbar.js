// Полоска кнопок над клавиатурой: перемещение, изменение размера, замок.
//
// Кнопки живут отдельной строкой внутри самого актёра Keyboard, первым
// ребёнком — до _suggestions и _aspectContainer. Вкладывать их в
// _aspectContainer нельзя: тот подгоняет содержимое под соотношение сторон
// раскладки и растянул бы иконки вместе с клавишами.
//
// Keyboard пересоздаётся при каждом включении экранной клавиатуры
// (KeyboardManager._syncEnabled), поэтому панель строится заново в attach()
// на каждый экземпляр, а прежняя уничтожается.

import Clutter from 'gi://Clutter';
import St from 'gi://St';

// Иконки проверены по установленной теме Adwaita.
const ICON_MOVE = 'list-drag-handle-symbolic';
const ICON_RESIZE = 'zoom-fit-best-symbolic';
const ICON_LOCKED = 'changes-prevent-symbolic';
const ICON_UNLOCKED = 'changes-allow-symbolic';

export class Toolbar {
    /**
     * @param {object} handlers обработчики нажатий
     * @param {() => void} handlers.onMove   переключить режим перемещения
     * @param {() => void} handlers.onResize переключить режим масштабирования
     * @param {() => void} handlers.onLock   переключить замок физической клавиатуры
     */
    constructor({onMove, onResize, onLock}) {
        this._handlers = {onMove, onResize, onLock};
        this._box = null;
        this._buttons = null;
        this._state = {move: false, resize: false, locked: false};
    }

    /**
     * Актёр панели — нужен Floating, чтобы пропускать её нажатия мимо
     * перехватчика касаний.
     *
     * @returns {object|null}
     */
    get actor() {
        return this._box;
    }

    /**
     * Построить панель в новом экземпляре клавиатуры.
     *
     * @param {object} keyboard экземпляр Keyboard
     */
    attach(keyboard) {
        this.destroy();

        if (!keyboard)
            return;

        this._box = new St.BoxLayout({
            style_class: 'osk-toolbar',
            x_align: Clutter.ActorAlign.CENTER,
            // Панель не должна съедать высоту у клавиш: строка фиксированная,
            // всё лишнее место по-прежнему достаётся _aspectContainer.
            y_expand: false,
            reactive: true,
            // Свой фон: заливку актёра Keyboard мы снимаем (иначе она
            // растягивается во всю ширину монитора), поэтому панель должна
            // рисовать подложку сама, ровно под собой.
            style: 'spacing: 12px; padding: 6px 10px; '
                + 'background-color: rgba(48, 48, 48, 0.95); '
                + 'border-radius: 10px;',
        });

        this._buttons = {
            move: this._addButton(ICON_MOVE, 'Переместить клавиатуру',
                this._handlers.onMove),
            resize: this._addButton(ICON_RESIZE, 'Изменить размер щипком',
                this._handlers.onResize),
            lock: this._addButton(ICON_UNLOCKED, 'Заблокировать физическую клавиатуру',
                this._handlers.onLock),
        };

        keyboard.insert_child_at_index(this._box, 0);
        this._sync();
    }

    /**
     * Отразить текущие режимы на кнопках.
     *
     * @param {object} state частичное состояние {move, resize, locked}
     */
    setState(state) {
        Object.assign(this._state, state);
        this._sync();
    }

    destroy() {
        this._box?.destroy();
        this._box = null;
        this._buttons = null;
    }

    _addButton(iconName, tooltip, onClicked) {
        const button = new St.Button({
            style_class: 'osk-toolbar-button',
            can_focus: false,
            // Клавиатура не забирает фокус ввода, и кнопки не должны тоже —
            // иначе набор уходит не в то окно.
            child: new St.Icon({icon_name: iconName, icon_size: 20}),
            accessible_name: tooltip,
            style: 'padding: 6px; border-radius: 6px;',
        });

        button.connect('clicked', () => {
            onClicked?.();
            return Clutter.EVENT_STOP;
        });

        this._box.add_child(button);
        return button;
    }

    _sync() {
        if (!this._buttons)
            return;

        // Активный режим подсвечиваем инлайновым стилем: у панели нет своего
        // css в теме оболочки, а таскать с расширением stylesheet ради трёх
        // кнопок не хочется.
        const mark = (button, active) => {
            button.style = active
                ? 'padding: 6px; border-radius: 6px; background-color: rgba(120,170,255,0.45);'
                : 'padding: 6px; border-radius: 6px;';
        };

        mark(this._buttons.move, this._state.move);
        mark(this._buttons.resize, this._state.resize);
        mark(this._buttons.lock, this._state.locked);

        this._buttons.lock.child.icon_name =
            this._state.locked ? ICON_LOCKED : ICON_UNLOCKED;
        this._buttons.lock.accessible_name = this._state.locked
            ? 'Разблокировать физическую клавиатуру'
            : 'Заблокировать физическую клавиатуру';
    }
}
