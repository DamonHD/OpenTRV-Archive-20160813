class Record(object):
    def __init__(self, name, ts, value, unit=None, topic=None):
        self.name = name
        self.timestamp = ts
        self.value = value
        self.unit = unit
        self.topic = topic

class Topic(object):
    def __init__(self, name, parent=None):
        self.name = name
        self.parent = parent

    def path(self, sep='/'):
        if self.parent is None:
            return self.name
        else:
            return sep.join([self.parent.path(), self.name])