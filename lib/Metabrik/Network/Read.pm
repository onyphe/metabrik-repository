#
# $Id$
#
# network::read Brik
#
package Metabrik::Network::Read;
use strict;
use warnings;

use base qw(Metabrik);

sub brik_properties {
   return {
      revision => '$Revision$',
      tags => [ qw(unstable network read ethernet ip raw socket) ],
      attributes => {
         device => [ qw(device) ],
         rtimeout => [ qw(seconds) ],
         family => [ qw(ipv4|ipv6) ],
         protocol => [ qw(tcp|udp) ],
         layer => [ qw(2|3|4) ],
         filter => [ qw(pcap_filter) ],
         max_read => [ qw(integer_packet_count) ],
         _dump => [ qw(INTERNAL) ],
      },
      attributes_default => {
         layer => 2,
         max_read => 0,
      },
      commands => {
         open => [ ],
         next => [ ],
         next_until_timeout => [ ],
         close => [ ],
         has_timeout => [ ],
         reset_timeout => [ ],
      },
      require_modules => {
         'Net::Frame::Dump' => [ ],
         'Net::Frame::Dump::Online2' => [ ],
      },
   };
}

sub brik_use_properties {
   my $self = shift;

   return {
      attributes_default => {
         rtimeout => $self->global->rtimeout,
         device => $self->global->device,
         family => $self->global->family,
         protocol => $self->global->protocol,
      },
   };
}

sub open {
   my $self = shift;

   my $family = $self->family eq 'ipv6' ? 'ip6' : 'ip';

   my $protocol = defined($self->protocol) ? $self->protocol : 'tcp';

   my $filter = $self->filter || '';

   my $dump;
   if ($self->layer == 2) {
      $self->debug && $self->log->debug("open: timeoutOnNext: ".$self->rtimeout);
      $self->debug && $self->log->debug("open: filter: ".$filter);
      $dump = Net::Frame::Dump::Online2->new(
         dev => $self->device,
         timeoutOnNext => $self->rtimeout,
         filter => $filter,
      );
   }
   elsif ($self->layer != 3) {
      return $self->log->error("open: not implemented");
   }

   $dump->start or return $self->log->error("open: error");

   return $self->_dump($dump);
}

sub next {
   my $self = shift;

   my $dump = $self->_dump;
   if (! defined($dump)) {
      return $self->log->error($self->brik_help_run('open'));
   }

   my $next = $dump->next;

   return defined($next) ? $next : 0;
}

sub next_until_timeout {
   my $self = shift;

   my $dump = $self->_dump;
   if (! defined($dump)) {
      return $self->log->error($self->brik_help_run('open'));
   }

   my $rtimeout = $self->rtimeout;
   my $max_read = $self->max_read;
   $self->log->verbose("next_until_timeout: will read until $rtimeout seconds timeout or $max_read max read packet(s) has been read");

   my $count = 0;
   my @next = ();
   while (! $dump->timeout) {
      if ($max_read && $count == $max_read) {
         last;
      }

      if (my $next = $dump->next) {
         push @next, $next;
         $self->debug && $self->log->debug("next_until_timeout: read one packet");
         $count++;
      }
   }

   return \@next;
}

sub has_timeout {
   my $self = shift;

   my $dump = $self->_dump;
   # We do not check for openness, simply returns 0 is ok to say we don't have a timeout now.
   if (! defined($dump)) {
      $self->debug && $self->log->debug("has_timeout: here: has_timeout [0]");
      return 0;
   }

   my $has_timeout = $dump->timeout;
   $self->debug && $self->log->debug("has_timeout: has_timeout [$has_timeout]");

   return $has_timeout;
}

sub reset_timeout {
   my $self = shift;

   my $dump = $self->_dump;
   # We do not check for openness, simply returns 1 is ok to say no need for timeout reset.
   if (! defined($dump)) {
      return 1;
   }

   return $dump->timeoutReset;
}

sub close {
   my $self = shift;

   my $dump = $self->_dump;
   if (! defined($dump)) {
      return 1;
   }

   $dump->stop;
   $self->_dump(undef);

   return 1;
}

1;

__END__

=head1 NAME

Metabrik::Network::Read - network::read Brik

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2014, Patrice E<lt>GomoRE<gt> Auffret

You may distribute this module under the terms of The BSD 3-Clause License.
See LICENSE file in the source distribution archive.

=head1 AUTHOR

Patrice E<lt>GomoRE<gt> Auffret

=cut
