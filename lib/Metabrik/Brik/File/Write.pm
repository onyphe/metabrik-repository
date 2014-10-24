#
# $Id$
#
# file::write Brik
#
package Metabrik::Brik::File::Write;
use strict;
use warnings;

use base qw(Metabrik::Brik);

sub brik_properties {
   return {
      revision => '$Revision$',
      tags => [ qw(main file) ],
      attributes => {
         output => [ qw(SCALAR) ],
         append => [ qw(SCALAR) ],
         overwrite => [ qw(SCALAR) ],
         encoding => [ qw(SCALAR) ],
         fd => [ qw(SCALAR) ],
      },
      commands => {
         text => [ qw(SCALAR SCALARREF) ],
         open => [ ],
         close => [ ],
      },
      require_modules => {
         'JSON::XS' => [ ],
         'XML::Simple' => [ ],
         'Text::CSV::Hashify' => [ ],
      },
   };
}

sub brik_use_properties {
   my $self = shift;

   # encoding: see `perldoc Encode::Supported' for other types
   return {
      attributes_default => {
         output => $self->global->output || '/tmp/output.txt',
         append => 1,
         overwrite => 0,
         encoding => $self->global->encoding || 'utf8',
      },
   };
}

sub open {
   my $self = shift;

   my $output = $self->output;
   if (! defined($output)) {
      return $self->log->info($self->brik_help_set('output'));
   }

   my $out;
   my $encoding = $self->encoding;
   if ($self->append) {
      my $r = open($out, ">>$encoding", $output);
      if (! defined($r)) {
         return $self->log->error("open: open: append file [$output]: $!");
      }
   }
   elsif (! $self->append && $self->overwrite) {
      my $r = open($out, ">$encoding", $output);
      if (! defined($r)) {
         return $self->log->error("open: open: write file [$output]: $!");
      }
   }
   elsif (! $self->append && ! $self->overwrite && -f $self->output) {
      $self->log->info("open: we will not overwrite an existing file. See:");
      return $self->log->info($self->brik_help_set('overwrite'));
   }

   return $self->fd($out);
}

sub close {
   my $self = shift;

   if (defined($self->fd)) {
      close($self->fd);
   }

   return 1;
}

sub text {
   my $self = shift;
   my ($data) = @_;

   $self->debug && $self->log->debug("text: data[$data]");

   if (! defined($self->output)) {
      return $self->log->info($self->brik_help_set('output'));
   }

   if (! defined($data)) {
      return $self->log->info($self->brik_help_run('text'));
   }

   my $out = $self->open or return;

   ref($data) eq 'SCALAR' ? print $out $$data : print $out $data;

   $self->close;

   return $data;
}

1;

__END__
