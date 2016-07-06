package uk.org.opentrv.ETV.parse;

import java.io.IOException;
import java.util.SortedMap;

import uk.org.opentrv.ETV.ETVPerHouseholdComputation.ETVPerHouseholdComputationInputKWH;

/**Get heating fuel energy consumption by whole local days (local midnight-to-midnight) from bulk data.
 * Days may not be contiguous.
 * <p>
 * Extracts from bulk data from the secondary meter provider.
 * <p>
 * The ID to extract data for has to be supplied to the constructor.
 */
public class NBulkKWHParseByID implements ETVPerHouseholdComputationInputKWH
    {
    /**House/meter ID to filter for. */
    private final int meterID;

    /**Create instance with the house/meter ID to filter for. */
    public NBulkKWHParseByID(final int meterID) { this.meterID = meterID; }

    /**Heating fuel consumption by whole local days; never null.
     * @return  never null though may be empty
     * @throws IOException  in case of failure, eg parse problems
     */
    @Override  public SortedMap<Integer, Float> getKWHByLocalDay() throws IOException
        {
        throw new IOException("NOT IMPLEMENTED");
        }

    }
