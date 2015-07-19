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
package uk.org.opentrv.test.statsHandling;

import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.fail;

import java.util.Collections;
import java.util.Random;

import org.junit.Test;

import uk.org.opentrv.comms.statshandlers.StatsMessageWithMetadata;
import uk.org.opentrv.comms.statshandlers.builtin.DummyStatsHandler;
import uk.org.opentrv.comms.statshandlers.filter.SimpleStaticFilterStatsHandlerWrapper;

/**Test simple static stats filtering. */
public class SimpleStaticFilterStatsHandlerWrapperTest
    {
    /**Test basic argument validation. */
    @Test
    public void testBasicArgHandling()
        {
        try { new SimpleStaticFilterStatsHandlerWrapper(null, null); fail(); }
        catch(final IllegalArgumentException e) { /* expected */ }
        final DummyStatsHandler dsh = new DummyStatsHandler();
        try { new SimpleStaticFilterStatsHandlerWrapper(dsh, null); fail(); }
        catch(final IllegalArgumentException e) { /* expected */ }
        try { new SimpleStaticFilterStatsHandlerWrapper(dsh, Collections.<String>emptySet()); fail(); }
        catch(final IllegalArgumentException e) { /* expected */ }
        new SimpleStaticFilterStatsHandlerWrapper(dsh, Collections.singleton("abcd"));
        }

    /**Test basic filtering by ID. */
    @Test
    public void testBasicFiltering() throws Exception
        {
        final DummyStatsHandler dsh1 = new DummyStatsHandler();
        final SimpleStaticFilterStatsHandlerWrapper ssf1 = new SimpleStaticFilterStatsHandlerWrapper(dsh1, Collections.singleton("abcd"));
        assertNull(dsh1.getLastStatsMessageWithMetadata());
        ssf1.processStatsMessage(new StatsMessageWithMetadata("{\"@\":\"b39a\",\"T|C16\":308,\"B|mV\":3247}", System.currentTimeMillis(), rnd.nextBoolean()));
        assertNull(dsh1.getLastStatsMessageWithMetadata());
        ssf1.processStatsMessage(new StatsMessageWithMetadata("{\"@\":\"abcd\",}", System.currentTimeMillis(), rnd.nextBoolean()));
        assertNotNull(dsh1.getLastStatsMessageWithMetadata());
        }

    /**OK PRNG. */
    private static final Random rnd = new Random();
    }
