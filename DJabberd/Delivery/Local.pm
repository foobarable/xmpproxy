package DJabberd::Delivery::Local;
use strict;
use warnings;
use base 'DJabberd::Delivery';

#Dummy local delivery plugin. Djabberd wants to have at least one object of this type but we don't need local delivery so
#we register this plugin which does nothing.

sub deliver {
}

1;
