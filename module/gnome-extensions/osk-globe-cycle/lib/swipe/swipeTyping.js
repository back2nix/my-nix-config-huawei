// Сборка свайп-ввода: жест → словарь → распознавание → ввод и подсказки.
//
// Один экземпляр SwipeSession живёт столько же, сколько экземпляр Keyboard;
// SwipeTyping следит за тем, чтобы сессия была у каждой созданной клавиатуры.

import * as Log from '../log.js';

import {Decoder} from './decoder.js';
import {DictionaryStore} from './dictionary.js';
import {GestureTracker} from './tracker.js';
import {WordWriter} from './writer.js';

/** Сколько вариантов показывать в строке подсказок вместе с выбранным. */
const SUGGESTIONS = 4;

/**
 * Обвязка одной клавиатуры: перехват жестов, распознавание, ввод.
 */
class SwipeSession {
    /**
     * @param {object} keyboard экземпляр gnome-shell Keyboard
     * @param {DictionaryStore} dictionaries
     * @param {Decoder} decoder
     */
    constructor(keyboard, dictionaries, decoder) {
        this._keyboard = keyboard;
        this._dictionaries = dictionaries;
        this._decoder = decoder;
        this._writer = new WordWriter(keyboard);

        this._tracker = new GestureTracker(keyboard, {
            onSwipe: (path, keyMap) => this._onSwipe(path, keyMap),
            onTap: () => this._writer.forget(),
        });
    }

    destroy() {
        this._tracker.destroy();
        this._tracker = null;
    }

    /**
     * @param {import('./geometry.js').Point[]} path
     * @param {import('./keyMap.js').KeyMap} keyMap
     */
    _onSwipe(path, keyMap) {
        // Жест уже завершён, дальше можно не спешить: словарь при первом
        // свайпе ещё грузится, и лучше ввести слово с задержкой, чем не ввести.
        this._decodeAndWrite(path, keyMap).catch(Log.error);
    }

    async _decodeAndWrite(path, keyMap) {
        const language = keyMap.language;
        const dictionary = await this._dictionaries.get(language);

        if (!dictionary)
            return;

        const matches = this._decoder.decode(path, keyMap, dictionary, SUGGESTIONS);
        if (matches.length === 0) {
            Log.debug('свайп не распознан');
            return;
        }

        Log.debug('варианты:', matches
            .map(m => `${m.word} (${m.score.toFixed(2)}/${m.shapeDistance.toFixed(2)})`)
            .join(', '));

        await this._writer.write(matches[0].word);
        this._showAlternatives(matches.slice(1));
    }

    /**
     * @param {{word: string}[]} alternatives
     */
    _showAlternatives(alternatives) {
        this._keyboard.resetSuggestions();

        for (const {word} of alternatives) {
            this._keyboard.addSuggestion(word,
                () => this._writer.replace(word).catch(Log.error));
        }
    }
}

export class SwipeTyping {
    /**
     * @param {string} dictionaryDirectory каталог со словарями
     */
    constructor(dictionaryDirectory) {
        this._dictionaries = new DictionaryStore(dictionaryDirectory);
        this._decoder = new Decoder();
        this._sessions = new Map();
    }

    /**
     * @param {object} keyboard экземпляр gnome-shell Keyboard
     */
    attach(keyboard) {
        if (this._sessions.has(keyboard))
            return;

        this._sessions.set(keyboard, new SwipeSession(
            keyboard, this._dictionaries, this._decoder));

        keyboard.connect('destroy', () => this.detach(keyboard));
    }

    /**
     * @param {object} keyboard
     */
    detach(keyboard) {
        this._sessions.get(keyboard)?.destroy();
        this._sessions.delete(keyboard);
    }

    destroy() {
        for (const session of this._sessions.values())
            session.destroy();

        this._sessions.clear();
        this._dictionaries.destroy();
    }
}
