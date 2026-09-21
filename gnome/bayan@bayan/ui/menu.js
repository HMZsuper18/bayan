import St from 'gi://St';
import Gio from 'gi://Gio';
import Clutter from 'gi://Clutter';
import {gettext as _} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';
import * as ModalDialog from 'resource:///org/gnome/shell/ui/modalDialog.js';

const PRAYER_ORDER = ['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha'];
const PRAYER_DISPLAY = {
    fajr: 'Fajr',
    sunrise: 'Sunrise',
    dhuhr: 'Dhuhr',
    asr: 'Asr',
    maghrib: 'Maghrib',
    isha: 'Isha',
};

export class PrayerMenu {
    constructor(indicator, extensionDir, settings, version) {
        this._indicator = indicator;
        this._extensionDir = extensionDir;
        this._settings = settings;
        this._version = version || '';
        this._prayerItems = {};
        this._locationItem = null;
        this._hijriItem = null;
        this._onRefresh = null;
        this._onOpenSettings = null;
        this._onLocationSwitch = null;

        this._build();
    }

    setCallbacks({ onRefresh, onOpenSettings, onLocationSwitch }) {
        this._onRefresh = onRefresh;
        this._onOpenSettings = onOpenSettings;
        this._onLocationSwitch = onLocationSwitch;
    }

    _build() {
        const { menu } = this._indicator;

        this._locationItem = new PopupMenu.PopupSubMenuMenuItem(_('Location: Not set'));
        this._locationItem.insert_child_at_index(
            this._createMenuIcon('location.svg'), 1);
        menu.addMenuItem(this._locationItem);

        this._hijriItem = new PopupMenu.PopupMenuItem('', { reactive: false });
        this._hijriItem.visible = false;
        this._hijriItem.insert_child_at_index(
            this._createMenuIcon('bayan-logo.svg'), 1);
        menu.addMenuItem(this._hijriItem);

        menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        for (const prayer of PRAYER_ORDER) {
            const item = new PopupMenu.PopupMenuItem(PRAYER_DISPLAY[prayer], {
                reactive: false,
                style_class: 'bayan-prayer-row',
            });
            item.insert_child_at_index(
                this._createMenuIcon(`${prayer}.svg`), 1);

            const timeLabel = new St.Label({
                text: '--:--',
                style_class: 'bayan-prayer-time',
                x_expand: true,
                x_align: Clutter.ActorAlign.END,
            });
            item.add_child(timeLabel);
            item._timeLabel = timeLabel;

            this._prayerItems[prayer] = item;
            menu.addMenuItem(item);
        }

        menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        const actionItem = new PopupMenu.PopupBaseMenuItem({
            reactive: false,
            style_class: 'bayan-button-container',
        });

        const actionBox = new St.BoxLayout({
            style_class: 'bayan-button-box',
            vertical: false,
            y_align: Clutter.ActorAlign.CENTER,
            x_expand: true,
        });

        const refreshBtn = this._createRoundButton('view-refresh-symbolic');
        refreshBtn.connect('clicked', () => {
            this._indicator.menu._getTopMenu().close();
            this._onRefresh?.();
        });

        const aboutBtn = this._createRoundButton('dialog-information-symbolic');
        aboutBtn.connect('clicked', () => {
            this._indicator.menu._getTopMenu().close();
            this._showAboutDialog();
        });

        const settingsBtn = this._createRoundButton('preferences-system-symbolic');
        settingsBtn.connect('clicked', () => {
            this._indicator.menu._getTopMenu().close();
            this._onOpenSettings?.();
        });

        aboutBtn.child.icon_size = 22;

        actionBox.add_child(refreshBtn);
        actionBox.add_child(new St.Widget({x_expand: true}));
        actionBox.add_child(aboutBtn);
        actionBox.add_child(new St.Widget({x_expand: true}));
        actionBox.add_child(settingsBtn);
        actionItem.actor.add_child(actionBox);
        menu.addMenuItem(actionItem);
    }

    updateTimes(allTimes, nextPrayerName, showSunrise) {
        if (!allTimes) return;

        for (const prayer of PRAYER_ORDER) {
            const item = this._prayerItems[prayer];
            if (!item) continue;

            if (prayer === 'sunrise') {
                item.visible = showSunrise;
                if (!showSunrise) continue;
            }

            const time = allTimes[prayer] || '--:--';
            item._timeLabel.text = time;

            if (prayer === nextPrayerName) {
                item.add_style_class_name('prayer-times-next');
            } else {
                item.remove_style_class_name('prayer-times-next');
            }
        }
    }

    updateLocation(locationName, savedLocations, activeId) {
        this._locationItem.label.text = locationName || _('Location: Not set');

        this._locationItem.menu.removeAll();

        for (const loc of savedLocations) {
            const item = new PopupMenu.PopupMenuItem(loc.name);
            if (loc.id === activeId) {
                item.setOrnament(PopupMenu.Ornament.CHECK);
            }
            item.connect('activate', () => this._onLocationSwitch?.(loc));
            this._locationItem.menu.addMenuItem(item);
        }

        if (savedLocations.length > 0) {
            this._locationItem.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        }

        const addItem = new PopupMenu.PopupMenuItem(_('Add location...'));
        addItem.connect('activate', () => this._onOpenSettings?.());
        this._locationItem.menu.addMenuItem(addItem);
    }

    clear() {
        this._locationItem.label.text = _('Location: Not set');
        this._locationItem.menu.removeAll();

        const addItem = new PopupMenu.PopupMenuItem(_('Add location...'));
        addItem.connect('activate', () => this._onOpenSettings?.());
        this._locationItem.menu.addMenuItem(addItem);

        for (const prayer of PRAYER_ORDER) {
            const item = this._prayerItems[prayer];
            if (item) item._timeLabel.text = '--:--';
            item?.remove_style_class_name('prayer-times-next');
        }

        this._hijriItem.visible = false;
    }

    updateHijri(hijriText, showHijri) {
        if (!showHijri || !hijriText) {
            this._hijriItem.visible = false;
            return;
        }
        this._hijriItem.label.text = hijriText;
        this._hijriItem.visible = true;
    }

    _showAboutDialog() {
        const dialog = new ModalDialog.ModalDialog({
            styleClass: 'bayan-about-dialog',
            destroyOnClose: true,
        });

        const content = new St.BoxLayout({
            vertical: true,
            x_align: Clutter.ActorAlign.CENTER,
            style_class: 'bayan-about-content',
        });

        const logoPath = this._extensionDir.get_child('icons')
            .get_child('bayan-logo.svg').get_path();
        content.add_child(new St.Icon({
            gicon: Gio.icon_new_for_string(logoPath),
            icon_size: 64,
            style_class: 'bayan-about-logo',
        }));

        content.add_child(new St.Label({
            text: 'Bayan: Islamic Prayer Times',
            style_class: 'bayan-about-title',
            x_align: Clutter.ActorAlign.CENTER,
        }));

        content.add_child(new St.Label({
            text: 'Your daily prayer companion.',
            style_class: 'bayan-about-tagline',
            x_align: Clutter.ActorAlign.CENTER,
        }));

        const linksBox = new St.BoxLayout({
            vertical: true,
            x_align: Clutter.ActorAlign.CENTER,
            style_class: 'bayan-about-links',
        });

        const addLink = (label, url) => {
            const btn = new St.Button({
                label,
                style_class: 'bayan-about-link',
                x_align: Clutter.ActorAlign.CENTER,
            });
            btn.connect('clicked', () => {
                Gio.AppInfo.launch_default_for_uri(url, null);
                dialog.close();
            });
            linksBox.add_child(btn);
        };

        addLink('sajda.com', 'https://sajda.com/en');
        addLink('GitHub', 'https://github.com/anomalyco/bayan');

        content.add_child(linksBox);

        if (this._version) {
            content.add_child(new St.Label({
                text: `Version: ${this._version}`,
                style_class: 'bayan-about-version',
                x_align: Clutter.ActorAlign.CENTER,
            }));
        }

        dialog.contentLayout.add_child(content);

        dialog.addButton({
            label: _('Close'),
            action: () => dialog.close(),
            key: Clutter.KEY_Escape,
        });

        dialog.open();
    }

    _createMenuIcon(filename) {
        const iconPath = this._extensionDir.get_child('icons')
            .get_child(filename).get_path();
        const icon = new St.Icon({
            gicon: Gio.icon_new_for_string(iconPath),
            icon_size: 18,
        });
        const bin = new St.Bin({
            style: 'width: 24px;',
            x_align: Clutter.ActorAlign.CENTER,
            child: icon,
        });
        return bin;
    }

    _createRoundButton(iconName) {
        const button = new St.Button({
            style_class: 'message-list-clear-button button bayan-button-action',
        });
        button.child = new St.Icon({ icon_name: iconName });
        return button;
    }

    destroy() {
        this._prayerItems = {};
        this._locationItem = null;
        this._hijriItem = null;
    }
}
