// Снимок геометрии буквенных клавиш текущей страницы OSK.
//
// Снимок делается один раз в начале жеста: клавиатура во время свайпа не
// перестраивается, а обращение к get_transformed_position() на каждое
// touch-событие обошлось бы в лишние вычисления аллокаций.
//
// Зависимость от приватных полей Key (_hasAction, _keyval) намеренная: у
// gnome-shell нет публичного способа отличить букву от Shift/Backspace.
// Обе проверки продублированы регуляркой по подписи, поэтому переименование
// полей выше по течению приведёт к деградации (свайп перестанет включаться),
// а не к вводу мусора.

import {distance} from './geometry.js';

/** @typedef {import('./geometry.js').Point} Point */

/** @typedef {{char: string, center: Point, width: number, height: number}} KeyBox */

const SINGLE_LETTER = /^\p{L}$/u;

const CYRILLIC = /\p{Script=Cyrillic}/u;

// Буквы, которых нет отдельной клавишей на раскладке: в ru.json «ъ» и «ё»
// доступны только долгим нажатием, провести по ним пальцем нельзя. Слова с
// ними всё равно должны набираться — считаем, что палец проезжает по
// клавише-заместителю. Вводится при этом настоящее слово из словаря.
const SUBSTITUTES = new Map([
    ['ъ', 'ь'],
    ['ё', 'е'],
]);

/**
 * Медиана — а не среднее — чтобы широкий пробел не растягивал масштаб.
 *
 * @param {number[]} values непустой массив
 * @returns {number}
 */
function median(values) {
    const sorted = [...values].sort((a, b) => a - b);
    return sorted[Math.floor(sorted.length / 2)];
}

/**
 * Рекурсивно собирает актёры Key под заданным контейнером.
 *
 * KeyContainer раскладывает клавиши через Clutter.GridLayout, то есть они
 * лежат прямыми детьми, но полагаться на это не хочется: обход по
 * `.keyButton` переживёт смену раскладочного контейнера.
 *
 * @param {object} actor
 * @param {object[]} accumulator
 * @returns {object[]}
 */
function collectKeys(actor, accumulator = []) {
    for (const child of actor.get_children?.() ?? []) {
        if (child.keyButton)
            accumulator.push(child);
        else
            collectKeys(child, accumulator);
    }
    return accumulator;
}

export class KeyMap {
    /**
     * @param {KeyBox[]} keys буквенные клавиши в координатах сцены
     */
    constructor(keys) {
        this._keys = keys;
        this._byChar = new Map(keys.map(key => [key.char, key]));
        this._keyWidth = keys.length > 0
            ? median(keys.map(key => key.width))
            : 0;
    }

    /**
     * Строит карту по актёру страницы клавиатуры (Keyboard._currentPage).
     *
     * @param {object} page KeyContainer текущего уровня
     * @returns {KeyMap} возможно пустая — вызывающий обязан проверить isUsable
     */
    static fromPage(page) {
        const keys = [];

        for (const key of collectKeys(page)) {
            const label = key.keyButton.label;

            if (!label || !SINGLE_LETTER.test(label))
                continue;
            if (key._hasAction || key._keyval)
                continue;
            if (!key.keyButton.visible || !key.keyButton.is_mapped())
                continue;

            const [x, y] = key.keyButton.get_transformed_position();
            const [width, height] = key.keyButton.get_transformed_size();

            keys.push({
                char: label.toLowerCase(),
                center: {x: x + width / 2, y: y + height / 2},
                width,
                height,
            });
        }

        return new KeyMap(keys);
    }

    /** @returns {boolean} хватает ли клавиш, чтобы свайп имел смысл */
    get isUsable() {
        return this._keys.length >= 10 && this._keyWidth > 0;
    }

    /** @returns {number} типичная ширина клавиши, единица измерения расстояний */
    get keyWidth() {
        return this._keyWidth;
    }

    /**
     * Алфавит определяем по самим клавишам, а не по id источника ввода:
     * раскладка на экране может отставать от InputSourceManager, а словарь
     * должен соответствовать тому, что пользователь видит под пальцем.
     *
     * @returns {'ru'|'en'} код словаря
     */
    get language() {
        const cyrillic = this._keys.filter(key => CYRILLIC.test(key.char)).length;
        return cyrillic > this._keys.length / 2 ? 'ru' : 'en';
    }

    /**
     * @param {string} char
     * @returns {Point|null} центр клавиши или null, если буквы нет на раскладке
     */
    centerOf(char) {
        const key = this._byChar.get(char) ??
            this._byChar.get(SUBSTITUTES.get(char));
        return key?.center ?? null;
    }

    /**
     * Приводит буквы слова к тем, по которым реально можно провести пальцем.
     *
     * @param {string[]} chars буквы слова без повторов подряд
     * @returns {string[]} буквы клавиш, тоже без повторов подряд
     */
    canonicalize(chars) {
        const result = [];

        for (const char of chars) {
            const mapped = this._byChar.has(char)
                ? char
                : SUBSTITUTES.get(char) ?? char;

            if (result[result.length - 1] !== mapped)
                result.push(mapped);
        }

        return result;
    }

    /**
     * Клавиша под точкой. Строгое попадание в прямоугольник, без «примагничивания»:
     * промежутки между клавишами должны давать null, иначе последовательность
     * пройденных клавиш засоряется соседями при движении по границе.
     *
     * @param {Point} point координаты сцены
     * @returns {KeyBox|null}
     */
    keyAt(point) {
        for (const key of this._keys) {
            const dx = Math.abs(point.x - key.center.x);
            const dy = Math.abs(point.y - key.center.y);

            if (dx <= key.width / 2 && dy <= key.height / 2)
                return key;
        }
        return null;
    }

    /**
     * Буквы, чьи клавиши достаточно близки к точке, чтобы считаться
     * возможным началом или концом жеста. Палец редко останавливается
     * ровно на нужной клавише, поэтому концы проверяем с допуском.
     *
     * @param {Point} point координаты сцены
     * @param {number} tolerance радиус в ширинах клавиши
     * @returns {Set<string>}
     */
    charsNear(point, tolerance) {
        const radius = this._keyWidth * tolerance;
        const chars = new Set();

        for (const key of this._keys) {
            if (distance(point, key.center) <= radius)
                chars.add(key.char);
        }

        return chars;
    }
}
