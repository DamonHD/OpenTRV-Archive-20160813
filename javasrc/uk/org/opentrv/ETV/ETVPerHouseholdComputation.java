package uk.org.opentrv.ETV;

import java.io.IOException;
import java.util.SortedMap;
import java.util.TimeZone;
import java.util.function.Function;

import uk.org.opentrv.ETV.ETVPerHouseholdComputation.ETVPerHouseholdComputationInput;
import uk.org.opentrv.ETV.ETVPerHouseholdComputation.ETVPerHouseholdComputationResult;
import uk.org.opentrv.hdd.Util.HDDMetrics;

/**Compute space-heat energy efficiency change per ETV protocol for one household; supports lambdas.
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
    extends Function<ETVPerHouseholdComputationInput, ETVPerHouseholdComputationResult>
    {
    public enum SavingEnabledAndDataStatus { Enabled, Disabled, DontUse };

    /**Get heating fuel energy consumption (kWh) by whole local days (local midnight-to-midnight).
     * Days may not be contiguous and the result may be empty.
     */
    public interface ETVPerHouseholdComputationInputKWh
        {
        /**Interval heating fuel consumption (kWh) by whole local days; never null.
         * @return  never null though may be empty
         * @throws IOException  in case of failure, eg parse problems
         */
        SortedMap<Integer, Float> getKWhByLocalDay() throws IOException;
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

        /**Get base temperature for this data set as float; never Inf, may be NaN if unknown or not constant. */
        float getBaseTemperatureAsFloat();
        }

    /**Abstract input for running the computation for one household.
     * This should have an implementation that is backed by
     * plain-text CSV input data files,
     * though these may need filtering, transforming, and cross-referencing.
     */
    public interface ETVPerHouseholdComputationInput
        extends ETVPerHouseholdComputationInputKWh, ETVPerHouseholdComputationInputHDD
        {
        /**Get unique house ID as alphanumeric String; never null. */
        String getHouseID();
        // TO BE DOCUMENTED
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
        /**Get unique house ID as alphanumeric String; never null. */
        String getHouseID();
        /**Return HDD metrics; null if not computable. */
        HDDMetrics getHDDMetrics();
        /**Return energy efficiency improvement (more than 1.0 is good), +ve, null if not computable. */
        Float getRatiokWhPerHDDNotSmartOverSmart();
        }

    /**Convert the input data to the output result; never null. */
    ETVPerHouseholdComputationResult apply(ETVPerHouseholdComputationInput in)
        throws IllegalArgumentException;
    }
