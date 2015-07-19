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

import java.util.Random;

import org.junit.Test;

import uk.org.opentrv.comms.statshandlers.StatsMessageWithMetadata;
import uk.org.opentrv.comms.statshandlers.builtin.twitter.SingleTwitterChannel;
import uk.org.opentrv.comms.statshandlers.builtin.twitter.SingleTwitterChannelConfig;

public class TwitterTest
    {
    /**Test that very basic Tweeting does not fail horribly at least!
     * It is possible to eyeball Twitter itself for Tweets getting published,
     * subject to rate limiting, etc,
     * if credentials are available at run-time (NOTE: must never be checked in).
     */
    @Test
    public void testSingleTwitterChannel() throws Exception
        {
        final SingleTwitterChannelConfig config = new SingleTwitterChannelConfig("b39a");
        try(final SingleTwitterChannel stc = new SingleTwitterChannel(config))
            {
            assertEquals("no messages should have been counted yet", 0, stc.getMessageCount());
            stc.processStatsMessage(new StatsMessageWithMetadata("garbage", System.currentTimeMillis(), rnd.nextBoolean()));
            assertEquals("garbage message should be ignored", 0, stc.getMessageCount());
            stc.processStatsMessage(new StatsMessageWithMetadata("@2D1A;T19C6;L1;O1", System.currentTimeMillis(), rnd.nextBoolean()));
            assertEquals("message with wrong ID should be ignored", 0, stc.getMessageCount());
            stc.processStatsMessage(new StatsMessageWithMetadata("{\"@\":\"819c\",\"T|C16\":238,\"L\":3,\"B|cV\":256}", System.currentTimeMillis(), rnd.nextBoolean()));
            assertEquals("message with wrong ID should be ignored", 0, stc.getMessageCount());
            stc.processStatsMessage(new StatsMessageWithMetadata("{\"@\":\"b39a\",\"B|mV\":3230,\"T|C16\":420}", System.currentTimeMillis(), rnd.nextBoolean()));
            assertEquals("message with correct ID should be processed", 1, stc.getMessageCount());
            stc.processStatsMessage(new StatsMessageWithMetadata("{\"@\":\"819c\",\"T|C16\":238,\"L\":3,\"B|cV\":256}", System.currentTimeMillis(), rnd.nextBoolean()));
            assertEquals("message with wrong ID should be ignored", 1, stc.getMessageCount());
            }
        }

//    /**Tests direct access to Twitter providing auth credentials are in the expected place. */
//    @Test
//    public void testTwitterAccess()
//        {
//        final Twitter th = TwitterUtils.getTwitterHandle("OpenTRV_Sb39a");
//        th.setStatus("Here's a random number: " + rnd.nextInt());
//        }

//    /**Test user-mediated extraction of auth token.
//     * Also useful for gathering new secrets manually...
//       */
//    @Test
//    public void testOOBTokenAccess()
//        {
//        final OAuthSignpostClient client = new OAuthSignpostClient(
//                OAuthSignpostClient.JTWITTER_OAUTH_KEY,
//                OAuthSignpostClient.JTWITTER_OAUTH_SECRET, "oob");
//        final Twitter jtwit = new Twitter("OpenTRV_Sb39a", client);
//        // open the authorisation page in the user's browser
//        // This is a convenience method for directing the user to
//        // client.authorizeUrl()
//        client.authorizeDesktop();
//        // get the pin
//        final String v = OAuthSignpostClient
//                .askUser("Please enter the verification PIN from Twitter");
//        client.setAuthorizationCode(v);
//        // Optional: store the authorisation token details
//        final String[] accessToken = client.getAccessToken();
//        for(final String s : accessToken)
//            {
//            System.out.println(s);
//            }
//        // use the API!
//        jtwit.setStatus("Testing auth...");
//        }

    /**OK PRNG. */
    private static final Random rnd = new Random();
    }
