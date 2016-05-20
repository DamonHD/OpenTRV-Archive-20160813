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

Author(s) / Copyright (s): Damon Hart-Davis 2016
*/

/**Support for processing data for the EU Environmental Technology Verification programme data.
 * This support includes accepting data in its usual forms for
 * evaluating per-household energy efficiency changes with OpenTRV devices:
 * <ul>
 * <li>Daily (local midnight-to-midnight, or close) HDD (Heating Degree Day) data.</li>
 * <li>Daily (local midnight-to-midnight, or close) kWh space-heating fuel-use date or equivalent.</li>
 * <li>Optional OpenTRV stats data,
 *     in particular indicating when occupancy-based energy-saving features are enabled or not.</li>
 * <li>Explicitly active / non-active / mixed or don't-user flags by day for the household.</li>
 * </ul>
 * <p>
 * The data is then processed to look for changes in kWh/HDD,
 * and establish some per-household confidence,
 * and write the output in a form suitable for further aggregate processing,
 * eg for trial-wide statistical confidence analysis.
 */
package uk.org.opentrv.ETV;