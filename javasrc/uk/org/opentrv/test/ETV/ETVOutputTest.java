package uk.org.opentrv.test.ETV;

import static org.junit.Assert.assertEquals;

import java.io.IOException;

import org.junit.Test;

import uk.org.opentrv.ETV.ETVPerHouseholdComputation.ETVPerHouseholdComputationResult;
import uk.org.opentrv.ETV.output.ETVPerHouseholdComputationResultToCSV;
import uk.org.opentrv.hdd.Util.HDDMetrics;

public class ETVOutputTest
    {
    /**Test generation of simple CSV output. */
    @Test public void testSimpleSingleCSVOutput() throws IOException
        {
        // Simple result without efficacy computation.
        final ETVPerHouseholdComputationResult r1 = new ETVPerHouseholdComputationResult(){
            @Override public String getHouseID() { return("1234"); }
            @Override public Float getRatiokWhPerHDDNotSmartOverSmart() { return(null); }
            @Override public HDDMetrics getHDDMetrics() { return(new HDDMetrics(1.2f, 5.4f, 0.8f, 63)); }
            };
        final String r1CSV = (new ETVPerHouseholdComputationResultToCSV()).apply(r1);
        assertEquals("\"1234\",1.2,5.4,0.8,63,", r1CSV);
        // Simple result without efficacy computation.
        final ETVPerHouseholdComputationResult r2 = new ETVPerHouseholdComputationResult(){
            @Override public String getHouseID() { return("56"); }
            @Override public Float getRatiokWhPerHDDNotSmartOverSmart() { return(1.23f); }
            @Override public HDDMetrics getHDDMetrics() { return(new HDDMetrics(7.89f, 0.1f, 0.6f, 532)); }
            };
        final String r2CSV = (new ETVPerHouseholdComputationResultToCSV()).apply(r2);
        assertEquals("\"56\",7.89,0.1,0.6,532,1.23", r2CSV);
        }
    }
