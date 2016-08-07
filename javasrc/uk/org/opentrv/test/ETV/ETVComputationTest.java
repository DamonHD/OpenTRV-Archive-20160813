package uk.org.opentrv.test.ETV;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

import java.io.IOException;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import org.junit.Test;

import uk.org.opentrv.ETV.ETVPerHouseholdComputation.ETVPerHouseholdComputationInput;
import uk.org.opentrv.ETV.ETVPerHouseholdComputation.ETVPerHouseholdComputationResult;
import uk.org.opentrv.ETV.ETVPerHouseholdComputationSimpleImpl;
import uk.org.opentrv.ETV.parse.NBulkInputs;
import uk.org.opentrv.hdd.Util.HDDMetrics;
import uk.org.opentrv.test.hdd.DDNExtractorTest;

public class ETVComputationTest
    {
    /**Test for correct computation for a single household info for several months' data. */
    @Test public void testNBulkSHInputs() throws IOException
        {
        final ETVPerHouseholdComputationInput in = NBulkInputs.gatherData(5013, ETVParseTest.getNBulkSH2016H1CSVReader(), DDNExtractorTest.getETVEGLLHDD2016H1CSVReader());
        assertNotNull(in);
        final ETVPerHouseholdComputationResult out = ETVPerHouseholdComputationSimpleImpl.getInstance().compute(in);
        assertNotNull(out);
        assertNull("simple analysis should not compute ratio", out.getRatiokWhPerHDDNotSmartOverSmart());
        final HDDMetrics hddMetrics = out.getHDDMetrics();
        assertNotNull("simple analysis should compute kWh/HD", hddMetrics);
        assertTrue("simple analysis should compute kWh/HD", hddMetrics.n > 0);
        assertFalse("simple analysis should compute kWh/HD", Float.isNaN(hddMetrics.slopeEnergyPerHDD));
        assertTrue("simple analysis should compute kWh/HD", hddMetrics.slopeEnergyPerHDD > 0.0f);
//        System.out.println(hddMetrics);
        assertEquals("days", 156, hddMetrics.n);
        assertEquals("slope ~ 1.5kWh/HDD12.5", 1.5f, hddMetrics.slopeEnergyPerHDD, 0.1f);
        assertEquals("baseline usage ~ 1.3kWh/d", 1.3f, hddMetrics.interceptBaseline, 0.1f);
        assertEquals("R^2 ~ 0.6", 0.6f, hddMetrics.rsqFit, 0.1f);
        }

    /**Test bulk gas meter parse and calc for via multi-household route. */
    @Test public void testNBulkSHMultiInputs() throws IOException
        {
        final Map<String, ETVPerHouseholdComputationInput> mhi =
            NBulkInputs.gatherDataForAllHouseholds(
                    ETVParseTest.NBulkSH2016H1CSVReaderSupplier,
                DDNExtractorTest.getETVEGLLHDD2016H1CSVReader());
        assertNotNull(mhi);
        assertEquals(1, mhi.size());
        assertTrue(mhi.containsKey("5013"));
        assertEquals("5013", mhi.get("5013").getHouseID());

        final List<ETVPerHouseholdComputationResult> computed = mhi.values().stream().map(ETVPerHouseholdComputationSimpleImpl.Simple).collect(Collectors.toList());
        assertEquals(1, computed.size());
        assertEquals("5013", computed.get(0).getHouseID());
        assertEquals("slope ~ 1.5kWh/HDD12.5", 1.5f, computed.get(0).getHDDMetrics().slopeEnergyPerHDD, 0.1f);
        }
    }
