import Clutter from 'gi://Clutter';
import GLib from 'gi://GLib';
import St from 'gi://St';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

export default class DualClockExtension extends Extension {
    enable() {
        this._moscowZone = GLib.TimeZone.new_identifier('Europe/Moscow');
        this._label = new St.Label({
            style_class: 'clock',
            y_align: Clutter.ActorAlign.CENTER,
        });
        const clock = Main.panel.statusArea.dateMenu._clockDisplay;
        clock.get_parent().insert_child_above(this._label, clock);
        this._update();
        // Use actual wall time each tick, including after suspend or NTP updates.
        this._sourceId = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 1, () => {
            this._update();
            return GLib.SOURCE_CONTINUE;
        });
    }

    _update() {
        const now = GLib.DateTime.new_now(this._moscowZone);
        this._label.text = `  ·  МСК ${now.format('%H:%M')}`;
    }

    disable() {
        if (this._sourceId) {
            GLib.Source.remove(this._sourceId);
            this._sourceId = null;
        }
        this._label?.destroy();
        this._label = null;
        this._moscowZone = null;
    }
}
