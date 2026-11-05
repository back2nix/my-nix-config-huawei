// Распознавание жеста «ведение пальцем» поверх штатной обработки клавиш.
//
// Key._makeKey() вешает обработчик touch-event прямо на кнопку и всегда
// возвращает EVENT_STOP, поэтому перехватываться нужно раньше — на фазе
// capture у актёра клавиатуры.
//
// Состояния:
//   IDLE     — ждём касания буквенной клавиши;
//   TRACKING — палец опущен, копим точки, событий не глушим (обычный тап
//              обязан продолжать работать);
//   SWIPING  — жест признан свайпом, дальше события до клавиш не доходят.
//
// Переход TRACKING → SWIPING требует одновременно смещения и второй
// задетой клавиши. Одного смещения мало: у клавиатуры есть собственный
// жест «смахнуть вниз, чтобы скрыть», и он начинается тем же движением.

import Clutter from 'gi://Clutter';

import {distance, simplify} from './geometry.js';
import {KeyMap} from './keyMap.js';

/** @typedef {import('./geometry.js').Point} Point */

/** Смещение для перехода в свайп, в ширинах клавиши. */
const ENGAGE_DISTANCE = 0.75;

/** Минимум различных буквенных клавиш под пальцем, чтобы это был свайп. */
const ENGAGE_KEYS = 2;

/** Прореживание точек, в ширинах клавиши. */
const MIN_STEP = 0.08;

const State = {
    IDLE: 'idle',
    TRACKING: 'tracking',
    SWIPING: 'swiping',
};

/**
 * @param {object} event
 * @returns {Point}
 */
function coordsOf(event) {
    const [x, y] = event.get_coords();
    return {x, y};
}

/**
 * Снимает нажатие, которое клавиша успела зарегистрировать до того,
 * как движение стало свайпом.
 *
 * Key.cancel() гасит таймер долгого нажатия и подсветку, но не сбрасывает
 * _pressed — рассчитано на то, что следом придёт _release. У нас его не
 * будет (TOUCH_END мы проглатываем), поэтому флаг снимаем сами.
 *
 * @param {object} key актёр Key
 */
function cancelKeyPress(key) {
    key.cancel();
    key._pressed = false;
}

export class GestureTracker {
    /**
     * @param {object} keyboard экземпляр gnome-shell Keyboard
     * @param {object} handlers
     * @param {(path: Point[], keyMap: KeyMap) => void} handlers.onSwipe жест завершён свайпом
     * @param {() => void} handlers.onTap касание оказалось обычным нажатием клавиши
     */
    constructor(keyboard, {onSwipe, onTap}) {
        this._keyboard = keyboard;
        this._onSwipe = onSwipe;
        this._onTap = onTap;

        this._state = State.IDLE;
        this._slot = null;
        this._keyMap = null;
        this._origin = null;
        this._points = [];
        this._visited = new Set();
        this._pressedKey = null;

        this._handlerId = keyboard.connect(
            'captured-event', this._onCapturedEvent.bind(this));
    }

    destroy() {
        if (this._handlerId) {
            this._keyboard.disconnect(this._handlerId);
            this._handlerId = 0;
        }
        this._reset();
    }

    _reset() {
        this._state = State.IDLE;
        this._slot = null;
        this._keyMap = null;
        this._origin = null;
        this._points = [];
        this._visited = new Set();
        this._pressedKey = null;
    }

    _onCapturedEvent(_actor, event) {
        switch (event.type()) {
        case Clutter.EventType.TOUCH_BEGIN:
            return this._onBegin(event);
        case Clutter.EventType.TOUCH_UPDATE:
            return this._onUpdate(event);
        case Clutter.EventType.TOUCH_END:
            return this._onEnd(event);
        case Clutter.EventType.TOUCH_CANCEL:
            this._reset();
            return Clutter.EVENT_PROPAGATE;
        default:
            return Clutter.EVENT_PROPAGATE;
        }
    }

    _onBegin(event) {
        // Мультитач не поддерживаем: второй палец во время жеста отменяет его,
        // иначе точки двух касаний склеятся в одну бессмысленную траекторию.
        if (this._state !== State.IDLE) {
            this._reset();
            return Clutter.EVENT_PROPAGATE;
        }

        const page = this._keyboard._currentPage;
        if (!page)
            return Clutter.EVENT_PROPAGATE;

        const keyMap = KeyMap.fromPage(page);
        if (!keyMap.isUsable)
            return Clutter.EVENT_PROPAGATE;

        const point = coordsOf(event);
        const key = keyMap.keyAt(point);

        // Жест начинается только с буквы. Пробел, Shift и Backspace остаются
        // за штатной обработкой вместе со всеми их долгими нажатиями.
        if (!key)
            return Clutter.EVENT_PROPAGATE;

        this._state = State.TRACKING;
        this._slot = event.get_event_sequence().get_slot();
        this._keyMap = keyMap;
        this._origin = point;
        this._points = [point];
        this._visited = new Set([key.char]);
        this._pressedKey = this._keyActorAt(event);

        return Clutter.EVENT_PROPAGATE;
    }

    /**
     * Актёр Key, которому Clutter отдал касание. Нужен, чтобы отменить
     * подсветку и таймер долгого нажатия при переходе в свайп.
     *
     * @param {object} event
     * @returns {object|null}
     */
    _keyActorAt(event) {
        let actor = global.stage.get_event_actor(event);

        while (actor && actor !== this._keyboard) {
            if (actor.keyButton)
                return actor;
            actor = actor.get_parent();
        }

        return null;
    }

    _onUpdate(event) {
        if (this._state === State.IDLE || !this._isOurSlot(event))
            return Clutter.EVENT_PROPAGATE;

        const point = coordsOf(event);
        this._points.push(point);

        const key = this._keyMap.keyAt(point);
        if (key)
            this._visited.add(key.char);

        if (this._state === State.SWIPING)
            return Clutter.EVENT_STOP;

        if (!this._shouldEngage(point))
            return Clutter.EVENT_PROPAGATE;

        this._state = State.SWIPING;
        if (this._pressedKey)
            cancelKeyPress(this._pressedKey);

        return Clutter.EVENT_STOP;
    }

    /**
     * @param {Point} point
     * @returns {boolean}
     */
    _shouldEngage(point) {
        const travelled = distance(this._origin, point);
        return travelled >= this._keyMap.keyWidth * ENGAGE_DISTANCE &&
            this._visited.size >= ENGAGE_KEYS;
    }

    _onEnd(event) {
        if (this._state === State.IDLE || !this._isOurSlot(event))
            return Clutter.EVENT_PROPAGATE;

        if (this._state !== State.SWIPING) {
            // Обычный тап: клавиша сама себя обработает.
            this._reset();
            this._onTap();
            return Clutter.EVENT_PROPAGATE;
        }

        this._points.push(coordsOf(event));

        const path = simplify(this._points, this._keyMap.keyWidth * MIN_STEP);
        const keyMap = this._keyMap;

        this._reset();
        this._onSwipe(path, keyMap);

        return Clutter.EVENT_STOP;
    }

    /**
     * @param {object} event
     * @returns {boolean} принадлежит ли событие отслеживаемому касанию
     */
    _isOurSlot(event) {
        return event.get_event_sequence()?.get_slot() === this._slot;
    }
}
