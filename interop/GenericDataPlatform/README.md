# Generic data platform interop

The aim of this section is to provide a proof of concept for interoperability
with a generic data platform. It comes in two parts:

1. A data platform proof of concept that would be deployed on a cloud server
   and that offers a REST API. Note the the implementation provided here is
   a proof of concept and is not designed to support large volumes of data.
2. An interop component that would be deployed on the OpenTRV concentrator
   and would send data to the data platform in a way that this platform can
   understand.

## Run the tests

You can run all unit tests by calling the following command in the same
directory as this file:

    PYTHONPATH=$PYTHONPATH:. python3 -m unittest discover
