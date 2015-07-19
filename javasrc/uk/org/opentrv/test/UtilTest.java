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

Author(s) / Copyright (s): Damon Hart-Davis 2013
*/

package uk.org.opentrv.test;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertTrue;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;

import org.junit.Test;

import uk.org.opentrv.util.FHT80VProtocol;

public class UtilTest
    {
    /**Test of test system; should always succeed. */
    @Test public void testSanity() { assertTrue(true); }

    /**Test of serialisation of byte with parity. */
    @Test public void testAppendBitsWithEvenParity()
        {
        final List<Boolean> bits = new ArrayList<Boolean>();
        FHT80VProtocol.appendBitsWithEvenParity(bits, (byte) 0x00);
        assertEquals(9, bits.size());
        assertTrue(Arrays.equals(new Boolean[]{false,false,false,false,false,false,false,false,false}, bits.toArray(new Boolean[9])));

        bits.clear();
        uk.org.opentrv.util.FHT80VProtocol.appendBitsWithEvenParity(bits, (byte) 0x01);
        assertTrue(Arrays.equals(new Boolean[]{false,false,false,false,false,false,false,true,true}, bits.toArray(new Boolean[9])));

        bits.clear();
        uk.org.opentrv.util.FHT80VProtocol.appendBitsWithEvenParity(bits, (byte) 0x11);
        assertTrue(Arrays.equals(new Boolean[]{false,false,false,true,false,false,false,true,false}, bits.toArray(new Boolean[9])));
        }

    /**Test of logical serialisation of entire FHT80V command packet to TRV. */
    @Test public void testPacketConstruction()
        {
        // Set valve for all (13,73) housecode TRVs to fully open...
        assertEquals("H0000000000001-000011011-010010011-000000000-001001101-111111110-100001110T0",
            FHT80VProtocol.showLogicalBitStreamGrouped(FHT80VProtocol.generateLogicalBitStreamForTRVBroadcastSetting(13, 73, 255)));
        // Set valve for all (13,73) housecode TRVs to fully closed...
        assertEquals("H0000000000001-000011011-010010011-000000000-001001101-000000000-100010000T0",
            FHT80VProtocol.showLogicalBitStreamGrouped(FHT80VProtocol.generateLogicalBitStreamForTRVBroadcastSetting(13, 73, 0)));
        }

    /**Test of conversion of logical FHT80V bits to one-the-wire 200uS bit encoding.. */
    @Test public void testExpansionToVariableBitWidth()
        {
        final List<Boolean> e = FHT80VProtocol.logicalToVariableBitWidthEncode(Collections.<Boolean>emptyList());
        assertNotNull(e);
        assertEquals(0, e.size());

        final List<Boolean> one = FHT80VProtocol.logicalToVariableBitWidthEncode(Collections.singletonList(Boolean.TRUE));
        assertNotNull(one);
        assertEquals(6, one.size());
        assertTrue(Arrays.equals(new Boolean[]{true,true,true,false,false,false}, one.toArray(new Boolean[6])));

        final List<Boolean> zero = FHT80VProtocol.logicalToVariableBitWidthEncode(Collections.singletonList(Boolean.FALSE));
        assertNotNull(zero);
        assertEquals(4, zero.size());
        assertTrue(Arrays.equals(new Boolean[]{true,true,false,false}, zero.toArray(new Boolean[4])));
        }
    }
