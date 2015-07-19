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

package uk.org.opentrv.comms.util.crc;


/**Generic CRC calculation utilities.
 * Mirrors C/C++/etc implementations used elsewhere.
 * <p>
 * See http://users.ece.cmu.edu/~koopman/roses/dsn04/koopman04_crc_poly_embedded.pdf
 * Also: http://users.ece.cmu.edu/~koopman/crc/
 * Also: http://www.ross.net/crc/crcpaper.html
 * Also: http://en.wikipedia.org/wiki/Cyclic_redundancy_check
 */
public final class CRC
    {
    private CRC() { /* prevent instance creation */ }

    private static final int crc7_44_table[] =
        { 0, 0x12, 0x24, 0x36, 0x48, 0x5a, 0x6c, 0x7e, 0x90, 0x82, 0xb4, 0xa6, 0xd8, 0xca, 0xfc, 0xee };

    /**Update "CRC-7 inverse" 7-bit CRC with next byte; result always has bottom bit zero.
     * Polynomial 0x44 (1000100, Koopman) = (x^7 + x^3 + 1) = 0x09 (1001, Normal)
     * <p>
     * See: http://users.ece.cmu.edu/~koopman/roses/dsn04/koopman04_crc_poly_embedded.pdf
     * <p>
     * TODO: provide table-driven optimised alternative,
     *     eg see http://www.tty1.net/pycrc/index_en.html
     *     or see https://leventozturk.com/engineering/crc/
     */
    public static byte crc7_44_update(byte crc, final byte datum)
        {
        int tbl_idx;
        tbl_idx = (crc >> 4) ^ (datum >> 4);
        crc = (byte) (crc7_44_table[tbl_idx & 0xf] ^ (crc << 4));
        tbl_idx = (crc >> 4) ^ (datum >> 0);
        crc = (byte) (crc7_44_table[tbl_idx & 0xf] ^ (crc << 4));
        return((byte) (crc & 0xfe));

//        crc ^= datum;
//        for(int i = 0; ++i <= 8; )
//            {
//            if(0 != (crc & 0x80)) { crc = (byte) ((crc << 1) ^ 0x9); }
//            else { crc <<= 1; }
//            }
//        return((byte) (crc & 0xfe));
//        for(int i = 0; i < 8; ++i)
//            {
//            final boolean bit = (0 != (crc & 0x40));
//            crc = (byte) ((crc << 1) | ((datum >> (7 - i)) & 0x01));
//            if(bit) { crc ^= 0x09; }
//            }
//        return((byte) (crc & 0x7f));
        }

    /**Overloading to make use with int-typed arguments (eg literal constants) easier. */
    public static byte crc7_44_update(final int crc, final int datum)
        { return(crc7_44_update((byte)crc, (byte)datum)); }

    }
