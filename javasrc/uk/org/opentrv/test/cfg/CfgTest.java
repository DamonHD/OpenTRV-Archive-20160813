package uk.org.opentrv.test.cfg;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.fail;
import static uk.org.opentrv.comms.cfg.ConfigUtil.getAsString;

import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.Reader;
import java.io.StringReader;
import java.util.List;
import java.util.Map;

import org.junit.Test;

import uk.org.opentrv.comms.cfg.ConfigException;
import uk.org.opentrv.comms.cfg.ConfigUtil;
import uk.org.opentrv.comms.statshandlers.StatsHandler;
import uk.org.opentrv.comms.statshandlers.StatsHandlerFactory;

public class CfgTest
    {
    /**Check some basics. */
    @Test
    public void testBasicConfigParse() throws Exception
        {
        try { ConfigUtil.loadConfigFile(new StringReader("")); fail("wrongly allowed empty input"); }
        catch(final ConfigException e) { /* expected */ }
        final Map<?,?> m0 = ConfigUtil.loadConfigFile(new StringReader("{}"));
        assertNotNull(m0);
        assertEquals(0, m0.size());
        }

    /**Return a stream for the 'DHD' example config file; never null. */
    public static InputStream getDHDConfigStream()
        { return(CfgTest.class.getResourceAsStream("dhd.conf")); }
    /**Return a Reader for the large sample HDD data for EGLL; never null. */
    public static Reader getDHDConfigReader() throws IOException
        { return(new InputStreamReader(getDHDConfigStream(), "ASCII7")); }

    /**Check that 'DHD' configuration is parseable! */
    @Test
    public void testDHDConfigParse() throws Exception
        {
        final Map<?,?> m = ConfigUtil.loadConfigFile(getDHDConfigReader());
        assertNotNull(m);
        // Make sure that the parse is basically correct...
        assertEquals(2, m.size());
        final String portName = getAsString(m, "serialPort");
        assertNotNull("missing port name", portName);
        assertEquals("/dev/serial/by-id/usb-FTDI_TTL232R-3V3_FTGW5R3C-if00-port0", portName);
        final List<StatsHandler> handlers = StatsHandlerFactory.getInstance().newHandlerList(m);
        assertEquals(5, handlers.size());
        assertEquals(uk.org.opentrv.comms.statshandlers.builtin.SimpleFileLoggingStatsHandler.class, handlers.get(0).getClass());
        assertEquals(uk.org.opentrv.comms.statshandlers.builtin.twitter.SingleTwitterChannelTemperature.class, handlers.get(1).getClass());
        assertEquals(uk.org.opentrv.comms.statshandlers.builtin.twitter.SingleTwitterChannelTemperature.class, handlers.get(2).getClass());
        assertEquals(uk.org.opentrv.comms.statshandlers.filter.SimpleStaticFilterStatsHandlerWrapper.class, handlers.get(3).getClass());
        assertEquals(uk.org.opentrv.comms.statshandlers.builtin.openemon.OpenEnergyMonitorPostSimple.class, handlers.get(4).getClass());
        // TODO
        }

    }
