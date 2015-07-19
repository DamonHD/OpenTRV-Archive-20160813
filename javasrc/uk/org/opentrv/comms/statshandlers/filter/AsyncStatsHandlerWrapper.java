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

Author(s) / Copyright (s): Damon Hart-Davis 2015
*/
package uk.org.opentrv.comms.statshandlers.filter;

import static uk.org.opentrv.comms.cfg.ConfigUtil.getAsNumber;
import static uk.org.opentrv.comms.cfg.ConfigUtil.getAsMap;

import java.io.IOException;
import java.util.Map;
import java.util.concurrent.ArrayBlockingQueue;
import java.util.concurrent.RejectedExecutionException;
import java.util.concurrent.ThreadPoolExecutor;
import java.util.concurrent.TimeUnit;

import uk.org.opentrv.comms.statshandlers.StatsHandler;
import uk.org.opentrv.comms.statshandlers.StatsMessageWithMetadata;
import uk.org.opentrv.comms.statshandlers.StatsHandlerFactory;
import uk.org.opentrv.comms.cfg.ConfigException;


/**This wraps a StatsHandler to make it queued, threaded and asynchronous.
 * Events are delivered to the wrapped handler's process...() methods
 * in the order that the process...() methods of this wrapper instance are called,
 * including any interleaving of the process...() methods.
 * <p>
 * Delivery is by a dedicated thread (for each instance of this class)
 * so that different handlers cannot block one another.
 * <p>
 * The process...() calls complete quickly,
 * simply queueing the requested item.
 * <p>
 * The queue is bounded (and non-blocking) and an IOException is thrown
 * if the queue overflows, ie a process...() method cannot queue the request.
 * <p>
 * Calling close() frees up resources such as the queue and thread.
 */
public final class AsyncStatsHandlerWrapper implements StatsHandler, AutoCloseable
    {
    /**Default queue size (shared between all process...() stats; strictly positive.
     * Puts bounds on resource usage,
     * but not so large as to mask persistent problems with event delivery downstream.
     */
    public static final int DEFAULT_QUEUE_SIZE = 16;

    /**Default close()/shutdown time in milliseconds for unfinished tasks; strictly positive. */
    public static final int DEFAULT_CLOSE_TIMEOUT_MS = 10_000;

    /**Single-threaded pool; not null. */
    private final ThreadPoolExecutor _singleThreadPool;

    /**Wrapped handler; not null. */
    private final StatsHandler sh;

    /**Close timeout in milliseconds; strictly positive. */
    private final int closeTimeoutMS;

    public AsyncStatsHandlerWrapper(final Map config) throws ConfigException
        {
        this(
            StatsHandlerFactory.getInstance().newHandler(getAsMap(config, "handler")),
            getAsNumber(config, "maxQueueSize", DEFAULT_QUEUE_SIZE).intValue(),
            getAsNumber(config, "closeTimeoutMS", DEFAULT_CLOSE_TIMEOUT_MS).intValue()
            );
        }

    public AsyncStatsHandlerWrapper(final StatsHandler sh) { this(sh, DEFAULT_QUEUE_SIZE, DEFAULT_CLOSE_TIMEOUT_MS); }

    public AsyncStatsHandlerWrapper(final StatsHandler sh, final int maxQueueSize, final int closeTimeoutMS)
        {
        if(null == sh) { throw new IllegalArgumentException(); }
        if(maxQueueSize < 1) { throw new IllegalArgumentException(); }
        if(closeTimeoutMS < 1) { throw new IllegalArgumentException(); }
        this.sh = sh;
        this.closeTimeoutMS = closeTimeoutMS;
        _singleThreadPool = new ThreadPoolExecutor(1, 1,
                601, TimeUnit.SECONDS, // Allow threads to die if idle for quite a while.
                new ArrayBlockingQueue<Runnable>(maxQueueSize),
                new ThreadPoolExecutor.AbortPolicy());
        _singleThreadPool.allowCoreThreadTimeOut(true);
        }

    @Override
    public void processStatsMessage(final StatsMessageWithMetadata swmd) throws IOException
        {
        try {
            _singleThreadPool.execute(new Runnable()
                {
                @Override public void run()
                    {
                    try { sh.processStatsMessage(swmd); } catch(final Exception e) { e.printStackTrace(); }
                    }
                });
            }
        catch(final RejectedExecutionException e) { throw new IOException(e); }
        }

    /**Releases resources, letting current queued work complete if it can do so quickly. */
    @Override
    public void close() throws Exception
        {
        // Shut down thread, letting current tasks complete.
        _singleThreadPool.shutdown();
        _singleThreadPool.awaitTermination(closeTimeoutMS, TimeUnit.MILLISECONDS);
        _singleThreadPool.shutdownNow();
        }
    }
