#
# $Id$
#
# address::generate Brik
#
package Metabrik::Address::Generate;
use strict;
use warnings;

use base qw(Metabrik);

sub brik_properties {
   return {
      revision => '$Revision$',
      tags => [ qw(unstable ipv4 ipv6 public routable reserved) ],
      author => 'GomoR <GomoR[at]metabrik.org>',
      license => 'http://opensource.org/licenses/BSD-3-Clause',
      attributes => {
         datadir => [ qw(directory) ],
         file_count => [ qw(integer) ],
         count => [ qw(integer) ],
      },
      attributes_default => {
         file_count => 1000,
         count => 0,
      },
      commands => {
         ipv4_reserved_ranges => [ ],
         ipv4_private_ranges => [ ],
         ipv4_public_ranges => [ ],
         ipv4_generate_space => [ qw(count|OPTIONAL file_count|OPTIONAL) ],
         random_ipv4_addresses => [ qw(count|OPTIONAL) ],
      },
      require_modules => {
         'List::Util' => [ qw(shuffle) ],
      },
      #require_binaries => {
         #'ulimit' => [ ],   # It is built-in
      #},
   };
}

sub brik_init {
   my $self = shift;

   # Increase the max open files limit under Linux
   if ($^O eq 'Linux') {
      `ulimit -n 2048`;
   }

   return $self->SUPER::brik_init(@_);
}

sub ipv4_reserved_ranges {
   my $self = shift;

   # http://www.h-online.com/security/services/Reserved-IPv4-addresses-732899.html
   my @reserved = qw(
      0.0.0.0/8
      10.0.0.0/8
      127.0.0.0/8
      169.254.0.0/16
      172.16.0.0/12
      192.0.2.0/24
      192.168.0.0/16
      224.0.0.0/4
      240.0.0.0/4
   );

   return \@reserved;
}

sub ipv4_private_ranges {
   my $self = shift;

   my @private = qw(
      10.0.0.0/8
      127.0.0.0/8
      169.254.0.0/16
      172.16.0.0/12
      192.0.2.0/24
      192.168.0.0/16
   );

   return \@private;
}

sub ipv4_public_ranges {
   my $self = shift;

   my $reserved = $self->ipv4_reserved_ranges;

   return 1;
}

sub ipv4_generate_space {
   my $self = shift;
   my ($count, $file_count) = @_;

   $count ||= $self->count;
   $file_count ||= $self->file_count;
   if ($count <= 0) {
      return $self->log->error("ipv4_generate_space: cannot generate [$count] address");
   }
   if ($file_count <= 0) {
      return $self->log->error("ipv4_generate_space: cannot generate [$file_count] file");
   }

   my $datadir = $self->datadir;
   my $n = $file_count - 1;

   my @chunks = ();
   if ($n > 0) {
      for (0..$n) {
         my $file = sprintf("ip4-space-%03d.txt", $_);
         open(my $fd, '>', "$datadir/$file")
            or return $self->log->error("ipv4_generate_space: open: file [$datadir/$file]: $!");
         push @chunks, $fd;
      }
   }
   else {
      my $file = "ip4-space.txt";
      open(my $fd, '>', "$datadir/$file")
         or return $self->log->error("ipv4_generate_space: open: file [$datadir/$file]: $!");
      push @chunks, $fd;
   }

   my $current = 0;
   # Note: this algorithm is best suited to generate the full IPv4 address space
   for my $b1 (List::Util::shuffle(1..9,11..126,128..223)) {  # Skip 0.0.0.0/8, 224.0.0.0/4,
                                                              # 240.0.0.0/4, 10.0.0.0/8,
                                                              # 127.0.0.0/8
      for my $b2 (List::Util::shuffle(0..255)) {
         next if ($b1 == 169 && $b2 == 254);               # Skip 169.254.0.0/16
         next if ($b1 == 172 && ($b2 >= 16 && $b2 <= 31)); # Skip 172.16.0.0/12
         next if ($b1 == 192 && $b2 == 168);               # Skip 192.168.0.0/16
         for my $b3 (List::Util::shuffle(0..255)) {
            next if ($b1 == 192 && $b2 == 0 && $b3 == 2);  # Skip 192.0.2.0/24
            for my $b4 (List::Util::shuffle(0..255)) {
               # Write randomly to one of the previously open files
               my $i;
               ($n > 0) ? ($i = int(rand($n + 1))) : ($i = 0);

               my $out = $chunks[$i];
               print $out "$b1.$b2.$b3.$b4\n";
               $current++;

               # Stop if we have the number we wanted
               if ($count && $current == $count) {
                  $self->log->info("ipv4_generate_space: generated $current IP addresses");
                  return 1;
               }
            }
         }
      }
   }

   $self->log->info("ipv4_generate_space: generated $current IP addresses");

   return 1;
}

sub random_ipv4_addresses {
   my $self = shift;
   my ($count) = @_;

   $count ||= $self->count;
   if ($count <= 0) {
      return $self->log->error("random_ipv4_addresses: cannot generate [$count] address");
   }

   my $current = 0;
   my %random = ();
   while (1) {
      my $b1 = List::Util::shuffle(1..9,11..126,128..223); # Skip 0.0.0.0/8, 224.0.0.0/4,
                                                           # 240.0.0.0/4, 10.0.0.0/8,
                                                           # 127.0.0.0/8
      my $b2 = List::Util::shuffle(0..255);
      next if ($b1 == 169 && $b2 == 254);               # Skip 169.254.0.0/16
      next if ($b1 == 172 && ($b2 >= 16 && $b2 <= 31)); # Skip 172.16.0.0/12
      next if ($b1 == 192 && $b2 == 168);               # Skip 192.168.0.0/16

      my $b3 = List::Util::shuffle(0..255);
      next if ($b1 == 192 && $b2 == 0 && $b3 == 2);  # Skip 192.0.2.0/24

      my $b4 = List::Util::shuffle(0..255);
      my $ip = "$b1.$b2.$b3.$b4";
      if (! exists($random{$ip})) {
         $random{$ip}++;
         $current++;
      }

      last if $current == $count;
   }

   return [ keys %random ];
}

1;

__END__

=head1 NAME

Metabrik::Address::Generate - address::generate Brik

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2014-2015, Patrice E<lt>GomoRE<gt> Auffret

You may distribute this module under the terms of The BSD 3-Clause License.
See LICENSE file in the source distribution archive.

=head1 AUTHOR

Patrice E<lt>GomoRE<gt> Auffret

=cut
