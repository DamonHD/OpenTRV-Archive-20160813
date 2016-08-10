package uk.org.opentrv.test.ETV;

import static org.junit.Assert.assertEquals;

import java.io.IOException;
import java.util.Arrays;
import java.util.List;

import org.junit.Test;

import uk.org.opentrv.ETV.ETVPerHouseholdComputation.ETVPerHouseholdComputationResult;
import uk.org.opentrv.ETV.output.ETVPerHouseholdComputationResultToCSV;
import uk.org.opentrv.ETV.output.ETVPerHouseholdComputationResultsToCSV;
import uk.org.opentrv.hdd.Util.HDDMetrics;

public class ETVOutputTest
    {
    /**Test generation of simple (part-line) CSV output for a single household. */
    @Test public void testSimpleSingleCSVOutput() throws IOException
        {
        // Simple result without efficacy value.
        final ETVPerHouseholdComputationResult r1 = new ETVPerHouseholdComputationResult(){
            @Override public String getHouseID() { return("1234"); }
            @Override public Float getRatiokWhPerHDDNotSmartOverSmart() { return(null); }
            @Override public HDDMetrics getHDDMetrics() { return(new HDDMetrics(1.2f, 5.4f, 0.8f, 63)); }
            };
        final String r1CSV = (new ETVPerHouseholdComputationResultToCSV()).apply(r1);
        assertEquals("\"1234\",1.2,5.4,0.8,63,", r1CSV);
        // Simple result with efficacy value.
        final ETVPerHouseholdComputationResult r2 = new ETVPerHouseholdComputationResult(){
            @Override public String getHouseID() { return("56"); }
            @Override public Float getRatiokWhPerHDDNotSmartOverSmart() { return(1.23f); }
            @Override public HDDMetrics getHDDMetrics() { return(new HDDMetrics(7.89f, 0.1f, 0.6f, 532)); }
            };
        final String r2CSV = (new ETVPerHouseholdComputationResultToCSV()).apply(r2);
        assertEquals("\"56\",7.89,0.1,0.6,532,1.23", r2CSV);
        }

    /**Test generation of composite (multi-line) CSV output for multiple households. */
    @Test public void testSimpleMultiCSVOutput() throws IOException
        {
        // Simple result without efficacy value.
        final ETVPerHouseholdComputationResult r1 = new ETVPerHouseholdComputationResult(){
            @Override public String getHouseID() { return("1234"); }
            @Override public Float getRatiokWhPerHDDNotSmartOverSmart() { return(null); }
            @Override public HDDMetrics getHDDMetrics() { return(new HDDMetrics(1.2f, 5.4f, 0.8f, 63)); }
            };
        // Simple result with efficacy value.
        final ETVPerHouseholdComputationResult r2 = new ETVPerHouseholdComputationResult(){
            @Override public String getHouseID() { return("56"); }
            @Override public Float getRatiokWhPerHDDNotSmartOverSmart() { return(1.23f); }
            @Override public HDDMetrics getHDDMetrics() { return(new HDDMetrics(7.89f, 0.1f, 0.6f, 532)); }
            };
        final List<ETVPerHouseholdComputationResult> rl = Arrays.asList(r1, r2);
        final String rlCSV = (new ETVPerHouseholdComputationResultsToCSV()).apply(rl);
//        System.out.println(rlCSV);
        assertEquals(
                "\"house ID\",\"slope energy/HDD\",\"baseload energy\",\"R^2\",\"n\",\"efficiency gain if computed\"\n" +
                "\"1234\",1.2,5.4,0.8,63,\n" +
                "\"56\",7.89,0.1,0.6,532,1.23\n",
                rlCSV);
        }
    }
