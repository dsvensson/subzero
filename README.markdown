SubZero
=======

A minimalistic cross-platform GObject based zeroconf library.

Motivation
----------
I used to use the zeroconf-parts from libdmapsharing, but it turned out they were
racy on Mac OS X due to how the DNS-SD APIs were used / worked. Another downside
was having the same wrapper implementation duplicated for DNS-SD and Avahi which
could require duplicate work when fixing bugs or adding features.

So started to toy with the idea of writing a browsing implementation, instead of a
wrapper, in a lot less lines of code, with a simple API and so SubZero was born.

The name SubZero is to denote that it's a subpar zeroconf implementation, good enough to
discover the services I need on the network and possibly others.

Goals
-----
No bugs, and never ever support for registering services or taking the role of a proxy.

Install
-------

    ./waf configure --prefix=/usr/local
    ./waf build
    ./waf install