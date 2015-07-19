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

/**
 * Generic configuration exception class.
 */
public class ConfigException extends Exception {
	/**
	 * Create a config exception with a message.
	 */
	public ConfigException(String message) {
		super(message);
	}

	/**
	 * Create a config exception with a message and a cause.
	 */
	public ConfigException(String message, Throwable cause) {
		super(message, cause);
	}
}