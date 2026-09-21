import Gio from 'gi://Gio';
import GLib from 'gi://GLib';

Gio._promisify(Gio.File.prototype, 'load_contents_async', 'load_contents_finish');
Gio._promisify(Gio.File.prototype,
    'replace_contents_bytes_async', 'replace_contents_finish');
Gio._promisify(Gio.File.prototype,
    'enumerate_children_async', 'enumerate_children_finish');
Gio._promisify(Gio.FileEnumerator.prototype,
    'next_files_async', 'next_files_finish');
Gio._promisify(Gio.File.prototype, 'delete_async', 'delete_finish');

export class Cache {
    constructor() {
        this._cacheDir = GLib.build_filenamev([
            GLib.get_user_cache_dir(), 'bayan-gnome'
        ]);
        GLib.mkdir_with_parents(this._cacheDir, 0o700);
    }

    _safeName(value) {
        return String(value).replace(/[^a-zA-Z0-9\-_.]/g, '_');
    }

    _getPath(filename) {
        return GLib.build_filenamev([this._cacheDir, filename]);
    }

    async _readFile(filename) {
        const file = Gio.File.new_for_path(this._getPath(filename));
        try {
            const [contents] = await file.load_contents_async(null);
            return new TextDecoder('utf-8').decode(contents);
        } catch (e) {
            if (e instanceof GLib.Error
                && e.matches(Gio.IOErrorEnum, Gio.IOErrorEnum.NOT_FOUND)) {
                return null;
            }
            logError(e, `Bayan: cache read failed for ${filename}`);
            return null;
        }
    }

    async _writeFile(filename, contents) {
        const file = Gio.File.new_for_path(this._getPath(filename));
        const bytes = new GLib.Bytes(new TextEncoder().encode(contents));
        try {
            await file.replace_contents_bytes_async(
                bytes, null, false,
                Gio.FileCreateFlags.REPLACE_DESTINATION | Gio.FileCreateFlags.PRIVATE,
                null
            );
        } catch (e) {
            logError(e, `Bayan: cache write failed for ${filename}`);
        }
    }

    async getPrayerData(locationId, methodId, year) {
        const key = `${this._safeName(locationId)}_${this._safeName(methodId)}_${year}`;
        const text = await this._readFile(`${key}.json`);
        if (!text) return null;
        try {
            return JSON.parse(text);
        } catch {
            return null;
        }
    }

    async setPrayerData(locationId, methodId, year, data) {
        const key = `${this._safeName(locationId)}_${this._safeName(methodId)}_${year}`;
        await this._writeFile(`${key}.json`, JSON.stringify(data));
    }

    async getEtag(locationId, methodId, year) {
        const key = `${this._safeName(locationId)}_${this._safeName(methodId)}_${year}`;
        return this._readFile(`${key}.etag`);
    }

    async setEtag(locationId, methodId, year, etag) {
        const key = `${this._safeName(locationId)}_${this._safeName(methodId)}_${year}`;
        await this._writeFile(`${key}.etag`, etag);
    }

    async getLocationMeta(locationId) {
        const text = await this._readFile(`location_${this._safeName(locationId)}.json`);
        if (!text) return null;
        try {
            return JSON.parse(text);
        } catch {
            return null;
        }
    }

    async setLocationMeta(locationId, data) {
        await this._writeFile(`location_${this._safeName(locationId)}.json`, JSON.stringify(data));
    }

    async getHijriDate(dateString) {
        const text = await this._readFile(`hijri_${this._safeName(dateString)}.json`);
        if (!text) return null;
        try {
            return JSON.parse(text);
        } catch {
            return null;
        }
    }

    async setHijriDate(dateString, data) {
        await this._writeFile(`hijri_${this._safeName(dateString)}.json`, JSON.stringify(data));
    }

    async getFreshData(locationId, methodId, year, todayString) {
        const data = await this.getPrayerData(locationId, methodId, year);
        if (!data?.payload) return null;
        return data.payload.some(day => day.date === todayString) ? data : null;
    }

    async evictOld(maxAgeDays = 400) {
        try {
            const dir = Gio.File.new_for_path(this._cacheDir);
            const enumerator = await dir.enumerate_children_async(
                'standard::name,time::modified',
                Gio.FileQueryInfoFlags.NONE,
                GLib.PRIORITY_DEFAULT, null
            );
            const cutoff = GLib.DateTime.new_now_utc().to_unix()
                - maxAgeDays * 86400;

            while (true) {
                const batch = await enumerator.next_files_async(
                    32, GLib.PRIORITY_DEFAULT, null
                );
                if (!batch || batch.length === 0) break;
                for (const info of batch) {
                    const modified = info.get_modification_date_time();
                    if (modified && modified.to_unix() < cutoff) {
                        const child = dir.get_child(info.get_name());
                        try {
                            await child.delete_async(GLib.PRIORITY_DEFAULT, null);
                        } catch (e) {
                            logError(e, `Bayan: cache evict failed for ${info.get_name()}`);
                        }
                    }
                }
            }
            enumerator.close(null);
        } catch (e) {
            logError(e, 'Bayan: cache eviction failed');
        }
    }

    destroy() {
        // nothing to clean up
    }
}
