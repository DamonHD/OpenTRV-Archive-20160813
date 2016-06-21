package uk.org.opentrv.ETV;

/**Compute space-heat energy efficiency change per ETV protocol for one household.
 * Typically used over one heating season,
 * or back-to-back heating seasons without significant changes in occupancy or heating season.
 * <p>
 * Reports on the change in slope of a linear regression of kWh/HDD for space-heating fuel.
 * <p>
 * Note:
 * <ul>
 * <li>There must be no significant secondary heating.</li>
 * <li>The heating fuel can also be used for other purposed,
 *     eg gas for cooking and DHW (domestic hot water) as well as space heating.</li>
 * </ul>
 */
public interface ETVPerHouseholdComputation
    {
    /**Abstract input for running the computation for one household. */
    public interface ETVPerHouseholdComputationInput
        {
        }

    /**Result of running the computation for one household. */
    public interface ETVPerHouseholdComputationResult
        {
        }

    public ETVPerHouseholdComputationResult compute(ETVPerHouseholdComputationInput in);
    }
