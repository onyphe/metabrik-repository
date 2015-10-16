#
# $Id$
#
# client::www Brik
#
package Metabrik::Client::Www;
use strict;
use warnings;

use base qw(Metabrik);

sub brik_properties {
   return {
      revision => '$Revision$',
      tags => [ qw(unstable browser http client www javascript screenshot) ],
      attributes => {
         uri => [ qw(uri) ],
         username => [ qw(username) ],
         password => [ qw(password) ],
         ignore_content => [ qw(0|1) ],
         user_agent => [ qw(user_agent) ],
         ssl_verify => [ qw(0|1) ],
         _client => [ qw(object|INTERNAL) ],
         _last => [ qw(object|INTERNAL) ],
      },
      attributes_default => {
         ssl_verify => 0,
         ignore_content => 0,
      },
      commands => {
         create_user_agent => [ ],
         reset_user_agent => [ ],
         get => [ qw(uri|OPTIONAL username|OPTIONAL password|OPTIONAL) ],
         post => [ qw(content_hash uri|OPTIONAL username|OPTIONAL password|OPTIONAL) ],
         patch => [ qw(content_hash uri|OPTIONAL username|OPTIONAL password|OPTIONAL) ],
         put => [ qw(content_hash uri|OPTIONAL username|OPTIONAL password|OPTIONAL) ],
         head => [ qw(uri|OPTIONAL username|OPTIONAL password|OPTIONAL) ],
         delete => [ qw(uri|OPTIONAL username|OPTIONAL password|OPTIONAL) ],
         options => [ qw(uri|OPTIONAL username|OPTIONAL password|OPTIONAL) ],
         code => [ ],
         content => [ ],
         headers => [ ],
         forms => [ ],
         links => [ ],
         trace_redirect => [ qw(uri|OPTIONAL) ],
         screenshot => [ qw(uri output_file) ],
         eval_javascript => [ qw(js uri|OPTIONAL) ],
         info => [ ],
      },
      require_modules => {
         'Net::SSL' => [ ],
         'Data::Dumper' => [ ],
         'LWP::UserAgent' => [ ],
         'HTTP::Request' => [ ],
         'WWW::Mechanize' => [ ],
         'WWW::Mechanize::PhantomJS' => [ ],
         'Metabrik::File::Write' => [ ],
         'Metabrik::Client::Ssl' => [ ],
      },
      require_binaries => {
         'phantomjs' => [ ],
      },
   };
}

sub create_user_agent {
   my $self = shift;
   my ($uri, $username, $password) = @_;

   $uri ||= $self->uri;
   if ($self->ssl_verify) {
      if (! defined($uri)) {
         return $self->log->error("create_user_agent: you have to give URI argument to check SSL");
      }

      # We have to use a different method to check certificate because all 
      # IO::Socket::SSL, Net::SSL, Net::SSLeay, Net::HTTPS, AnyEvent::TLS just sucks.
      # So we have to perform a first TCP connexion to verify cert, then a second 
      # One to actually negatiate an unverified session.
      my $cs = Metabrik::Client::Ssl->new_from_brik($self) or return;
      my $verified = $cs->verify_server($uri);
      if (! defined($verified)) {
         return;
      }
      if ($verified == 0) {
         return $self->log->error("create_user_agent: server [$uri] not verified");
      }
   }

   $ENV{PERL_NET_HTTPS_SSL_SOCKET_CLASS} = 'Net::SSL';

   my $mech = WWW::Mechanize->new(
      autocheck => 0,  # Do not throw on error by checking HTTP code. Let us do it.
      timeout => $self->global->rtimeout,
      ssl_opts => {
         verify_hostname => 0,
      },
   );
   if (! defined($mech)) {
      return $self->log->error("create_user_agent: unable to create WWW::Mechanize object");
   }

   if ($self->user_agent) {
      $mech->agent($self->user_agent);
   }
   else {
      $mech->agent_alias('Linux Mozilla');
   }

   $username ||= $self->username;
   $password ||= $self->password;
   if (defined($username) && defined($password)) {
      $self->log->verbose("create_user_agent: using Basic authentication");
      $mech->cookie_jar({});
      $mech->credentials($username, $password);
   }

   return $mech;
}

sub reset_user_agent {
   my $self = shift;

   $self->_client(undef);

   return 1;
}

sub _method {
   my $self = shift;
   my ($uri, $username, $password, $method, $data) = @_;

   $uri ||= $self->uri;
   if (! defined($uri)) {
      return $self->log->error($self->brik_help_run($method));
   }

   $username ||= $self->username;
   $password ||= $self->password;
   my $client = $self->_client;
   if (! defined($self->_client)) {
      $client = $self->create_user_agent($uri, $username, $password) or return;
      $self->_client($client);
   }

   $self->log->verbose("$method: $uri");

   my $response;
   eval {
      if ($method eq 'post' || $method eq 'put') {
         $response = $client->$method($uri, Content => $data);
      }
      elsif ($method eq 'options' || $method eq 'patch') {
         my $req = HTTP::Request->new($method => $uri);
         $response = $client->request($req);
      }
      else {
         $response = $client->$method($uri);
      }
   };
   if ($@) {
      chomp($@);
      return $self->log->error("$method: unable to $method uri [$uri]: $@");
   }

   $self->_last($response);

   my %response = ();
   $response{code} = $response->code;
   if (! $self->ignore_content) {
      $response{content} = $response->decoded_content;
   }

   my $headers = $response->headers;
   $response{headers} = { map { $_ => $headers->{$_} } keys %$headers };
   delete $response{headers}->{'::std_case'};

   return \%response;
}

sub get {
   my $self = shift;
   my ($uri, $username, $password) = @_;

   return $self->_method($uri, $username, $password, 'get');
}

sub post {
   my $self = shift;
   my ($href, $uri, $username, $password) = @_;

   if (! defined($href)) {
      return $self->log->error($self->brik_help_run('post'));
   }

   return $self->_method($uri, $username, $password, 'post', $href);
}

sub put {
   my $self = shift;
   my ($href, $uri, $username, $password) = @_;

   if (! defined($href)) {
      return $self->log->error($self->brik_help_run('put'));
   }

   return $self->_method($uri, $username, $password, 'put', $href);
}

sub patch {
   my $self = shift;
   my ($href, $uri, $username, $password) = @_;

   if (! defined($href)) {
      return $self->log->error($self->brik_help_run('patch'));
   }

   return $self->_method($uri, $username, $password, 'patch', $href);
}

sub delete {
   my $self = shift;
   my ($uri, $username, $password) = @_;

   return $self->_method($uri, $username, $password, 'delete');
}

sub options {
   my $self = shift;
   my ($uri, $username, $password) = @_;

   return $self->_method($uri, $username, $password, 'options');
}

sub head {
   my $self = shift;
   my ($uri, $username, $password) = @_;

   return $self->_method($uri, $username, $password, 'head');
}

sub code {
   my $self = shift;

   my $last = $self->_last;
   if (! defined($last)) {
      return $self->log->error("status: you have to execute a request first");
   }

   return $last->code;
}

sub content {
   my $self = shift;

   my $last = $self->_last;
   if (! defined($last)) {
      return $self->log->error("content: you have to execute a request first");
   }

   return $last->decoded_content;
}

sub headers {
   my $self = shift;

   my $last = $self->_last;
   if (! defined($last)) {
      return $self->log->error("headers: you have to execute a request first");
   }

   return $last->headers;
}

sub links {
   my $self = shift;

   my $last = $self->_last;
   if (! defined($last)) {
      return $self->log->error("links: you have to execute a request first");
   }

   my @links = ();
   for my $l ($self->_client->links) {
      push @links, $l->url;
      $self->log->verbose("links: found link [".$l->url."]");
   }

   return \@links;
}

sub forms {
   my $self = shift;

   my $last = $self->_last;
   if (! defined($last)) {
      return $self->log->error("links: you have to execute a request first");
   }

   my $client = $self->_client;

   if ($self->debug) {
      print Data::Dumper::Dumper($last->headers)."\n";
   }

   my @forms = $client->forms;
   my $count = 0; 
   for my $form (@forms) {
      my $name = $form->{attr}->{name} || '(undef)';
      print "$count: name: $name\n";

      for my $input (@{$form->{inputs}}) {
         print "   title:    ".$input->{title}."\n"    if exists $input->{title};
         print "   type:     ".$input->{type}."\n"     if exists $input->{type};
         print "   name:     ".$input->{name}."\n"     if exists $input->{name};
         print "   value:    ".$input->{value}."\n"    if exists $input->{value};
         print "   readonly: ".$input->{readonly}."\n" if exists $input->{readonly};
         print "\n";
      }

      $count++;
   }

   return $client;
}

sub trace_redirect {
   my $self = shift;
   my ($uri, $username, $password) = @_;

   $uri ||= $self->uri;
   if (! defined($uri)) {
      return $self->log->error($self->brik_help_set('uri'));
   }

   my %args = ();
   if (! $self->ssl_verify) {
      $args{ssl_opts} = { SSL_verify_mode => 'SSL_VERIFY_NONE'};
   }

   my $lwp = LWP::UserAgent->new(%args);
   $lwp->timeout($self->global->rtimeout);
   $lwp->agent('Mozilla/5.0');
   $lwp->max_redirect(0);
   $lwp->env_proxy;

   $username ||= $self->username;
   $password ||= $self->password;
   if (defined($username) && defined($password)) {
      $lwp->credentials($username, $password);
   }

   my @results = ();

   my $location = $uri;
   # Max 20 redirects
   for (1..20) {
      $self->log->verbose("trace_redirect: $location");

      my $response;
      eval {
         $response = $lwp->get($location);
      };
      if ($@) {
         chomp($@);
         return $self->log->error("trace_redirect: unable to get uri [$uri]: $@");
      }

      my $this = {
         uri => $location,
         code => $response->code,
      };
      push @results, $this;

      if ($this->{code} != 302 && $this->{code} != 301) {
         last;
      }

      $location = $this->{location} = $response->headers->{location};
   }

   return \@results;
}

sub screenshot {
   my $self = shift;
   my ($uri, $output) = @_;

   my $mech = WWW::Mechanize::PhantomJS->new
      or return $self->log->error("screenshot: PhantomJS failed");
   $mech->get($uri)
      or return $self->log->error("screenshot: get uri [$uri] failed");

   my $data = $mech->content_as_png
      or return $self->log->error("screenshot: content_as_png failed");

   my $write = Metabrik::File::Write->new_from_brik($self) or return;
   $write->encoding('ascii');
   $write->overwrite(1);
   $write->append(0);

   $write->open($output) or return $self->log->error("screenshot: open failed");
   $write->write($data) or return $self->log->error("screenshot: write failed");
   $write->close;

   return $output;
}

sub eval_javascript {
   my $self = shift;
   my ($js, $uri) = @_;

   # Perl module Wight may also be an option.

   my $mech = WWW::Mechanize::PhantomJS->new
      or return $self->log->error("eval_javascript: PhantomJS failed");

   if ($uri) {
      $mech->get($uri)
         or return $self->log->error("eval_javascript: get uri [$uri] failed");
   }

   return $mech->eval_in_page($js);
}

sub info {
   my $self = shift;

   if (! defined($self->mechanize)) {
      return $self->log->error($self->brik_help_run('get'));
   }

   my $mech = $self->mechanize;
   my $headers = $mech->response->headers;

   # Taken from apps.json from Wappalyzer
   my @headers = qw(
      IBM-Web2-Location
      X-Drupal-Cache
      X-Powered-By
      X-Drectory-Script
      Set-Cookie
      X-Powered-CMS
      X-KoobooCMS-Version
      X-ATG-Version
      User-Agent
      X-Varnish
      X-Compressed-By
      X-Firefox-Spdy
      X-ServedBy
      MicrosoftSharePointTeamServices
      Set-Cookie
      Generator
      X-CDN
      Server
      X-Tumblr-User
      X-XRDS-Location
      X-Content-Encoded-By
      X-Ghost-Cache-Status
      X-Umbraco-Version
      X-Rack-Cache
      Liferay-Portal
      X-Flow-Powered
      X-Swiftlet-Cache
      X-Lift-Version
      X-Spip-Cache
      X-Wix-Dispatcher-Cache-Hit
      COMMERCE-SERVER-SOFTWARE
      X-AMP-Version
      X-Powered-By-Plesk
      X-Akamai-Transformed
      X-Confluence-Request-Time
      X-Mod-Pagespeed
      Composed-By
      Via
   );

   if ($self->debug) {
      print Data::Dumper::Dumper($headers)."\n";
   }

   my %info = ();
   for my $hdr (@headers) {
      my $this = $headers->header(lc($hdr));
      $info{$hdr} = $this if defined($this);
   }

   my $title = $mech->title;
   if (defined($title)) {
      print "Title: $title\n";
   }

   for my $k (sort { $a cmp $b } keys %info) {
      print "$k: ".$info{$k}."\n";
   }

   return $mech;
}

1;

__END__

=head1 NAME

Metabrik::Client::Www - client::www Brik

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2014-2015, Patrice E<lt>GomoRE<gt> Auffret

You may distribute this module under the terms of The BSD 3-Clause License.
See LICENSE file in the source distribution archive.

=head1 AUTHOR

Patrice E<lt>GomoRE<gt> Auffret

=cut
