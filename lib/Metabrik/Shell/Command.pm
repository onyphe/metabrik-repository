#
# $Id$
#
# shell::command Brik
#
package Metabrik::Shell::Command;
use strict;
use warnings;

use base qw(Metabrik);

sub brik_properties {
   return {
      revision => '$Revision$',
      tags => [ qw(main shell command system) ],
      attributes => {
         as_array => [ qw(0|1) ],
         as_matrix => [ qw(0|1) ],
         capture_stderr => [ qw(0|1) ],
      },
      commands => {
         system => [ qw(command) ],
         capture => [ qw(command) ],
      },
      require_modules => {
         'IPC::Run' => [ qw(run) ],
      },
   };
}

sub brik_use_properties {
   my $self = shift;

   return {
      attributes_default => {
         as_array => 1,
         as_matrix => 0,
         capture_stderr => 1,
      },
   };
}

sub system {
   my $self = shift;
   my ($cmd, @args) = @_;

   if (! defined($cmd)) {
      return $self->log->error($self->brik_help_run('system'));
   }

   $cmd = join(' ', $cmd, @args);
   my $r = CORE::system($cmd);

   return defined($r) ? 1 : 0;
}

sub capture {
   my $self = shift;
   my ($cmd, @args) = @_;

   if (! defined($cmd)) {
      return $self->log->error($self->brik_help_run('capture'));
   }

   my $run = join(' ', $cmd, @args);

   #my $out = '';
   #eval {
      ## IPC::Run: does not provide string interpolation for shell
      #IPC::Run::run([ $run ], \undef, \$out);
   #};
   #if ($@) {
      #return $self->log->error("capture: $@");
   #}

   my $out = $self->capture_stderr ? `$run 2>&1` : `$run`;

   # as_matrix has precedence over as_array (because as_array is the default)
   if (! $self->as_matrix && $self->as_array) {
      $out = [ split(/\n/, $out) ];
   }
   elsif ($self->as_matrix) {
      my @matrix = ();
      for my $this (split(/\n/, $out)) {
         push @matrix, [ split(/\s+/, $this) ];
      }
      $out = \@matrix;
   }

   return $out;
}

1;

__END__
