package uk.org.opentrv.ETV.parse;

import java.io.IOException;
import java.io.Reader;
import java.util.SortedMap;

import uk.org.opentrv.ETV.ETVPerHouseholdComputation.ETVPerHouseholdComputationInputKWH;

/**Get heating fuel energy consumption by whole local days (local midnight-to-midnight) from bulk data.
 * Days may not be contiguous.
 * <p>
 * Extracts from bulk data from the secondary meter provider.
 * <p>
 * The ID to extract data for has to be supplied to the constructor.
 * <p>
 * Format sample, initial few lines:
<pre>
house_id,received_timestamp,device_timestamp,energy,temperature
1002,1456790560,1456790400,306.48,-3
1002,1456791348,1456791300,306.48,-3
1002,1456792442,1456792200,306.48,-3
</pre>
 */
public class NBulkKWHParseByID implements ETVPerHouseholdComputationInputKWH
    {
    /**House/meter ID to filter for; usually +ve. */
    private final int meterID;
    
    /**Reader for CSV; never null but may be closed. */
    private final Reader r;

    /**Create instance with the house/meter ID to filter for and CSV input Reader.
     * Reader will be closed by getKWHByLocalDay()
     * so this is one shot and a new instance of this class
     * is needed if the data is to be read again.
     */
    public NBulkKWHParseByID(final int meterID, final Reader r)
        {
        if(meterID < 0) { throw new IllegalArgumentException(); }
        if(null == r) { throw new IllegalArgumentException(); }
        this.meterID = meterID;
        this.r = r;
        }

    /**Heating fuel consumption by whole local days; never null.
     * @return  never null though may be empty
     * @throws IOException  in case of failure, eg parse problems
     */
    @Override  public SortedMap<Integer, Float> getKWHByLocalDay() throws IOException
        {
        throw new IOException("NOT IMPLEMENTED");
        }

    }
