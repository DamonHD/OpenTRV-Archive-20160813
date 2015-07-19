package uk.org.opentrv.test.json;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;
import static org.junit.Assert.fail;

import java.io.BufferedReader;
import java.io.Reader;
import java.io.StringReader;
import java.util.List;
import java.util.Map;
import java.util.Random;

import org.json.simple.JSONObject;
import org.json.simple.parser.JSONParser;
import org.json.simple.parser.ParseException;
import org.junit.Test;

import uk.org.opentrv.comms.json.JSONStatsLineStreamReader;
import uk.org.opentrv.comms.statshandlers.builtin.SimpleFileLoggingStatsHandler;

public class BasicJSONTest
    {
    /**Example from https://code.google.com/p/json-simple/wiki/EncodingExamples to test basic behaviour. */
    @Test public void testEncExample()
        {
        final JSONObject obj = new JSONObject();
        obj.put("name", "foo");
        obj.put("num", new Integer(100));
        obj.put("balance", new Double(1000.21));
        obj.put("is_vip", new Boolean(true));
        obj.put("nickname", null);
        final String result = String.valueOf(obj);
//        System.out.print(obj);
        assertEquals("{\"balance\":1000.21,\"is_vip\":true,\"num\":100,\"name\":\"foo\",\"nickname\":null}", result);
        }

    /**Decoding plausible input. */
    @Test public void testDecExample() throws Exception
        {
        final String in = "{\"id\":\"c2e0\",\"t|C16\":332,\"RH|%\":65,\"l\":254,\"o\":2,\"b|cV\":323}";
        final JSONParser parser = new JSONParser();
        final Map json = (Map)parser.parse(in);
        assertNull(json.get("bogus"));
        assertEquals("c2e0", json.get("id"));
        assertEquals(323, ((Number)json.get("b|cV")).intValue());
        assertNotNull(json.get("l"));
        assertEquals(254, ((Number)json.get("l")).intValue());
        }

    /**Decoding broken input. */
    @Test public void testBrokenExample()
        {
        // DHD20141123: one common-ish failure mode seen over RF is truncation of the frame.
        final String truncated = "{\"id\":\"c2e0\",\"t|C16\":332,\"RH|%\":65,\"l\":254,\"o";
        final JSONParser parser = new JSONParser();
        try { parser.parse(truncated); fail("should have been rejected"); } catch(final ParseException e) { /* expected */ }
        try { parser.parse("}"); fail("should have been rejected"); } catch(final ParseException e) { /* expected */ }
        try { parser.parse(""); fail("should have been rejected"); } catch(final ParseException e) { /* expected */ }
        try { parser.parse("@abc"); fail("should have been rejected"); } catch(final ParseException e) { /* expected */ }
        }

    /**Test of conversion of raw leaf-node JSON to JSON-array log line. */
    @Test public void testJSONLoggingSimple() throws Exception
        {
        for(final String concID : new String[]{"", Long.toString((rnd.nextLong()>>>1),36)} )
            {
            final String line = SimpleFileLoggingStatsHandler.wrapLeafJSONAsArrayLogLine(1416763674255L, concID, "{}");
            assertEquals("[ \"2014-11-23T17:27:54Z\", \""+concID+"\", {} ]", line);
            final JSONParser parser = new JSONParser();
            final Object lO = parser.parse(line);
            assertTrue(lO instanceof List);
            final List l = (List)lO;
            assertEquals("2014-11-23T17:27:54Z", l.get(0));
            assertEquals(concID, l.get(1));
            assertTrue(l.get(2) instanceof Map);
            }
        }

    /**Sample of [ timestamp, concetratorID, lightweightNodeJSON ] format, line oriented. */
    public static final String StreamedJSONSample1 =
        "[ \"2014-12-19T14:58:20Z\", \"\", {\"@\":\"2d1a\",\"+\":7,\"v|%\":0,\"tT|C\":7,\"O\":1,\"vac|h\":6} ]\n" +
        "[ \"2014-12-19T14:58:28Z\", \"\", {\"@\":\"3015\",\"+\":2,\"T|C16\":290,\"L\":255,\"B|mV\":2567} ]\n" +
        "[ \"2014-12-19T14:59:50Z\", \"\", {\"@\":\"0a45\",\"+\":5,\"B|mV\":3315,\"v|%\":0,\"tT|C\":7,\"O\":1} ]\n" +
        "[ \"2014-12-19T15:00:06Z\", \"\", {\"@\":\"414a\",\"+\":3,\"B|mV\":3315,\"v|%\":0,\"tT|C\":7,\"O\":1} ]\n" +
        "[ \"2014-12-19T15:00:20Z\", \"\", {\"@\":\"2d1a\",\"+\":0,\"L\":120,\"T|C16\":305,\"B|mV\":3315} ]\n" +
        "[ \"2014-12-19T15:00:28Z\", \"\", {\"@\":\"3015\",\"+\":3,\"v|%\":0,\"tT|C\":12,\"O\":1,\"vac|h\":6} ]\n" +
        "[ \"2014-12-19T15:01:28Z\", \"\", {\"@\":\"3015\",\"+\":4,\"B|mV\":2550,\"T|C16\":290,\"H|%\":80} ]\n" +
        "[ \"2014-12-19T15:01:50Z\", \"\", {\"@\":\"0a45\",\"+\":7,\"L\":206,\"B|mV\":3315,\"v|%\":0,\"tT|C\":7} ]\n" +
        "[ \"2014-12-19T15:02:06Z\", \"\", {\"@\":\"414a\",\"+\":4,\"L\":142,\"vac|h\":6,\"T|C16\":278} ]\n" +
        "[ \"2014-12-19T15:02:10Z\", \"\", {\"@\":\"0d49\",\"+\":4,\"L\":239,\"vac|h\":7,\"T|C16\":290} ]\n";

    /**Test extraction to space-separated text 3-column output of single stat by node ID and stat name. */
    @Test public void extractStreamingStatTest() throws Exception
        {
        // Test filter just by field.
        try(final BufferedReader br = new BufferedReader(new JSONStatsLineStreamReader(new StringReader(StreamedJSONSample1), "v|%")))
            {
            assertEquals("2014-12-19T14:58:20Z 2d1a 0", br.readLine());
            assertEquals("2014-12-19T14:59:50Z 0a45 0", br.readLine());
            assertEquals("2014-12-19T15:00:06Z 414a 0", br.readLine());
            assertEquals("2014-12-19T15:00:28Z 3015 0", br.readLine());
            assertEquals("2014-12-19T15:01:50Z 0a45 0", br.readLine());
            assertNull(br.readLine());
            }

        // Test filter by field and ID.
        try(final BufferedReader br = new BufferedReader(new JSONStatsLineStreamReader(new StringReader(StreamedJSONSample1), "v|%", "414a")))
            {
            assertEquals("2014-12-19T15:00:06Z 414a 0", br.readLine());
            assertNull(br.readLine());
            }

        // Test of single-char reads.
        try(final Reader r = new JSONStatsLineStreamReader(new StringReader(StreamedJSONSample1), "v|%"))
            {
            assertEquals('2', r.read());
            assertEquals('0', r.read());
            assertEquals('1', r.read());
            assertEquals('4', r.read());
            }
        }

    /**OK local PRNG. */
    private static final Random rnd = new Random();
    }
