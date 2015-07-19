/*
The OpenTRV project licenses this file to you
under the Apache Licence, Version 2.0 (the "Licence");
you may not use this file except in compliance
with the Licence. You may obtain a copy of the Licence at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing,
software distributed under the Licence is distributed on an
"AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
KIND, either express or implied. See the Licence for the
specific language governing permissions and limitations
under the Licence.

Author(s) / Copyright (s): Damon Hart-Davis 2015
*/

package uk.org.opentrv.comms.statshandlers.builtin;

import java.io.File;
import java.io.IOException;

import uk.org.opentrv.comms.statshandlers.StatsHandler;
import uk.org.opentrv.comms.statshandlers.StatsMessageWithMetadata;
import uk.org.opentrv.comms.statshandlers.support.Util;

/**Very simple file flag handler that sets a flag per leaf ID on receipt of any stats from that ID.
 * Authenticated messages will have a second flag set also.
 * <p>
 * The flag is simply touched to update its last-modified timestamp;
 * no data is written to the file.
 * <p>
 * This is useful for simple tasks such as detecting when a sensor is transmitting
 * (or not) which in some cases may be all that is required for use.
 * <p>
 * To avoid ambiguity and for security,
 * IDs that are not pure ASCII7 printable alphanumeric,
 * or are overly long,
 * are ignored.
 */
public class FileFlagStatsHandler implements StatsHandler
    {
    private final File statsDir;

    public FileFlagStatsHandler(final String statsDirName)
        {
        if(null == statsDirName) { throw new IllegalArgumentException(); }
        this.statsDir = new File(statsDirName);
        }

    @Override
    public void processStatsMessage(final StatsMessageWithMetadata swmd) throws IOException
        {
        final String id = swmd.GetLeafIDAsString();
        // Give up if no ID is extractable.
        if(null == id) { return; }
        // Check for any non-ASCII7 non-alphanumeric characters that may represent a security hazard.
        // Only allow digits and lower-case and limited length to ensure reliable safe behaviour
        // even in more limited filesystems such as even DOS 8+3.
        if(id.length() > 8) { return; }
        for(int i = id.length(); --i >= 0;)
            {
            final char c = id.charAt(i);
            if((c >= '0') && (c <= '9')) { continue; }
            if((c >= 'a') && (c <= 'z')) { continue; }
            return;
            }
        // Construct (non-auth) flag name.
        final String flagName = id + ".flg";
        final File flagFile = new File(statsDir, flagName);
        // TODO: check not 'special' in target filesystem, eg "CON" or "AUX" in Windows.
        // Touch file, creating if necessary.
        Util.touch(flagFile);
        if(swmd.authenticated)
            {
            // Construct auth flag name.
            final String flagNameAuth = id + ".afl";
            final File flagFileAuth = new File(statsDir, flagNameAuth);
            // TODO: check not 'special' in target filesystem, eg "CON" or "AUX" in Windows.
            // Touch file, creating if necessary.
            Util.touch(flagFileAuth);
            }
        }
    }
