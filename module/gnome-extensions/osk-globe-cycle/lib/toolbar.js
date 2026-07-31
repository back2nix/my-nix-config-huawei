// Панель кнопок: перемещение, изменение размера, замок.
//
// Расположение. Панель — САМОСТОЯТЕЛЬНЫЙ элемент поверх экрана
// (Main.layoutManager.addTopChrome), а не ребёнок клавиатуры. Так и должно
// быть: её место — сбоку ОТ клавиатуры, во внешней области.
//
// Прежние попытки вложить её внутрь не работали. Ребёнком Keyboard она
// отбирала высоту у сетки клавиш (Keyboard — вертикальный St.BoxLayout,
// любой ребёнок становится строкой). Ребёнком _aspectContainer с выносом
// через translation_x она оставалась внутри области клавиш и перекрывала их:
// AspectContainer сужает собственную аллокацию до пропорции раскладки, и
// вложенный актёр живёт в этих же границах. Единственный способ оказаться
// снаружи — не быть ребёнком вовсе.
//
// Позицию задаёт lib/floating.js через updatePosition(): он знает реальную
// экранную геометрию области клавиш (с учётом сдвига и масштаба) и ставит
// колонку справа от неё, а если справа не помещается — слева.
//
// Нажатия панель не обрабатывает — их разбирает Floating по координатам.
// Полагаться на St.Button нельзя: в модальных диалогах (Alt+F2, экран
// блокировки) события доставляются в обход цепочки актёров через
// Main.keyboard.maybeHandleEvent() → actor.event(), и внутренняя механика
// кнопки не срабатывает.

import Clutter from 'gi://Clutter';
import St from 'gi://St';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';

// Иконки проверены по установленной теме Adwaita.
const ICON_MOVE = 'list-drag-handle-symbolic';
const ICON_RESIZE = 'zoom-fit-best-symbolic';
const ICON_LOCKED = 'changes-prevent-symbolic';
const ICON_UNLOCKED = 'changes-allow-symbolic';

// Зазор между клавишами и колонкой кнопок.
const GAP = 10;

const BUTTON_BASE =
    'padding: 8px; border-radius: 8px; background-color: rgba(70, 70, 70, 0.9);';
const BUTTON_ACTIVE =
    'padding: 8px; border-radius: 8px; background-color: rgba(120, 170, 255, 0.85);';

export class Toolbar {
    constructor() {
        this._box = null;
        this._buttons = null;
        this._state = {move: false, resize: false, locked: false};
    }

    /**
     * Актёр панели.
     *
     * @returns {object|null}
     */
    get actor() {
        return this._box;
    }

    /**
     * Построить панель. Вызывается на каждый новый экземпляр Keyboard
     * (KeyboardManager._syncEnabled() пересоздаёт его при каждом включении).
     */
    attach() {
        this.destroy();

        this._box = new St.BoxLayout({
            style_class: 'osk-toolbar',
            orientation: Clutter.Orientation.VERTICAL,
            reactive: true,
            style: 'spacing: 8px; padding: 8px; '
                + 'background-color: rgba(48, 48, 48, 0.95); '
                + 'border-radius: 12px;',
        });

        this._buttons = {
            move: this._addButton(ICON_MOVE),
            resize: this._addButton(ICON_RESIZE),
            lock: this._addButton(ICON_UNLOCKED),
        };

        // Верхний слой поверх окон, вне поддерева клавиатуры.
        Main.layoutManager.addTopChrome(this._box);
        this._box.hide();

        this._sync();
    }

    /**
     * Поставить колонку сбоку от области клавиш.
     *
     * @param {object|null} keys экранная геометрия клавиш {x, y, width, height}
     * @param {object|null} monitor монитор клавиатуры
     * @param {boolean} visible показана ли клавиатура
     */
    updatePosition(keys, monitor, visible) {
        if (!this._box)
            return;

        if (!visible || !keys || !monitor || keys.width <= 0) {
            this._box.hide();
            return;
        }

        const [, width] = this._box.get_preferred_width(-1);
        const [, height] = this._box.get_preferred_height(-1);

        // Справа от клавиш, а если там не помещается — слева.
        let x = keys.x + keys.width + GAP;
        if (x + width > monitor.x + monitor.width)
            x = keys.x - GAP - width;

        // Совсем не поместилось ни с одной стороны — прижимаем к краю,
        // лишь бы кнопки оставались доступны.
        x = Math.min(Math.max(x, monitor.x),
            monitor.x + monitor.width - width);

        // По вертикали — по верхней кромке клавиш, не вылезая за монитор.
        let y = keys.y;
        y = Math.min(Math.max(y, monitor.y),
            monitor.y + monitor.height - height);

        this._box.set_position(Math.round(x), Math.round(y));
        this._box.show();
    }

    /**
     * Какая кнопка находится под точкой экрана.
     *
     * @param {number} x координата в системе стейджа
     * @param {number} y координата в системе стейджа
     * @returns {string|null} 'move' | 'resize' | 'lock' | null
     */
    hitTest(x, y) {
        if (!this._buttons || !this._box?.visible)
            return null;

        for (const [name, button] of Object.entries(this._buttons)) {
            const [bx, by] = button.get_transformed_position();
            const [bw, bh] = button.get_transformed_size();
            if (Number.isFinite(bx) && x >= bx && x <= bx + bw &&
                y >= by && y <= by + bh)
                return name;
        }

        return null;
    }

    /**
     * Отразить текущее состояние на кнопках.
     *
     * @param {object} state частичное состояние {move, resize, locked}
     */
    setState(state) {
        Object.assign(this._state, state);
        this._sync();
    }

    destroy() {
        if (this._box) {
            Main.layoutManager.removeChrome(this._box);
            this._box.destroy();
        }
        this._box = null;
        this._buttons = null;
    }

    _addButton(iconName) {
        // St.Bin, а не St.Button: нажатия разбирает Floating.
        const button = new St.Bin({
            style_class: 'osk-toolbar-button',
            reactive: true,
            child: new St.Icon({icon_name: iconName, icon_size: 22}),
            style: BUTTON_BASE,
        });

        this._box.add_child(button);
        return button;
    }

    _sync() {
        if (!this._buttons)
            return;

        this._buttons.move.style =
            this._state.move ? BUTTON_ACTIVE : BUTTON_BASE;
        this._buttons.resize.style =
            this._state.resize ? BUTTON_ACTIVE : BUTTON_BASE;
        this._buttons.lock.style =
            this._state.locked ? BUTTON_ACTIVE : BUTTON_BASE;

        this._buttons.lock.child.icon_name =
            this._state.locked ? ICON_LOCKED : ICON_UNLOCKED;
    }
}
