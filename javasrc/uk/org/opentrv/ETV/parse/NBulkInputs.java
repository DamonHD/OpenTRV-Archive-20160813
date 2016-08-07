package uk.org.opentrv.ETV.parse;

import java.io.IOException;
import java.io.Reader;
import java.util.Collections;
import java.util.HashMap;
import java.util.Map;
import java.util.Set;
import java.util.SortedMap;
import java.util.TimeZone;
import java.util.function.Supplier;

import uk.org.opentrv.ETV.ETVPerHouseholdComputation.ETVPerHouseholdComputationInput;
import uk.org.opentrv.ETV.ETVPerHouseholdComputation.SavingEnabledAndDataStatus;
import uk.org.opentrv.hdd.DDNExtractor;

/**Process typical set of bulk data, with HDDs, into input data object(s).
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
    /**Standard HDD base temperature used for this class, Celsius. */
    public static final float STD_BASE_TEMP_C = 15.5f;

    /**For energy (and preparsed HDD) data in the default time zone; no logs, overall kWh/HDD estimates only.
     * The standard/default (UK) time zone for this type of bulk data will be used, in this format:
<pre>
house_id,received_timestamp,device_timestamp,energy,temperature
1002,1456790560,1456790400,306.48,-3
1002,1456791348,1456791300,306.48,-3
1002,1456792442,1456792200,306.48,-3
</pre>
     * The space taken is roughly 1MB/year per household.
     *
     * @param houseID the house to extract data for
     * @param NBulkDataFile  Reader (eg from file) for bulk energy user data,
     *        Reader is closed when done; never null
     * @param HDDDataFile  Reader (eg from file) for simple HDD data with standard/default baseline,
     *        Reader is closed when done; never null
     * @return  collection of all data to process to compute
     *     overall kWh/HDD per household, no efficacy computation;
     *     never null
     * @throws IOException  in case of input data problems
     */
    public static ETVPerHouseholdComputationInput gatherData(
            final int houseID,
            final Reader NBulkData,
            final SortedMap<Integer, Float> hdd)
        throws IOException
        {
        if(null == NBulkData) { throw new IllegalArgumentException(); }
        if(null == hdd) { throw new IllegalArgumentException(); }
        final SortedMap<Integer, Float> kwhByLocalDay;
        try(final Reader r = NBulkData) // Ensure NBulkData Reader closed when done, probably redundantly.
            { kwhByLocalDay = (new NBulkKWHParseByID(houseID, r, NBulkKWHParseByID.DEFAULT_NB_TIMEZONE)).getKWhByLocalDay(); }
        return(new ETVPerHouseholdComputationInput(){
            @Override public String getHouseID() { return(String.valueOf(houseID)); }
            @Override public SortedMap<Integer, Float> getKWhByLocalDay() throws IOException { return(kwhByLocalDay); }
            @Override public SortedMap<Integer, Float> getHDDByLocalDay() throws IOException { return(hdd); }
            @Override public TimeZone getLocalTimeZoneForKWhAndHDD() { return(NBulkKWHParseByID.DEFAULT_NB_TIMEZONE); }
            @Override public float getBaseTemperatureAsFloat() { return(STD_BASE_TEMP_C); }
            // Not implemented (null return values).
            @Override public SortedMap<Integer, SavingEnabledAndDataStatus> getOptionalEnabledAndUsableFlagsByLocalDay() { return(null); }
            @Override public SortedMap<Long, String> getOptionalJSONStatsByUTCTimestamp() { return(null); }
            @Override public SortedMap<String, Boolean> getJSONStatusValveElseBoilerControlByID() { return(null); }
            });
        }

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
     * The space taken is roughly 1MB/year per household.
     *
     * @param houseID the house to extract data for
     * @param NBulkDataFile  Reader (eg from file) for bulk energy user data,
     *        Reader is closed when done; never null
     * @param HDDDataFile  Reader (eg from file) for simple HDD data with standard/default baseline,
     *        Reader is closed when done; never null
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
        if(null == simpleHDDData) { throw new IllegalArgumentException(); }
        final SortedMap<Integer, Float> hdd = DDNExtractor.extractSimpleHDD(simpleHDDData, STD_BASE_TEMP_C).getMap();
        simpleHDDData.close(); // Close HDD reader when done.
        return(gatherData(houseID, NBulkData, hdd));
        }

    /**Extract data for all the households in the bulk data file.
     * Note that this may repeatedly scan the input data,
     * and will call the supplier each time to get a new Reader to do so;
     * the Reader will be closed each time.
     * <p>
     * The common HDD data should only need to be read once.
     *
     * @param NBulkDataFileSupplier  created a Reader (eg from file) for bulk energy user data,
     *        each Reader is closed when done; never null
     * @param HDDDataFile  Reader (eg from file) for simple HDD data with standard/default baseline,
     *        Reader is closed when done; never null
     * @return  immutable map from (String) household ID to data to process to compute
     *     overall kWh/HDD per household, no efficacy computation;
     *     never null
     * @throws IOException  in case of input data problems
     */
    public static Map<String, ETVPerHouseholdComputationInput> gatherDataForAllHouseholds(
            final Supplier<Reader> NBulkDataSupplier,
            final Reader simpleHDDData)
        throws IOException
        {
        if(null == NBulkDataSupplier) { throw new IllegalArgumentException(); }
        if(null == simpleHDDData) { throw new IllegalArgumentException(); }
        final SortedMap<Integer, Float> hdd = DDNExtractor.extractSimpleHDD(simpleHDDData, STD_BASE_TEMP_C).getMap();
        simpleHDDData.close();

        // Get the set of household IDs present.
        final Set<Integer> IDs;
        try(final Reader rID = NBulkDataSupplier.get())
            { IDs = NBulkKWHParseByID.extractIDs(rID); }

        // Load the data for each household.
        final Map<String, ETVPerHouseholdComputationInput> result = new HashMap<>(2*IDs.size());
        for(final Integer id : IDs)
            {
            final ETVPerHouseholdComputationInput oneHousehold = gatherData(id, NBulkDataSupplier.get(), hdd);
            result.put(id.toString(), oneHousehold);
            }

        return(Collections.unmodifiableMap(result));
        }
    }
