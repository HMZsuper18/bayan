export class PrayerEngine {
    constructor(api, cache) {
        this._api = api;
        this._cache = cache;
        this._todayTimes = null;
        this._tomorrowFajr = null;
        this._locationInfo = null;
        this._fullPayload = null;
        this._lastLoadedDate = null;
    }

    get todayTimes() { return this._todayTimes; }
    get tomorrowFajr() { return this._tomorrowFajr; }
    get locationInfo() { return this._locationInfo; }

    async loadForLocation(location, force = false) {
        const { id, lat, lng, methodId } = location;
        const now = new Date();
        const year = now.getFullYear();
        const todayString = this._formatDate(now);

        if (!force) {
            const fresh = await this._cache.getFreshData(id, methodId, year, todayString);
            if (fresh) {
                this._setFromPayload(fresh, todayString);
                this._locationInfo = await this._cache.getLocationMeta(id) || location;
                return true;
            }
        }

        const locationData = await this._api.getClosestLocation(lat, lng);
        this._locationInfo = locationData;
        await this._cache.setLocationMeta(id, locationData);

        const calcResult = await this._api.getCalcTimesWithRetry(
            year, methodId, id
        );

        const cachedEtag = await this._cache.getEtag(id, methodId, year);
        const downloadResult = await this._api.downloadPrayerData(
            calcResult.url, cachedEtag
        );

        if (downloadResult === null) {
            const cached = await this._cache.getPrayerData(id, methodId, year);
            if (cached) {
                this._setFromPayload(cached, todayString);
                return true;
            }
            return false;
        }

        await this._cache.setPrayerData(id, methodId, year, downloadResult.data);
        if (downloadResult.etag) {
            await this._cache.setEtag(id, methodId, year, downloadResult.etag);
        }

        this._setFromPayload(downloadResult.data, todayString);
        return true;
    }

    checkDateRollover() {
        const todayString = this._formatDate(new Date());
        if (todayString === this._lastLoadedDate) {
            return { changed: false };
        }

        if (this._fullPayload) {
            const todayEntry = this._fullPayload.payload.find(
                day => day.date === todayString
            );
            if (todayEntry) {
                this._todayTimes = todayEntry;
                this._lastLoadedDate = todayString;
                this._updateTomorrowFajr(todayString);
                return { changed: true };
            }
        }

        return { changed: true, needsFetch: true };
    }

    getNextPrayer(asrField = 'asr', hour12 = false) {
        if (!this._todayTimes || !this._locationInfo) {
            return null;
        }

        const now = new Date();
        const timezone = this._locationInfo.timezone || 'UTC';
        const prayerOrder = ['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha'];

        for (const prayer of prayerOrder) {
            const field = prayer === 'asr' ? asrField : prayer;
            const timeStr = this._todayTimes[field];
            if (!timeStr) continue;

            const prayerTime = new Date(timeStr);
            if (isNaN(prayerTime.getTime())) continue;
            if (prayerTime > now) {
                return {
                    name: prayer,
                    time: prayerTime,
                    timeFormatted: this._formatTime(prayerTime, timezone, hour12),
                    countdown: this._formatCountdown(prayerTime, now),
                };
            }
        }

        if (this._tomorrowFajr) {
            const fajrTime = new Date(this._tomorrowFajr);
            if (isNaN(fajrTime.getTime())) return null;
            return {
                name: 'fajr',
                time: fajrTime,
                timeFormatted: this._formatTime(fajrTime, timezone, hour12),
                countdown: this._formatCountdown(fajrTime, now),
                isTomorrow: true,
            };
        }

        return null;
    }

    getAllTimes(asrField = 'asr', hour12 = false) {
        if (!this._todayTimes || !this._locationInfo) return null;

        const timezone = this._locationInfo.timezone || 'UTC';
        const prayers = ['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha'];
        const result = {};

        for (const prayer of prayers) {
            const field = prayer === 'asr' ? asrField : prayer;
            const timeStr = this._todayTimes[field];
            if (timeStr) {
                const dt = new Date(timeStr);
                if (isNaN(dt.getTime())) continue;
                result[prayer] = this._formatTime(dt, timezone, hour12);
            }
        }
        return result;
    }

    _setFromPayload(prayerData, todayString) {
        this._fullPayload = prayerData;
        this._todayTimes = prayerData.payload.find(
            day => day.date === todayString
        );
        this._lastLoadedDate = todayString;
        this._updateTomorrowFajr(todayString);
    }

    _updateTomorrowFajr(todayString) {
        if (!this._fullPayload?.payload) {
            this._tomorrowFajr = null;
            return;
        }
        const tomorrow = new Date(todayString);
        tomorrow.setDate(tomorrow.getDate() + 1);
        const tomorrowStr = this._formatDate(tomorrow);
        const tomorrowEntry = this._fullPayload.payload.find(
            day => day.date === tomorrowStr
        );
        this._tomorrowFajr = tomorrowEntry?.fajr || null;
    }

    _formatDate(date) {
        const y = date.getFullYear();
        const m = String(date.getMonth() + 1).padStart(2, '0');
        const d = String(date.getDate()).padStart(2, '0');
        return `${y}-${m}-${d}`;
    }

    _formatTime(date, timezone, hour12 = false) {
        try {
            return new Intl.DateTimeFormat(hour12 ? 'en-US' : 'en-GB', {
                timeZone: timezone,
                hour: '2-digit',
                minute: '2-digit',
                hour12,
            }).format(date);
        } catch {
            return '--:--';
        }
    }

    _formatCountdown(future, now) {
        const diffMs = future - now;
        const diffMins = Math.floor(diffMs / 60000);
        if (diffMins < 60) {
            return `${diffMins}m`;
        }
        const hours = Math.floor(diffMins / 60);
        const mins = diffMins % 60;
        return `${hours}h ${mins}m`;
    }

    destroy() {
        this._todayTimes = null;
        this._tomorrowFajr = null;
        this._locationInfo = null;
        this._fullPayload = null;
    }
}
