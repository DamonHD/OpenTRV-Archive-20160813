package uk.org.opentrv.ETV.parse;

import java.io.IOException;
import java.io.Reader;
import java.util.SortedMap;
import java.util.TimeZone;

import uk.org.opentrv.ETV.ETVPerHouseholdComputation.ETVPerHouseholdComputationInput;
import uk.org.opentrv.ETV.ETVPerHouseholdComputation.SavingEnabledAndDataStatus;
import uk.org.opentrv.hdd.DDNExtractor;

/**Process typical set of bulk data, with HDDs, into input data object.
 * This allows bulk processing in one hit,
 * with single bulk files (or possibly directories) for each of:
 * <ul>
 * <li>household space-heat energy consumption</li>
 * <li>HDD</li>
 * <li>OpenTRV log data</li>
 * <li>associations between the various IDs</li>
 * </ul>
 * All households must be in the same time zone
 * and have the same local HDD source.
 * <p>
 * Note: the API and implementation of this will evolve to add functionality.
 */
public final class NBulkInputs
    {
    /**For energy (and HDD) data in the default time zone; no logs, overall kWh/HDD estimates only.
     * The uniform/default HDD baseline temperature will be used, in this format:
<pre>
Date,HDD,% Estimated
2016-03-01,6.6,0
2016-03-02,10.1,0
2016-03-03,9.2,0
</pre>
     * <p>
     * The standard/default (UK) time zone for this type of bulk data will be used, in this format:
<pre>
house_id,received_timestamp,device_timestamp,energy,temperature
1002,1456790560,1456790400,306.48,-3
1002,1456791348,1456791300,306.48,-3
1002,1456792442,1456792200,306.48,-3
</pre>
     *
     * @param houseID the house to extract data for
     * @param NBulkDataFile  Reader (eg from file) for bulk energy user data; never null
     * @param HDDDataFile  Reader (eg from file) for simple HDD data with standard/default baseline
     * @return  collection of all data to process to compute
     *     overall kWh/HDD per household, no efficacy computation;
     *     never null
     * @throws IOException  in case of input data problems
     */
    public static ETVPerHouseholdComputationInput gatherData(
            final int houseID,
            final Reader NBulkData,
            final Reader simpleHDDData)
        throws IOException
        {
        final SortedMap<Integer, Float> kwhByLocalDay = (new NBulkKWHParseByID(houseID, NBulkData, NBulkKWHParseByID.DEFAULT_NB_TIMEZONE)).getKWhByLocalDay();
        final float baseTemp = 15.5f;
        final SortedMap<Integer, Float> hdd = DDNExtractor.extractSimpleHDD(simpleHDDData, baseTemp).getMap();

        return(new ETVPerHouseholdComputationInput(){
            @Override public String getHouseID() { return(String.valueOf(houseID)); }
            @Override public SortedMap<Integer, Float> getKWhByLocalDay() throws IOException { return(kwhByLocalDay); }
            @Override public SortedMap<Integer, Float> getHDDByLocalDay() throws IOException { return(hdd); }
            @Override public TimeZone getLocalTimeZoneForKWhAndHDD() { return(NBulkKWHParseByID.DEFAULT_NB_TIMEZONE); }
            @Override public float getBaseTemperatureAsFloat() { return(baseTemp); }
            // Not implemented (null return values).
            @Override public SortedMap<Integer, SavingEnabledAndDataStatus> getOptionalEnabledAndUsableFlagsByLocalDay() { return(null); }
            @Override public SortedMap<Long, String> getOptionalJSONStatsByUTCTimestamp() { return(null); }
            @Override public SortedMap<String, Boolean> getJSONStatusValveElseBoilerControlByID() { return(null); }
            });
        }
    }
