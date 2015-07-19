Installation instructions

To install on a Raspberry Pi, you will need to install the following
packages first:

$ sudo apt-get install librxtx-java
$ sudo apt-get install libjson-simple-java

The latest raspbian release (2015-02-06) comes with Oracle JDK 8 by default,
which should work. If you prefer 7, you can install that instead:

$ sudo apt-get install oracle-java7-jdk

Add the latest soft link in /usr/lib/jvm
$ cd /usr/lib/jvm
$ ln -s ./jdk-8-oracle-arm-vfp-hflt latest

