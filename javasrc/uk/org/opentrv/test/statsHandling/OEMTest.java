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

import java.net.URL;
import java.util.Collections;
import java.util.Random;

import org.junit.Test;

import uk.org.opentrv.comms.statshandlers.StatsMessageWithMetadata;
import uk.org.opentrv.comms.statshandlers.builtin.openemon.OpenEnergyMonitorPostConfig;
import uk.org.opentrv.comms.statshandlers.builtin.openemon.OpenEnergyMonitorPostCredentials;
import uk.org.opentrv.comms.statshandlers.builtin.openemon.OpenEnergyMonitorPostSimple;

/**Test Open Energy Monitor data push. */
public class OEMTest
    {
    /**Test EMONCMS node ID to make test data clearly identifiable; non-negative. */
    public static final String EMONCMS_TEST_NODE_ID = "555";

    /**Test basic usage of OpenEnergyMonitorPostConfig. */
    @Test
    public void testOpenEnergyMonitorPostConfigBasics() throws Exception
        {
        final String hexID = "b39a";
        final OpenEnergyMonitorPostConfig oemc1 = new OpenEnergyMonitorPostConfig(
                new OpenEnergyMonitorPostCredentials(new URL("http://127.0.0.1/"), "ABC"),
                hexID,
                '{',
                Collections.singletonMap("T|C16", "Temp16"),
                EMONCMS_TEST_NODE_ID);
        assertTrue(oemc1.isInterestingMessage('{', hexID));
        assertFalse(oemc1.isInterestingMessage('@', hexID));
        assertFalse(oemc1.isInterestingMessage('{', "9999"));
        assertNull(oemc1.keyMapsToName('@', hexID, "x"));
        assertNull(oemc1.keyMapsToName('{', hexID, "x"));
        assertEquals("Temp16", oemc1.keyMapsToName('{', hexID, "T|C16"));
        }

    /**Test basic usage of OpenEnergyMonitorPostSimple. */
    @Test
    public void testOpenEnergyMonitorPostSimpleBasics() throws Exception
        {
        final String hexID = "b39a";
        final OpenEnergyMonitorPostConfig oemc1 = new OpenEnergyMonitorPostConfig(
                new OpenEnergyMonitorPostCredentials(new URL("http://127.0.0.1/"), "ABC"),
                hexID,
                '{',
                Collections.singletonMap("T|C16", "Temp16"),
                EMONCMS_TEST_NODE_ID);

        // Test message conversion (and filtering) from input message to output set.
        assertNotNull(OpenEnergyMonitorPostSimple.convertMessages(oemc1, new StatsMessageWithMetadata("@9999;", 1, false)));
        assertEquals(0, OpenEnergyMonitorPostSimple.convertMessages(oemc1, new StatsMessageWithMetadata("@9999;", 1, false)).size());
        assertEquals(1, OpenEnergyMonitorPostSimple.convertMessages(oemc1, new StatsMessageWithMetadata("{\"@\":\""+hexID+"\",\"T|C16\":308,\"B|mV\":3247}", 1, false)).size());
        assertNotNull(OpenEnergyMonitorPostSimple.convertMessages(oemc1, new StatsMessageWithMetadata("{\"@\":\""+hexID+"\",\"T|C16\":308,\"B|mV\":3247}", 1, false)).get(String.valueOf(EMONCMS_TEST_NODE_ID)).size());
        assertEquals(1, OpenEnergyMonitorPostSimple.convertMessages(oemc1, new StatsMessageWithMetadata("{\"@\":\""+hexID+"\",\"T|C16\":308,\"B|mV\":3247}", 1, false)).get(String.valueOf(EMONCMS_TEST_NODE_ID)).size());
        assertEquals(308, OpenEnergyMonitorPostSimple.convertMessages(oemc1, new StatsMessageWithMetadata("{\"@\":\""+hexID+"\",\"T|C16\":308,\"B|mV\":3247}", 1, false)).get(String.valueOf(EMONCMS_TEST_NODE_ID)).get("Temp16").intValue());

        // Test construction of emoncms (GET) URL from input data.
        final URL u1 = OpenEnergyMonitorPostSimple.createGETURLToSendDataToEmonCMSV8p4(oemc1, EMONCMS_TEST_NODE_ID, Collections.<String,Number>emptyMap());
//        System.out.println(u1);
        assertEquals("http://127.0.0.1/emoncms/api/post?apikey=ABC&node=555&json=%7B%7D", u1.toString());
        final URL u2 = OpenEnergyMonitorPostSimple.createGETURLToSendDataToEmonCMSV8p4(oemc1, EMONCMS_TEST_NODE_ID, Collections.<String,Number>singletonMap("Temp16", 308));
//        System.out.println(u2);
        assertEquals("http://127.0.0.1/emoncms/api/post?apikey=ABC&node=555&json=%7B%22Temp16%22%3A308%7D", u2.toString());
        }

//    /**Test post to real server (credentials must exist in credentials store). */
//    @Test
//    public void testRawPostToServer1() throws Exception
//        {
//        final String hexID = "b39a";
//        final OpenEnergyMonitorPostCredentials creds = OpenEnergyMonitorPostCredentials.getEmoncmsCrentials("emonserver1");
//        assertNotNull(creds);
//        final OpenEnergyMonitorPostConfig config1 = new OpenEnergyMonitorPostConfig(
//                creds,
//                hexID,
//                '{',
//                Collections.singletonMap("T|C16", "Temp16"),
//                hexID);
//        OpenEnergyMonitorPostSimple.sendDataToEmonCMSV8p4(config1, hexID, Collections.<String,Number>singletonMap("Temp16", (20*16)+rnd.nextInt(16)));
//        }
//
//    /**Test post to real server via the StatsHandler interface (credentials must exist in credentials store). */
//    @Test
//    public void testRawPostToServerViaHandler() throws Exception
//        {
//        final OpenEnergyMonitorPostCredentials creds = OpenEnergyMonitorPostCredentials.getEmoncmsCrentials("emonserver1");
//        assertNotNull(creds);
//        final String hexID = "b39a";
//        final Map<String, String> mapping = new HashMap<>();
//        mapping.put("T|C16", "Temp16");
//        mapping.put("B|mV", "BattmV");
//        final OpenEnergyMonitorPostConfig config1 = new OpenEnergyMonitorPostConfig(
//                creds,
//                hexID,
//                '{',
//                mapping,
//                EMONCMS_TEST_NODE_ID);
//        final OpenEnergyMonitorPostSimple sh1 = new OpenEnergyMonitorPostSimple(config1);
//        sh1.processStatsMessage(new StatsMessageWithMetadata("{\"@\":\""+hexID+"\",\"T|C16\":308,\"B|mV\":3247}", System.currentTimeMillis(), false));
//        sh1.processStatsMessage(new StatsMessageWithMetadata("{\"@\":\""+hexID+"\",\"T|C16\":309}", System.currentTimeMillis(), false));
//        sh1.processStatsMessage(new StatsMessageWithMetadata("{\"@\":\""+hexID+"\",\"T|C16\":310,\"B|mV\":3247}", System.currentTimeMillis(), false));
//        sh1.processStatsMessage(new StatsMessageWithMetadata("{\"@\":\""+hexID+"\",\"T|C16\":311}", System.currentTimeMillis(), false));
//        }

    /**OK PRNG. */
    private static final Random rnd = new Random();
    }
