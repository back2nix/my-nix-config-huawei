#!/usr/bin/env python3
# Захват (EVIOCGRAB) evdev-узлов физических устройств ввода: клавиатуры,
# тачпада и всего, что попросили заблокировать.
#
# Зачем отдельный процесс, а не ioctl прямо из gnome-shell:
#   ядро снимает EVIOCGRAB автоматически при закрытии файлового дескриптора.
#   Пока захват держит короткоживущий процесс-помощник, любая смерть
#   gnome-shell (краш, logout, перезапуск расширения) закрывает pipe -> мы
#   получаем EOF на stdin -> отпускаем устройства. Пользователь физически
#   не может остаться с мёртвым вводом.
#
# Поэтому основной цикл — это блокирующий sys.stdin.read(): вызывающая
# сторона открывает нас с Gio.SubprocessFlags.STDIN_PIPE и просто закрывает
# трубу, когда захват больше не нужен. Никаких сигналов и PID-файлов.
#
# Wayland: xinput здесь бесполезен (нет X-устройств реальной периферии),
# EVIOCGRAB — единственный работающий механизм. Экранная клавиатура GNOME
# не затрагивается: она печатает через Main.inputMethod.commit() и
# виртуальное Clutter-устройство, а не через evdev.
#
# Аргументы: один или несколько «дескрипторов устройства». Каждый — либо
# абсолютный путь (начинается с '/'), либо подстрока имени устройства.
# Подстрока нужна потому, что у тачпада ELAN есть второй узел ("... Mouse")
# без единого симлинка в by-path/by-id: сослаться на него можно только по
# имени из /proc/bus/input/devices. Одна подстрока может дать несколько
# узлов — захватываем все, иначе события утекут через незахваченный узел.
#
# Права: root не нужен, достаточно членства в группе input
# (/dev/input/event* — crw-rw-r-- root input).

import fcntl
import os
import signal
import sys

# ioctl EVIOCGRAB: _IOW('E', 0x90, int)
EVIOCGRAB = 0x40044590

INPUT_DEVICES = '/proc/bus/input/devices'


def warn(message):
    print(message, file=sys.stderr, flush=True)


def die(message, code=1):
    warn(message)
    sys.exit(code)


def parse_input_devices():
    """[(name, ['/dev/input/eventN', ...]), ...] из /proc/bus/input/devices.

    Записи разделены пустой строкой: 'N: Name="..."' даёт имя,
    'H: Handlers=...' — список обработчиков. Интересуют только те, где есть
    обработчик eventN: остальные (mouseN, jsN) не поддерживают EVIOCGRAB.
    """
    try:
        with open(INPUT_DEVICES, 'r', errors='replace') as fh:
            raw = fh.read()
    except OSError as exc:
        warn(f'kbd-grab: cannot read {INPUT_DEVICES}: {exc.strerror}')
        return []

    records = []
    for block in raw.split('\n\n'):
        name = None
        nodes = []
        for line in block.splitlines():
            if line.startswith('N: Name='):
                name = line.split('=', 1)[1].strip().strip('"')
            elif line.startswith('H: Handlers='):
                for handler in line.split('=', 1)[1].split():
                    if handler.startswith('event'):
                        nodes.append(f'/dev/input/{handler}')
        if name is not None and nodes:
            records.append((name, nodes))
    return records


def resolve(spec, records):
    """Один аргумент -> список evdev-узлов (может быть пустым)."""
    if spec.startswith('/'):
        return [spec]

    needle = spec.lower()
    nodes = []
    for name, candidates in records:
        if needle in name.lower():
            nodes.extend(candidates)
    return nodes


def main():
    if len(sys.argv) < 2:
        die('usage: kbd-grab.py <device-path|name-substring> [...]', 2)

    records = parse_input_devices()

    # Порядок сохраняем (для читаемого отчёта), дубли убираем по realpath:
    # by-path-симлинк и голый eventN — это один и тот же узел, открыть его
    # дважды значит захватить его дважды и в лучшем случае потратить fd.
    targets = []
    seen = set()
    for spec in sys.argv[1:]:
        nodes = resolve(spec, records)
        if not nodes:
            warn(f'kbd-grab: nothing matches "{spec}", skipping')
            continue
        for node in nodes:
            real = os.path.realpath(node)
            if real in seen:
                continue
            seen.add(real)
            targets.append(real)

    if not targets:
        die('kbd-grab: no devices resolved from ' + ' '.join(sys.argv[1:]))

    # Частичный успех — это успех: заблокировать клавиатуру, но не тачпад,
    # намного лучше, чем не заблокировать ничего. Ошибки только в stderr.
    grabbed = []
    fds = []
    for device in targets:
        try:
            fd = os.open(device, os.O_RDWR)
        except OSError as exc:
            warn(f'kbd-grab: cannot open {device}: {exc.strerror} '
                 f'(errno {exc.errno}); check the path and that the user '
                 f'is in the "input" group')
            continue
        try:
            fcntl.ioctl(fd, EVIOCGRAB, 1)
        except OSError as exc:
            os.close(fd)
            warn(f'kbd-grab: EVIOCGRAB failed on {device}: {exc.strerror} '
                 f'(errno {exc.errno}); another process may already hold '
                 f'the grab')
            continue
        fds.append(fd)
        grabbed.append(device)

    if not fds:
        die('kbd-grab: could not grab any of: ' + ' '.join(targets))

    released = False

    def release(*_args):
        # Идемпотентно: сюда приходим и по сигналу, и по нормальному выходу.
        nonlocal released
        if released:
            return
        released = True
        for fd in fds:
            try:
                fcntl.ioctl(fd, EVIOCGRAB, 0)
            except OSError:
                pass  # fd всё равно закрывается — ядро снимет захват само
            try:
                os.close(fd)
            except OSError:
                pass

    def on_signal(signum, _frame):
        release()
        sys.exit(0)

    # SIGTERM/SIGINT — если вызывающая сторона решит force_exit();
    # SIGALRM — сторож ниже.
    signal.signal(signal.SIGTERM, on_signal)
    signal.signal(signal.SIGINT, on_signal)
    signal.signal(signal.SIGALRM, on_signal)

    # Необязательный «мёртвый человек»: если процесс по какой-то причине завис
    # (например, stdin остался открытым у осиротевшего процесса), захват
    # снимется сам через KBD_GRAB_TIMEOUT секунд. 0 = выключено.
    try:
        timeout = int(os.environ.get('KBD_GRAB_TIMEOUT', '0'))
    except ValueError:
        timeout = 0
    if timeout > 0:
        signal.alarm(timeout)

    # Подтверждение для вызывающей стороны: захват уже активен.
    print('grabbed ' + ' '.join(grabbed), flush=True)

    try:
        # Блокируемся до EOF. Закрытие stdin-трубы (штатное «отпусти») или
        # смерть родителя разбудят нас здесь.
        sys.stdin.read()
    except KeyboardInterrupt:
        pass
    finally:
        release()

    sys.exit(0)


if __name__ == '__main__':
    main()
