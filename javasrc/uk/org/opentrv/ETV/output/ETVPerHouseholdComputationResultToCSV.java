package uk.org.opentrv.ETV.output;

import java.util.function.Function;

import uk.org.opentrv.ETV.ETVPerHouseholdComputation.ETVPerHouseholdComputationResult;
import uk.org.opentrv.hdd.Util.HDDMetrics;

/**Generate machine-readable (partial-CVS-line) form for a single result.
 * Stateless.
 */
public final class ETVPerHouseholdComputationResultToCSV
        implements Function<ETVPerHouseholdComputationResult,String>
    {
    /**Produce simple CVS format "house ID,slope,baseload,R^2,n,efficiency gain" eg "12345,1.2,3.5,0.73,156,1.1"; no leading/terminating comma, never null. */
    public String apply(ETVPerHouseholdComputationResult r)
        {
        final Float ratio = r.getRatiokWhPerHDDNotSmartOverSmart();
        return("\""+r.getHouseID()+"\","+r.getHDDMetrics().toCSV()+"," + ((null!=ratio)?ratio:""));
        }

    /**Produce header for simple CSV format; no leading/terminating comma (nor line-end), never null. */
    public static String headerCSV() { return("\"house ID\","+HDDMetrics.headerCSV()+",\"efficiency gain if computed\""); }
    }
