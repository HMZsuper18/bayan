import GLib from 'gi://GLib';

const HIJRI_MONTHS = {
    en: [
        'Muharram', 'Safar', "Rabi' al-awwal", "Rabi' al-thani",
        'Jumada al-ula', 'Jumada al-akhirah', 'Rajab', "Sha'ban",
        'Ramadan', 'Shawwal', "Thul-qi'dah", 'Thul-hijjah',
    ],
    ar: [
        'محرّم', 'صفر', 'ربيع الأول', 'ربيع الثاني',
        'جمادى الأولى', 'جمادى الآخرة', 'رجب', 'شعبان',
        'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة',
    ],
    ru: [
        'Мухаррам', 'Сафар', "Раби'уль-авваль", "Раби'ус-cани",
        'Джумада аль-уля', 'Джумада аль-ахира', 'Раджаб', "Ша'бан",
        'Рамадан', 'Шавваль', "Зуль-ка'да", 'Зуль-хиджа',
    ],
    kk: [
        'Мухаррам', 'Сафар', "Раби' әл-әууәл", "Раби' әс-сәни",
        'Жумәдә әл-улә', 'Жумәдә әл-ахира', 'Ражәб', 'Шағбан',
        'Рамазан', 'Шәууәл', 'Зул-қағда', 'Зул-хижжа',
    ],
};

function getSystemLang() {
    const raw = GLib.getenv('LANG') || '';
    const match = raw.match(/^([a-zA-Z]{2,3})/);
    return match ? match[1] : 'en';
}

export class HijriDate {
    constructor(api, cache) {
        this._api = api;
        this._cache = cache;
        this._current = null;
    }

    get current() { return this._current; }

    async load(countryCode, dateString) {
        const cached = await this._cache.getHijriDate(dateString);
        if (cached) {
            this._current = cached;
            return cached;
        }

        try {
            const data = await this._api.getHijriDate(countryCode, dateString);
            this._current = data;
            await this._cache.setHijriDate(dateString, data);
            return data;
        } catch (error) {
            logError(error, 'Failed to fetch Hijri date');
            this._current = null;
            return null;
        }
    }

    format() {
        if (!this._current) return null;
        const { day, month, year } = this._current;
        const lang = getSystemLang();
        const months = HIJRI_MONTHS[lang] || HIJRI_MONTHS.en;
        const monthName = months[(month || 1) - 1] || this._current.month_name;
        return `${day} ${monthName} ${year}`;
    }

    destroy() {
        this._current = null;
    }
}
