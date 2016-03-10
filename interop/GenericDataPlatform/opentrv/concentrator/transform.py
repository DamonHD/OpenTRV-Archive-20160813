class MessageTransform:
    def __init__(self, sink):
        this.sink = sink

    def on_message(self, msg):
        # transform the message
        sink.on_message(msg)
        