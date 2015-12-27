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
      tags => [ qw(exec execute) ],
      attributes => {
         as_array => [ qw(0|1) ],
         as_matrix => [ qw(0|1) ],
         capture_stderr => [ qw(0|1) ],
         capture_mode => [ qw(0|1) ],
         ignore_error => [ qw(0|1) ],
         use_sudo => [ qw(0|1) ],
         use_pager => [ qw(0|1) ],
         sudo_args => [ qw(args) ],
      },
      attributes_default => {
         as_array => 1,
         as_matrix => 0,
         capture_stderr => 1,
         capture_mode => 0,
         ignore_error => 1,
         use_sudo => 0,
         use_pager => 0,
         sudo_args => '-E',  # Keep environment
      },
      commands => {
         system => [ qw(command) ],
         capture => [ qw(command) ],
         execute => [ qw(command) ],
      },
      require_modules => {
         'IPC::Run3' => [ ],
      },
   };
}

sub system {
   my $self = shift;
   my ($cmd, @args) = @_;

   $self->brik_help_run_undef_arg('system', $cmd) or return;

   # Remove undefined values from arguments
   my @new;
   for (@args) {
      if (defined($_)) {
         push @new, $_;
      }
   }

   my $command = join(' ', $cmd, @new);
   my @toks = split(/\s+/, $command);
   my $bin = $toks[0];

   my @path = split(':', $ENV{PATH});
   if (! -f $bin) {  # If file is not directly found
      for my $path (@path) {
         if (-f "$path/$bin") {
            $bin = "$path/$bin";
            last;
         }
      }
   }
   $toks[0] = $bin;

   if (! -f $bin) {
      return $self->log->error("system: program [$bin] not found in PATH");
   }

   $command = join(' ', @toks);

   if ($self->use_sudo) {
      my @sudo = ( "sudo" );
      if (! ref($self->sudo_args) && length($self->sudo_args)) {
         my @args = split(/\s+/, $self->sudo_args);
         push @sudo, @args;
      }
      $command = join(' ', @sudo)." $command";
      @toks = ( @sudo, @toks );
      $self->log->verbose("system: using sudo: running [$command]");
   }

   if ($self->use_pager) {
      my $pager = $ENV{PAGER} || 'less';
      $command .= " | $pager";
   }

   my $r = CORE::system($command);

   $self->debug && $self->log->debug("system: return code [$r] with status [$?]");

   if (! $self->ignore_error && $? != 0) {
      # Failure, we return the program exit code
      return $? >> 8;
   }

   # Success
   if ($r == 0) {
      return 1;
   }

   return 1;
}

sub capture {
   my $self = shift;
   my ($cmd, @args) = @_;

   if (! defined($cmd)) {
      return $self->log->error($self->brik_help_run('capture'));
   }

   # Remove undefined values from arguments
   my @new;
   for (@args) {
      if (defined($_)) {
         push @new, $_;
      }
   }

   my $command = join(' ', $cmd, @new);
   my @toks = split(/\s+/, $command);
   my $bin = $toks[0];

   my @path = split(':', $ENV{PATH});
   if (! -f $bin) {  # If file is not directly found
      for my $path (@path) {
         if (-f "$path/$bin") {
            $bin = "$path/$bin";
            last;
         }
      }
   }
   $toks[0] = $bin;

   if (! -f $bin) {
      return $self->log->error("capture: program [$bin] not found in PATH");
   }

   # Perform file globbing, if any
   my @globbed = ();
   for (@toks) {
      push @globbed, glob($_);
   }
   @toks = @globbed;

   $command = join(' ', @toks);

   if ($self->use_sudo) {
      my @sudo = ( "sudo" );
      if (! ref($self->sudo_args) && length($self->sudo_args)) {
         my @args = split(/\s+/, $self->sudo_args);
         push @sudo, @args;
      }
      $command = join(' ', @sudo)." $command";
      @toks = ( @sudo, @toks );
      $self->log->verbose("capture: using sudo: running [$command]");
   }

   my $out;
   my $err;
   eval {
      IPC::Run3::run3(\@toks, undef, \$out, \$err);
   };
   # Error in executing run3()
   if ($@) {
      chomp($@);
      return $self->log->error("capture: unable to execute command [$command]: $@");
   }
   # Error in command execution
   elsif ($?) {
      chomp($err);
      chomp($out);
      $err ||= $out; # Sometimes, the error is printed on stdout instead of stderr
      if ($self->ignore_error) {
         $self->log->warning("capture: command execution had errors [$command]: $err");
      }
      else {
         return $self->log->error("capture: command execution failed [$command]: $err");
      }
   }

   $out ||= 'undef';
   $err ||= 'undef';
   chomp($out);
   chomp($err);

   # If we also wanted stderr, we put it at the end of output
   if ($self->capture_stderr && $err ne 'undef') {
      $out .= "\n\nSTDERR:\n$err";
   }

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

sub execute {
   my $self = shift;
   my ($cmd, @args) = @_;
   
   if (! defined($cmd)) {
      return $self->log->error($self->brik_help_run('execute'));
   }

   if ($self->capture_mode) {
      return $self->capture($cmd, @args);
   }
   else {  # non-capture mode
      return $self->system($cmd, @args);
   }

   # Unknown error
   return;
}

1;

__END__

=head1 NAME

Metabrik::Shell::Command - shell::command Brik

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2014-2015, Patrice E<lt>GomoRE<gt> Auffret

You may distribute this module under the terms of The BSD 3-Clause License.
See LICENSE file in the source distribution archive.

=head1 AUTHOR

Patrice E<lt>GomoRE<gt> Auffret

=cut