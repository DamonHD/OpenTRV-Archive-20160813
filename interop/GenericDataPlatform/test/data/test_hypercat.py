import unittest
import json

from opentrv.data.hypercat import Catalogue, CatalogueItem, Serializer

class TestHypercatSerializer(unittest.TestCase):

    def test_to_json_object(self):
        self.maxDiff = None
        c = Catalogue(
            [
                CatalogueItem("http://a", "Item A"),
                CatalogueItem("http://b", "Item B", "text/csv"),
                CatalogueItem("http://c", "Item C", payload={"n": "c"}),
                CatalogueItem("http://d", "Item D", "text/csv", payload={"n": "d"})
            ],
            "Test Catalogue"
            )
        jo = Serializer().to_json_object(c)
        self.assertDictEqual({
                "catalogue-metadata": [
                    {
                    "rel": "urn:X-hypercat:rels:isContentType",
                    "val": "application/vnd.hypercat.catalogue+json"
                    },
                    {
                    "rel": "urn:X-hypercat:rels:hasDescription:en",
                    "val": "Test Catalogue"
                    }
                ],
                "items": [
                    {
                    "href": "http://a",
                    "item-metadata": [
                        {
                        "rel": "urn:X-hypercat:rels:isContentType",
                        "val": "application/vnd.hypercat.catalogue+json"
                        },
                        {
                        "rel": "urn:X-hypercat:rels:hasDescription:en",
                        "val": "Item A"
                        }
                    ]
                    },
                    {
                    "href": "http://b",
                    "item-metadata": [
                        {
                        "rel": "urn:X-hypercat:rels:isContentType",
                        "val": "text/csv"
                        },
                        {
                        "rel": "urn:X-hypercat:rels:hasDescription:en",
                        "val": "Item B"
                        }
                    ]
                    },
                    {
                    "href": "http://c",
                    "item-metadata": [
                        {
                        "rel": "urn:X-hypercat:rels:isContentType",
                        "val": "application/vnd.hypercat.catalogue+json"
                        },
                        {
                        "rel": "urn:X-hypercat:rels:hasDescription:en",
                        "val": "Item C"
                        },
                        {
                        "rel": "urn:X-hypercat:rels:n",
                        "val": "c"
                        }
                    ]
                    },
                    {
                    "href": "http://d",
                    "item-metadata": [
                        {
                        "rel": "urn:X-hypercat:rels:isContentType",
                        "val": "text/csv"
                        },
                        {
                        "rel": "urn:X-hypercat:rels:hasDescription:en",
                        "val": "Item D"
                        },
                        {
                        "rel": "urn:X-hypercat:rels:n",
                        "val": "d"
                        }
                    ]
                    }
                ]
            }, jo
            )
