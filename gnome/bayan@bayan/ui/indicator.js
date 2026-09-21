import GObject from 'gi://GObject';
import St from 'gi://St';
import Gio from 'gi://Gio';
import Clutter from 'gi://Clutter';

import {gettext as _} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';

const PRAYER_ICONS = {
    fajr: 'fajr',
    sunrise: 'sunrise',
    dhuhr: 'dhuhr',
    asr: 'asr',
    maghrib: 'maghrib',
    isha: 'isha',
};

export const PrayerTimesIndicator = GObject.registerClass(
class PrayerTimesIndicator extends PanelMenu.Button {
    _init(extensionDir) {
        super._init(0.0, _('Prayer Times'));
        this.menu.box.add_style_class_name('bayan-menu');

        this._extensionDir = extensionDir;

        const box = new St.BoxLayout({
            style_class: 'panel-status-menu-box',
        });

        this._icon = new St.Icon({
            icon_size: 16,
        });
        this._setIcon('bayan-logo');

        this._label = new St.Label({
            text: _('Loading...'),
            y_align: Clutter.ActorAlign.CENTER,
            style_class: 'prayer-times-label',
        });

        box.add_child(this._icon);
        box.add_child(this._label);
        this.add_child(box);
    }

    update(nextPrayer, showCountdown) {
        if (!nextPrayer) {
            this._label.set_text(_('No data'));
            this._setIcon('bayan-logo');
            return;
        }

        const { name, timeFormatted, countdown } = nextPrayer;
        const displayName = name.charAt(0).toUpperCase() + name.slice(1);

        let text;
        if (showCountdown) {
            text = `${displayName}: ${timeFormatted} (${countdown})`;
        } else {
            text = `${displayName}: ${timeFormatted}`;
        }

        this._label.set_text(text);
        this._setIcon(PRAYER_ICONS[name] || 'bayan-logo');
    }

    setStatus(text) {
        this._label.set_text(_(text));
        this._setIcon('bayan-logo');
    }

    _setIcon(iconName) {
        const iconPath = this._extensionDir.get_child('icons')
            .get_child(`${iconName}.svg`).get_path();
        const gicon = Gio.icon_new_for_string(iconPath);
        this._icon.set_gicon(gicon);
    }
});
