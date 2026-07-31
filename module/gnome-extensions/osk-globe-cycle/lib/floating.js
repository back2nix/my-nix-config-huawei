// Плавающая экранная клавиатура: произвольный размер и положение.
//
// Штатная OSK всегда во всю ширину монитора и приклеена к нижнему краю.
// Размер задаётся в Keyboard._relayout(), положение — сдвигом translation_y
// в _animateShow(). Мы патчим _relayout() и дальше сами держим translation_x/y.
//
// Чего делать НЕЛЬЗЯ: переносить актор Keyboard из Main.layoutManager.keyboardBox.
// KeyboardManager.maybeHandleEvent() маршрутизирует события проверкой
// keyboardBox.contains(actor) — вне коробки клавиатура перестанет получать
// касания. Поэтому коробка остаётся во всю ширину монитора (её геометрию
// задаёт LayoutManager._updateKeyboardBox()), а двигаем мы дочерний актор
// внутри неё через translation_x/translation_y.
//
// Фон #keyboard { background-color: ... } рисует сам актор Keyboard, так что
// при уменьшенной ширине лишней заливки не остаётся — правило по #id,
// перебить его можно только инлайновым set_style(), что мы и делаем для
// подсветки активного режима.
//
// Про жесты. В Clutter 18 не осталось ни ZoomAction, ни PinchGesture, ни
// DragAction/GestureAction — весь набор это Action, Gesture, PressGesture,
// ClickGesture, LongPressGesture, PanGesture. Свой жест поверх
// Clutter.Gesture написать тоже нельзя: в Clutter-18.gir виртуальные методы
// point_began/point_moved/point_ended/may_recognize и методы
// set_state()/get_point_coords_abs() помечены introspectable="0", то есть из
// GJS недоступны — ни переопределить, ни вызвать. Поэтому оба режима сделаны
// на сырых touch-событиях через сигнал 'captured-event': он идёт по цепочке
// сверху вниз (стейдж → клавиатура → кнопка клавиши), так что мы
// перехватываем касание раньше кнопки и во взведённом режиме клавиши не
// печатают. Пальцы различаем по ClutterEventSequence.get_slot() —
// единственный интроспектируемый способ получить стабильный идентификатор
// касания (сами обёртки ClutterEventSequence в GJS сравнивать нельзя).

import Clutter from 'gi://Clutter';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import {Keyboard} from 'resource:///org/gnome/shell/ui/keyboard.js';

import * as Log from './log.js';

// Сколько пикселей клавиатуры обязано остаться на экране при перетаскивании.
const MIN_VISIBLE = 80;

// Длительность штатной анимации показа (KEYBOARD_ANIMATION_TIME в
// ui/keyboard.js). Повторяем её, чтобы подменённый _animateShow() выглядел
// неотличимо от исходного.
const KEYBOARD_ANIMATION_TIME = 150;

// Границы из gschema; держим копию, чтобы обрезать значения до записи.
// Ширины и высоты среди них нет: высоту задаёт масштаб, ширину — пропорция.
const SCALE_MIN = 25;
const SCALE_MAX = 200;

// Фон переносим с актёра Keyboard на контейнер с клавишами.
//
// Ужать сам Keyboard по ширине не выходит: он лежит в St.BoxLayout
// (Main.layoutManager.keyboardBox), которому LayoutManager._updateKeyboardBox()
// жёстко задаёт ширину монитора, и присвоение keyboard.width на итоговую
// аллокацию не влияет. А раз актёр всё равно во всю ширину, то и его заливка
// #keyboard { background-color: ... } тянется через весь экран, оставляя
// серые поля там, где клавиш нет.
//
// Поэтому не боремся с аллокацией, а убираем заливку у самого Keyboard
// и рисуем фон под тем, что реально занято: под сеткой клавиш и под
// панелью кнопок. Пустые поля становятся прозрачными и исчезают.
const STYLE_KEYBOARD_BASE =
    'background-color: transparent; box-shadow: none; border: none;';
const STYLE_CONTENT =
    'background-color: rgba(48, 48, 48, 0.95); border-radius: 12px;';

// Подсветка взведённого режима — рамкой вокруг сетки клавиш.
const STYLE_MOVE = 'border: 2px solid #62a0ea;';
const STYLE_RESIZE = 'border: 2px solid #e5a50a;';

export class Floating {
    /**
     * @param {object} settings Gio.Settings расширения
     * @param {(state: {move: boolean, resize: boolean}) => void} onModeChanged
     */
    constructor(settings, onModeChanged) {
        this._settings = settings;
        this._onModeChanged = onModeChanged ?? (() => {});

        this._originalRelayout = null;
        this._originalAnimateShow = null;
        this._originalAnimateShowComplete = null;
        this._originalGestureProgress = null;

        this._keyboard = null;
        this._toolbarActor = null;
        this._capturedEventId = 0;
        this._allocationNotifyId = 0;
        this._heightNotifyId = 0;

        this._moveMode = false;
        this._resizeMode = false;

        // slot касания -> {x, y} последних координат.
        this._points = new Map();
        // Расстояние между двумя пальцами в момент начала щипка.
        this._pinchBegin = 0;
        this._pinchRatio = 1;
        // Перетаскивание мышью/тачпадом (без сенсорного экрана).
        this._pointerDrag = null;

        // Незакоммиченный сдвиг текущего перетаскивания (в GSettings пишем
        // только по окончании жеста, чтобы не долбить dconf каждый кадр).
        this._dragOffsetX = 0;
        this._dragOffsetY = 0;
        this._dragging = false;
    }

    get isMoveMode() {
        return this._moveMode;
    }

    get isResizeMode() {
        return this._resizeMode;
    }

    enable() {
        if (this._originalRelayout)
            return;

        const self = this;

        this._originalRelayout = Keyboard.prototype._relayout;
        this._originalAnimateShow = Keyboard.prototype._animateShow;
        this._originalAnimateShowComplete = Keyboard.prototype._animateShowComplete;
        this._originalGestureProgress = Keyboard.prototype.gestureProgress;

        const originalRelayout = this._originalRelayout;
        Keyboard.prototype._relayout = function () {
            if (!self._enabledInSettings()) {
                originalRelayout.call(this);
                return;
            }
            self._applyGeometry(this, originalRelayout);
        };

        // Штатный _animateShow() анимирует translation_y строго к -height,
        // то есть к нижнему краю экрана, и про наше сохранённое положение
        // ничего не знает. Из-за этого клавиатура при каждом показе уезжала
        // вниз сама по себе, а вернуть её на место удавалось только тем,
        // что кнопка режима дёргала пересчёт позиции. Повторяем штатную
        // логику целиком, подменив только конечную точку анимации.
        const originalShow = this._originalAnimateShow;
        Keyboard.prototype._animateShow = function () {
            if (!self._enabledInSettings()) {
                originalShow.call(this);
                return;
            }

            global.compositor.disable_unredirect();

            if (this._focusWindow)
                this._animateWindow(this._focusWindow, true);

            Main.layoutManager.keyboardBox.show();

            const {x, y} = self._targetPosition(this);
            // По горизонтали не анимируем: штатный код её не трогает,
            // а рывок вбок при показе выглядел бы странно.
            this.translation_x = x;

            this.ease({
                translation_y: y,
                opacity: 255,
                duration: KEYBOARD_ANIMATION_TIME,
                mode: Clutter.AnimationMode.EASE_OUT_QUAD,
                onComplete: () => {
                    this._animateShowComplete();
                },
            });

            this._keyboardVisible = true;
            this.emit('visibility-changed');
        };

        // _animateShowComplete() штатно вешает на keyboardBox обработчик
        // notify::height, который вечно возвращает translation_y = -height.
        // Он будет драться с нашим смещением по вертикали, поэтому даём
        // штатному коду отработать, а затем отключаем его обработчик и
        // ставим свой, который пересчитывает позицию с учётом offset-y.
        const originalComplete = this._originalAnimateShowComplete;
        Keyboard.prototype._animateShowComplete = function () {
            originalComplete.call(this);
            if (self._enabledInSettings())
                self._takeOverHeightNotify(this);
        };

        // gestureProgress() пишет translation_y напрямую во время
        // «вытягивания» клавиатуры пальцем снизу. В плавающем режиме
        // конечная точка другая, поэтому масштабируем прогресс к нашему
        // целевому y, а не к -height.
        const originalProgress = this._originalGestureProgress;
        Keyboard.prototype.gestureProgress = function (delta) {
            if (!self._enabledInSettings()) {
                originalProgress.call(this, delta);
                return;
            }
            originalProgress.call(this, delta);
            // Штатная реализация оставила translation_y в диапазоне
            // [0, -height]; переводим долю в наш диапазон [0, targetY].
            const height = this.height || 1;
            const progress = Math.clamp(-this.translation_y / height, 0, 1);
            const {x, y} = self._targetPosition(this);
            this.translation_x = x;
            this.translation_y = y * progress;
        };

        this._settings.connectObject(
            'changed::floating', () => this._resync(),
            'changed::scale-percent', () => this._resync(),
            'changed::offset-x', () => this._resync(),
            'changed::offset-y', () => this._resync(),
            this);

        Log.debug('floating: enabled');
    }

    disable() {
        if (!this._originalRelayout)
            return;

        this._settings.disconnectObject(this);

        this._moveMode = false;
        this._resizeMode = false;
        this._resetGestureState();
        this._disconnectCapturedEvent();
        this._restoreHeightNotify();

        const keyboard = this._keyboard;
        this._keyboard = null;

        Keyboard.prototype._relayout = this._originalRelayout;
        Keyboard.prototype._animateShow = this._originalAnimateShow;
        Keyboard.prototype._animateShowComplete = this._originalAnimateShowComplete;
        Keyboard.prototype.gestureProgress = this._originalGestureProgress;
        this._originalRelayout = null;
        this._originalAnimateShow = null;
        this._originalAnimateShowComplete = null;
        this._originalGestureProgress = null;

        // Вернуть шеллу ровно то состояние, в котором мы его нашли.
        if (keyboard) {
            keyboard.set_style(null);
            // Фон мы переносили на контейнер клавиш — снимаем и его,
            // иначе после выключения расширения останется чужой стиль.
            keyboard._aspectContainer?.set_style(null);
            keyboard.set_scale(1, 1);
            keyboard.set_pivot_point(0, 0);
            keyboard.translation_x = 0;
            try {
                keyboard._relayout();
                keyboard.translation_y = keyboard.visible ? -keyboard.height : 0;
            } catch (e) {
                Log.warn('floating: restore failed', e);
            }
        }

        this._onModeChanged({move: false, resize: false});
        Log.debug('floating: disabled');
    }

    /**
     * Новый экземпляр Keyboard (KeyboardManager._syncEnabled() пересоздаёт
     * его при каждом включении OSK), поэтому всё «на экземпляр» —
     * обработчик событий, стиль, id сигналов — ставим заново.
     *
     * @param {object} keyboard экземпляр Keyboard
     */
    attach(keyboard) {
        if (this._keyboard === keyboard)
            return;

        this._disconnectCapturedEvent();
        this._resetGestureState();
        this._heightNotifyId = 0;
        this._keyboard = keyboard;

        // Обработчик держим подключённым всегда, а не переподключаем на
        // каждое переключение режима: он первым делом выходит, если ни один
        // режим не взведён, так что накладные расходы нулевые, зато нет
        // риска забыть отключить его при пересоздании клавиатуры.
        this._capturedEventId = keyboard.connect('captured-event',
            (_actor, event) => this._onCapturedEvent(event));

        // Позиция считается от фактической аллокации, а она становится
        // известна только после переразмещения. Пересчитываем по факту:
        // запись translation_* аллокацию не меняет, зацикливания нет.
        this._allocationNotifyId = keyboard.connect('notify::allocation',
            () => this._syncPosition(this._keyboard));

        this._syncStyle();

        Log.debug('floating: attached to new keyboard');
    }

    /**
     * Запомнить актёр панели кнопок: её нажатия перехватчик обязан
     * пропускать, иначе взведённый режим нечем будет выключить.
     *
     * @param {object|null} actor актёр панели
     */
    setToolbar(actor) {
        this._toolbarActor = actor;
    }

    toggleMove() {
        this._moveMode = !this._moveMode;
        // Два режима одновременно не имеют смысла: оба перехватывают
        // одни и те же касания в фазе capture.
        if (this._moveMode)
            this._resizeMode = false;
        this._resetGestureState();
        this._syncStyle();
        this._emitMode();
    }

    toggleResize() {
        this._resizeMode = !this._resizeMode;
        if (this._resizeMode)
            this._moveMode = false;
        this._resetGestureState();
        this._syncStyle();
        this._emitMode();
    }

    // --- геометрия -------------------------------------------------------

    _enabledInSettings() {
        return this._settings.get_boolean('floating');
    }

    _emitMode() {
        this._onModeChanged({move: this._moveMode, resize: this._resizeMode});
    }

    _resync() {
        const keyboard = this._keyboard;
        if (!keyboard)
            return;
        try {
            keyboard._relayout();
        } catch (e) {
            Log.warn('floating: relayout failed', e);
        }
    }

    /**
     * Замена штатного _relayout() в плавающем режиме.
     *
     * @param {object} keyboard экземпляр Keyboard (this внутри патча)
     * @param {Function} originalRelayout штатная реализация
     */
    _applyGeometry(keyboard, originalRelayout) {
        const monitor = Main.layoutManager.keyboardMonitor;
        if (!monitor) {
            // Мониторов может не быть в момент пересчёта — штатный код
            // в этом случае просто выходит, повторяем поведение.
            originalRelayout.call(keyboard);
            return;
        }

        // minHeight — собственный минимум сетки клавиш; ниже него
        // AspectContainer/KeyContainer ломают раскладку, поэтому пол
        // из штатного кода сохраняем.
        const [minHeight] = keyboard.get_preferred_height(-1);

        // Базовая высота — штатная (GNOME берёт треть монитора в альбомной
        // ориентации и четверть в портретной). Пользовательский размер сюда
        // не подмешиваем: сетка клавиш имеет собственный минимум minHeight,
        // и любое меньшее значение всё равно поднимется до него — именно
        // поэтому уменьшение через аллокацию не фиксировалось. Размер даёт
        // масштаб, он применяется ниже отдельно.
        const base = monitor.width > monitor.height
            ? monitor.height / 3
            : monitor.height / 4;

        let height = this._clamp(base, minHeight, monitor.height / 2);

        // Ширина всегда строго выводится из высоты и пропорции раскладки.
        //
        // AspectContainer.vfunc_allocate() вписывает сетку клавиш в свой
        // _ratio и центрирует её по горизонтали, а фон рисует актёр Keyboard
        // целиком — отсюда и берутся серые пустые поля по бокам. Любая
        // независимая настройка ширины неизбежно расходится с пропорцией
        // и поля возвращает, поэтому её просто нет.
        const chrome = this._chromeHeight(keyboard);
        const ratio = keyboard._aspectContainer?._ratio;
        let width;

        if (Number.isFinite(ratio) && ratio > 0) {
            // Строка подсказок и панель кнопок делят высоту с сеткой,
            // пропорцию считаем от остатка.
            width = Math.max(height - chrome, 1) * ratio;

            if (width > monitor.width) {
                // Шире экрана быть не может — тогда высоту задаёт ширина.
                width = monitor.width;
                height = width / ratio + chrome;
            }
        } else {
            // Пропорция ещё не известна (раскладка не построена) —
            // повторяем штатное поведение, чтобы не рисовать мусор.
            width = monitor.width;
        }

        keyboard.width = this._clamp(width, MIN_VISIBLE, monitor.width);
        keyboard.height = height;

        this._applyScale(keyboard);
        this._syncPosition(keyboard);
        this._syncStyle();

        Log.debug('floating: geometry ' +
            `monitor=${monitor.width}x${monitor.height} ratio=${ratio} ` +
            `chrome=${Math.round(chrome)} minHeight=${Math.round(minHeight)} ` +
            `asked=${Math.round(width)}x${Math.round(height)} ` +
            `got=${Math.round(keyboard.width)}x${Math.round(keyboard.height)} ` +
            `scale=${this._savedScale()}`);
    }

    /**
     * Сохранённый масштаб пользователя.
     *
     * @returns {number} множитель, 1 = штатный размер
     */
    _savedScale() {
        return this._clamp(this._settings.get_int('scale-percent'),
            SCALE_MIN, SCALE_MAX) / 100;
    }

    /**
     * Применить масштаб к актёру.
     *
     * Опорная точка — низ по центру: при любом масштабе нижняя кромка и
     * центр остаются на месте, поэтому положение (translation_x/y) считается
     * от нетронутых width/height и от масштаба не зависит.
     *
     * @param {object} keyboard экземпляр Keyboard
     * @param {number} [live] коэффициент текущего незавершённого щипка
     */
    _applyScale(keyboard, live = 1) {
        if (!keyboard)
            return;
        const scale = this._clamp(this._savedScale() * live,
            SCALE_MIN / 100, SCALE_MAX / 100);
        keyboard.set_pivot_point(0.5, 1.0);
        keyboard.set_scale(scale, scale);
    }

    /**
     * Высота всего, что делит клавиатуру по вертикали с сеткой клавиш:
     * строка подсказок и панель кнопок.
     *
     * @param {object} keyboard экземпляр Keyboard
     * @returns {number}
     */
    _chromeHeight(keyboard) {
        let chrome = 0;
        for (const child of keyboard.get_children()) {
            if (child === keyboard._aspectContainer || !child.visible)
                continue;
            const [, natural] = child.get_preferred_height(-1);
            chrome += natural;
        }
        return chrome;
    }

    /**
     * Фактический размер актёра — по аллокации, а не по запрошенному.
     *
     * Геттер actor.width сразу после присваивания возвращает то, что мы
     * попросили, а не то, что актёр получил: keyboardBox всё равно растянет
     * его на всю ширину монитора. Если считать позицию по запрошенному
     * значению, она получается разной в зависимости от момента вызова —
     * именно из-за этого клавиатура прыгала вбок при пересборке (например,
     * при открытии модального диалога по Alt+F2).
     *
     * @param {object} keyboard экземпляр Keyboard
     * @returns {{width: number, height: number}}
     */
    _actorSize(keyboard) {
        const box = keyboard.get_allocation_box?.();
        const width = box ? box.get_width() : 0;
        const height = box ? box.get_height() : 0;

        return {
            // До первой аллокации опереться не на что — берём запрошенное.
            width: width > 0 ? width : keyboard.width,
            height: height > 0 ? height : keyboard.height,
        };
    }

    /**
     * Размер того, что реально видно на экране, с учётом масштаба.
     *
     * AspectContainer в своём vfunc_allocate() сужает собственную аллокацию
     * до пропорции раскладки, поэтому его размер — это и есть область, где
     * действительно есть клавиши. Берём именно его, а не ширину актёра.
     *
     * @param {object} keyboard экземпляр Keyboard
     * @returns {{width: number, height: number}}
     */
    _contentSize(keyboard) {
        const scale = this._savedScale();
        const actor = this._actorSize(keyboard);
        const content = keyboard._aspectContainer;

        let width = actor.width;
        if (content) {
            const box = content.get_allocation_box?.();
            const allocated = box ? box.get_width() : 0;
            // Пока аллокация не посчитана, ширина нулевая — тогда честнее
            // опереться на размер актёра, чем ограничивать нулём.
            if (allocated > 0)
                width = allocated;
        }

        return {
            width: width * scale,
            height: actor.height * scale,
        };
    }

    /**
     * Целевые translation_x/y для текущих размеров и смещений.
     *
     * keyboardBox стоит в (monitor.x, monitor.y + monitor.height) и шириной
     * во весь монитор, то есть сразу ПОД нижней кромкой экрана. Значит
     * translation_y должен быть отрицательным, чтобы клавиатура «выехала».
     *
     * @param {object} keyboard экземпляр Keyboard
     * @returns {{x: number, y: number}}
     */
    _targetPosition(keyboard) {
        const monitor = Main.layoutManager.keyboardMonitor;
        if (!monitor)
            return {x: 0, y: -keyboard.height};

        const offsetX = this._settings.get_int('offset-x') + this._dragOffsetX;
        const offsetY = this._settings.get_int('offset-y') + this._dragOffsetY;

        // Только фактическая аллокация: по запрошенному размеру позиция
        // получалась разной в зависимости от момента вызова.
        const {width, height} = this._actorSize(keyboard);

        // Ограничения считаем по ВИДИМОЙ области, а не по актёру.
        //
        // Актёр Keyboard всегда во всю ширину монитора (его растягивает
        // keyboardBox), а клавиши занимают лишь узкую полосу по центру.
        // Раньше предел брался от ширины актёра — и клавиатуру можно было
        // утащить так, что видимая часть уезжала далеко за край экрана,
        // хотя формально «актёр на экране».
        const content = this._contentSize(keyboard);

        // Сетка клавиш центрирована внутри актёра, а масштаб применяется
        // относительно его центра по горизонтали, поэтому середина видимой
        // области всегда приходится на width / 2.
        const halfGap = width / 2 - content.width / 2;

        let x = (monitor.width - width) / 2 + offsetX;
        // Хотя бы MIN_VISIBLE пикселей КЛАВИШ обязаны остаться на экране,
        // иначе клавиатуру невозможно будет вернуть обратно.
        x = this._clamp(x,
            MIN_VISIBLE - halfGap - content.width,
            monitor.width - MIN_VISIBLE - halfGap);

        // Опорная точка масштаба — низ актёра, поэтому нижняя кромка видимой
        // области всегда приходится на translation_y + height.
        let y = -(height + offsetY);
        y = this._clamp(y,
            MIN_VISIBLE - monitor.height - height,
            content.height - height - MIN_VISIBLE);

        return {x, y};
    }

    _syncPosition(keyboard) {
        if (!keyboard)
            return;
        const {x, y} = this._targetPosition(keyboard);
        keyboard.translation_x = x;
        keyboard.translation_y = y;
    }

    /**
     * Перехват обработчика notify::height, поставленного в
     * _animateShowComplete(). Штатный обработчик жёстко пишет
     * translation_y = -height и затирает наше смещение; отключаем его
     * и ставим свой пересчёт позиции.
     *
     * @param {object} keyboard экземпляр Keyboard
     */
    _takeOverHeightNotify(keyboard) {
        const box = Main.layoutManager.keyboardBox;
        if (!box)
            return;

        if (keyboard._keyboardHeightNotifyId) {
            box.disconnect(keyboard._keyboardHeightNotifyId);
            keyboard._keyboardHeightNotifyId = 0;
        }

        if (this._heightNotifyId) {
            box.disconnect(this._heightNotifyId);
            this._heightNotifyId = 0;
        }

        this._heightNotifyId = box.connect('notify::height',
            () => this._syncPosition(this._keyboard));
        // Кладём id туда же, где его ждёт штатный _animateHide(): иначе
        // при скрытии обработчик останется висеть.
        keyboard._keyboardHeightNotifyId = this._heightNotifyId;

        this._syncPosition(keyboard);
    }

    _restoreHeightNotify() {
        const box = Main.layoutManager.keyboardBox;
        if (this._heightNotifyId && box) {
            try {
                box.disconnect(this._heightNotifyId);
            } catch (e) {
                // Штатный _animateHide() мог отключить его раньше нас.
                Log.debug('floating: height notify already gone', e);
            }
        }
        if (this._keyboard && this._keyboard._keyboardHeightNotifyId === this._heightNotifyId)
            this._keyboard._keyboardHeightNotifyId = 0;
        this._heightNotifyId = 0;
    }

    // --- события ---------------------------------------------------------

    _disconnectCapturedEvent() {
        if (this._capturedEventId && this._keyboard) {
            this._keyboard.disconnect(this._capturedEventId);
            this._keyboard.set_style(null);
            this._keyboard._aspectContainer?.set_style(null);
        }
        this._capturedEventId = 0;

        if (this._allocationNotifyId && this._keyboard)
            this._keyboard.disconnect(this._allocationNotifyId);
        this._allocationNotifyId = 0;
    }

    _resetGestureState() {
        this._points.clear();
        this._pinchBegin = 0;
        this._pinchRatio = 1;
        this._pointerDrag = null;
        this._dragging = false;
        this._dragOffsetX = 0;
        this._dragOffsetY = 0;
        // Возврат к сохранённому масштабу, а не к единице: прерванный жест
        // не должен отменять ранее зафиксированный размер.
        if (this._keyboard)
            this._applyScale(this._keyboard);
        this._syncPosition(this._keyboard);
    }

    /**
     * Единственная точка входа для касаний.
     *
     * Сигнал 'captured-event' идёт по цепочке сверху вниз и приходит нам
     * раньше, чем кнопке клавиши. Возвращая EVENT_STOP, мы гасим событие
     * до печати — именно так режимы перемещения и масштабирования не
     * набирают текст.
     *
     * @param {object} event Clutter.Event
     * @returns {boolean} Clutter.EVENT_STOP или Clutter.EVENT_PROPAGATE
     */
    _onCapturedEvent(event) {
        if (!this._moveMode && !this._resizeMode)
            return Clutter.EVENT_PROPAGATE;
        if (!this._keyboard)
            return Clutter.EVENT_PROPAGATE;

        // Панель кнопок лежит внутри самого актёра Keyboard, поэтому её
        // нажатия тоже приходят сюда. Гасить их нельзя: иначе взведённый
        // режим невозможно будет выключить той же кнопкой, которой включили.
        if (this._isToolbarEvent(event))
            return Clutter.EVENT_PROPAGATE;

        switch (event.type()) {
        case Clutter.EventType.TOUCH_BEGIN:
            return this._onTouchBegin(event);
        case Clutter.EventType.TOUCH_UPDATE:
            return this._onTouchUpdate(event);
        case Clutter.EventType.TOUCH_END:
        case Clutter.EventType.TOUCH_CANCEL:
            return this._onTouchEnd(event);
        case Clutter.EventType.BUTTON_PRESS:
            return this._onButtonPress(event);
        case Clutter.EventType.MOTION:
            return this._onMotion(event);
        case Clutter.EventType.BUTTON_RELEASE:
            return this._onButtonRelease(event);
        default:
            return Clutter.EVENT_PROPAGATE;
        }
    }

    /**
     * Пришло ли событие из панели кнопок (lib/toolbar.js).
     *
     * Поднимаемся от источника события вверх до самого Keyboard: всё, что
     * помечено классом osk-toolbar, пропускаем к кнопкам нетронутым.
     *
     * @param {object} event Clutter.Event
     * @returns {boolean}
     */
    _isToolbarEvent(event) {
        const toolbar = this._toolbarActor;
        if (!toolbar)
            return false;

        // Основной путь: прямая проверка родства. contains() отвечает и за
        // сам актёр панели, и за любую вложенную кнопку с иконкой.
        const source = event.get_source();
        if (source && toolbar.contains(source))
            return true;

        // Запасной путь по координатам: у сенсорных событий источником может
        // оказаться не тот актёр, по которому реально попал палец (пикинг
        // в фазе capture ещё не обязан совпадать с конечной целью). Панель
        // маленькая, поэтому промах здесь дороже лишней проверки.
        const [x, y] = event.get_coords();
        const [tx, ty] = toolbar.get_transformed_position();
        const [tw, th] = toolbar.get_transformed_size();
        if (Number.isFinite(tx) && Number.isFinite(ty) &&
            x >= tx && x <= tx + tw && y >= ty && y <= ty + th)
            return true;

        return false;
    }

    /**
     * Идентификатор пальца. ClutterEventSequence — непрозрачная структура,
     * сравнивать обёртки GJS между собой нельзя, зато get_slot() отдаёт
     * стабильный int (и он интроспектируем).
     *
     * @param {object} event Clutter.Event
     * @returns {number|null}
     */
    _slotOf(event) {
        const sequence = event.get_event_sequence();
        if (!sequence)
            return null;
        return sequence.get_slot();
    }

    _onTouchBegin(event) {
        const slot = this._slotOf(event);
        if (slot === null)
            return Clutter.EVENT_PROPAGATE;

        const [x, y] = event.get_coords();
        this._points.set(slot, {x, y});

        if (this._resizeMode && this._points.size === 2) {
            this._pinchBegin = this._distance();
            this._pinchRatio = 1;
            // Опорная точка внизу по центру: клавиатура растёт вверх
            // и не «уползает» от пальцев.
            this._keyboard.set_pivot_point(0.5, 1.0);
        }

        if (this._moveMode && this._points.size === 1) {
            this._dragging = true;
            this._dragOffsetX = 0;
            this._dragOffsetY = 0;
        }

        return Clutter.EVENT_STOP;
    }

    _onTouchUpdate(event) {
        const slot = this._slotOf(event);
        if (slot === null || !this._points.has(slot))
            return Clutter.EVENT_PROPAGATE;

        const [x, y] = event.get_coords();
        const previous = this._points.get(slot);
        this._points.set(slot, {x, y});

        if (this._resizeMode && this._points.size === 2 && this._pinchBegin > 0) {
            this._pinchRatio = this._distance() / this._pinchBegin;
            // Живой масштаб только на время жеста: пересчитывать настоящую
            // аллокацию KeyContainer каждый кадр слишком дорого. Clutter
            // прогоняет пикинг через ту же матрицу трансформации, поэтому
            // касания продолжают попадать в нужные клавиши.
            this._applyScale(this._keyboard, this._pinchRatio);
        } else if (this._moveMode && this._dragging && this._points.size === 1) {
            this._dragOffsetX += x - previous.x;
            // offset-y растёт вверх (см. _targetPosition), а координаты
            // Clutter — вниз, отсюда знак минус.
            this._dragOffsetY -= y - previous.y;
            this._syncPosition(this._keyboard);
        }

        return Clutter.EVENT_STOP;
    }

    _onTouchEnd(event) {
        const slot = this._slotOf(event);
        if (slot === null || !this._points.has(slot))
            return Clutter.EVENT_PROPAGATE;

        const wasPinch = this._resizeMode && this._points.size === 2;
        this._points.delete(slot);

        if (wasPinch) {
            // Коммитим на первом же поднятом пальце: продолжать щипок
            // одним пальцем всё равно нечем.
            this._commitScale(this._pinchRatio);
            this._pinchBegin = 0;
            this._pinchRatio = 1;
        } else if (this._moveMode && this._dragging && this._points.size === 0) {
            this._commitOffsets();
        }

        return Clutter.EVENT_STOP;
    }

    // Мышь/тачпад: режим перемещения должен работать и без сенсорного
    // экрана, поэтому дублируем логику на кнопке указателя.

    _onButtonPress(event) {
        if (!this._moveMode)
            return Clutter.EVENT_PROPAGATE;
        if (event.get_button() !== Clutter.BUTTON_PRIMARY)
            return Clutter.EVENT_PROPAGATE;

        const [x, y] = event.get_coords();
        this._pointerDrag = {x, y};
        this._dragging = true;
        this._dragOffsetX = 0;
        this._dragOffsetY = 0;
        return Clutter.EVENT_STOP;
    }

    _onMotion(event) {
        if (!this._pointerDrag)
            return Clutter.EVENT_PROPAGATE;

        const [x, y] = event.get_coords();
        this._dragOffsetX += x - this._pointerDrag.x;
        this._dragOffsetY -= y - this._pointerDrag.y;
        this._pointerDrag = {x, y};
        this._syncPosition(this._keyboard);
        return Clutter.EVENT_STOP;
    }

    _onButtonRelease(_event) {
        if (!this._pointerDrag)
            return Clutter.EVENT_PROPAGATE;

        this._pointerDrag = null;
        this._commitOffsets();
        return Clutter.EVENT_STOP;
    }

    /**
     * Расстояние между двумя отслеживаемыми пальцами.
     *
     * @returns {number}
     */
    _distance() {
        const [a, b] = [...this._points.values()];
        if (!a || !b)
            return 0;
        return Math.hypot(b.x - a.x, b.y - a.y);
    }

    /**
     * Записать накопленный сдвиг в GSettings. Во время перетаскивания
     * двигали только актор — в dconf пишем один раз, по завершении жеста.
     */
    _commitOffsets() {
        if (!this._dragging)
            return;
        this._dragging = false;

        const x = this._settings.get_int('offset-x') + Math.round(this._dragOffsetX);
        const y = this._settings.get_int('offset-y') + Math.round(this._dragOffsetY);
        this._dragOffsetX = 0;
        this._dragOffsetY = 0;
        this._settings.set_int('offset-x', x);
        this._settings.set_int('offset-y', y);
        this._syncPosition(this._keyboard);
        this._disarm();
    }

    /**
     * Свернуть масштаб жеста в проценты настроек и вернуть scale = 1,
     * чтобы текст снова рисовался в родном разрешении.
     *
     * @param {number} ratio итоговый коэффициент щипка
     */
    _commitScale(ratio) {
        const keyboard = this._keyboard;
        if (!keyboard)
            return;

        if (!Number.isFinite(ratio) || ratio <= 0) {
            this._applyScale(keyboard);
            this._disarm();
            return;
        }

        // Складываем коэффициент жеста с уже сохранённым масштабом.
        const percent = this._clamp(
            Math.round(this._savedScale() * ratio * 100),
            SCALE_MIN, SCALE_MAX);

        this._settings.set_int('scale-percent', percent);

        // changed:: тоже дёрнет _relayout(), но значение могло не
        // измениться (упёрлись в границу) — применяем явно.
        this._applyScale(keyboard);
        this._syncPosition(keyboard);
        this._disarm();
    }

    /**
     * Снять оба режима после завершённого жеста.
     *
     * Это ещё и страховка от «залипания»: даже если нажатие на кнопку панели
     * почему-то не дойдёт до неё, одного перетаскивания или щипка достаточно,
     * чтобы вернуть клавиатуре обычное поведение. Оказаться запертым в режиме,
     * где клавиши не печатают, нельзя.
     */
    _disarm() {
        if (!this._moveMode && !this._resizeMode)
            return;
        this._moveMode = false;
        this._resizeMode = false;
        this._syncStyle();
        this._emitMode();
    }

    _syncStyle() {
        const keyboard = this._keyboard;
        if (!keyboard)
            return;

        // #keyboard объявлен через #id, перебить его можно только
        // инлайновым стилем. Сам актёр всегда делаем прозрачным — иначе его
        // заливка растянется во всю ширину монитора и даст пустые поля.
        keyboard.set_style(STYLE_KEYBOARD_BASE);

        // Фон и подсветку режима несёт контейнер с клавишами: он занимает
        // ровно ту область, где клавиши действительно есть.
        const content = keyboard._aspectContainer;
        if (!content)
            return;

        let style = STYLE_CONTENT;
        if (this._moveMode)
            style += STYLE_MOVE;
        else if (this._resizeMode)
            style += STYLE_RESIZE;

        content.set_style(style);
    }

    _clamp(value, min, max) {
        if (max < min)
            return min;
        return Math.min(Math.max(value, min), max);
    }
}
