import Adw from 'gi://Adw';
import Gtk from 'gi://Gtk';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';

import {ExtensionPreferences, gettext as _} from 'resource:///org/gnome/Shell/Extensions/js/extensions/prefs.js';
import {BayanApi} from './lib/api.js';

const PRAYERS = [
    { key: 'fajr', label: 'Fajr' },
    { key: 'dhuhr', label: 'Dhuhr' },
    { key: 'asr', label: 'Asr' },
    { key: 'maghrib', label: 'Maghrib' },
    { key: 'isha', label: 'Isha' },
];

export default class BayanPreferences extends ExtensionPreferences {
    fillPreferencesWindow(window) {
        const settings = this.getSettings();
        this._api = new BayanApi();
        const api = this._api;

        const page = new Adw.PreferencesPage({
            title: _('General'),
            icon_name: 'dialog-information-symbolic',
        });
        window.add(page);

        this._buildLocationsGroup(page, settings, api);
        this._buildNotificationsGroup(page, settings);
        this._buildDisplayGroup(page, settings);

        this._settingsChangedId = settings.connect('changed::locations', () => {
            this._rebuildSavedLocations(settings);
        });

        window.connect('close-request', () => {
            if (this._searchTimeout) {
                GLib.Source.remove(this._searchTimeout);
                this._searchTimeout = null;
            }
            settings.disconnect(this._settingsChangedId);
            this._settingsChangedId = null;
            api.destroy();
            return false;
        });
    }

    _buildLocationsGroup(page, settings, api) {
        const group = new Adw.PreferencesGroup({
            title: _('Locations'),
            description: _('Search and manage your prayer time locations'),
        });
        page.add(group);

        const searchRow = new Adw.EntryRow({ title: _('Search City') });
        group.add(searchRow);

        const resultsExpander = new Adw.ExpanderRow({
            title: _('Search Results'),
            subtitle: _('Type at least 2 characters'),
            show_enable_switch: false,
            expanded: false,
        });
        group.add(resultsExpander);

        this._searchTimeout = null;
        let searchId = 0;
        let resultRows = [];

        const clearResults = () => {
            resultRows.forEach(r => resultsExpander.remove(r));
            resultRows = [];
        };

        searchRow.connect('changed', () => {
            const query = searchRow.text.trim();
            if (this._searchTimeout) {
                GLib.Source.remove(this._searchTimeout);
                this._searchTimeout = null;
            }
            searchId++;
            const thisId = searchId;

            if (query.length < 2) {
                clearResults();
                resultsExpander.set_subtitle(_('Type at least 2 characters'));
                resultsExpander.set_expanded(false);
                return;
            }

            this._searchTimeout = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 500, () => {
                this._searchTimeout = null;
                this._performSearch(api, settings, query, thisId, searchId,
                    resultsExpander, resultRows, clearResults);
                return GLib.SOURCE_REMOVE;
            });
        });

        this._savedGroup = new Adw.PreferencesGroup({
            title: _('Saved Locations'),
        });
        page.add(this._savedGroup);
        this._rebuildSavedLocations(settings);
    }

    async _performSearch(api, settings, query, thisId, currentSearchId,
        resultsExpander, resultRows, clearResults) {
        clearResults();
        resultsExpander.set_subtitle(_('Searching...'));
        resultsExpander.set_expanded(true);

        try {
            const results = await api.searchCities(query);
            if (thisId !== currentSearchId) return;

            if (!results.length) {
                resultsExpander.set_subtitle(_('No cities found'));
                return;
            }

            resultsExpander.set_subtitle(`${results.length} cities found`);

            for (const city of results.slice(0, 15)) {
                const name = city.translations?.en?.title || city.asciiname || 'Unknown';
                const subtitle = [city.admin1_asciiname, city.translations?.en?.country_title]
                    .filter(Boolean).join(', ');

                const row = new Adw.ActionRow({
                    title: name,
                    subtitle,
                    activatable: true,
                });
                row.add_suffix(new Gtk.Image({ icon_name: 'list-add-symbolic' }));

                row.connect('activated', () => {
                    this._addLocation(api, settings, city, name);
                    resultsExpander.set_expanded(false);
                });

                resultsExpander.add_row(row);
                resultRows.push(row);
            }
        } catch (error) {
            logError(error, 'City search failed');
            resultsExpander.set_subtitle(_('Search failed'));
        }
    }

    async _addLocation(api, settings, city, name) {
        try {
            const fullLoc = await api.getClosestLocation(city.latitude, city.longitude);
            const saved = {
                id: String(fullLoc.id),
                name: GLib.markup_escape_text(
                    fullLoc.translations?.en?.title || fullLoc.asciiname || name, -1),
                lat: fullLoc.latitude,
                lng: fullLoc.longitude,
                country: fullLoc.country,
                timezone: fullLoc.timezone,
                methodId: fullLoc.method?.id,
            };

            const locations = this._parseLocations(settings);
            if (!locations.find(l => l.id === saved.id)) {
                locations.push(saved);
                settings.set_string('locations', JSON.stringify(locations));
            }
            if (!settings.get_string('active-location-id')) {
                settings.set_string('active-location-id', saved.id);
            }
        } catch (error) {
            logError(error, 'Failed to add location');
        }
    }

    _rebuildSavedLocations(settings) {
        if (!this._savedGroup) return;

        if (this._savedRows) {
            this._savedRows.forEach(r => this._savedGroup.remove(r));
        }
        this._savedRows = [];

        const locations = this._parseLocations(settings);
        const activeId = settings.get_string('active-location-id');

        for (const loc of locations) {
            const expander = new Adw.ExpanderRow({
                title: loc.name,
                subtitle: loc.country || '',
            });

            if (loc.id === activeId) {
                expander.add_prefix(new Gtk.Image({ icon_name: 'starred-symbolic' }));
            }

            const removeBtn = new Gtk.Button({
                icon_name: 'edit-delete-symbolic',
                valign: Gtk.Align.CENTER,
                css_classes: ['flat'],
            });
            removeBtn.connect('clicked', () => {
                const locs = this._parseLocations(settings)
                    .filter(l => l.id !== loc.id);
                settings.set_string('locations', JSON.stringify(locs));
                if (activeId === loc.id) {
                    settings.set_string('active-location-id',
                        locs.length > 0 ? locs[0].id : '');
                }
            });
            expander.add_suffix(removeBtn);

            if (loc.id !== activeId) {
                const activateRow = new Adw.ActionRow({
                    title: _('Set as active'),
                    activatable: true,
                });
                activateRow.add_suffix(new Gtk.Image({ icon_name: 'object-select-symbolic' }));
                activateRow.connect('activated', () => {
                    settings.set_string('active-location-id', loc.id);
                    this._rebuildSavedLocations(settings);
                });
                expander.add_row(activateRow);
            }

            const methodRow = new Adw.ComboRow({
                title: _('Calculation Method'),
                use_subtitle: true,
            });
            const methodModel = new Gtk.StringList();
            methodModel.append(_('Loading...'));
            methodRow.model = methodModel;
            methodRow.sensitive = false;
            expander.add_row(methodRow);

            this._loadMethodsForRow(this._api, settings, loc, methodRow);

            this._savedGroup.add(expander);
            this._savedRows.push(expander);
        }
    }

    _buildNotificationsGroup(page, settings) {
        const group = new Adw.PreferencesGroup({
            title: _('Notifications'),
            description: _('Configure prayer time notifications'),
        });
        page.add(group);

        const soundRow = new Adw.SwitchRow({
            title: _('Play Sound'),
            subtitle: _('Play adhan sound with notifications'),
        });
        settings.bind('notification-sound-enabled', soundRow, 'active',
            Gio.SettingsBindFlags.DEFAULT);
        group.add(soundRow);

        const currentFile = settings.get_string('notification-sound-file');
        const fileRow = new Adw.ActionRow({
            title: _('Custom Sound File'),
            subtitle: currentFile || _('Default adhan'),
            activatable: true,
        });
        const clearBtn = new Gtk.Button({
            icon_name: 'edit-clear-symbolic',
            valign: Gtk.Align.CENTER,
            css_classes: ['flat'],
            visible: Boolean(currentFile),
        });
        clearBtn.connect('clicked', () => {
            settings.set_string('notification-sound-file', '');
            fileRow.subtitle = _('Default adhan');
            clearBtn.visible = false;
        });
        fileRow.add_suffix(clearBtn);
        fileRow.add_suffix(new Gtk.Image({ icon_name: 'document-open-symbolic' }));
        fileRow.connect('activated', () => {
            const dialog = new Gtk.FileDialog({
                title: _('Select Sound File'),
            });
            const filter = new Gtk.FileFilter();
            filter.set_name(_('Audio files'));
            filter.add_mime_type('audio/ogg');
            filter.add_mime_type('audio/mpeg');
            filter.add_mime_type('audio/wav');
            filter.add_mime_type('audio/flac');
            filter.add_pattern('*.ogg');
            filter.add_pattern('*.mp3');
            filter.add_pattern('*.wav');
            filter.add_pattern('*.flac');
            const filters = Gio.ListStore.new(Gtk.FileFilter);
            filters.append(filter);
            dialog.filters = filters;
            const soundsDir = Gio.File.new_for_path(
                GLib.build_filenamev([this.path, 'sounds']));
            dialog.initial_folder = soundsDir;
            dialog.open(fileRow.get_root(), null, (dlg, res) => {
                try {
                    const file = dlg.open_finish(res);
                    const path = file.get_path();
                    settings.set_string('notification-sound-file', path);
                    fileRow.subtitle = GLib.path_get_basename(path);
                    clearBtn.visible = true;
                } catch {
                    // User cancelled
                }
            });
        });
        settings.bind('notification-sound-enabled', fileRow, 'sensitive',
            Gio.SettingsBindFlags.GET);
        group.add(fileRow);

        for (const { key, label } of PRAYERS) {
            const row = new Adw.SpinRow({
                title: label,
                subtitle: _('Minutes before prayer'),
                adjustment: new Gtk.Adjustment({
                    lower: 0, upper: 120, step_increment: 5, value:
                        settings.get_int(`notification-${key}-minutes`),
                }),
            });
            row.connect('notify::value', () => {
                settings.set_int(`notification-${key}-minutes`, row.value);
            });

            const toggle = new Gtk.Switch({ valign: Gtk.Align.CENTER });
            settings.bind(`notification-${key}-enabled`, toggle, 'active',
                Gio.SettingsBindFlags.DEFAULT);
            row.add_prefix(toggle);

            group.add(row);
        }
    }

    _buildDisplayGroup(page, settings) {
        const group = new Adw.PreferencesGroup({
            title: _('Display'),
            description: _('Customize what is shown'),
        });
        page.add(group);

        const hijriRow = new Adw.SwitchRow({
            title: _('Show Hijri Date'),
            subtitle: _('Display Islamic calendar date in menu'),
        });
        settings.bind('show-hijri', hijriRow, 'active', Gio.SettingsBindFlags.DEFAULT);
        group.add(hijriRow);

        const countdownRow = new Adw.SwitchRow({
            title: _('Show Countdown'),
            subtitle: _('Show time remaining in panel'),
        });
        settings.bind('show-countdown', countdownRow, 'active', Gio.SettingsBindFlags.DEFAULT);
        group.add(countdownRow);

        const sunriseRow = new Adw.SwitchRow({
            title: _('Show Sunrise'),
            subtitle: _('Display sunrise time in menu'),
        });
        settings.bind('show-sunrise', sunriseRow, 'active', Gio.SettingsBindFlags.DEFAULT);
        group.add(sunriseRow);

        const timeModel = new Gtk.StringList();
        timeModel.append(_('24-hour'));
        timeModel.append(_('12-hour (AM/PM)'));
        const timeRow = new Adw.ComboRow({
            title: _('Time Format'),
            model: timeModel,
        });
        timeRow.selected = settings.get_string('time-format') === '12h' ? 1 : 0;
        timeRow.connect('notify::selected', () => {
            settings.set_string('time-format', timeRow.selected === 1 ? '12h' : '24h');
        });
        group.add(timeRow);

        const asrModel = new Gtk.StringList();
        asrModel.append(_('Hanafi'));
        asrModel.append(_('Standard (Shafi\'i)'));
        const asrRow = new Adw.ComboRow({
            title: _('Asr Calculation'),
            subtitle: _('Hanafi uses a later Asr time'),
            model: asrModel,
        });
        asrRow.selected = settings.get_string('asr-method') === 'standard' ? 1 : 0;
        asrRow.connect('notify::selected', () => {
            settings.set_string('asr-method', asrRow.selected === 1 ? 'standard' : 'hanafi');
        });
        group.add(asrRow);
    }

    async _loadMethodsForRow(api, settings, loc, methodRow) {
        try {
            const methods = await api.getCalcMethods(loc.id);
            if (!methods.length) return;

            const model = new Gtk.StringList();
            let selectedIdx = 0;
            const rawLang = GLib.getenv('LANG') || '';
            const lang = rawLang.match(/^([a-z]{2})/)?.[1] || 'en';

            for (let i = 0; i < methods.length; i++) {
                const m = methods[i];
                const name = m.translations?.[lang]?.title
                    || m.translations?.en?.title || `Method ${m.id}`;
                const suffix = m.is_verified ? ` (${_('verified')})` : '';
                model.append(`${name}${suffix}`);
                if (m.id === loc.methodId) selectedIdx = i;
            }

            const listFactory = new Gtk.SignalListItemFactory();
            listFactory.connect('setup', (_factory, listItem) => {
                const label = new Gtk.Label({
                    xalign: 0,
                    wrap: true,
                    max_width_chars: 40,
                });
                listItem.child = label;
            });
            listFactory.connect('bind', (_factory, listItem) => {
                listItem.child.label = listItem.item.string;
            });
            methodRow.list_factory = listFactory;

            methodRow.model = model;
            methodRow.selected = selectedIdx;
            methodRow.sensitive = true;

            methodRow.connect('notify::selected', () => {
                const chosen = methods[methodRow.selected];
                if (!chosen || chosen.id == null) return;
                const currentLocs = this._parseLocations(settings);
                const current = currentLocs.find(l => l.id === loc.id);
                if (!current || chosen.id === current.methodId) return;
                const updated = currentLocs.map(l =>
                    l.id === loc.id ? { ...l, methodId: chosen.id } : l
                );
                settings.set_string('locations', JSON.stringify(updated));
            });
        } catch (error) {
            logError(error, 'Failed to load calculation methods');
        }
    }

    _parseLocations(settings) {
        try {
            const parsed = JSON.parse(settings.get_string('locations'));
            return Array.isArray(parsed) ? parsed : [];
        } catch {
            return [];
        }
    }
}
