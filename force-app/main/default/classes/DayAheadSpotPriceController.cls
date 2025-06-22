public with sharing class DayAheadSpotPriceController {

    @AuraEnabled(cacheable=true)
    public static List<DayAheadSpotPriceWrapper> getTop4LowestPricesPerDay(Date forDate) {
        DateTime startOfDay = DateTime.newInstance(forDate, Time.newInstance(0, 0, 0, 0));
        DateTime endOfDay = startOfDay.addDays(1);

        List<DayAheadSpotPrice__c> allPrices = [
            SELECT Id, CustomerPrice__c, StartDateTime__c
            FROM DayAheadSpotPrice__c
            WHERE StartDateTime__c >= :startOfDay AND StartDateTime__c < :endOfDay
            ORDER BY CustomerPrice__c ASC, StartDateTime__c ASC
        ];

        Set<Decimal> uniquePrices = new Set<Decimal>();
        List<DayAheadSpotPriceWrapper> results = new List<DayAheadSpotPriceWrapper>();
        Integer ordinalRank = 1;

        for (DayAheadSpotPrice__c record : allPrices) {
            if (!uniquePrices.contains(record.CustomerPrice__c)) {
                uniquePrices.add(record.CustomerPrice__c);

                DayAheadSpotPriceWrapper wrap = new DayAheadSpotPriceWrapper();
                wrap.recordId = record.Id;
                wrap.customerPrice = record.CustomerPrice__c;
                wrap.startDateTime = record.StartDateTime__c;
                wrap.Category = getOrdinal(ordinalRank);
                results.add(wrap);

                ordinalRank++;

                if (results.size() == 4) {
                    break;
                }
            }
        }

        return results;
    }

    private static String getOrdinal(Integer rank) {
        if (rank >= 11 && rank <= 13) return rank + 'th';
        Integer mod = Math.mod(rank, 10);
        if (mod == 1) return rank + 'st';
        if (mod == 2) return rank + 'nd';
        if (mod == 3) return rank + 'rd';
        return rank + 'th';
    }
}