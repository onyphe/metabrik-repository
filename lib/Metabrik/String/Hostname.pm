#
# $Id$
#
# string::hostname Brik
#
package Metabrik::String::Hostname;
use strict;
use warnings;

use base qw(Metabrik);

sub brik_properties {
   return {
      revision => '$Revision$',
      tags => [ qw(unstable hostname string) ],
      attributes => {
         hostname => [ qw(hostname) ],
      },
      commands => {
         parse => [ qw(hostname|OPTIONAL) ],
      },
   };
}

sub parse {
   my $self = shift;
   my ($hostname) = @_;

   $hostname ||= $self->hostname;
   if (! defined($hostname)) {
      return $self->log->error($self->brik_help_run('parse'));
   }

   my $tld = '';
   my $domain = '';
   my $host = '';
   my @subdomain_list = ();
   my @toks = split('\.', $hostname);
   if (@toks == 1) {
      $host = $toks[0];
   }
   elsif (@toks == 2) {
      $tld = $toks[1];
      $domain = $toks[0].'.'.$tld;
   }
   elsif (@toks == 3) {
      $tld = $toks[2];
      $domain = $toks[1].'.'.$tld;
      $host = $toks[0];
   }
   elsif (@toks > 3) {
      $tld = $toks[-1];
      $domain = $toks[-2].'.'.$tld;
      $host = $toks[0];
      my $count = @toks - 3;
      my $last = $domain;
      for my $t (reverse 1..$count) {
         $last = $toks[$t].'.'.$last;
         push @subdomain_list, $last;
      }
   }

   return {
      host => $host,
      domain => $domain,
      subdomain_list => \@subdomain_list,
      tld => $tld,
   };
}

1;

__END__

=head1 NAME

Metabrik::String::Hostname - string::hostname Brik

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2014-2015, Patrice E<lt>GomoRE<gt> Auffret

You may distribute this module under the terms of The BSD 3-Clause License.
See LICENSE file in the source distribution archive.

=head1 AUTHOR

Patrice E<lt>GomoRE<gt> Auffret

=cut