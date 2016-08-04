package uk.org.opentrv.test.ETV;

import static org.junit.Assert.*;

import java.io.IOException;

import org.junit.Test;

import uk.org.opentrv.ETV.ETVPerHouseholdComputation.ETVPerHouseholdComputationInput;
import uk.org.opentrv.ETV.ETVPerHouseholdComputation.ETVPerHouseholdComputationResult;
import uk.org.opentrv.ETV.ETVPerHouseholdComputationSimpleImpl;
import uk.org.opentrv.ETV.parse.NBulkInputs;
import uk.org.opentrv.test.hdd.DDNExtractorTest;

public class ETVComputationTest
    {
    /**Test for correct computation for a single household into for several months' data. */
    @Test public void testNBulkSHInputs() throws IOException
        {
        final ETVPerHouseholdComputationInput in = NBulkInputs.gatherData(5013, ETVParseTest.getNBulkSH2016H1CSVReader(), DDNExtractorTest.getETVEGLLHDD2016H1CSVReader());
        assertNotNull(in);
        final ETVPerHouseholdComputationResult out = ETVPerHouseholdComputationSimpleImpl.getInstance().compute(in);
        assertNotNull(out);
        assertNull("simple analysis should not compute ratio", out.getRatiokWhPerHDDNotSmartOverSmart());
        assertNotNull("simple analysis should compute kWh/HD", out.getHDDMetrics());
        assertTrue("simple analysis should compute kWh/HD", out.getHDDMetrics().n > 0);
        assertFalse("simple analysis should compute kWh/HD", Float.isNaN(out.getHDDMetrics().slopeEnergyPerHDD));
        assertTrue("simple analysis should compute kWh/HD", out.getHDDMetrics().slopeEnergyPerHDD > 0.0f);

//            System.out.println(metrics);
//            assertEquals("slope ~ 1.5kWh/HDD12.5", 1.5f, metrics.slopeEnergyPerHDD, 0.1f);
//            assertEquals("baseline usage ~ 5.2kWh/d", 5.2f, metrics.interceptBaseline, 0.1f);
//            assertEquals("R^2 ~ 0.6", 0.6f, metrics.rsqFit, 0.1f);
        }
    }
