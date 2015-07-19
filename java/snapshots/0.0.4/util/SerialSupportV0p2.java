package uk.org.opentrv.comms.util;

import gnu.io.CommPortIdentifier;
import gnu.io.PortInUseException;
import gnu.io.SerialPort;
import gnu.io.UnsupportedCommOperationException;

import java.io.File;
import java.io.IOException;
import java.util.Enumeration;

/**Support for interaction with ~V0p2 OpenTRV CLI/status over serial. */
public final class SerialSupportV0p2
    {
    private SerialSupportV0p2() { /* prevent creation of instances */ }

    /**Serial connection speed for V0p2 CLI. */
    public static final int CLI_V0p2_BAUD = 4800;

    /**Max stats line length that should ever need to be captured. */
    public static final int MAX_STATS_LINE_CHARS = 255;

    /**Character at start of (local) stats line. */
    public static final char LEAD_CHAR_STATS_LINE = '=';

//    /**Open and configure with jSSC the named serial device that connects to the V0.2 CLI; never null. */
//    public static jssc.SerialPort openCLIPortV0p2WithJSSC(final String portName)
//        throws SerialPortException, IOException
//        {
//        final jssc.SerialPort sp = new jssc.SerialPort(portName);
//        sp.openPort();
//        sp.setParams(CLI_V0p2_BAUD, 8, 1, 0 /* , true, true */ );
//        return(sp);
//        }

    /**Open and configure with RXTX the named serial device that connects to the V0.2 CLI; never null. */
    public static SerialPort openCLIPortV0p2WithRXTX(final String portName)
        throws PortInUseException, UnsupportedCommOperationException, IOException
        {
        // Canonicalise, eg to traverse symlinks...
        final String portCanonName = new File(portName).getCanonicalPath();
        if(!portCanonName.equals(portName))
            { System.out.println("Canonicalised port name to " + portCanonName + " from " + portName); }
        final Enumeration<?> portEnum = CommPortIdentifier.getPortIdentifiers();
        CommPortIdentifier portID = null;
        while(portEnum.hasMoreElements())
            {
            final CommPortIdentifier currPortID = (CommPortIdentifier) portEnum
                    .nextElement();
            System.out.println(currPortID.getName());
            if(currPortID.getName().equals(portName) || currPortID.getName().equals(portCanonName))
                {
                portID = currPortID;
                break;
                }
            }
        if(null == portID)
            { throw new IOException("port not found"); }

        // Open serial port, and use class name for the appName.
        final SerialPort serialPort = (SerialPort) portID.open(VeryBasicV0p2CLIFollower.class.getName(),
                2000); // Time-out in ms.

        // Set port parameters.
        serialPort.setSerialPortParams(CLI_V0p2_BAUD,
                SerialPort.DATABITS_8,
                SerialPort.STOPBITS_1,
                SerialPort.PARITY_NONE);

        return(serialPort);
        }

    }
