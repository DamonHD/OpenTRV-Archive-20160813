package uk.org.opentrv.ETV;

import java.io.IOException;
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

    /**Get heating fuel energy consumption (kWh) by whole local days (local midnight-to-midnight).
     * Days may not be contiguous and the result may be empty.
     */
    public interface ETVPerHouseholdComputationInputKWH
        {
        /**Interval heating fuel consumption (kWh) by whole local days; never null.
         * @return  never null though may be empty
         * @throws IOException  in case of failure, eg parse problems
         */
        SortedMap<Integer, Float> getKWHByLocalDay() throws IOException;
        }

    /**Get Heating Degree Days (HDD, Celsius) by whole local days (local midnight-to-midnight).
     * Days may not be contiguous and the result may be empty.
     */
    public interface ETVPerHouseholdComputationInputHDD
        {
        /**Heating Degree Days (HDD, Celsius) by whole local days; never null.
         * Uses values for either a 'standard' base temperature (typically 15.5C)
         * or per-household value determined in other ways, eg by best-fit.
         *
         * @return  never null though may be empty
         * @throws IOException  in case of failure, eg parse problems
         */
        SortedMap<Integer, Float> getHDDByLocalDay() throws IOException;
        }

    /**Abstract input for running the computation for one household.
     * This should have an implementation that is backed by
     * plain-text CSV input data files,
     * though these may need filtering, transforming, and cross-referencing.
     */
    public interface ETVPerHouseholdComputationInput
        extends ETVPerHouseholdComputationInputKWH, ETVPerHouseholdComputationInputHDD
        {
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
