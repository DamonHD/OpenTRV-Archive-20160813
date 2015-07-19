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

Author(s) / Copyright (s): Bruno Girin 2015
*/

package uk.org.opentrv.comms.cfg;

import java.util.List;
import java.util.ArrayList;
import java.io.PrintStream;
import java.io.PrintWriter;

/**
 * Configuration exception that wraps multiple causing
 * configuration exceptions, used primarily when creating a
 * handler list to make it possible to catch and report all
 * errors.
 */
public class ListConfigException extends ConfigException {

	private final List<ConfigException> causes;

	/**
	 * Create a config exception with a message.
	 */
	public ListConfigException(String message) {
		super(message);
		causes = new ArrayList<ConfigException>();
	}

	public void addCause(ConfigException cause) {
		causes.add(cause);
	}

	public List<ConfigException> getCauses() {
		return causes;
	}

	@Override
	public void printStackTrace(PrintStream s) {
		super.printStackTrace(s);
		if (causes.size() > 0) {
			s.println("Root causes:");
			boolean first = true;
			for (ConfigException e : causes) {
				e.printStackTrace(s);
				if(first) {
					first = false;
				} else {
					s.println("-----");
				}
			}
		}
		s.flush();
	}

	@Override
	public void printStackTrace(PrintWriter w) {
		super.printStackTrace(w);
		if (causes.size() > 0) {
			w.println("Root causes:");
			boolean first = true;
			for (ConfigException e : causes) {
				if(first) {
					first = false;
				} else {
					w.println("-----");
				}
				e.printStackTrace(w);
			}
		}
	}
}