// Частотные словари: загрузка, разбор и индекс для быстрого отбора кандидатов.
//
// Файл словаря — «слово частота» по строке, отсортировано по убыванию частоты
// (формат hermitdave/FrequencyWords, подготовка в module/osk-globe-cycle.nix).
//
// Разбор 50k строк занимает десятки миллисекунд, а мы находимся в процессе
// gnome-shell, где такая пауза видна как подвисание анимации. Поэтому файл
// читается асинхронно, а разбирается порциями в idle.

import Gio from 'gi://Gio';
import GLib from 'gi://GLib';

import * as Log from '../log.js';

/** Сколько строк разбирать за один заход в idle. */
const PARSE_CHUNK = 4000;

/** @typedef {{word: string, chars: string[], logFrequency: number}} Entry */

/**
 * Схлопывает подряд идущие одинаковые буквы: палец, проезжая «класс»,
 * задевает клавишу «с» один раз, и последовательность пройденных клавиш
 * тоже без повторов. Сравнивать их можно только в одинаковой форме.
 *
 * @param {string} word
 * @returns {string[]}
 */
export function collapseRepeats(word) {
    const chars = [];
    for (const char of word) {
        if (chars[chars.length - 1] !== char)
            chars.push(char);
    }
    return chars;
}

export class Dictionary {
    /**
     * @param {Entry[]} entries записи в порядке убывания частоты
     */
    constructor(entries) {
        this._byFirstChar = new Map();

        for (const entry of entries) {
            const first = entry.chars[0];
            const bucket = this._byFirstChar.get(first);

            if (bucket)
                bucket.push(entry);
            else
                this._byFirstChar.set(first, [entry]);
        }

        this.size = entries.length;
    }

    /**
     * Кандидаты, начинающиеся на любую из указанных букв.
     *
     * Индекс по первой букве отсекает ~97% словаря до того, как начнётся
     * дорогое сравнение траекторий.
     *
     * @param {Set<string>} chars
     * @returns {Entry[]} в порядке убывания частоты
     */
    startingWith(chars) {
        const result = [];
        for (const char of chars)
            result.push(...this._byFirstChar.get(char) ?? []);
        return result;
    }
}

/**
 * Разбирает содержимое словаря порциями, отдавая управление главному циклу.
 *
 * @param {string} text содержимое файла
 * @returns {Promise<Dictionary>}
 */
function parseInChunks(text) {
    return new Promise(resolve => {
        const lines = text.split('\n');
        const entries = [];
        let cursor = 0;

        GLib.idle_add(GLib.PRIORITY_LOW, () => {
            const end = Math.min(cursor + PARSE_CHUNK, lines.length);

            for (; cursor < end; cursor++) {
                const separator = lines[cursor].indexOf(' ');
                if (separator <= 0)
                    continue;

                const word = lines[cursor].slice(0, separator);
                const frequency = Number(lines[cursor].slice(separator + 1));

                if (!Number.isFinite(frequency) || frequency <= 0)
                    continue;

                entries.push({
                    word,
                    chars: collapseRepeats(word),
                    logFrequency: Math.log(frequency),
                });
            }

            if (cursor < lines.length)
                return GLib.SOURCE_CONTINUE;

            resolve(new Dictionary(entries));
            return GLib.SOURCE_REMOVE;
        });
    });
}

export class DictionaryStore {
    /**
     * @param {string} directory каталог с файлами `<язык>.txt`
     */
    constructor(directory) {
        this._directory = directory;
        this._loading = new Map();
        this._cancellable = new Gio.Cancellable();
    }

    destroy() {
        this._cancellable.cancel();
        this._loading.clear();
    }

    /**
     * @param {string} language код языка, он же имя файла
     * @returns {Promise<Dictionary|null>} null, если словаря нет или он битый
     */
    get(language) {
        let pending = this._loading.get(language);
        if (!pending) {
            pending = this._load(language);
            this._loading.set(language, pending);
        }
        return pending;
    }

    async _load(language) {
        const path = GLib.build_filenamev([this._directory, `${language}.txt`]);
        const file = Gio.File.new_for_path(path);

        try {
            const [contents] = await file.load_contents_async(this._cancellable);
            const dictionary = await parseInChunks(new TextDecoder().decode(contents));

            Log.debug(`словарь ${language}: ${dictionary.size} слов`);
            return dictionary;
        } catch (cause) {
            if (!cause.matches?.(Gio.IOErrorEnum, Gio.IOErrorEnum.CANCELLED))
                Log.warn(`не удалось загрузить словарь ${language}: ${cause.message}`);
            return null;
        }
    }
}
