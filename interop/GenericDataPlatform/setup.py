#!/usr/bin/env python3

from setuptools import setup

setup(
    name="Generic data platform interop",
    version="0.1",
    description="Interoperability tools and generic data platform reference implementation",
    author="Bruno Girin, OpenTRV",
    author_email="brunogirin@gmail.com",
    packages=[
        'opentrv',
        'opentrv.data', 'opentrv.data.storage', 'opentrv.data.model',
        'opentrv.concentrator',
        'opentrv.platform',
    ],
    long_description="""
    Generic data platform interop implements a MQTT to HTTP bridge for OpenTRV
    data as well as a reference data platform API that includes commissioning
    support to reduce the amount of configuration required to forward any
    OpenTRV data to upstream data platforms.
    """,
    classifiers=[
        "License :: OSI Approved :: Apache Software License",
        "Programming Language :: Python :: 3 :: Only",
        "Development Status :: 2 - Pre-Alpha",
        "Framework :: Flask",
        "Intended Audience :: Developers",
        "Natural Language :: English",
        "Operating System :: POSIX :: Linux"
    ],
    keywords='MQTT REST IoT',
    license="Apache",
    install_requires=[
        'setuptools',
        'mosquitto'
    ],
    )