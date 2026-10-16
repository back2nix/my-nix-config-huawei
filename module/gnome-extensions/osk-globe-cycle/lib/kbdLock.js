// Блокировка физического ввода ноутбука (клавиатура + тачпад) по кнопке на
// экранной клавиатуре.
//
// Сессия Wayland: xinput не видит реальные устройства (в Xwayland есть только
// синтетический xwayland-keyboard), поэтому единственный работающий механизм —
// EVIOCGRAB на evdev-узлах. Сам ioctl держит внешний процесс
// helpers/kbd-grab.py: ядро снимает захват при закрытии fd, значит смерть
// gnome-shell гарантированно освобождает устройства.
//
// OSK при этом продолжает печатать: keyboard.js отправляет символы через
// Main.inputMethod.commit() и виртуальное Clutter-устройство, а не через
// захваченный evdev-узел.
//
// Список устройств берём из GSettings (ключ lock-devices): либо стабильный
// путь /dev/input/by-path/... (а не eventN, который перенумеровывается), либо
// подстрока имени — у тачпада ELAN второй узел вообще без симлинков.

import Gio from 'gi://Gio';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';

import * as Log from './log.js';

Gio._promisify(Gio.Subprocess.prototype, 'wait_check_async');

export class KbdLock {
    /**
     * @param {Gio.Settings} settings настройки расширения (ключ lock-devices)
     * @param {string} extensionPath каталог установленного расширения
     * @param {Function} onStateChanged (locked: boolean) => void
     */
    constructor(settings, extensionPath, onStateChanged) {
        this._settings = settings;
        this._helperPath = `${extensionPath}/helpers/kbd-grab.py`;
        this._onStateChanged = onStateChanged;

        this._proc = null;
        this._cancellable = null;
        this._sessionModeId = 0;
        this._enabled = false;
    }

    get isLocked() {
        return this._proc !== null;
    }

    enable() {
        if (this._enabled)
            return;

        this._enabled = true;

        // САМАЯ ВАЖНАЯ СТРАХОВКА: при уходе из режима 'user' (экран блокировки,
        // GDM, unlock-dialog) захват обязан сниматься — иначе пользователь не
        // сможет ввести пароль и останется без клавиатуры вообще.
        this._sessionModeId = Main.sessionMode.connect('updated',
            () => this._onSessionModeUpdated());
    }

    disable() {
        this._enabled = false;

        if (this._sessionModeId) {
            Main.sessionMode.disconnect(this._sessionModeId);
            this._sessionModeId = 0;
        }

        // Захват не должен переживать расширение.
        this.unlock();
    }

    toggle() {
        // Наружу не бросаем: вызывается из обработчика клавиши OSK.
        try {
            if (this.isLocked)
                this.unlock();
            else
                this.lock();
        } catch (e) {
            Log.error('kbdLock: toggle failed', e);
        }
    }

    lock() {
        if (this.isLocked)
            return;

        const devices = this._settings.get_strv('lock-devices');
        if (!devices.length) {
            Log.warn('kbdLock: lock-devices is empty, refusing to lock');
            return;
        }

        let proc;
        try {
            // STDIN_PIPE — канал «отпусти»: закрытие трубы даёт помощнику EOF.
            proc = Gio.Subprocess.new(
                ['python3', this._helperPath, ...devices],
                Gio.SubprocessFlags.STDIN_PIPE);
        } catch (e) {
            Log.error(`kbdLock: cannot spawn ${this._helperPath}`, e);
            return;
        }

        this._proc = proc;
        this._cancellable = new Gio.Cancellable();

        const cancellable = this._cancellable;

        proc.wait_check_async(cancellable)
            .catch(e => {
                // Отмена — наш собственный unlock(), а не ошибка.
                if (e?.matches?.(Gio.IOErrorEnum, Gio.IOErrorEnum.CANCELLED))
                    return;
                // Ненулевой код: помощник не смог открыть устройство или
                // не смог захватить его. Состояние всё равно сбрасываем ниже.
                Log.warn('kbdLock: helper exited with error', e);
            })
            .finally(() => {
                // Помощник умер по любой причине -> физический ввод
                // снова жив, UI обязан это показать.
                if (this._proc !== proc)
                    return;
                this._proc = null;
                this._cancellable = null;
                Log.debug('kbdLock: unlocked (helper gone)');
                this._notify(false);
            });

        Log.debug(`kbdLock: locked ${devices.join(' ')}`);
        this._notify(true);
    }

    unlock() {
        const proc = this._proc;
        if (!proc)
            return;

        // Обнуляем сразу, чтобы обработчик wait_check_async не дублировал
        // уведомление, и чтобы отмена не попала в журнал как ошибка.
        this._proc = null;
        this._cancellable?.cancel();
        this._cancellable = null;

        try {
            // Штатный путь: EOF на stdin, помощник сам делает EVIOCGRAB 0.
            proc.get_stdin_pipe()?.close(null);
        } catch (e) {
            Log.debug('kbdLock: closing stdin failed', e);
        }

        // Подстраховка на случай зависшего помощника: fd закроется при
        // смерти процесса, и ядро снимет захват само.
        try {
            proc.force_exit();
        } catch (e) {
            Log.debug('kbdLock: force_exit failed', e);
        }

        Log.debug('kbdLock: unlocked');
        this._notify(false);
    }

    _onSessionModeUpdated() {
        if (!this.isLocked)
            return;

        if (Main.sessionMode.currentMode !== 'user' ||
            !Main.sessionMode.hasWindows) {
            Log.debug('kbdLock: releasing grab, session mode is ' +
                `${Main.sessionMode.currentMode}`);
            this.unlock();
        }
    }

    _notify(locked) {
        try {
            this._onStateChanged?.(locked);
        } catch (e) {
            Log.error('kbdLock: onStateChanged callback failed', e);
        }
    }
}
