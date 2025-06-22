public class DayAheadSpotPriceWrapper {
    @AuraEnabled public Id recordId;
    @AuraEnabled public Decimal customerPrice;
    @AuraEnabled public Datetime startDateTime;
    @AuraEnabled public String Category;
}