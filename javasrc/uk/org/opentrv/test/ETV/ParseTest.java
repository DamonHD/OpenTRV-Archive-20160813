package uk.org.opentrv.test.ETV;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;
import static org.junit.Assert.fail;

import java.io.IOException;
import java.io.StringReader;

import org.junit.Test;

import uk.org.opentrv.ETV.parse.NBulkKWHParseByID;

public class ParseTest
    {
    /**Sample 1 of bulk energy readings; too small a sample to extract a whole day's readings from*/
    public static final String sampleN1 =
        "house_id,received_timestamp,device_timestamp,energy,temperature\n" +
        "1002,1456790560,1456790400,306.48,-3\n" +
        "1002,1456791348,1456791300,306.48,-3\n" +
        "1002,1456792442,1456792200,306.48,-3\n";

    /**Test bulk gas meter parse. */
    @Test public void testNBulkParse() throws IOException
        {
        // Rudimentary test of bad-arg checking.
        try { new NBulkKWHParseByID(-1, null); fail(); } catch(final IllegalArgumentException e) { /* OK */ }
        // Check that just a header, or no matching entries, returns empty rather than an exception.
        assertTrue(new NBulkKWHParseByID(0, new StringReader("house_id,received_timestamp,device_timestamp,energy,temperature")).getKWHByLocalDay().isEmpty());

        // Check correct number of rows read with wrong/right ID chosen.
        assertEquals(0, new NBulkKWHParseByID(0, new StringReader(sampleN1)).getKWHByLocalDay().size());
        assertEquals(0, new NBulkKWHParseByID(1002, new StringReader(sampleN1)).getKWHByLocalDay().size());
        }
    }
