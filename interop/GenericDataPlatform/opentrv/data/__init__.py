import re
import datetime

DEFAULT_SEPARATOR = '/'

class Record(object):
    def __init__(self, name, ts, value, unit=None, topic=None):
        self.name = name
        self.timestamp = ts
        self.value = value
        self.unit = unit
        self.topic = topic

    def __str__(self):
        return "[{0}] {1}@{2} {3}{4}".format(
            "" if self.topic is None else self.topic,
            self.name,
            int((self.timestamp - datetime.datetime.utcfromtimestamp(0)).total_seconds()),
            self.value,
            "" if self.unit is None else " {0}".format(self.unit)
            )

class Topic(object):
    def __init__(self, name, parent=None, sep=DEFAULT_SEPARATOR):
        while name[0] == sep:
            name = name[1:]
        while name[-1] == sep:
            name = name[:-1]
        c = name.rfind(sep)
        if c >= 0:
            self.name = name[c+1:]
            self.parent = Topic(name[:c], parent, sep)
        else:
            self.name = name
            self.parent = parent

    def path(self, sep=DEFAULT_SEPARATOR):
        if self.parent is None:
            return self.name
        else:
            return sep.join([self.parent.path(), self.name])

    def __eq__(self, other):
        return (
            self.name == other.name and
            (other.parent is None) if self.parent is None else (
                other.parent is not None and other.parent == self.parent
                )
            )

    def __str__(self):
        return self.path()