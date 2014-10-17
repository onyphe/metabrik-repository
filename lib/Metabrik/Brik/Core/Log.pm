#
# $Id$
#
# core::log Brik
#
package Metabrik::Brik::Core::Log;
use strict;
use warnings;

use base qw(Metabrik::Brik);

sub brik_properties {
   return {
      revision => '$Revision$',
      tags => [ qw(core main log) ],
      attributes => {
         color => [ qw(SCALAR) ],
         level => [ qw(SCALAR) ],
      },
      attributes_default => {
         color => 1,
         level => 1,
      },
      commands => {
         info => [ qw(SCALAR) ],
         verbose => [ qw(SCALAR) ],
         warning => [ qw(SCALAR) ],
         error => [ qw(SCALAR) ],
         fatal => [ qw(SCALAR) ],
         debug => [ qw(SCALAR) ],
      },
      require_modules => {
         'Term::ANSIColor' => [ ],
      },
   };
}

sub _msg {
   my $self = shift;
   my ($brik, $msg) = @_;

   $msg ||= 'undef';

   $brik =~ s/^metabrik::brik:://i;

   return lc($brik).": $msg\n";
}

sub warning {
   my $self = shift;
   my ($msg, $caller) = @_;

   if ($self->color) {
      print Term::ANSIColor::MAGENTA(), "[!] ", Term::ANSIColor::RESET();
   }
   else {
      print "[!] ";
   }

   print $self->_msg(($caller) ||= caller(), $msg);

   return 1;
}

sub error {
   my $self = shift;
   my ($msg, $caller) = @_;

   if ($self->color) {
      print Term::ANSIColor::RED(), "[-] ", Term::ANSIColor::RESET();
   }
   else {
      print "[-] ";
   }

   print $self->_msg(($caller) ||= caller(), $msg);

   return;
}

sub fatal {
   my $self = shift;
   my ($msg, $caller) = @_;

   if ($self->color) {
      print Term::ANSIColor::RED(), "[F] ", Term::ANSIColor::RESET();
   }
   else {
      print "[F] ";
   }

   die($self->_msg(($caller) ||= caller(), $msg));
}

sub info {
   my $self = shift;
   my ($msg, $caller) = @_;

   return unless $self->level > 0;

   if ($self->color) {
      print Term::ANSIColor::GREEN(), "[*] ", Term::ANSIColor::RESET();
   }
   else {
      print "[*] ";
   }

   $msg ||= 'undef';

   print "$msg\n";

   return 1;
}

sub verbose {
   my $self = shift;
   my ($msg, $caller) = @_;

   return unless $self->level > 1;

   if ($self->color) {
      print Term::ANSIColor::YELLOW(), "[+] ", Term::ANSIColor::RESET();
   }
   else {
      print "[+] ";
   }

   print $self->_msg(($caller) ||= caller(), $msg);

   return 1;
}

sub debug {
   my $self = shift;
   my ($msg, $caller) = @_;

   # We have a conflict between the method and the accessor,
   # we have to identify which one is accessed.

   # If no message defined, we want to access the Attribute
   if (! defined($msg)) {
      return $self->{debug};
   }
   else {
      # If $msg is either 1 or 0, we want to set the Attribute
      if ($msg =~ /^(?:1|0)$/) {
         return $self->{debug} = $msg;
      }
      else {
         return unless $self->level > 2;

         if ($self->color) {
            print Term::ANSIColor::CYAN(), "[D] ", Term::ANSIColor::RESET();
         }
         else {
            print "[D] ";
         }

         print $self->_msg(($caller) ||= caller(), $msg);
      }
   }

   return 1;
}

1;

__END__

=head1 NAME

Metabrik::Brik::Core::Log - logging directly on the console

=head1 SYNOPSIS

   use Metabrik::Brik::Core::Log;

   my $log = Metabrik::Brik::Core::Log->new(
      level => 1,
   );

=head1 DESCRIPTION

=head1 COMMANDS

=over 4

=item B<new>

=item B<info>

=item B<warning>

=item B<error>

=item B<fatal>

=item B<verbose>

=item B<debug>

=back

=head1 AUTHOR

Patrice E<lt>GomoRE<gt> Auffret

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2014, Patrice E<lt>GomoRE<gt> Auffret

You may distribute this module under the terms of the Artistic license.
See LICENSE.Artistic file in the source distribution archive.

=cut
