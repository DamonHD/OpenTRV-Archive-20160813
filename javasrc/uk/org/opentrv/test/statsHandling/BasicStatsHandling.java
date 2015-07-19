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

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

import java.io.IOException;
import java.util.Collections;
import java.util.Random;

import org.junit.Test;

import uk.org.opentrv.comms.statshandlers.StatsHandler;
import uk.org.opentrv.comms.statshandlers.StatsMessageWithMetadata;
import uk.org.opentrv.comms.statshandlers.builtin.DummyStatsHandler;
import uk.org.opentrv.comms.statshandlers.filter.AsyncStatsHandlerWrapper;
import uk.org.opentrv.comms.statshandlers.support.Util;
import uk.org.opentrv.comms.util.IOHandlingV0p2;

public class BasicStatsHandling
    {
    @Test
    public void testDummyStatsHandler() throws Exception
        {
        final DummyStatsHandler dsh = new DummyStatsHandler();
        assertNull(dsh.getLastStatsMessageWithMetadata());

        dsh.processStatsMessage(new StatsMessageWithMetadata("=F0%@20C3;", System.currentTimeMillis(), rnd.nextBoolean()));
        assertNotNull(dsh.getLastStatsMessageWithMetadata());
        assertEquals("=F0%@20C3;", dsh.getLastStatsMessageWithMetadata().message);
        }

    @Test
    public void testDummyStatsHandlerViaIOHandler() throws Exception
        {
        final DummyStatsHandler dsh = new DummyStatsHandler();
        assertNull(dsh.getLastStatsMessageWithMetadata());

        IOHandlingV0p2.processStats("=F0%@20C3;", Collections.singletonList((StatsHandler) dsh), rnd.nextBoolean());
        assertNotNull(dsh.getLastStatsMessageWithMetadata());
        assertEquals("=F0%@20C3;", dsh.getLastStatsMessageWithMetadata().message);
        }

    @Test
    public void testAsyncStatsHandlerWrapper() throws Exception
        {
        final DummyStatsHandler dsh = new DummyStatsHandler();
        try(final AsyncStatsHandlerWrapper ashw = new AsyncStatsHandlerWrapper(dsh))
            {
            assertNull(dsh.getLastStatsMessageWithMetadata());

            dsh.processStatsMessage(new StatsMessageWithMetadata("=F0%@20C3;", System.currentTimeMillis(), rnd.nextBoolean()));
            ashw.close();
            assertNotNull(dsh.getLastStatsMessageWithMetadata());
            assertEquals("=F0%@20C3;", dsh.getLastStatsMessageWithMetadata().message);
            }
        }

    /**Stats handler that blocks for a loooong time, simulating a slow downstream network, etc. */
    public static final class BlockingStatsHandler implements StatsHandler
        {
        private void sleep() throws IOException { try { Thread.sleep(9999999); } catch(final InterruptedException e) { /* expected */ } }
        @Override public void processStatsMessage(final StatsMessageWithMetadata swmd) throws IOException { sleep(); }
        }

    @Test
    public void testAsyncStatsHandlerWrapperWithBlocking() throws Exception
        {
        // Tests that termination is possible in reasonable time...
        try(final AsyncStatsHandlerWrapper ashw = new AsyncStatsHandlerWrapper(new BlockingStatsHandler(), 1, 1))
            {
            ashw.processStatsMessage(new StatsMessageWithMetadata("=F0%@20C3;", System.currentTimeMillis(), rnd.nextBoolean()));
            ashw.close();
            }
        }

    /**Tests basic ID extraction and normalisation. */
    @Test
    public void testIDExtraction()
        {
        assertNull(Util.extractNormalisedID(null));
        assertNull(Util.extractNormalisedID(""));
        assertNull(Util.extractNormalisedID("bogus"));
        assertNull(Util.extractNormalisedID("@bogus"));
        assertNull(Util.extractNormalisedID("{bogus"));
        assertEquals("b39a", Util.extractNormalisedID("{\"@\":\"b39a\"}"));
        assertEquals("b39a", Util.extractNormalisedID("{\"@\":\"b39a\",\"B|mV\":3247,\"T|C16\":274}"));
        assertEquals("414a", Util.extractNormalisedID("@414A;T15C8;L36;O1"));
        assertEquals("0a45", Util.extractNormalisedID("@A45;T15CD;L56;O1"));
        }

    /**Test basic rate-limiting operation code. */
    @Test
    public void testRateLimitOp() throws Exception
        {
        final String uniqueOperationID = "tmp-testRateLimitOp";
        assertFalse("must allow purge", Util.canDoRateLimitedOperation(uniqueOperationID, -1));
        assertTrue("must succeed with 'new' flag", Util.canDoRateLimitedOperation(uniqueOperationID, 1));
        assertFalse("must fail immediately after previous op", Util.canDoRateLimitedOperation(uniqueOperationID, 1));
        assertFalse("must fail immediately after previous op", Util.canDoRateLimitedOperation(uniqueOperationID, 1));
        assertFalse("must allow purge", Util.canDoRateLimitedOperation(uniqueOperationID, -1));
        assertFalse("must allow purge", Util.canDoRateLimitedOperation(uniqueOperationID, -1));
        }

    /**OK local PRNG. */
    private static final Random rnd = new Random();
    }
