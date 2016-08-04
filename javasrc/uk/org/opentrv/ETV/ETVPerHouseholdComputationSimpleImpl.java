package uk.org.opentrv.ETV;

import java.io.IOException;
import java.util.SortedMap;

import uk.org.opentrv.hdd.ContinuousDailyHDD;

/**Simple computation implementation for one household, no efficacy.
 * This can do a simple computation to find overall kWh/HDD
 * from the supplied house's data,
 * ignoring (not computing) change in efficiency with equipment operation.
 * <p>
 * May not work if input data is discontinuous,
 * or iff energy data date range is not completely within HDD data date range.
 * <p>
 * This class is a stateless singleton.
 */
public final class ETVPerHouseholdComputationSimpleImpl implements ETVPerHouseholdComputation
    {
    // Lazy-creation singleton.
    private ETVPerHouseholdComputationSimpleImpl() { /* prevent direct instance creation. */ }
    private static class ETVPerHouseholdComputationSimpleImplHolder { static final ETVPerHouseholdComputationSimpleImpl INSTANCE = new ETVPerHouseholdComputationSimpleImpl(); }
    public static ETVPerHouseholdComputationSimpleImpl getInstance() { return(ETVPerHouseholdComputationSimpleImplHolder.INSTANCE); }

    @Override
    public ETVPerHouseholdComputationResult compute(final ETVPerHouseholdComputationInput in) throws IllegalArgumentException
        {
        if(null == in) { throw new IllegalArgumentException(); }

        // FIXME: not meeting contract if HDD data discontinuous; should check.
        final ContinuousDailyHDD cdh = new ContinuousDailyHDD()
            {
            @Override public SortedMap<Integer, Float> getMap() { try { return(in.getHDDByLocalDay()); } catch(final IOException e) { throw new IllegalArgumentException(e); } }
            @Override public float getBaseTemperatureAsFloat() { return(Float.NaN); } // FIXME: UNKNOWN
            };

//        final Collection<ConsumptionHDDTuple> ds = Util.combineMeterReadingsWithHDD(
//                MeterReadingsExtractor.extractMeterReadings(getETVKWh201602CSVReader(), true),
//                DDNExtractor.extractSimpleHDD(DDNExtractorTest.getETVEGLLHDD201602CSVReader(), 15.5f),
//                true);
//            final HDDMetrics metrics = Util.computeHDDMetrics(ds);
//            System.out.println(metrics);
//            assertEquals("slope ~ 1.5kWh/HDD12.5", 1.5f, metrics.slopeEnergyPerHDD, 0.1f);
//            assertEquals("baseline usage ~ 5.2kWh/d", 5.2f, metrics.interceptBaseline, 0.1f);
//            assertEquals("R^2 ~ 0.6", 0.6f, metrics.rsqFit, 0.1f);

        return(new ETVPerHouseholdComputationResult() {

            @Override
            public int getDaysSampled()
                {
                // TODO Auto-generated method stub
                return 0;
                }

            @Override
            public Float getkWhPerHDD()
                {
                // TODO Auto-generated method stub
                return null;
                }

            // Efficacy computation not implemented for simple analysis.
            @Override public Float getRatiokWhPerHDDNotSmartOverSmart() { return(null); }
            });
        }

    }
