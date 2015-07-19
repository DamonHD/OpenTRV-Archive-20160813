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

package uk.org.opentrv.util;

import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;

/**Check/generate FHT80V on-the-air protocol/encoding.
 * See https://sourceforge.net/p/opentrv/wiki/FS20%20Protocol%20Notes/
 */
public final class FHT80VProtocol
    {
    /**Invoke from command line. */
    public static void main(final String[] args)
        {
        System.out.println("main");
        System.out.println("close valve: " + showLogicalBitStreamGrouped(generateLogicalBitStreamForTRVBroadcastSetting(HC1Test, HC2Test, 0)));
        System.out.println("open valve: " + showLogicalBitStreamGrouped(generateLogicalBitStreamForTRVBroadcastSetting(HC1Test, HC2Test, 255)));
        System.out.println("test beep: " + showLogicalBitStreamGrouped(generateLogicalBitStream(HC1Test, HC2Test, (byte)0, (byte)0x2e, (byte)0)));

        System.out.println("close valve, on the wire variable bit width encoding: " + lengthAndByteDumpOfVariableBitWidthForm(
                logicalToVariableBitWidthEncode(generateLogicalBitStreamForTRVBroadcastSetting(HC1Test, HC2Test, 0))));
        System.out.println("open valve, on the wire variable bit width encoding: " + lengthAndByteDumpOfVariableBitWidthForm(
                logicalToVariableBitWidthEncode(generateLogicalBitStreamForTRVBroadcastSetting(HC1Test, HC2Test, 255))));
        System.out.println("test beep, on the wire variable bit width encoding: " + lengthAndByteDumpOfVariableBitWidthForm(
                logicalToVariableBitWidthEncode(generateLogicalBitStream(HC1Test, HC2Test, (byte)0, (byte)0x2e, (byte)0))));
        }


    /**Test house code 1 for TRV in range [0,99] inclusive. */
    public static final byte HC1Test = 13;
    /**Test house code 2 for TRV in range [0,99] inclusive. */
    public static final byte HC2Test = 73;

    /**Append bits most-significant first and with trailing even parity. */
    public static void appendBitsWithEvenParity(final List<Boolean> bits, final byte data)
    {
        boolean parity = false;
        for(int mask = 0x80; mask != 0; mask >>>= 1)
        {
            final boolean is1 = 0 != (data & mask);
            bits.add(is1 ? Boolean.TRUE : Boolean.FALSE);
            if(is1) { parity = !parity; }
        }
        bits.add(parity);
    }

    /**Generate logical bit stream (including header and trailer, etc) for entire FHT80V packet BEFORE 200uS pseudo-encoding; never null.
     * true => 1, false => 0.
     * <p>
     * This is NOT intended to be especially efficient,
     * simply to generate example bit streams for development and testing.
     *
     * @param raw  raw byte stream (usually 5 or 6 bytes excluding parity and trailing checksum); never null
     * @return  non-empty bit-stream containing header, parity, checksum and trailer; never null nor empty
     */
    public static List<Boolean> generatePacketLogicalBitStream(final byte raw[])
        {
        final List<Boolean> result = new ArrayList<Boolean>();

        // Header of 12x zero then 1x one bits.
        for(int i = 12; --i >= 0; ) { result.add(false); }
        result.add(true);

        // Append bytes.
        for(final byte b : raw) { appendBitsWithEvenParity(result, b); }

        // Compute checksum.
        byte checksum = 0xc;
        for(final byte b : raw) { checksum += b; }
        appendBitsWithEvenParity(result, checksum);

        // Trailing 'zero': really half a zero bit to get a trailing 400us burst.
        result.add(false);

        return(result);
        }

    /**Generate logical bit stream for FHT80V from house codes and extended command.
     * @param hc1 house code 1 in range [0,99] inclusive
     * @param hc2 house code 2 in range [0,99] inclusive
     * @param address  sub-address or 0 for broadcast
     * @param command  command code; must have 'extended' bit set
     * @param extension  command extension byte
     * @return logical bit stream for FHT80V; never null nor empty
     */
    public static List<Boolean> generateLogicalBitStream(final byte hc1, final byte hc2, final byte address, final byte command, final byte extension)
        {
        // Some limited argument validation...
        if((hc1 < 0) || (hc1 > 99)) { throw new IllegalArgumentException(); }
        if((hc2 < 0) || (hc2 > 99)) { throw new IllegalArgumentException(); }
        if(0 == (command & 0x20)) { throw new IllegalArgumentException("command must have extension bit set"); }
        return(generatePacketLogicalBitStream(new byte[]{hc1, hc2, address, command, extension}));
        }

    /**Generate logical bit stream for FHT80V from house codes to set TRV open a specified fraction (broadcast).
     * @param hc1 house code 1 in range [0,99] inclusive
     * @param hc2 house code 2 in range [0,99] inclusive
     * @param fractionOpen  in range [0,255] inclusive from 0 (fully closed) to 255 (fully open)
     * @return logical bit stream for FHT80V; never null nor empty
     */
    public static List<Boolean> generateLogicalBitStreamForTRVBroadcastSetting(final int hc1, final int hc2, final int fractionOpen)
        {
        if((fractionOpen < 0) || (fractionOpen > 255)) { throw new IllegalArgumentException(); }
        return(generateLogicalBitStream((byte)hc1, (byte)hc2, (byte)0, (byte)0x26, (byte)fractionOpen));
        }

    /**Show logical bit string grouped by unit; never null.
     * A typical 'open valve to full' packet might look like:
     * <pre>H0000000000001-000011011-010010011-000000000-001001101-111111110-100001110T1</pre>.
     *
     * @param bits  packet to display
     * @return  human-/machine- readable form; never null.
     */
    public static String showLogicalBitStreamGrouped(final List<Boolean> bits)
        {
        if(null == bits) { throw new IllegalArgumentException(); }
        if(5 != (bits.size() % 9)) { throw new IllegalArgumentException("unexpected size " + bits.size() + " % 9 = "+(bits.size() % 9)); }

        final StringBuilder sb = new StringBuilder(2 + bits.size());
        sb.append('H');

        // Do header up to first 1...
        int index;
        for(index = 0; !bits.get(index); ++index) { sb.append('0'); }
        sb.append('1'); ++index;

        // Do groups of 9 bits for each original byte plus parity...
        while((bits.size() - index) > 9)
            {
            sb.append('-');
            for(int i = 0; i < 9; ++i)
                { sb.append(bits.get(index++) ? '1' : '0'); }
            }

        // Trailer...
        sb.append('T');
        for( ; index < bits.size(); )
            { sb.append(bits.get(index++) ? '1' : '0'); }

        return(sb.toString());
        }

    /**Encode logical FHT80V packet stream into variable-count 200uS bits; never null.
     * Encodes 0 as 400 us on, 400 us off; encodes 1 as 600 us on, 600 us off.
     */
    public static List<Boolean> logicalToVariableBitWidthEncode(final List<Boolean> logical)
        {
        final List<Boolean> result = new ArrayList<Boolean>(5 * logical.size());
        for(final Boolean logicalBit : logical)
            {
            result.add(true); result.add(true);
            if(logicalBit)
                {
                result.add(true);
                result.add(false);
                }
            result.add(false); result.add(false);
            }
        return(result);
        }

    /**Show '200us' bitstream as bytes, ms bit first, with leading count, and padded to a whole byte with zeros at the end; never null.
     * May be directly suitable to use for (eg) PICAXE EEPROM initialiser for data to send to RFM22.
     */
    public static String lengthAndByteDumpOfVariableBitWidthForm(final List<Boolean> vbw)
        {
        final StringBuilder sb = new StringBuilder(vbw.size()); // Chars in output approx same as bits in input...
        final int bytesInInput = (vbw.size() + 7) / 8;
        sb.append("length ").append(String.valueOf(bytesInInput)).append("   ");

        final Iterator<Boolean> li = vbw.iterator();
        while(li.hasNext())
            {
            int value = 0;

            // Generate output a byte at a time.
            for(int mask = 0x80; mask != 0; mask >>>= 1)
                {
                if(!li.hasNext()) { break; }
                if(li.next()) { value |= mask; }
                }

            sb.append(", 0x").append(Integer.toHexString(value));
            }

        return(sb.toString());
        }
    }
