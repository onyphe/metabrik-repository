#
# $Id$
#
# http::proxy Brik
#
package Metabrik::Brik::Http::Proxy;
use strict;
use warnings;

use base qw(Metabrik::Brik);

sub revision {
   return '$Revision$';
}

sub declare_attributes {
   return {
      port => [],
      truncate_request => [],
      truncate_response => [],
   };
}

sub require_modules {
   return {
      'HTTP::Proxy' => [],
      'HTTP::Proxy::HeaderFilter::simple' => [],
      'LWP::Protocol::connect' => [],
   };
}

sub help {
   return {
      'set:port' => '<port> (default: 3128)',
      'set:truncate_response' => '<characters> (default: 0, do not truncate)',
      'set:truncate_request' => '<characters> (default: 512 characters)',
      'run:requests' => '- simply display browser requests',
      'run:requests_responses' => '- simply display browser requests and server responses',
   };
}

sub default_values {
   return {
      port => 3128,
      truncate_response => 512,
   };
}

# XXX: see http://cpansearch.perl.org/src/MIKEM/Net-SSLeay-1.65/examples/https-proxy-snif.pl
# XXX: for HTTPS mitm

sub requests {
   my $self = shift;

   my $proxy = HTTP::Proxy->new(
      port => $self->port,
   );

   $proxy->push_filter(
      request => HTTP::Proxy::HeaderFilter::simple->new(
         sub {
            my ($self, $headers, $request) = @_;
            my $string = $request->as_string;
            if ($self->truncate_request) {
               print substr($string, 0, $self->truncate_request);
               print "\n[..]\n";
            }
            else {
               print $string;
            }
         },
      ),
   );

   print "Listening on port: ".$self->port."\n";
   print "Ready to process browser requests, blocking state...\n";

   return $proxy->start;
}

sub requests_responses {
   my $self = shift;

   my $proxy = HTTP::Proxy->new(
      port => $self->port,
   );

   $proxy->push_filter(
      request => HTTP::Proxy::HeaderFilter::simple->new(
         sub {
            my ($proxy, $headers, $request) = @_;
            my $string = $request->as_string;
            if ($self->truncate_request) {
               print substr($string, 0, $self->truncate_request);
               print "\n[..]\n";
            }
            else {
               print $string;
            }
         },
      ),
      response => HTTP::Proxy::HeaderFilter::simple->new(
         sub {
            my ($proxy, $headers, $response) = @_;
            my $string = $response->as_string;
            if ($self->truncate_response) {
               print substr($string, 0, $self->truncate_response);
               print "\n[..]\n";
            }
            else {
               print $string;
            }
         },
      ),
   );

   print "Listening on port: ".$self->port."\n";
   print "Ready to process browser requests, blocking state...\n";

   return $proxy->start;
}

1;

__END__
