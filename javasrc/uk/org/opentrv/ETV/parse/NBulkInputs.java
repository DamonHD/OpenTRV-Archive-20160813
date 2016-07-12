package uk.org.opentrv.ETV.parse;

import java.io.File;
import java.io.IOException;

import uk.org.opentrv.ETV.ETVPerHouseholdComputation.ETVPerHouseholdComputationInput;

/**Process typical set of bulk data with HDDs into input data object.
 * This allows bulk processing in one hit,
 * with single bulk files (or possibly directories) for each of:
 * <ul>
 * <li>household space-heat energy consumption</li>
 * <li>HDD</li>
 * <li>OpenTRV log data</li>
 * <li>associations between the various IDs</li>
 * </ul> 
 * All households must be in the same time zone
 * and have the same local HDD source.
 * <p>
 * Note: the API and implementation of this will evolve to add functionality.
 */
public final class NBulkInputs
    {
    public static ETVPerHouseholdComputationInput gatherData(
            final File NBulkDataFile,
            final File HDDDataFile)
        throws IOException
        {
        throw new RuntimeException("NOT IMPLEMENTED");
        }
    }
