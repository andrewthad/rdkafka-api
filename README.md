# rdkafka-api

This library used to dynamically linked against rdkafka, but rdkafka is not
widely available from various system package managers. So now, what is done
instead is that the source for rdkafka has been copied into this library
with a number of settings hardcoded. Here are the settings:

* Configure flag --disable-sasl
* Configure flag --disable-curl
* Configure flag --disable-zstd
* Configure flag --disable-syslog
* Configure flag --disable-ssl
* Configure flag --disable-gssapi
* Configure flag --enable-c11threads
* All sasl files have been removed, and references to functions in them
  have been deleted.
* This library dynamically links against lz4
* All source files have been renamed with an `hs_` prefix
* All unit tests have been removed from lbrdkafka source code
* The macro `HAVE_STRLCPY` is set to 0 because sometimes it's not available
  on systems that I build on.

The version of rdkafka is 1.9.2, the last stable release in the 1.x series.
