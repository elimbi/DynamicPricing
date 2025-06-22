public class ParseSoptimSpotPriceJSON {

    public class InputWrapper {
        @InvocableVariable(required=true)
        public String jsonResponse;
    }

    public class OutputWrapper {
        @InvocableVariable
        public Integer recordsInserted;

        @InvocableVariable
        public String message;
    }

    @InvocableMethod(label='Parse and Save SpotPrice JSON (Anti-Duplikat)' description='Parses Soptim JSON and saves new DayAheadSpotPrice__c records without duplicates.')
    public static List<OutputWrapper> savePrices(List<InputWrapper> inputList) {
        List<OutputWrapper> outputList = new List<OutputWrapper>();

        // 🔸 Feste Zuschläge für Netzentgelt, Steuern und Marge
        Decimal netzentgelt = 7.00;
        Decimal steuern = 3.00;
        Decimal vertriebMarge = 1.50;

        for (InputWrapper input : inputList) {
            OutputWrapper result = new OutputWrapper();
            List<DayAheadSpotPrice__c> recordsToInsert = new List<DayAheadSpotPrice__c>();

            try {
                if (String.isBlank(input.jsonResponse)) {
                    result.message = 'Empty JSON response.';
                    outputList.add(result);
                    continue;
                }

                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(input.jsonResponse);
                String start = (String) responseMap.get('start');
                String raster = (String) responseMap.get('raster');
                String einheit = (String) responseMap.get('einheit');
                List<Object> werte = (List<Object>) responseMap.get('werte');

                String cleanDate = start.replace('T', ' ').replace('.000Z', '');
                DateTime baseTime = DateTime.valueOfGmt(cleanDate);
                Integer intervalMinutes = getIntervalMinutes(raster);

                // 🔎 Alle existierenden Startzeiten abrufen
                Set<DateTime> startTimesToCheck = new Set<DateTime>();
                for (Integer i = 0; i < werte.size(); i++) {
                    startTimesToCheck.add(baseTime.addMinutes(i * intervalMinutes));
                }

                Set<DateTime> existingStartTimes = new Set<DateTime>();
                if (!startTimesToCheck.isEmpty()) {
                    for (DayAheadSpotPrice__c spot : [
    SELECT StartDateTime__c FROM DayAheadSpotPrice__c
    WHERE StartDateTime__c IN :startTimesToCheck
]) {
    existingStartTimes.add(spot.StartDateTime__c);
}
                }

                // 🔨 Nur neue Datensätze bauen (keine Duplikate)
                for (Integer i = 0; i < werte.size(); i++) {
                    DateTime recordTime = baseTime.addMinutes(i * intervalMinutes);
                    if (existingStartTimes.contains(recordTime)) {
                        continue; // Bereits vorhanden ➔ überspringen
                    }

                    Object valueObj = werte[i];
                    if (valueObj == null) continue;

                    Map<String, Object> entry = (Map<String, Object>) valueObj;

                    if (entry.containsKey('wert') && entry.get('wert') != null) {
                        Decimal price = Decimal.valueOf(entry.get('wert').toString());

                        Decimal customerPrice;
                        if (einheit == 'ct/kWh') {
                            customerPrice = price + netzentgelt + steuern + vertriebMarge;
                        } else {
                            customerPrice = price + netzentgelt + steuern + vertriebMarge;
                        }

                        DayAheadSpotPrice__c record = new DayAheadSpotPrice__c();
                        record.StartDateTime__c = recordTime;
                        record.Raster__c = raster;
                        record.Unit__c = 'ct/kWh';
                        record.Value__c = price;
                        record.CustomerPrice__c = customerPrice;

                        recordsToInsert.add(record);
                    }
                }

                // 🔥 INSERT in 5.000er Batches
                if (!recordsToInsert.isEmpty()) {
                    Integer batchSize = 5000;
                    for (Integer i = 0; i < recordsToInsert.size(); i += batchSize) {
                        Integer endIdx = Math.min(i + batchSize, recordsToInsert.size());
                        List<DayAheadSpotPrice__c> batch = new List<DayAheadSpotPrice__c>();
                        for (Integer j = i; j < endIdx; j++) {
                            batch.add(recordsToInsert[j]);
                        }
                        insert batch;
                    }
                }

                result.recordsInserted = recordsToInsert.size();
                result.message = 'Success';

            } catch (Exception e) {
                result.recordsInserted = 0;
                result.message = 'Error: ' + e.getMessage();
                System.debug('❌ Fehler beim Speichern: ' + e.getMessage());
            }

            outputList.add(result);
        }

        return outputList;
    }

    private static Integer getIntervalMinutes(String raster) {
        if (raster == 'PT15M') return 15;
        if (raster == 'PT1H') return 60;
        if (raster == 'P1D') return 1440;
        if (raster == 'P1M') return 43200;
        return 15; // fallback
    }
}