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
package uk.org.opentrv.comms.statshandlers.filter;

import static uk.org.opentrv.comms.cfg.ConfigUtil.getAsList;
import static uk.org.opentrv.comms.cfg.ConfigUtil.getAsMap;

import java.io.IOException;
import java.util.HashSet;
import java.util.Set;
import java.util.Map;
import java.util.List;

import uk.org.opentrv.comms.statshandlers.StatsHandler;
import uk.org.opentrv.comms.statshandlers.StatsMessageWithMetadata;
import uk.org.opentrv.comms.statshandlers.StatsHandlerFactory;
import uk.org.opentrv.comms.cfg.ConfigException;


/**This wrapper filters stats messages by leaf ID and possibly by other simple/static features.
 * Used to (for example) allow only public data through to public data sinks.
 */
public final class SimpleStaticFilterStatsHandlerWrapper implements StatsHandler
    {
    /**Wrapped handler; not null. */
    private final StatsHandler sh;

    /**Immutable set of IDs to allow entire messages for; not null nor empty. */
    final Set<String> allowedIDs;

    public SimpleStaticFilterStatsHandlerWrapper(final Map config) throws ConfigException
        {
        this(
            StatsHandlerFactory.getInstance().newHandler(getAsMap(config, "handler")),
            new HashSet<String>(getAsList(config, "allowedIDs"))
            );
        }

    public SimpleStaticFilterStatsHandlerWrapper(final StatsHandler sh, final Set<String> allowedIDs)
        {
        if(null == sh) { throw new IllegalArgumentException(); }
        if(null == allowedIDs) { throw new IllegalArgumentException(); }
        final Set<String> immutableAllowedIDs = new HashSet<>(allowedIDs); // Defensive copy.
        if(immutableAllowedIDs.isEmpty()) { throw new IllegalArgumentException(); }
        this.sh = sh;
        this.allowedIDs = immutableAllowedIDs;
        }

    @Override
    public void processStatsMessage(final StatsMessageWithMetadata swmd) throws IOException
        {
        // Quickly and silently reject messages not for the right ID(s).
        if(!allowedIDs.contains(swmd.getLeafIDAsString())) { return; }

        // Pass message through.
        sh.processStatsMessage(swmd);
        }
    }
