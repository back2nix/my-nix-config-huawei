// Превращение траектории пальца в список слов-кандидатов.
//
// Два этапа, потому что сравнивать траекторию с каждым из 50 000 слов дорого:
//
//  1. Отбор. Слово проходит, если его первая и последняя буквы лежат рядом с
//     концами жеста, а все буквы встречаются вдоль траектории в правильном
//     порядке. Проверки дискретные и стоят порядка длины слова.
//  2. Ранжирование. Для выживших строится «идеальная» ломаная через центры
//     клавиш, обе траектории приводятся к одному числу точек и сравниваются
//     поточечно (location channel из SHARK²). Частотность добавляется как
//     слагаемое, чтобы разрешать ничьи в пользу употребимого слова.

import {meanPointDistance, resample} from './geometry.js';

/** @typedef {import('./geometry.js').Point} Point */
/** @typedef {import('./dictionary.js').Dictionary} Dictionary */
/** @typedef {import('./dictionary.js').Entry} Entry */
/** @typedef {import('./keyMap.js').KeyMap} KeyMap */

/** Число точек, к которому приводятся обе траектории. */
const SAMPLES = 48;

// Радиус поиска первой и последней буквы, в ширинах клавиши. Чуть больше
// одной клавиши: палец начинает и заканчивает жест неточно, поэтому в
// кандидаты попадают и соседи по горизонтали и вертикали (по диагонали —
// уже нет, там расстояние ~1.41).
const END_TOLERANCE = 1.15;

/** Сколько кандидатов доходит до сравнения траекторий. */
const MAX_CANDIDATES = 400;

/** Вес расхождения траекторий (расстояние измеряется в ширинах клавиши). */
const SHAPE_WEIGHT = 4;

/** Вес частотности (логарифм абсолютной частоты). */
const FREQUENCY_WEIGHT = 0.4;

/**
 * Проверяет, что `needle` — подпоследовательность `haystack`.
 *
 * @param {string[]} needle буквы слова без повторов подряд
 * @param {string[]} haystack буквы пройденных клавиш
 * @returns {boolean}
 */
function isSubsequence(needle, haystack) {
    if (needle.length > haystack.length)
        return false;

    let index = 0;
    for (const char of haystack) {
        if (char === needle[index])
            index++;
        if (index === needle.length)
            return true;
    }

    return index === needle.length;
}

/**
 * Буквы клавиш, через которые прошёл палец, без повторов подряд.
 *
 * @param {Point[]} path
 * @param {KeyMap} keyMap
 * @returns {string[]}
 */
function traversedChars(path, keyMap) {
    const chars = [];

    for (const point of path) {
        const key = keyMap.keyAt(point);
        if (key && chars[chars.length - 1] !== key.char)
            chars.push(key.char);
    }

    return chars;
}

/**
 * Ломаная через центры клавиш слова.
 *
 * @param {string[]} chars
 * @param {KeyMap} keyMap
 * @returns {Point[]|null} null, если хотя бы одной буквы нет на раскладке
 */
function idealPath(chars, keyMap) {
    const points = [];

    for (const char of chars) {
        const center = keyMap.centerOf(char);
        if (!center)
            return null;
        points.push(center);
    }

    return points;
}

export class Decoder {
    /**
     * @param {object} [options] переопределения весов, по умолчанию — константы модуля
     * @param {number} [options.shapeWeight]
     * @param {number} [options.frequencyWeight]
     * @param {number} [options.maxCandidates]
     */
    constructor({shapeWeight, frequencyWeight, maxCandidates} = {}) {
        this._shapeWeight = shapeWeight ?? SHAPE_WEIGHT;
        this._frequencyWeight = frequencyWeight ?? FREQUENCY_WEIGHT;
        this._maxCandidates = maxCandidates ?? MAX_CANDIDATES;
    }

    /**
     * @param {Point[]} path траектория пальца в координатах сцены
     * @param {KeyMap} keyMap раскладка, на которой сделан жест
     * @param {Dictionary} dictionary словарь языка раскладки
     * @param {number} limit сколько вариантов вернуть
     * @returns {{word: string, score: number, shapeDistance: number}[]} по убыванию уверенности
     */
    decode(path, keyMap, dictionary, limit) {
        if (path.length < 2)
            return [];

        const traversed = traversedChars(path, keyMap);
        if (traversed.length < 2)
            return [];

        const candidates = this._selectCandidates(path, keyMap, dictionary, traversed);
        const sampled = resample(path, SAMPLES);

        const scored = [];
        for (const {entry, chars} of candidates) {
            const ideal = idealPath(chars, keyMap);
            if (!ideal)
                continue;

            const shapeDistance =
                meanPointDistance(sampled, resample(ideal, SAMPLES)) / keyMap.keyWidth;

            scored.push({
                word: entry.word,
                shapeDistance,
                score: this._frequencyWeight * entry.logFrequency -
                    this._shapeWeight * shapeDistance,
            });
        }

        scored.sort((a, b) => b.score - a.score);
        return scored.slice(0, limit);
    }

    /**
     * @param {Point[]} path
     * @param {KeyMap} keyMap
     * @param {Dictionary} dictionary
     * @param {string[]} traversed
     * @returns {{entry: Entry, chars: string[]}[]}
     */
    _selectCandidates(path, keyMap, dictionary, traversed) {
        const startChars = keyMap.charsNear(path[0], END_TOLERANCE);
        const endChars = keyMap.charsNear(path[path.length - 1], END_TOLERANCE);

        // Клавиши под самими концами жеста могли не попасть в радиус, если
        // ширина клавиши мала относительно допуска — добавляем их явно.
        startChars.add(traversed[0]);
        endChars.add(traversed[traversed.length - 1]);

        const matched = [];

        for (const entry of dictionary.startingWith(startChars)) {
            // Буквы без своей клавиши («ъ») заменяются на клавишу-заместитель,
            // иначе слово не пройдёт проверку на подпоследовательность.
            const chars = keyMap.canonicalize(entry.chars);

            if (chars.length < 2)
                continue;
            if (!endChars.has(chars[chars.length - 1]))
                continue;
            if (!isSubsequence(chars, traversed))
                continue;

            matched.push({entry, chars});
        }

        // Индекс упорядочен по частоте только внутри одной первой буквы,
        // после слияния корзин порядок надо восстановить.
        matched.sort((a, b) => b.entry.logFrequency - a.entry.logFrequency);
        return matched.slice(0, this._maxCandidates);
    }
}
