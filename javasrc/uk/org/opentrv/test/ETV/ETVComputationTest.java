package uk.org.opentrv.test.ETV;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

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
        final ETVPerHouseholdComputationInput in = NBulkInputs.gatherData(5013, ETVParseTest.getNBulkSHCSVReader(), DDNExtractorTest.getETVEGLLHDD2016H1CSVReader());
        assertNotNull(in);
        final ETVPerHouseholdComputationResult out = ETVPerHouseholdComputationSimpleImpl.getInstance().compute(in);
        assertNotNull(out);
        assertNull("simple analysis should not compute ratio", out.getRatiokWhPerHDDNotSmartOverSmart());
//        assertTrue("simple analysis should compute kWh/HD", out.getDaysSampled() > 0);
//        assertNotNull("simple analysis should compute kWh/HD", out.getkWhPerHDD());
//        assertFalse("simple analysis should compute kWh/HD", Float.isNaN(out.getkWhPerHDD()));
//        assertTrue("simple analysis should compute kWh/HD", out.getkWhPerHDD() > 0.0f);
        }
    }
