import sys
import logging
import opentrv.platform.app

# Main entry into the system. This code is called when the platform
# module is run from the command line using the python -m option.
if __name__ == "__main__":
    logger = logging.getLogger(__name__)
    logger.info("Starting platform")
    app = opentrv.platform.app.app
    app.run(debug=True)
