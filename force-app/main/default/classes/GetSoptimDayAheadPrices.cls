public class GetSoptimDayAheadPrices {

    public class Input {
        @InvocableVariable(required=true)
        public String tenantId;

        @InvocableVariable(required=true)
        public String startDateTime; // ISO8601 format e.g. "2024-04-14T00:00:00Z"

        @InvocableVariable(required=true)
        public String endDateTime;
    }

    public class Output {
        @InvocableVariable
        public String jsonResponse;
    }

    @InvocableMethod(label='Get Day-Ahead Spot Prices' description='Calls SOPTIM API to get day-ahead electricity prices and stores them as records')
    public static List<Output> getPrices(List<Input> inputs) {
        List<Output> results = new List<Output>();

        for (Input input : inputs) {
            Http http = new Http();
            HttpRequest req = new HttpRequest();

            String endpoint = 'callout:SOPTIM_API/day-ahead-spotpreise' +
                '?start=' + EncodingUtil.urlEncode(input.startDateTime, 'UTF-8') +
                '&ende=' + EncodingUtil.urlEncode(input.endDateTime, 'UTF-8');

            req.setEndpoint(endpoint);
            req.setMethod('GET');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('x-soptim-tenant-id', input.tenantId);

            HttpResponse res;
            Output out = new Output();

            try {
                res = http.send(req);

                if (res.getStatusCode() == 200) {
                    out.jsonResponse = res.getBody();

                    // Parse response body
                    Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                    String start = (String) responseMap.get('start');
                    String raster = (String) responseMap.get('raster');
                    String einheit = (String) responseMap.get('einheit');
                    List<Object> werte = (List<Object>) responseMap.get('werte');

                    List<DayAheadSpotPrice__c> recordsToInsert = new List<DayAheadSpotPrice__c>();

                    for (Integer i = 0; i < werte.size(); i++) {
                        Object value = werte[i];
                        if (value != null && value instanceof Decimal) {
                            DateTime baseTime = DateTime.valueOfGmt(start);
                            Integer intervalMinutes = getIntervalMinutes(raster);
                            DateTime recordTime = baseTime.addMinutes(i * intervalMinutes);

                            DayAheadSpotPrice__c priceRecord = new DayAheadSpotPrice__c();
                            priceRecord.StartDateTime__c = recordTime;
                            priceRecord.Raster__c = raster;
                            priceRecord.Unit__c = einheit;
                            priceRecord.Value__c = (Decimal) value;

                            recordsToInsert.add(priceRecord);
                        }
                    }

                    if (!recordsToInsert.isEmpty()) {
                        insert recordsToInsert;
                    }

                } else {
                    out.jsonResponse = 'Error: ' + res.getStatusCode() + ' - ' + res.getBody();
                }
            } catch (Exception e) {
                out.jsonResponse = 'Exception: ' + e.getMessage();
            }

            results.add(out);
        }

        return results;
    }

    // Helper method to determine minutes per raster unit
    private static Integer getIntervalMinutes(String raster) {
        if (raster == 'PT15M') return 15;
        if (raster == 'PT1H') return 60;
        if (raster == 'P1D') return 1440;
        if (raster == 'P1M') return 43200; // Approximate monthly value
        return 15; // Default fallback
    }
}