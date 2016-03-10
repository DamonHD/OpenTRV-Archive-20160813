import logging

class Core(object):
    def __init__(self):
        self.logger = logging.getLogger(__name__)
        self.logger.setLevel(logging.DEBUG)
        self.logger.debug("Initialising core")

    def run(self):
        logger.debug("Starting core")
