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
import java.util.Map;

import uk.org.opentrv.comms.statshandlers.StatsHandler;
import uk.org.opentrv.comms.statshandlers.StatsMessageWithMetadata;
import uk.org.opentrv.comms.statshandlers.support.Util;
import winterwell.jtwitter.Status;
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
 * FIXME: avoid multiple (re)parsings of the stats message
 * <p>
 * Not thread-safe.
 */
public class SingleTwitterChannel implements StatsHandler, AutoCloseable
    {
    /**Maximum supported tweet length; strictly positive. */
    public static final int MAX_RAW_MESSAGE_LENGTH = 140;

    /**Immutable configuration for this channel; never null. */
    protected final SingleTwitterChannelConfig config;

    /**Unique operation ID for rate limiting. */
    protected final String uniqueOpID;

    /**Count of (matching) messages received by this instance. */
    protected int messageCount;

    /**Get the count of messages passed with the correct ID. */
    public int getMessageCount() { return(messageCount); }

//    /**Time of last (successful) tweet from this instance (zero if none); ms since Java epoch. */
//    long lastTweetSent;

    public SingleTwitterChannel(final Map config)
        {
        this(new SingleTwitterChannelConfig(config));
        }

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
     * May contain a part of the message count to help monitor dropped messages
     * (eg due to Twitter rate limiting) and concentrator restarts.
     */
    protected String getTweetPrefix()
        {
        final String time = new java.text.SimpleDateFormat("HHmm").format(new java.util.Date());
        return(FIXED_TWEET_PREFIX+(messageCount&0x3f)+"%64@"+time+"> ");
        }

    /**Generate body of tweet, under 140 characters minus the prefix; never null.
     * Should be idempotent and not affect internal state.
     */
    public String getTweetBody(final StatsMessageWithMetadata swmd)
        {
        // Defaults to the raw stats message itself. */
        return(swmd.message);
        }

    /**If true, this is a hint not to bother sending the current message.
     * This returns true if there is likely little new information,
     * eg compared to the previous message sent this would be a duplicate.
     * <p>
     * Default behaviour is to return false, ie to always attempt to send.
     */
    protected boolean dontSend(final StatsMessageWithMetadata swmd)
        { return(false); }

    /**Called once it appears that the tweet has been successfully sent.
     * Can be used to update state to help avoid sending duplicates.
     */
    protected void sent(final StatsMessageWithMetadata swmd)
        { }

    @Override
    public void processStatsMessage(final StatsMessageWithMetadata swmd) throws IOException
        {
        // Quickly and silently reject messages not for the right leaf/Twitter ID.
        if(!config.hexID.equals(swmd.getLeafIDAsString())) { return; }

        // Count all matching incoming messages.
        ++messageCount;

        // If sending not recommended (eg no applicable or little new info) then return.
        if(dontSend(swmd)) { return; }

        // Silently drop messages that would exceed the rate limit.
        if(!canSendMessage()) { return; }

        final String tweetText = getTweetPrefix() + getTweetBody(swmd);
//        System.out.println("Can tweet to " + config.fullHandle + " ... " + tweetText);

        // Drop over-length messages!
        if(tweetText.length() > MAX_RAW_MESSAGE_LENGTH) { throw new IOException("putative tweet too long"); }

        // Send Tweet!
        // TODO: cache Twitter handle for efficiency; recreate as needed.
        final Twitter th = TwitterUtils.getTwitterHandle(config.fullHandle);
        final Status status = th.setStatus(tweetText);

        if(null == status) { throw new IOException("tweet not sent (null status)"); }

        // Note that the tweet appears to have actually been sent successfully.
        sent(swmd);
        }

    /**Release resources. */
    @Override
    public void close() throws Exception
        {
        // Nothing to do for now; could dispose of cached state.
        }
    }
