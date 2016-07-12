package uk.org.opentrv.ETV.parse;

import java.io.IOException;
import java.io.Reader;
import java.util.SortedMap;

import uk.org.opentrv.ETV.ETVPerHouseholdComputation.ETVPerHouseholdComputationInput;

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
     * The standard HDD baseline temperature will be used.
     * <p>
     * The standard (UK) time zone will be used.
     *
     * @param houseID the house to extract data for
     * @param NBulkDataFile  Reader (eg from file) for bulk energy user data; never null
     * @param HDDDataFile  Reader (eg from file) for HDD data
     * @return  collection of all data to process to compute
     *     overall kWh/HDD per household, no efficacy computation;
     *     never null
     * @throws IOException  in case of input data problems
     */
    public static ETVPerHouseholdComputationInput gatherData(
            final int houseID,
            final Reader NBulkData,
            final Reader HDDData)
        throws IOException
        {
        final SortedMap<Integer, Float> kwhByLocalDay = (new NBulkKWHParseByID(houseID, NBulkData)).getKWHByLocalDay();


        throw new RuntimeException("NOT IMPLEMENTED");
        }
    }
