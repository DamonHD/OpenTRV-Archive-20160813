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

Author(s) / Copyright (s): Damon Hart-Davis 2014
*/

package uk.org.opentrv.test;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.fail;

import org.junit.Test;

import uk.org.opentrv.comms.util.CommonSensorLabels;
import uk.org.opentrv.comms.util.ParsedRemoteBinaryStatsRecord;

public class V0p2CLIInteractionTest
    {
    /**Basic tests. */
    @Test public void testParsedERemoteStatsRecordBasics()
        {
        try { new ParsedRemoteBinaryStatsRecord(null); fail("must reject null"); }
        catch(final IllegalArgumentException e) { /* expected */ }
        try { new ParsedRemoteBinaryStatsRecord(""); fail("must reject empty string"); }
        catch(final IllegalArgumentException e) { /* expected */ }

        // Should accept and parse good minimal-stats line/record.
        final ParsedRemoteBinaryStatsRecord pr1 = new ParsedRemoteBinaryStatsRecord("@A45;T21CC");
        assertEquals("A45", pr1.sectionsByKey.get(CommonSensorLabels.ID.getLabel()));
        assertEquals("A45", pr1.ID);
        assertEquals("21CC", pr1.sectionsByKey.get(CommonSensorLabels.TEMPERATURE.getLabel()));
        assertNotNull(pr1.getTemperature());
        assertEquals(21.75f, pr1.getTemperature().floatValue(), 0.0001f);
        }

    /**Tests on a more complex record. */
    @Test public void testParsedRemoteStatsRecordExtended()
        {
        final ParsedRemoteBinaryStatsRecord pr1 = new ParsedRemoteBinaryStatsRecord("@A45;T21CC;L35;O1");
        assertEquals("A45", pr1.sectionsByKey.get(CommonSensorLabels.ID.getLabel()));
        assertEquals("A45", pr1.ID);
        assertEquals("21CC", pr1.sectionsByKey.get(CommonSensorLabels.TEMPERATURE.getLabel()));
        assertNotNull(pr1.getTemperature());
        assertEquals(21.75f, pr1.getTemperature().floatValue(), 0.0001f);
        assertEquals("35", pr1.sectionsByKey.get('L'));
        assertEquals("1", pr1.sectionsByKey.get('O'));
        }
    }
