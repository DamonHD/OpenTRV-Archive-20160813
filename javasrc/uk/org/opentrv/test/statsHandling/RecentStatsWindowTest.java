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
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertTrue;
import static org.junit.Assert.fail;

import java.io.File;
import java.io.IOException;
import java.util.List;
import java.util.Random;

import org.json.simple.parser.JSONParser;
import org.junit.Test;

import uk.org.opentrv.comms.statshandlers.StatsMessageWithMetadata;
import uk.org.opentrv.comms.statshandlers.builtin.RecentStatsWindowFileWriter;
import uk.org.opentrv.comms.statshandlers.support.RecentStatsWindow;
import uk.org.opentrv.comms.statshandlers.support.Util;

/**Test behaviour of RecentStatsWindow. */
public class RecentStatsWindowTest
    {
    /**Test basic handling of messages, eg with respect to expiry. */
    @Test
    public void testRecentStatsWindowBasics() throws IOException
        {
        final RecentStatsWindow rsw0 = new RecentStatsWindow();
        assertNotNull(rsw0.getRecentStatsMessagesInOrder());
        assertTrue(rsw0.getRecentStatsMessagesInOrder().isEmpty());
        final StatsMessageWithMetadata swm1 = new StatsMessageWithMetadata("@ABCD;", System.currentTimeMillis(), rnd.nextBoolean());
        rsw0.processStatsMessage(swm1);
        assertNotNull(rsw0.getRecentStatsMessagesInOrder());
        assertEquals(1, rsw0.getRecentStatsMessagesInOrder().size());
        assertEquals("getRecentStatsMessagesInOrder() must be idempotent", 1, rsw0.getRecentStatsMessagesInOrder().size());
        assertEquals(swm1, rsw0.getRecentStatsMessagesInOrder().get(0));
        // Construct second distinct message with *same* timestamp and make sure both retained, in order.
        final StatsMessageWithMetadata swm2 = new StatsMessageWithMetadata("@BCDE;", swm1.timestamp, rnd.nextBoolean());
        rsw0.processStatsMessage(swm2);
        assertNotNull(rsw0.getRecentStatsMessagesInOrder());
        assertEquals(2, rsw0.getRecentStatsMessagesInOrder().size());
        assertEquals(swm1, rsw0.getRecentStatsMessagesInOrder().get(0));
        assertEquals(swm2, rsw0.getRecentStatsMessagesInOrder().get(1));
        // Construct a message with older timestamp and make sure it is rejected.
        try
            {
            rsw0.processStatsMessage(new StatsMessageWithMetadata("@DEFA;", swm1.timestamp - 1, rnd.nextBoolean()));
            fail("should have rejected older (out-of-order) message");
            }
        catch(final IOException e) { /* expected */ }
        // Construct a much newer message to push the others out.
        final StatsMessageWithMetadata swm3 = new StatsMessageWithMetadata("@1234;", swm1.timestamp + rsw0.getWindowMs() + 1, rnd.nextBoolean());
        rsw0.processStatsMessage(swm3);
        assertNotNull(rsw0.getRecentStatsMessagesInOrder());
        assertEquals(1, rsw0.getRecentStatsMessagesInOrder().size());
        assertEquals(swm3, rsw0.getRecentStatsMessagesInOrder().get(0));
        }

    /**Test basic handling of messages, eg with respect to expiry. */
    @Test
    public void testRecentStatsWindowLog() throws IOException
        {
        final RecentStatsWindow rsw0 = new RecentStatsWindow();
        assertEquals(0, rsw0.getRecentStatsMessagesInOrderAsJSONArray().size());
        assertEquals("[]", rsw0.getRecentStatsMessagesInOrderAsJSONArray().toString());
        final StatsMessageWithMetadata swm1 = new StatsMessageWithMetadata("@ABCD;", System.currentTimeMillis(), rnd.nextBoolean());
        rsw0.processStatsMessage(swm1);
        assertEquals(1, rsw0.getRecentStatsMessagesInOrderAsJSONArray().size());
        final StatsMessageWithMetadata swm2 = new StatsMessageWithMetadata("@ABCD;", System.currentTimeMillis(), rnd.nextBoolean());
        rsw0.processStatsMessage(swm2);
        assertEquals(2, rsw0.getRecentStatsMessagesInOrderAsJSONArray().size());
        }

    /**Test file writer. */
    @Test
    public void testFileWriteBasics() throws Exception
        {
        final File tf0 = File.createTempFile("RSWFW0", "json");
        final RecentStatsWindowFileWriter rswfw0 = new RecentStatsWindowFileWriter(tf0);
        final long t = 1430933201000L; // ~2015/05/06 18:26
        final boolean authenticated = true;
        final StatsMessageWithMetadata sm0 = new StatsMessageWithMetadata("{\"@\":\"b39a\"}", t, authenticated);
        rswfw0.processStatsMessage(sm0);
        final StatsMessageWithMetadata sm1 = new StatsMessageWithMetadata("{\"@\":\"b39a\"}", t+1, authenticated);
        rswfw0.processStatsMessage(sm1);
        final StatsMessageWithMetadata sm2 = new StatsMessageWithMetadata("@ABCD;", t+2, authenticated);
        rswfw0.processStatsMessage(sm2);
        final String sm0f = Util.readTextFile(tf0);
//System.out.println(sm0f);
        assertEquals("[{},[[\"2015-05-06T18:26:41Z\",\"{\\\"@\\\":\\\"b39a\\\"}\",true],[\"2015-05-06T18:26:41Z\",\"{\\\"@\\\":\\\"b39a\\\"}\",true],[\"2015-05-06T18:26:41Z\",\"@ABCD;\",true]]]", sm0f.trim());
        assertTrue(0 != sm0f.length());
        final JSONParser parser = new JSONParser();
        // Output form is currently just the log as a list as last element of an outer list...  FIXME: test more.
        final List json = (List)parser.parse(sm0f);
        assertEquals(2, json.size());
        final List log = (List)json.get(1);
        assertEquals(3, log.size());
        }

    /**OK PRNG. */
    private static final Random rnd = new Random();
    }
