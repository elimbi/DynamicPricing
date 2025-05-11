import { LightningElement, track } from 'lwc';
import getTop4LowestPricesPerDay from '@salesforce/apex/DayAheadSpotPriceController.getTop4LowestPricesPerDay';
import Gechirrspuler from '@salesforce/resourceUrl/Gechirrspuler';
import Waschmaschine from '@salesforce/resourceUrl/Waschmaschine';
import Trockner from '@salesforce/resourceUrl/Trockner';
import Wallbox from '@salesforce/resourceUrl/Wallbox';

export default class DayAheadPrices extends LightningElement {
    @track records;
    @track error;
    @track fallbackUsed = false;
    @track displayDate; // 👈 Datum, für das Preise angezeigt werden

    connectedCallback() {
        const today = new Date();
        const nextDay = new Date(today);
        nextDay.setDate(today.getDate() + 1); // Morgen

        const formattedNextDay = this.formatDate(nextDay);
        const formattedToday = this.formatDate(today);

        // Erst versuchen, Preise für morgen zu laden
        getTop4LowestPricesPerDay({ forDate: nextDay })
            .then(result => {
                if (!result || result.length === 0) {
                    console.warn('No prices were found for tomorrow. Showing today’s prices instead.');
                    this.fallbackUsed = true;
                    this.displayDate = this.formatDisplayDate(today); // 👈 Anzeigen: heute
                    return getTop4LowestPricesPerDay({ forDate: today });
                }
                this.fallbackUsed = false;
                this.displayDate = this.formatDisplayDate(nextDay); // 👈 Anzeigen: morgen
                return result;
            })
            .then(result => {
                this.records = result.map(record => {
                    const dateObj = new Date(record.startDateTime);
                const time = dateObj.toLocaleTimeString('US', {
                    hour: '2-digit',
                    minute: '2-digit',
                    second: '2-digit',
                    hour24: true
                    });
                    const date = dateObj.toLocaleDateString('US');

                    return {
                        ...record,
                        iconUrl: this.getIconUrl(record.Category),
                        formattedPrice: `${record.customerPrice.toFixed(2)} Cents/kWh`,
                        formattedTime: time,
                        formattedDate: date,
                        style: `width: ${this.iconSize}; height: ${this.iconSize};`
                    };
                });
                this.error = undefined;
            })
            .catch(error => {
                console.error('⚠️ Error loading prices', error);
                this.error = error.body?.message || error.message;
                this.records = undefined;
            });
    }

    formatDate(dateObj) {
        const yyyy = dateObj.getFullYear();
        const mm = String(dateObj.getMonth() + 1).padStart(2, '0');
        const dd = String(dateObj.getDate()).padStart(2, '0');
        return `${yyyy}-${mm}-${dd}`;
    }

    formatDisplayDate(dateObj) {
        return dateObj.toLocaleDateString('US', {
            weekday: 'long',
            year: 'numeric',
            month: 'long',
            day: 'numeric'
        });
    }

    getIconUrl(Category) {
        switch (Category) {
            case '1st': return Wallbox;
            case '2nd': return Trockner;
            case '3rd': return Gechirrspuler;
            case '4th': return Waschmaschine;
            default: return '';
        }
    }

    fetchPrices() {
        getTop4LowestPricesPerDay({ forDate: this.selectedDate })
            .then(result => {
                this.records = result.map(record => ({
                    ...record,
                    iconUrl: this.getIconUrl(record.Category)
                }));
                this.error = undefined;
            })
            .catch(error => {
                console.error('⚠️ Error loading prices', error);
                this.error = error.body?.message || error.message;
                this.records = undefined;
            });
    }
}
