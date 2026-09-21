import GLib from 'gi://GLib';
import Gio from 'gi://Gio';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as MessageTray from 'resource:///org/gnome/shell/ui/messageTray.js';

const PRAYER_NAMES = {
    fajr: 'Fajr',
    dhuhr: 'Dhuhr',
    asr: 'Asr',
    maghrib: 'Maghrib',
    isha: 'Isha',
};

export class NotificationManager {
    constructor(settings, extensionDir) {
        this._settings = settings;
        this._extensionDir = extensionDir;
        this._timeouts = [];
        this._source = null;
    }

    schedule(todayTimes, timezone, asrField = 'asr') {
        this.cancelAll();

        const now = new Date();

        for (const [prayer, displayName] of Object.entries(PRAYER_NAMES)) {
            const enabled = this._settings.get_boolean(`notification-${prayer}-enabled`);
            if (!enabled) continue;

            const field = prayer === 'asr' ? asrField : prayer;
            const timeStr = todayTimes[field];
            if (!timeStr) continue;

            const prayerTime = new Date(timeStr);
            if (isNaN(prayerTime.getTime())) continue;

            const minutesBefore = this._settings.get_int(`notification-${prayer}-minutes`);
            const MAX_DELAY = 0x7FFFFFFF;

            if (minutesBefore > 0) {
                const remindAt = new Date(prayerTime.getTime() - minutesBefore * 60000);
                if (remindAt > now) {
                    const delayMs = Math.max(0, Math.min(remindAt.getTime() - now.getTime(), MAX_DELAY));
                    const tid = GLib.timeout_add(GLib.PRIORITY_DEFAULT, delayMs, () => {
                        this._fireNotification(prayer, displayName, prayerTime, minutesBefore, timezone);
                        return GLib.SOURCE_REMOVE;
                    });
                    this._timeouts.push(tid);
                }
            }

            if (prayerTime > now) {
                const delayMs = Math.max(0, Math.min(prayerTime.getTime() - now.getTime(), MAX_DELAY));
                const tid = GLib.timeout_add(GLib.PRIORITY_DEFAULT, delayMs, () => {
                    this._fireNotification(prayer, displayName, prayerTime, 0, timezone);
                    return GLib.SOURCE_REMOVE;
                });
                this._timeouts.push(tid);
            }
        }
    }

    _fireNotification(prayer, displayName, prayerTime, minutesBefore, timezone) {
        const title = minutesBefore > 0
            ? `${displayName} in ${minutesBefore} minutes`
            : `${displayName} has begun`;

        const hour12 = this._settings.get_string('time-format') === '12h';
        let timeFormatted;
        try {
            timeFormatted = new Intl.DateTimeFormat(hour12 ? 'en-US' : 'en-GB', {
                timeZone: timezone,
                hour: '2-digit',
                minute: '2-digit',
                hour12,
            }).format(prayerTime);
        } catch {
            timeFormatted = '--:--';
        }

        const safeTime = GLib.markup_escape_text(timeFormatted, -1);
        const body = `Prayer time: <b>${safeTime}</b>`;

        const iconPath = GLib.build_filenamev([
            this._extensionDir.get_path(), 'icons', `${prayer}.svg`,
        ]);
        const gicon = new Gio.FileIcon({file: Gio.File.new_for_path(iconPath)});

        const datetime = GLib.DateTime.new_from_unix_local(
            Math.floor(prayerTime.getTime() / 1000)
        );

        const buildNotification = () => {
            try {
                return new MessageTray.Notification({
                    source: this._source,
                    title,
                    body,
                    gicon,
                    useBodyMarkup: true,
                    isTransient: false,
                    resident: true,
                    urgency: 3,
                    privacyScope: 1,
                    datetime,
                });
            } catch {
                const n = new MessageTray.Notification(this._source, title, body);
                n.setTransient(false);
                n.setResident?.(true);
                n.setUrgency?.(3);
                return n;
            }
        };

        this._ensureSource();
        try {
            this._source.addNotification?.(buildNotification())
                ?? this._source.showNotification?.(buildNotification());
        } catch (e) {
            logError(e, 'Bayan: addNotification failed, rebuilding source');
            this._source = null;
            this._ensureSource();
            try {
                this._source.addNotification?.(buildNotification())
                    ?? this._source.showNotification?.(buildNotification());
            } catch (e2) {
                logError(e2, 'Bayan: notification retry also failed');
                return;
            }
        }

        if (this._settings.get_boolean('notification-sound-enabled')) {
            this._playSound();
        }
    }

    _ensureSource() {
        if (this._source) {
            const alive = Main.messageTray.contains?.(this._source)
                ?? Main.messageTray.getSources?.()?.includes(this._source)
                ?? true;
            if (!alive) {
                this._source = null;
            }
        }
        if (this._source) return;

        try {
            this._source = new MessageTray.Source({
                title: 'Bayan', iconName: 'appointment-symbolic',
            });
        } catch {
            this._source = new MessageTray.Source('Bayan', 'appointment-symbolic');
        }
        this._source.connect('destroy', () => {
            this._source = null;
        });
        Main.messageTray.add(this._source);
    }

    _playSound() {
        try {
            const customFile = this._settings.get_string('notification-sound-file');
            if (customFile) {
                this._playFile(customFile);
            } else {
                this._playSystemSound();
            }
        } catch (error) {
            logError(error, 'Bayan: failed to play notification sound');
        }
    }

    _playSystemSound() {
        try {
            const subprocess = Gio.Subprocess.new(
                ['canberra-gtk-play', '-i', 'message', '-d', 'Bayan prayer notification'],
                Gio.SubprocessFlags.NONE
            );
            subprocess.wait_async(null, (_proc, res) => {
                try { _proc.wait_finish(res); } catch {}
            });
        } catch {
            log('Bayan: canberra-gtk-play not found, cannot play system sound');
        }
    }

    _playFile(soundFile) {
        if (!GLib.path_is_absolute(soundFile)) {
            log('Bayan: sound file path must be absolute');
            return;
        }

        const file = Gio.File.new_for_path(soundFile);
        if (!file.query_exists(null)) {
            log('Bayan: sound file not found');
            return;
        }

        const info = file.query_info(
            'standard::type,standard::size',
            Gio.FileQueryInfoFlags.NOFOLLOW_SYMLINKS, null
        );
        if (info.get_file_type() !== Gio.FileType.REGULAR) {
            log('Bayan: sound file is not a regular file');
            return;
        }
        if (info.get_size() > 50 * 1024 * 1024) {
            log('Bayan: sound file exceeds 50 MB limit');
            return;
        }

        const players = ['paplay', 'pw-play'];
        for (const player of players) {
            try {
                const subprocess = Gio.Subprocess.new(
                    [player, soundFile],
                    Gio.SubprocessFlags.NONE
                );
                subprocess.wait_async(null, (_proc, res) => {
                    try { _proc.wait_finish(res); } catch {}
                });
                return;
            } catch {
                continue;
            }
        }
        log('Bayan: no audio player found (tried paplay, pw-play)');
    }

    cancelAll() {
        for (const id of this._timeouts) {
            GLib.source_remove(id);
        }
        this._timeouts = [];
    }

    destroy() {
        this.cancelAll();
        this._source?.destroy?.();
        this._source = null;
    }
}
