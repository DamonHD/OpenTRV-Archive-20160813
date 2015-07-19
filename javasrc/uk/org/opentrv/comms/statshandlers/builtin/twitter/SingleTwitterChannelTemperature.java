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

import java.util.Map;
import java.util.Random;

import uk.org.opentrv.comms.statshandlers.StatsMessageWithMetadata;
import uk.org.opentrv.comms.util.ParsedRemoteBinaryStatsRecord;

/**A single Twitter channel that just relays temperature.
 * This relays temperature in whole Celsius,
 * and avoids tweeting duplicate values.
 * <p>
 * This can extract temperature from the stats in a number of formats.
 */
public final class SingleTwitterChannelTemperature extends SingleTwitterChannel
    {
    /**Set up with given map config to Tweet the temperature. */
    public SingleTwitterChannelTemperature(final Map config)
        { super(config); }

    /**Set up with given config to Tweet the temperature. */
    public SingleTwitterChannelTemperature(final SingleTwitterChannelConfig config)
        { super(config); }

    /**Last temperature tweeted. */
    private int lastCTweeted = Integer.MIN_VALUE;

    /**If true, this is a hint not to bother sending the current message.
     * This returns true if there is likely little new information,
     * eg compared to the previous message sent this would be a duplicate.
     */
    @Override
    protected boolean dontSend(final StatsMessageWithMetadata swmd)
        {
        final Integer temp = extractTemperature(swmd);
        if(null == temp) { return(true); } // No temperature to tweet.
        if(temp.intValue() == lastCTweeted) { return(true); } // Unchanged temperature.
        return(false); // Looks OK to send.
        }

    /**Built-in list of chatty en_GB prefixes.
     * Eventually allow space to slot in a time {0} and message number {1}
     */
    private final static String [] DEFAULT_PREFIXES_en_GB =
        {
                "The temperature at {0} is",
                "Hiya, at {0} the temperature is",
                "Yep, it's {0} and",
                "Yo!, it's {0} and",
                "Howdy follower: the time is {0} and it's",
                "The time is {0} and it's",
                "The time sponsored by no one is {0} and it's",
                "All time is an illusion, even {0}, and it's",
                "Yep, it's {0} and the temperature is"
        };

    /**Generate 'uniquifier' for the putative tweet to help avoid triggering rejection as SPAM.
     * Short prefix string that also gives a human some context.
     * <p>
     * May contain a part of the message count to help monitor dropped messages
     * (eg due to Twitter rate limiting) and concentrator restarts.
     */
    @Override
    protected String getTweetPrefix()
        {
        final String time = new java.text.SimpleDateFormat("HH:mm").format(new java.util.Date());
        final String prefixRaw = DEFAULT_PREFIXES_en_GB[rnd.nextInt(DEFAULT_PREFIXES_en_GB.length)];
        final String prefix = prefixRaw.replace("{0}", time);
        return(prefix+" ");
        }

    /**Extracts the temperature rounded to the nearest C, else null if not present. */
    private Integer extractTemperature(final StatsMessageWithMetadata swmd)
        {
        switch(swmd.getStatsTypeAsChar())
            {
            case '@': // "Binary" message.
                {
                try
                    {
                    final ParsedRemoteBinaryStatsRecord b = new ParsedRemoteBinaryStatsRecord(swmd.message);
                    final Float c = b.getTemperature();
                    if(null != c) { return(c.intValue()); } // Truncate, don't round to nearest.
                    }
                catch(final Exception e) { break; } // Failed to extract temperature.
                break; // Failed to extract temperature.
                }
            case '{': // JSON message.
                {
                final Map<String, Object> statsMap = swmd.parseStatsAsMap();
                if(null == statsMap) { return(null); }
                final Integer tcel16 = StatsMessageWithMetadata.getStatMapItemAsInteger("T|Cel16", statsMap);
                if(null != tcel16) { return((tcel16) / 16); } // Truncate, don't round to nearest.
                final Integer tc16 = StatsMessageWithMetadata.getStatMapItemAsInteger("T|C16", statsMap);
                if(null != tc16) { return((tc16) / 16); } // Truncate, don't round to nearest.
                break; // Failed to extract temperature.
                }
            }
        return(null); // Cannot find/extract temperature.
        }

    /**Generate body of tweet, under 140 characters minus the prefix; never null. */
    @Override
    public String getTweetBody(final StatsMessageWithMetadata swmd)
        {
        final Integer temp = extractTemperature(swmd);
        if(null == temp) { return("?"); } // Unknown.
        return(temp.toString() + "\u00b0C");
        }

    /**Once this has been called it is assumed that the tweet has been sent. */
    @Override
    protected void sent(final StatsMessageWithMetadata swmd)
        {
        final Integer temp = extractTemperature(swmd);
        if(null == temp) { return; } // Unknown.
        lastCTweeted = temp.intValue();
        }

    /**Shared thread-safe OK PRNG. */
    private static final Random rnd = new Random();
    }
