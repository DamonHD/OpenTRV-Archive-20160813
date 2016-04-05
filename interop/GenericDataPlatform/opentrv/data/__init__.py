import re
import datetime

DEFAULT_SEPARATOR = '/'

class Record(object):
    """
    Sensor record with name, timestamp, value, optional unit and topic.
    """
    def __init__(self, name, ts, value, unit=None, topic=None):
        self.name = name
        self.timestamp = ts
        self.value = value
        self.unit = unit
        self.topic = topic

    def __str__(self):
        return "[{0}] {1}@{2} {3}{4}".format(
            "" if self.topic is None else str(self.topic),
            self.name,
            int((self.timestamp - datetime.datetime.utcfromtimestamp(0)).total_seconds()),
            self.value,
            "" if self.unit is None else " {0}".format(self.unit)
            )

class Topic(object):
    """
    Hierarchical topic.
    """
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

    def as_list(self):
        if self.parent is None:
            return [ self.name ]
        else:
            plist = self.parent.as_list()
            plist.append(self.name)
            return plist

    def relative_to(self, reference):
        """
        Return the part of the current topic that is relative to the reference.
        """
        slist = self.as_list()
        rlist = reference.as_list()
        i = 0
        for item in slist:
            if i >= len(rlist):
                break
            if item != rlist[i]:
                break
            i = i + 1
        return Topic(DEFAULT_SEPARATOR.join(slist[i:]))

    def __eq__(self, other):
        return (
            self.name == other.name and
            (other.parent is None) if self.parent is None else (
                other.parent is not None and other.parent == self.parent
                )
            )

    def __str__(self):
        return self.path()