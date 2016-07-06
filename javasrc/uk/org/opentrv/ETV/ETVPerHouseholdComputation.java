package uk.org.opentrv.ETV;

import java.util.SortedMap;
import java.util.TimeZone;

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
    public enum SavingEnabledAndDataStatus { Enabled, Disabled, DontUse };

    /**Get heating fuel energy consumption by whole local day (no partial days). */
    public interface ETVPerHouseholdComputationInputKWH
        {
        SortedMap<Integer, Float> getKWHByLocalDay();
        }

    /**Abstract input for running the computation for one household.
     * This should have an implementation that is backed by
     * plain-text CSV input data files,
     * though these may need filtering, transforming, and cross-referencing.
     */
    public interface ETVPerHouseholdComputationInput extends ETVPerHouseholdComputationInputKWH
        {
        SortedMap<Integer, Float> getHDDByLocalDay();
        SortedMap<Integer, SavingEnabledAndDataStatus> getOptionalEnabledAndUsableFlagsByLocalDay();
        TimeZone getLocalTimeZoneForKWhAndHDD();
        SortedMap<Long, String> getOptionalJSONStatsByUTCTimestamp();
        SortedMap<String, Boolean> getJSONStatusValveElseBoilerControlByID();
        }

    /**Result of running the computation for one household.
     * There should be an implementation that can write to
     * plain-text CSV output file(s).
     */
    public interface ETVPerHouseholdComputationResult
        {
        int getDaysSampled();
        float getRatiokWhPerHDDSmartOverNotSmart();
        }

    ETVPerHouseholdComputationResult compute(ETVPerHouseholdComputationInput in)
        throws IllegalArgumentException;
    }
