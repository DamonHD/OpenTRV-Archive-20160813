package uk.org.opentrv.ETV.parse;

import java.io.IOException;
import java.io.LineNumberReader;
import java.io.Reader;
import java.util.SortedMap;
import java.util.TimeZone;
import java.util.TreeMap;

import uk.org.opentrv.ETV.ETVPerHouseholdComputation.ETVPerHouseholdComputationInputKWH;

/**Get heating fuel energy consumption (kWh) by whole local days (local midnight-to-midnight) from bulk data.
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
 * <p>
 * No assumption is made about ordering by house_id,
 * but values for a given house ID must be in rising order by device_timestamp.
 */
public class NBulkKWHParseByID implements ETVPerHouseholdComputationInputKWH
    {
    /**Default time zone assumed for this data for UK based homes. */
    public static final TimeZone DEFAULT_NB_TIMEZONE = TimeZone.getTimeZone("Europe/London");

    /**House/meter ID to filter for; +ve. */
    private final int meterID;

    /**Reader for CSV; never null but may be closed. */
    private final Reader r;
    
    /**Time zone of house; never null. */
    private final TimeZone tz;

    /**Create instance with the house/meter ID to filter for and CSV input Reader.
     * Reader will be closed by getKWHByLocalDay()
     * so this is one shot and a new instance of this class
     * is needed if the data is to be read again.
     */
    public NBulkKWHParseByID(final int meterID, final Reader r, final TimeZone tz)
        {
        if(meterID < 0) { throw new IllegalArgumentException(); }
        if(null == r) { throw new IllegalArgumentException(); }
        if(null == tz) { throw new IllegalArgumentException(); }
        this.meterID = meterID;
        this.r = r;
        this.tz = tz;
        }

    /**Create instance with the house/meter ID to filter for and CSV input Reader and default UK timezone.
     * Reader will be closed by getKWHByLocalDay()
     * so this is one shot and a new instance of this class
     * is needed if the data is to be read again.
     */
    public NBulkKWHParseByID(final int meterID, final Reader r)
        { this(meterID, r, DEFAULT_NB_TIMEZONE); }

    /**Cumulative heating fuel consumption (kWh) by whole local days; never null.
     * @return  never null though may be empty
     * @throws IOException  in case of failure, eg parse problems
     */
    @Override public SortedMap<Integer, Float> getKWHByLocalDay() throws IOException
        {
        // Read first line, usually:
        //     house_id,received_timestamp,device_timestamp,energy,temperature
        // Simply check that the header exists, has (at least) 5 fields, and does not start with a digit.
        // An empty file is not acceptable (ie indicates a problem).

        final SortedMap<Integer, Float> result = new TreeMap<>();

        // Wrap with a by-line reader and arrange to close() when done...
        try(final LineNumberReader l = new LineNumberReader(r))
            {
            final String header = l.readLine();
            if(null == header) { throw new IOException("missing header row"); }
            final String hf[] = header.split(",");
            if(hf.length < 5) { throw new IOException("too few fields in header row"); }
            if((hf[0].length() > 0) && (Character.isDigit(hf[0].charAt(0)))) { throw new IOException("leading numeric not text in header row"); }

            // Avoid multiple parses of ID; check with a String comparison.
            final String sID = Integer.toString(meterID);

            // Read data rows...
            // Filter by house ID [0], use device timestamp [2] and energy [3].
            // This will need to accumulate energy for an entire day in the local timezone,
            // taking the last value from the previous day from the last value for the current day,
            // both values needing to be acceptably close to midnight.
            String row;
            while(null != (row = l.readLine()))
                {
                final String rf[] = row.split(",");
                if(rf.length < 4) { throw new IOException("too few fields in row " + l.getLineNumber()); }
                if(!sID.equals(rf[0])) { continue; }

                }
            }

        return(result);
        }

    }
