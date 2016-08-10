package uk.org.opentrv.ETV.output;

import java.util.List;
import java.util.function.Function;

import uk.org.opentrv.ETV.ETVPerHouseholdComputation.ETVPerHouseholdComputationResult;

/**Generate machine-readable (multi-line-CVS with header) form for a result list.
 * A header line is included.
 * <p>
 * Lines are terminated with '\n'.
 * <p>
 * Stateless.
 */
public final class ETVPerHouseholdComputationResultsToCSV
        implements Function<List<ETVPerHouseholdComputationResult>,String>
    {
    /**Produce simple CVS format "house ID,slope,baseload,R^2,n,efficiency gain" eg "12345,1.2,3.5,0.73,156,1.1"; no leading/terminating comma, never null. */
    public String apply(List<ETVPerHouseholdComputationResult> rl)
        {
        final ETVPerHouseholdComputationResultToCSV s = new ETVPerHouseholdComputationResultToCSV();
        final StringBuilder sb = new StringBuilder();
        sb.append(ETVPerHouseholdComputationResultToCSV.headerCSV()).append('\n');
        for(final ETVPerHouseholdComputationResult r : rl)
            { sb.append(s.apply(r)).append('\n'); }
        return(sb.toString());
        }
    }
