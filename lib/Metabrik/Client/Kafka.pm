#
# $Id$
#
# client::kafka Brik
#
package Metabrik::Client::Kafka;
use strict;
use warnings;

use base qw(Metabrik);

sub brik_properties {
   return {
      revision => '$Revision$',
      tags => [ qw(unstable) ],
      author => 'GomoR <GomoR[at]metabrik.org>',
      license => 'http://opensource.org/licenses/BSD-3-Clause',
      attributes => {
         _kc => [ qw(INTERNAL) ],
         _kcli => [ qw(INTERNAL) ],
      },
      attributes_default => {
      },
      commands => {
         create_connection => [ ],
         create_producer => [ ],
         create_consumer => [ ],
         send => [ qw(topic partition messages) ],
         loop_consumer_fetch => [ ],
         close => [ ],
      },
      require_modules => {
         'Kafka' => [ ],
         'Kafka::Connection' => [ ],
         'Kafka::Producer' => [ ],
         'Kafka::Consumer' => [ ],
      },
      require_binaries => {
      },
      optional_binaries => {
      },
      need_packages => {
      },
   };
}

sub create_connection {
   my $self = shift;
   my ($host) = @_;

   $host ||= 'localhost';

   my $kc;
   eval {
      $kc = Kafka::Connection->new(host => $host);
   };
   if ($@) {
      chomp($@);
      return $self->log->error("create_connection: failed [$@]");
   }

   return $self->_kc($kc);
}

sub create_producer {
   my $self = shift;
   my ($host) = @_;

   my $kc = $self->create_connection or return;

   my $kp;
   eval {
      $kp = Kafka::Producer->new(Connection => $kc);
   };
   if ($@) {
      chomp($@);
      return $self->log->error("create_producer: failed [$@]");
   }

   return $self->_kcli($kp);
}

sub create_consumer {
   my $self = shift;
   my ($host) = @_;

   my $kc = $self->create_connection or return;

   my $kco;  
   eval {
      $kco = Kafka::Consumer->new(Connection => $kc);
   };
   if ($@) {
      chomp($@);
      return $self->log->error("create_consumer: failed [$@]");
   }

   return $self->_kcli($kco);
}

sub send {
   my $self = shift;
   my ($topic, $partition, $messages) = @_;

   my $kcli = $self->_kcli;
   $self->brik_help_run_undef_arg('create_producer', $kcli) or return;

   $self->brik_help_run_undef_arg('send', $topic) or return;
   $self->brik_help_run_undef_arg('send', $partition) or return;
   $self->brik_help_run_undef_arg('send', $messages) or return;
   $self->brik_help_run_invalid_arg('send', $messages, 'ARRAY', 'SCALAR') or return;

   my $r;
   eval {
      $kcli->send($topic, $partition, $messages);
   };
   if ($@) {
      chomp($@);
      return $self->log->error("send: fail [$@]");
   }

   return $r;
}

sub loop_consumer_fetch {
   my $self = shift;
   my ($topic, $partition) = @_;

   my $kcli = $self->_kcli;
   $self->brik_help_run_undef_arg('create_consumer', $kcli) or return;
   $self->brik_help_run_undef_arg('loop_consumer_fetch', $topic) or return;

   $partition ||= 0;

   my $offsets = $kcli->offsets(
      $topic,
      $partition,
      $Kafka::RECEIVE_EARLIEST_OFFSET,        # time
      $Kafka::DEFAULT_MAX_NUMBER_OF_OFFSETS,  # max_number
   );

   for (@$offsets) {
      print "Received offset: $_\n";
   }
 
   # Consuming messages
   my $messages = $kcli->fetch(
       $topic,
       $partition,
       0,                         # offset
       $Kafka::DEFAULT_MAX_BYTES, # Maximum size of MESSAGE(s) to receive
   );
   for my $message (@$messages) {
      if ($message->valid) {
         print 'payload    : ', $message->payload, "\n";
         print 'key        : ', $message->key, "\n";
         print 'offset     : ', $message->offset, "\n";
         print 'next_offset: ', $message->next_offset, "\n";
      }
      else {
         print 'error      : ', $message->error, "\n";
      }
   }

   return 1;
}

sub close {
   my $self = shift;

   if ($self->_kcli) {
      $self->_kcli(undef);
   }

   if ($self->_kc) {
      $self->_kc->close;
      $self->_kc(undef);
   }

   return 1;
}

1;

__END__

=head1 NAME

Metabrik::Client::Kafka - client::kafka Brik

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2014-2017, Patrice E<lt>GomoRE<gt> Auffret

You may distribute this module under the terms of The BSD 3-Clause License.
See LICENSE file in the source distribution archive.

=head1 AUTHOR

Patrice E<lt>GomoRE<gt> Auffret

=cut
