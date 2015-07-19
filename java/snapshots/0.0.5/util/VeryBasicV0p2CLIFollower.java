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

package uk.org.opentrv.comms.util;

import gnu.io.SerialPort;

import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.InputStream;

/**Follows and prints CLI output given the device filename for serial connection to CLI as args[0].
 * args[0] might be something like /dev/tty.usbserial-FTGACM4G
 * <p>
 * See http://playground.arduino.cc/Interfacing/Java for some RXTX info.
 * Expect to muck around with classpath and native lib path and /var/lock.
 * <p>
 * Not very efficient as works by polling rather than using events.
 */
public final class VeryBasicV0p2CLIFollower
    {
    /**Start copying output from OpenTRV unit to System.out.
     * @param args
     * @throws IOException
     * @throws FileNotFoundException
     * @throws InterruptedException
     */
    public static void main(final String[] args) throws Exception
        {
        final String portName = args[0];
        final SerialPort serialPort = SerialSupportV0p2.openCLIPortV0p2WithRXTX(portName);

        try(final InputStream is = serialPort.getInputStream())
            {
            for( ; ; )
                {
                if(is.available() < 1) { Thread.sleep(1000); continue; }
                System.out.print((char) is.read());
                }
            }
//            output = serialPort.getOutputStream();

//            // add event listeners
//            serialPort.addEventListener(this);
//            serialPort.notifyOnDataAvailable(true);

        }
    }
