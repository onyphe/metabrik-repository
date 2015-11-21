#
# $Id$
#
# string::yara Brik
#
package Metabrik::String::Yara;
use strict;
use warnings;

use base qw(Metabrik);

sub brik_properties {
   return {
      revision => '$Revision$',
      tags => [ qw(unstable encode decode yara) ],
      commands => {
         encode => [ qw($data_hash) ],
         decode => [ qw($data_string) ],
      },
      require_modules => {
         'Parse::YARA' => [ ],
      },
   };
}

# Takes a hash and return a YARA string
sub encode {
   my $self = shift;
   my ($data) = @_;

   if (! defined($data)) {
      return $self->log->error($self->brik_help_run('encode'));
   }

   if (ref($data) ne 'HASH') {
      return $self->log->error("encode: data must be a HASHREF");
   }

   my $encoded = '';
   eval {
      $encoded = Parse::YARA->new(rulehash => $data, disable_includes => 0, verbose => 0);
   };
   if ($@) {
      chomp($@);
      return $self->log->error("encode: unable to encode YARA: $@");
   }

   return $encoded->as_string;
}

# Takes a YARA string and return a hash
sub decode {
   my $self = shift;
   my ($data) = @_;

   if (! defined($data)) {
      return $self->log->error($self->brik_help_run('decode'));
   }

   my $decoded = '';
   eval {
      $decoded = Parse::YARA->new(rule => $data, disable_includes => 0, verbose => 0);
   };
   if ($@) {
      chomp($@);
      return $self->log->error("decode: unable to decode YARA: $@");
   }

   return $decoded->{rules};
}

1;

__END__

=head1 NAME

Metabrik::String::Yara - string::yara Brik

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2014-2015, Patrice E<lt>GomoRE<gt> Auffret

You may distribute this module under the terms of The BSD 3-Clause License.
See LICENSE file in the source distribution archive.

=head1 AUTHOR

Patrice E<lt>GomoRE<gt> Auffret

=cut
