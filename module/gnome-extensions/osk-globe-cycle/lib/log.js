// Логгер расширения. Отладка включается через
//   dconf write /org/gnome/shell/extensions/osk-globe-cycle/debug true
// но сюда значение приходит извне (setDebug), чтобы модули не зависели
// от GSettings.

const PREFIX = '[osk-globe-cycle]';

let debugEnabled = false;

export function setDebug(enabled) {
    debugEnabled = enabled;
}

export function debug(...args) {
    if (debugEnabled)
        console.log(PREFIX, ...args);
}

export function warn(...args) {
    console.warn(PREFIX, ...args);
}

export function error(...args) {
    console.error(PREFIX, ...args);
}
