#
# $Id$
#
# lookup::oui Brik
#
package Metabrik::Lookup::Oui;
use strict;
use warnings;

use base qw(Metabrik::File::Text);

sub brik_properties {
   return {
      revision => '$Revision$',
      tags => [ qw(unstable lookup oui ieee) ],
      attributes => {
         datadir => [ qw(datadir) ],
         input => [ qw(input) ],
         _load => [ qw(INTERNAL) ],
      },
      attributes_default => {
         input => 'oui.txt',
      },
      commands => {
         update => [ qw(output|OPTIONAL) ],
         load => [ qw(input|OPTIONAL) ],
         from_dec => [ qw(dec_number) ],
         from_hex => [ qw(hex_number) ],
         from_string => [ qw(company_string) ],
      },
      require_modules => {
         'Metabrik::File::Fetch' => [ ],
      },
   };
}

sub update {
   my $self = shift;
   my ($output) = @_;

   my $url = 'http://standards-oui.ieee.org/oui.txt';
   my ($file) = $self->input;

   $output ||= $self->datadir.'/'.$file;

   my $ff = Metabrik::File::Fetch->new_from_brik_init($self) or return;
   $ff->get($url, $output)
      or return $self->log->error("update: get failed");

   return $output;
}

sub load {
   my $self = shift;
   my ($input) = @_;

   $input ||= $self->datadir.'/'.$self->input;
   if (! -f $input) {
      return $self->log->error("load: file [$input] not found");
   }

   $self->as_array(1);

   my $data = $self->read($input)
      or return $self->log->error("load: read failed");

   return $self->_load($data);
}

sub from_dec {
   my $self = shift;

   return $self->log->error("from_dec: not applicable");
}

sub from_hex {
   my $self = shift;
   my ($hex) = @_;

   if (! defined($hex)) {
      return $self->log->error($self->brik_help_run('from_hex'));
   }

   my $data = $self->_load || $self->load;
   if (! defined($data)) {
      return $self->log->error("from_hex: load failed");
   }

   # Accept multiple format for MAC address
   $hex =~ s/[:-]//g;

   for my $this (@$data) {
      if ($this =~ /^\s*([0-9A-F]{6})\s+\(base 16\)\s+(.*)$/i) {
         $self->debug && $self->log->debug("from_hex: this[$this]");
         my $oui = $1;
         my $company = $2;
         if ($hex =~ /^$oui/i) {
            return $company;
         }
      }
   }

   # No match
   return;
}

sub from_string {
   my $self = shift;
   my ($string) = @_;

   if (! defined($string)) {
      return $self->log->error($self->brik_help_run('from_string'));
   }

   my $data = $self->_load || $self->load;
   if (! defined($data)) {
      return $self->log->error("from_string: load failed");
   }

   my @match = ();
   for my $this (@$data) {
      if ($this =~ /^\s*([0-9A-F]{2}\-[0-9A-F]{2}\-[0-9A-F]{2})\s+\(hex\)\s+(.*)$/i) {
         $self->debug && $self->log->debug("from_string: this[$this]");
         my $oui = $1;
         my $company = $2;
         if ($company =~ /$string/i) {
            $self->log->verbose("from_string: match [$company]");
            $oui =~ s/\-/:/g;
            push @match, lc($oui);
         }
      }
   }

   return \@match;
}

1;

__END__

=head1 NAME

Metabrik::Lookup::Oui - lookup::oui Brik

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2014-2015, Patrice E<lt>GomoRE<gt> Auffret

You may distribute this module under the terms of The BSD 3-Clause License.
See LICENSE file in the source distribution archive.

=head1 AUTHOR

Patrice E<lt>GomoRE<gt> Auffret

=cut