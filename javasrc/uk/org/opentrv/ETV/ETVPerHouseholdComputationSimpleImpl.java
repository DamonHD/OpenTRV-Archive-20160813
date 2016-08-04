package uk.org.opentrv.ETV;

/**Simple computation implementation for one household, no efficacy.
 * This can do a simple computation to find overall kWh/HDD
 * from the supplied house's data,
 * ignoring any change in efficiency with equipment operation.
 * <p>
 * This is a stateless singleton.
 */
public final class ETVPerHouseholdComputationSimpleImpl implements ETVPerHouseholdComputation
    {
    // Lazy-creation singleton.
    private ETVPerHouseholdComputationSimpleImpl() { /* prevent direct instance creation. */ }
    private static class ETVPerHouseholdComputationSimpleImplHolder { static final ETVPerHouseholdComputationSimpleImpl INSTANCE = new ETVPerHouseholdComputationSimpleImpl(); }
    public static ETVPerHouseholdComputationSimpleImpl getInstance() { return(ETVPerHouseholdComputationSimpleImplHolder.INSTANCE); }

    @Override
    public ETVPerHouseholdComputationResult compute(ETVPerHouseholdComputationInput in) throws IllegalArgumentException
        {
        if(null == in) { throw new IllegalArgumentException(); }

        // TODO Auto-generated method stub
        return null;
        }

    }
