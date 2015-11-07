#
# $Id$
#
# system::ubuntu::package Brik
#
package Metabrik::System::Ubuntu::Package;
use strict;
use warnings;

use base qw(Metabrik::Shell::Command);

sub brik_properties {
   return {
      revision => '$Revision$',
      tags => [ qw(unstable system package ubuntu) ],
      commands => {
         search => [ qw(string) ],
         install => [ qw(package) ],
         update => [ ],
         upgrade => [ ],
         list => [ ],
      },
      require_binaries => {
         'aptitude' => [ ],
         'apt-get' => [ ],
         'sudo' => [ ],
      },
   };
}

sub search {
   my $self = shift;
   my ($package) = @_;

   if (! defined($package)) {
      return $self->log->error($self->brik_help_run('search'));
   }

   my $cmd = "aptitude search $package";

   return $self->capture($cmd);
}

sub install {
   my $self = shift;
   my ($package) = @_;

   if (! defined($package)) {
      return $self->log->error($self->brik_help_run('install'));
   }

   my $cmd = "sudo apt-get install $package";

   return $self->system($cmd);
}

sub update {
   my $self = shift;

   my $cmd = "sudo apt-get update";

   return $self->system($cmd);
}

sub upgrade {
   my $self = shift;

   my $cmd = "sudo apt-get dist-upgrade";

   return $self->system($cmd);
}

sub list {
   my $self = shift;

   return $self->log->info("list: not available on this system");
}

1;

__END__

=head1 NAME

Metabrik::System::Ubuntu::Package - system::ubuntu::package Brik

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2014-2015, Patrice E<lt>GomoRE<gt> Auffret

You may distribute this module under the terms of The BSD 3-Clause License.
See LICENSE file in the source distribution archive.

=head1 AUTHOR

Patrice E<lt>GomoRE<gt> Auffret

=cut
