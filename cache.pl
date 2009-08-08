#!/usr/bin/perl

use strict;
use warnings;
use utf8;
use Module::Find;
use Module::Load;

map { load $_; $_->import(); $_->cache();} findallmod plugins;

__END__

=head1 AUTHOR

Fd <fd@freefd.info> L<http://freefd.info/>

=head1 COPYRIGHT

Copyright (c) <2009> <Fd>

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut
