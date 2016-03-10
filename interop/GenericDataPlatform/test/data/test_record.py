import unittest

import opentrv.data

class TestRecord(unittest.TestCase):
    def test_init(self):
        pass

class TestTopic(unittest.TestCase):
    def test_init(self):
        t = opentrv.data.Topic("mytopic")
        self.assertEqual("mytopic", t.name)

    def test_path_single(self):
        t = opentrv.data.Topic("mytopic")
        self.assertEqual("mytopic", t.path())

    def test_path_multiple(self):
        t1 = opentrv.data.Topic("one")
        t2 = opentrv.data.Topic("two", t1)
        self.assertEqual("one/two", t2.path())

    def test_path_multiple_sep(self):
        t1 = opentrv.data.Topic("one")
        t2 = opentrv.data.Topic("two", t1)
        self.assertEqual("one.two", t2.path('.'))

if __name__ == '__main__':
    unittest.main()