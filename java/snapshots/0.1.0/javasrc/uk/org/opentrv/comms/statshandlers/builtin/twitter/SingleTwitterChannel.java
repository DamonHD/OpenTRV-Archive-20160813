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
package uk.org.opentrv.comms.statshandlers.builtin.twitter;

import java.io.IOException;

import uk.org.opentrv.comms.statshandlers.StatsHandler;
import uk.org.opentrv.comms.statshandlers.StatsMessageWithMetadata;
import uk.org.opentrv.comms.statshandlers.support.Util;
import winterwell.jtwitter.Twitter;

/**Single Twitter channel with some embedded state.
 * Only users stats messages whose the normalised ID matches that in the config.
 * <p>
 * By default posts the raw message in the Tweet with a simple timestamp and count.
 * (The count makes restarts and lost messages more evident.)
 * <p>
 * Obeys the configured rate limit, using the global limit.
 * Messages that would breach the limit are by default simply dropped.
 * <p>
 * TODO: avoid duplicate data content on successive tweets other than to meet some maximum "I'm alive" time between messages.
 * <p>
 * Not thread-safe.
 */
public class SingleTwitterChannel implements StatsHandler, AutoCloseable
    {
    /**Maximum supported raw message length if sent raw, allowing for variable prefix; strictly positive. */
    public static final int MAX_RAW_MESSAGE_LENGTH = 120;

    /**Immutable configuration for this channel; never null. */
    final SingleTwitterChannelConfig config;

    /**Unique operation ID for rate limiting. */
    final String uniqueOpID;

    /**Count of (matching) messages received by this instance. */
    int messageCount;

    /**Get the count of messages passed with the correct ID. */
    public int getMessageCount() { return(messageCount); }

//    /**Time of last (successful) tweet from this instance (zero if none); ms since Java epoch. */
//    long lastTweetSent;

    public SingleTwitterChannel(final SingleTwitterChannelConfig config)
        {
        if(null == config) { throw new IllegalArgumentException(); }
        this.config = config;
        uniqueOpID = "tweet@" + config.fullHandle;
        }

    /**If true then a message can be sent (and will be marked as having been done so). */
    protected boolean canSendMessage() throws IOException
        { return(Util.canDoRateLimitedOperation(uniqueOpID, config.minimumMessageIntervalMinutes)); }

    /**Fixed prefix by which this type of raw stats tweet can be recognised. */
    public static final String FIXED_TWEET_PREFIX = "RAW_";

    /**Generate 'uniquifier' for the putative tweet to help avoid triggering rejection as SPAM.
     * Short prefix string that also gives a human some context.
     * <p>
     * Contains a part of the message count to help monitor dropped messages
     * (eg due to Twitter rate limiting) and concentrator restarts.
     */
    protected String getTweetPrefix()
        {
        final String time = new java.text.SimpleDateFormat("HHmm").format(new java.util.Date());
        return(FIXED_TWEET_PREFIX+(messageCount&0x3f)+"%64@"+time+"> ");
        }

    @Override
    public void processStatsMessage(final StatsMessageWithMetadata swmd) throws IOException
        {
        // Don't even look at over-length messages!

        if(swmd.message.length() > MAX_RAW_MESSAGE_LENGTH) { return; }
        // Quickly and silently reject messages not for the right ID.
        if(!config.hexID.equals(Util.extractNormalisedID(swmd.message))) { return; }

        // Count all matching messages.
        ++messageCount;

        // Silently drop messages that would exceed the rate limit.
        if(!canSendMessage()) { return; }

        final String tweetText = getTweetPrefix() + swmd.message;
//        System.out.println("Can tweet to " + config.fullHandle + " ... " + tweetText);

        // Send Tweet!
        // TODO: cache Twitter handle for efficiency; recreate if needed.
        final Twitter th = TwitterUtils.getTwitterHandle("OpenTRV_Sb39a");
        th.setStatus(tweetText);
        }

    /**Release resources. */
    @Override
    public void close() throws Exception
        {
        // TODO Auto-generated method stub

        }
    }
