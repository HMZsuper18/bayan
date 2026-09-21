import GLib from 'gi://GLib';
import {Extension, gettext as _} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

import {BayanApi} from './lib/api.js';
import {Cache} from './lib/cache.js';
import {PrayerEngine} from './lib/prayerEngine.js';
import {HijriDate} from './lib/hijri.js';
import {NotificationManager} from './lib/notifications.js';
import {PrayerTimesIndicator} from './ui/indicator.js';
import {PrayerMenu} from './ui/menu.js';

export default class BayanExtension extends Extension {
    enable() {
        this._settings = this.getSettings();
        this._api = new BayanApi();
        this._cache = new Cache();
        this._engine = new PrayerEngine(this._api, this._cache);
        this._hijri = new HijriDate(this._api, this._cache);
        this._notifications = new NotificationManager(this._settings, this.dir);

        this._indicator = new PrayerTimesIndicator(this.dir);
        const version = this.metadata['version-name'] || `v${this.metadata.version}`;
        this._menu = new PrayerMenu(this._indicator, this.dir, this._settings, version);
        this._menu.setCallbacks({
            onRefresh: () => this._load(true),
            onOpenSettings: () => this.openPreferences(),
            onLocationSwitch: (loc) => this._switchLocation(loc),
        });

        Main.panel.addToStatusArea(this.uuid, this._indicator);

        this._settingsChangedId = this._settings.connect('changed', (s, key) => {
            if (key === 'active-location-id' || key === 'locations') {
                this._load().catch(e => logError(e, 'Bayan: reload failed'));
            } else if (key.startsWith('notification-')) {
                this._scheduleNotifications();
            } else if (['show-hijri', 'show-countdown', 'show-sunrise', 'asr-method', 'time-format'].includes(key)) {
                this._updateDisplay().catch(e => logError(e, 'Bayan: display update failed'));
            }
        });

        this._tickId = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 30, () => {
            this._tick();
            return GLib.SOURCE_CONTINUE;
        });

        this._cache.evictOld().catch(e => logError(e, 'Bayan: cache eviction failed'));
        this._migrateAndLoad().catch(e => logError(e, 'Bayan: initial load failed'));
    }

    async _migrateAndLoad() {
        const locations = this._parseLocations();
        const activeId = this._settings.get_string('active-location-id');

        if (locations.length === 0 && !activeId) {
            const lat = this._settings.get_double('latitude');
            const lng = this._settings.get_double('longitude');
            if (lat !== 0 || lng !== 0) {
                try {
                    const loc = await this._api.getClosestLocation(lat, lng);
                    const rawName = loc.translations?.en?.title || loc.asciiname || '';
                    const saved = {
                        id: String(loc.id), name: GLib.markup_escape_text(rawName, -1),
                        lat: loc.latitude, lng: loc.longitude,
                        country: loc.country, timezone: loc.timezone,
                        methodId: loc.method?.id,
                    };
                    this._settings.set_string('locations', JSON.stringify([saved]));
                    this._settings.set_string('active-location-id', saved.id);
                    return;
                } catch (e) {
                    logError(e, 'Bayan: migration failed');
                }
            }
        }

        await this._load();
    }

    async _load(force = false) {
        const location = this._getActiveLocation();
        if (!location) {
            this._indicator.setStatus('Set location');
            this._menu.clear();
            return;
        }

        try {
            this._indicator.setStatus('Loading...');
            const ok = await this._engine.loadForLocation(location, force);
            if (!ok) {
                this._indicator.setStatus('Error');
                return;
            }
            await this._updateAll();
        } catch (error) {
            logError(error, 'Bayan: load failed');
            this._indicator.setStatus('Error');
        }
    }

    async _updateAll() {
        await this._updateDisplay();
        this._scheduleNotifications();
    }

    _getAsrField() {
        const method = this._settings.get_string('asr-method');
        return method === 'standard' ? 'asr_shafi' : 'asr';
    }

    _getHour12() {
        return this._settings.get_string('time-format') === '12h';
    }

    async _updateDisplay() {
        const location = this._getActiveLocation();
        const showCountdown = this._settings.get_boolean('show-countdown');
        const showHijri = this._settings.get_boolean('show-hijri');
        const showSunrise = this._settings.get_boolean('show-sunrise');
        const asrField = this._getAsrField();
        const hour12 = this._getHour12();

        const nextPrayer = this._engine.getNextPrayer(asrField, hour12);
        this._indicator.update(nextPrayer, showCountdown);

        const allTimes = this._engine.getAllTimes(asrField, hour12);
        this._menu.updateTimes(allTimes, nextPrayer?.name, showSunrise);

        const locations = this._parseLocations();
        const activeId = this._settings.get_string('active-location-id');
        const locInfo = this._engine.locationInfo;
        const locName = locInfo?.translations?.en?.title
            || locInfo?.asciiname || location?.name || '';
        this._menu.updateLocation(locName, locations, activeId);

        if (showHijri && location?.country) {
            const now = new Date();
            const y = now.getFullYear();
            const m = String(now.getMonth() + 1).padStart(2, '0');
            const d = String(now.getDate()).padStart(2, '0');
            await this._hijri.load(location.country, `${y}-${m}-${d}`);
            if (!this._menu) return;
            this._menu.updateHijri(this._hijri.format(), true);
        } else {
            this._menu?.updateHijri(null, false);
        }
    }

    _scheduleNotifications() {
        if (this._engine.todayTimes) {
            const timezone = this._engine.locationInfo?.timezone || 'UTC';
            const asrField = this._getAsrField();
            this._notifications.schedule(this._engine.todayTimes, timezone, asrField);
        }
    }

    _tick() {
        const rollover = this._engine.checkDateRollover();
        if (rollover.needsFetch) {
            this._load().catch(e => logError(e, 'Bayan: date rollover fetch failed'));
            return;
        }
        if (rollover.changed) {
            this._updateAll().catch(e => logError(e, 'Bayan: date rollover update failed'));
            return;
        }
        const showCountdown = this._settings.get_boolean('show-countdown');
        const nextPrayer = this._engine.getNextPrayer(this._getAsrField(), this._getHour12());
        this._indicator.update(nextPrayer, showCountdown);
    }

    _switchLocation(loc) {
        this._settings.set_string('active-location-id', loc.id);
    }

    _parseLocations() {
        try {
            const parsed = JSON.parse(this._settings.get_string('locations'));
            return Array.isArray(parsed) ? parsed : [];
        } catch (e) {
            logError(e, 'Bayan: failed to parse locations setting');
            return [];
        }
    }

    _getActiveLocation() {
        const locations = this._parseLocations();
        const activeId = this._settings.get_string('active-location-id');
        return locations.find(l => l.id === activeId) || locations[0] || null;
    }

    disable() {
        if (this._tickId) {
            GLib.source_remove(this._tickId);
            this._tickId = null;
        }
        if (this._settingsChangedId) {
            this._settings.disconnect(this._settingsChangedId);
            this._settingsChangedId = null;
        }
        this._notifications?.destroy();
        this._menu?.destroy();
        this._indicator?.destroy();
        this._engine?.destroy();
        this._hijri?.destroy();
        this._api?.destroy();
        this._cache?.destroy();
        this._notifications = null;
        this._menu = null;
        this._indicator = null;
        this._engine = null;
        this._hijri = null;
        this._api = null;
        this._cache = null;
        this._settings = null;
    }
}
