import Soup from 'gi://Soup?version=3.0';
import GLib from 'gi://GLib';
import Gio from 'gi://Gio';

const API_BASE_URL = 'https://api.sajda.mobi/api/';
const API_CLIENT = 'af6f5310a7afd672486fea39bf961ad64cfdfd21';
const USER_AGENT = 'Bayan-GNOME/1.0';

export class BayanApi {
    constructor() {
        this._session = new Soup.Session();
        this._cancellable = new Gio.Cancellable();
        this._retryTimers = [];
    }

    _createMessage(method, url) {
        const message = Soup.Message.new(method, url);
        message.request_headers.append('Api-Client', API_CLIENT);
        message.request_headers.append('User-Agent', USER_AGENT);
        const rawLang = GLib.getenv('LANG') || '';
        const langMatch = rawLang.match(/^([a-zA-Z]{2,3})(?:_([a-zA-Z]{2}))?/);
        const acceptLang = langMatch
            ? (langMatch[2] ? `${langMatch[1]}-${langMatch[2]}` : langMatch[1])
            : 'en';
        message.request_headers.append('Accept-Language', acceptLang);
        return message;
    }

    _sendRequest(message) {
        return new Promise((resolve, reject) => {
            this._session.send_and_read_async(
                message, GLib.PRIORITY_DEFAULT, this._cancellable,
                (session, result) => {
                    try {
                        const bytes = session.send_and_read_finish(result);
                        resolve({ bytes, message });
                    } catch (e) {
                        reject(e);
                    }
                }
            );
        });
    }

    async _fetchJson(url) {
        const message = this._createMessage('GET', url);
        const { bytes } = await this._sendRequest(message);
        const data = bytes.get_data();
        if (data.length > 15 * 1024 * 1024) {
            throw new Error('API response exceeds 15 MB size limit');
        }
        const text = new TextDecoder('utf-8').decode(data);
        return JSON.parse(text);
    }

    async getClosestLocation(lat, lng) {
        const url = `${API_BASE_URL}v3/geoapi/closest/?point=${encodeURIComponent(lat)},${encodeURIComponent(lng)}`;
        const response = await this._fetchJson(url);
        const loc = response?.data?.[0];
        if (!loc) {
            throw new Error('No location found');
        }
        if (!loc.id || typeof loc.latitude !== 'number' || typeof loc.longitude !== 'number'
            || !loc.timezone) {
            throw new Error('Invalid location data from API');
        }
        return loc;
    }

    async getCalcTimes(year, methodId, geonameId) {
        const url = `${API_BASE_URL}v2/calctimes/${encodeURIComponent(year)}/${encodeURIComponent(methodId)}/${encodeURIComponent(geonameId)}.json`;
        const response = await this._fetchJson(url);
        if (!response?.data) {
            throw new Error('Invalid calctimes response');
        }
        return response.data;
    }

    async getCalcTimesWithRetry(year, methodId, geonameId, maxRetries = 6) {
        for (let attempt = 1; attempt <= maxRetries; attempt++) {
            const result = await this.getCalcTimes(year, methodId, geonameId);

            if (result.status === 'READY') {
                return result;
            }
            if (result.status === 'NOT_EXIST') {
                throw new Error(`Prayer data not available for method ${methodId}, location ${geonameId}`);
            }
            if (attempt < maxRetries) {
                await new Promise(resolve => {
                    const tid = GLib.timeout_add(GLib.PRIORITY_DEFAULT, attempt * 1000, () => {
                        const idx = this._retryTimers.indexOf(tid);
                        if (idx !== -1) this._retryTimers.splice(idx, 1);
                        resolve();
                        return GLib.SOURCE_REMOVE;
                    });
                    this._retryTimers.push(tid);
                });
            }
        }
        throw new Error('Prayer time calculation timed out after max retries');
    }

    async downloadPrayerData(url, cachedEtag = null) {
        try {
            const parsed = GLib.Uri.parse(url, GLib.UriFlags.NONE);
            const host = parsed.get_host();
            if (host !== 'sajda.mobi' && !host.endsWith('.sajda.mobi')) {
                throw new Error(`Untrusted download URL host: ${host}`);
            }
        } catch (e) {
            if (e.message?.includes('Untrusted')) throw e;
            throw new Error(`Invalid download URL: ${url}`);
        }

        const message = Soup.Message.new('GET', url);
        if (cachedEtag) {
            message.request_headers.append('If-None-Match', cachedEtag);
        }

        const result = await this._sendRequest(message);

        if (message.get_status() === Soup.Status.NOT_MODIFIED) {
            return null;
        }

        const converter = new Gio.ZlibDecompressor({
            format: Gio.ZlibCompressorFormat.GZIP,
        });
        const inputStream = Gio.MemoryInputStream.new_from_bytes(result.bytes);
        const converterStream = Gio.ConverterInputStream.new(inputStream, converter);

        const chunks = [];
        const CHUNK_SIZE = 65536;
        const MAX_DECOMPRESSED = 5 * 1024 * 1024;
        let totalSize = 0;
        try {
            while (true) {
                const chunk = converterStream.read_bytes(CHUNK_SIZE, null);
                if (chunk.get_size() === 0) break;
                totalSize += chunk.get_size();
                if (totalSize > MAX_DECOMPRESSED) {
                    throw new Error('Decompressed response exceeds 5 MB size limit');
                }
                chunks.push(chunk);
            }
        } finally {
            converterStream.close(null);
        }

        const buffer = new Uint8Array(totalSize);
        let offset = 0;
        for (const chunk of chunks) {
            const data = chunk.get_data();
            buffer.set(data, offset);
            offset += data.length;
        }

        const text = new TextDecoder('utf-8').decode(buffer);
        const etag = message.response_headers.get_one('ETag');

        const parsed = JSON.parse(text);
        if (!parsed || !Array.isArray(parsed.payload) || parsed.payload.length === 0) {
            throw new Error('Prayer data missing required payload array');
        }
        return { data: parsed, etag };
    }

    async searchCities(query) {
        const url = `${API_BASE_URL}v3/geoapi/?q=${encodeURIComponent(query)}`;
        const response = await this._fetchJson(url);
        return response?.data || [];
    }

    async getCalcMethods(geonameId) {
        const url = `${API_BASE_URL}v3/calcmethods/?geoname_id=${encodeURIComponent(geonameId)}`;
        const response = await this._fetchJson(url);
        const data = response?.data;
        if (!Array.isArray(data)) return [];
        return data.filter(m => m && m.id != null);
    }

    async getHijriDate(countryCode, dateString) {
        const url = `${API_BASE_URL}v1/hijridate/?country=${encodeURIComponent(countryCode)}&date=${encodeURIComponent(dateString)}`;
        const response = await this._fetchJson(url);
        const d = response?.data;
        if (!d || typeof d !== 'object'
            || typeof d.day !== 'number' || typeof d.month !== 'number'
            || typeof d.year !== 'number') {
            throw new Error('Invalid hijri date response');
        }
        return d;
    }

    destroy() {
        this._cancellable.cancel();
        for (const id of this._retryTimers) GLib.source_remove(id);
        this._retryTimers = [];
        this._session = null;
    }
}
