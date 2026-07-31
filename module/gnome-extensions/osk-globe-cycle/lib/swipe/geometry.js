// Чистая геометрия: работа с ломаными без единой зависимости от GNOME.
// Всё, что здесь есть, тестируется обычным `gjs -m` без запущенной сессии.

/** @typedef {{x: number, y: number}} Point */

/**
 * @param {Point} a
 * @param {Point} b
 * @returns {number} евклидово расстояние
 */
export function distance(a, b) {
    const dx = a.x - b.x;
    const dy = a.y - b.y;
    return Math.hypot(dx, dy);
}

/**
 * Суммарная длина ломаной.
 *
 * @param {Point[]} points
 * @returns {number}
 */
export function pathLength(points) {
    let total = 0;
    for (let i = 1; i < points.length; i++)
        total += distance(points[i - 1], points[i]);
    return total;
}

/**
 * Равномерная передискретизация ломаной по длине дуги.
 *
 * Приводит траекторию пальца и «идеальную» траекторию слова к одинаковому
 * числу точек, после чего их можно сравнивать поточечно. Это location channel
 * из SHARK²: дешевле DTW и на практике различает слова не хуже.
 *
 * @param {Point[]} points исходная ломаная (>= 1 точки)
 * @param {number} count сколько точек вернуть (>= 2)
 * @returns {Point[]} ровно `count` точек
 */
export function resample(points, count) {
    if (points.length === 0)
        return [];

    if (points.length === 1 || pathLength(points) === 0)
        return new Array(count).fill(points[0]);

    const step = pathLength(points) / (count - 1);
    const result = [points[0]];

    // Курсор «сегмент + пройденное внутри него расстояние» едет по ломаной
    // один раз, поэтому передискретизация линейна по числу точек.
    let segment = 1;
    let offset = 0;

    for (let i = 1; i < count - 1; i++) {
        let remaining = step;

        while (segment < points.length) {
            const length = distance(points[segment - 1], points[segment]);
            const left = length - offset;

            if (left >= remaining) {
                offset += remaining;
                remaining = 0;
                break;
            }

            remaining -= left;
            offset = 0;
            segment++;
        }

        if (segment >= points.length)
            break;

        const from = points[segment - 1];
        const to = points[segment];
        const length = distance(from, to);
        const ratio = length === 0 ? 0 : offset / length;

        result.push({
            x: from.x + (to.x - from.x) * ratio,
            y: from.y + (to.y - from.y) * ratio,
        });
    }

    // Хвост добиваем последней точкой: накопленная погрешность может не
    // дотянуть курсор до конца ломаной.
    while (result.length < count)
        result.push(points[points.length - 1]);

    return result;
}

/**
 * Среднее поточечное расстояние между двумя ломаными одинаковой длины.
 *
 * @param {Point[]} a
 * @param {Point[]} b
 * @returns {number}
 */
export function meanPointDistance(a, b) {
    if (a.length !== b.length || a.length === 0)
        return Infinity;

    let total = 0;
    for (let i = 0; i < a.length; i++)
        total += distance(a[i], b[i]);

    return total / a.length;
}

/**
 * Убирает точки, стоящие ближе `minStep` друг к другу.
 *
 * Тачскрин выдаёт события пачками; без прореживания в начале жеста копится
 * десяток почти совпадающих точек, которые перекашивают передискретизацию.
 *
 * @param {Point[]} points
 * @param {number} minStep
 * @returns {Point[]}
 */
export function simplify(points, minStep) {
    if (points.length < 2)
        return [...points];

    const result = [points[0]];
    for (const point of points.slice(1, -1)) {
        if (distance(result[result.length - 1], point) >= minStep)
            result.push(point);
    }
    result.push(points[points.length - 1]);

    return result;
}
