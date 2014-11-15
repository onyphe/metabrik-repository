#
# $Id$
#
# database::nvd Brik
#
package Metabrik::Database::Nvd;
use strict;
use warnings;

use base qw(Metabrik);

sub brik_properties {
   return {
      revision => '$Revision$',
      tags => [ qw(unstable cve cpe) ],
      attributes => {
         uri_recent => [ qw($uri_list) ],
         uri_modified => [ qw($uri_list) ],
         uri_others => [ qw($uri_list) ],
         xml_recent => [ qw($xml_list) ],
         xml_modified => [ qw($xml_list) ],
         xml_others => [ qw($xml_list) ],
         xml => [ qw($xml) ],
      },
      commands => {
         update => [ qw(recent|modified|others) ],
         load => [ qw(recent|modified|others file_pattern) ],
         search => [ qw(cve_pattern) ],
         search_by_cpe => [ qw(cpe_pattern) ],
         getxml => [ qw(cve_id) ],
      },
      require_used => {
         'file::fetch' => [ ],
         'file::xml' => [ ],
      },
   };
}

sub brik_use_properties {
   my $self = shift;

   my $datadir = $self->global->datadir;

   return {
      # http://nvd.nist.gov/download.cfm
      # nvdcve-2.0-modified.xml includes all recently published and recently updated vulnerabilities
      # nvdcve-2.0-recent.xml includes all recently published vulnerabilities
      # nvdcve-2.0-2002.xml includes vulnerabilities prior to and including 2002.
      attributes_default => {
         uri_recent => [ 'http://static.nvd.nist.gov/feeds/xml/cve/nvdcve-2.0-recent.xml', ],
         uri_modified => [ 'http://static.nvd.nist.gov/feeds/xml/cve/nvdcve-2.0-modified.xml', ],
         uri_others => [ qw(
            http://static.nvd.nist.gov/feeds/xml/cve/nvdcve-2.0-2002.xml
            http://static.nvd.nist.gov/feeds/xml/cve/nvdcve-2.0-2003.xml
            http://static.nvd.nist.gov/feeds/xml/cve/nvdcve-2.0-2004.xml
            http://static.nvd.nist.gov/feeds/xml/cve/nvdcve-2.0-2005.xml
            http://static.nvd.nist.gov/feeds/xml/cve/nvdcve-2.0-2006.xml
            http://static.nvd.nist.gov/feeds/xml/cve/nvdcve-2.0-2007.xml
            http://static.nvd.nist.gov/feeds/xml/cve/nvdcve-2.0-2008.xml
            http://static.nvd.nist.gov/feeds/xml/cve/nvdcve-2.0-2009.xml
            http://static.nvd.nist.gov/feeds/xml/cve/nvdcve-2.0-2010.xml
            http://static.nvd.nist.gov/feeds/xml/cve/nvdcve-2.0-2011.xml
            http://static.nvd.nist.gov/feeds/xml/cve/nvdcve-2.0-2012.xml
            http://static.nvd.nist.gov/feeds/xml/cve/nvdcve-2.0-2013.xml
            http://static.nvd.nist.gov/feeds/xml/cve/nvdcve-2.0-2014.xml
         ) ],
         xml_recent => [ "$datadir/nvdcve-2.0-recent.xml", ],
         xml_modified => [ "$datadir/nvdcve-2.0-modified.xml", ],
         xml_others => [
            "$datadir/nvdcve-2.0-2002.xml",
            "$datadir/nvdcve-2.0-2003.xml",
            "$datadir/nvdcve-2.0-2004.xml",
            "$datadir/nvdcve-2.0-2005.xml",
            "$datadir/nvdcve-2.0-2006.xml",
            "$datadir/nvdcve-2.0-2007.xml",
            "$datadir/nvdcve-2.0-2008.xml",
            "$datadir/nvdcve-2.0-2009.xml",
            "$datadir/nvdcve-2.0-2010.xml",
            "$datadir/nvdcve-2.0-2011.xml",
            "$datadir/nvdcve-2.0-2012.xml",
            "$datadir/nvdcve-2.0-2013.xml",
            "$datadir/nvdcve-2.0-2014.xml",
         ],
      },
   };
}

sub update {
   my $self = shift;
   my ($type) = @_;

   my $context = $self->context;

   if (! defined($type)) {
      return $self->log->error($self->brik_help_run('update'));
   }

   if ($type ne 'recent'
   &&  $type ne 'modified'
   &&  $type ne 'others') {
      return $self->log->error($self->brik_help_run('update'));
   }

   my $datadir = $self->global->datadir;
   my $xml_method = "xml_$type";
   my $xml_files = $self->$xml_method;
   my $uri_method = "uri_$type";
   my $uri_list = $self->$uri_method;
   my $count = scalar @$xml_files;

   for my $c (0..$count-1) {
      $context->set('file::fetch', 'output', $xml_files->[$c]);
      $context->run('file::fetch', 'get', $uri_list->[$c])
         or $self->log->warning("update: file::fetch: get: uri[".$uri_list->[$c]."]");
   }

   return 1;
}

sub load {
   my $self = shift;
   my ($type, $pattern) = @_;

   my $context = $self->context;

   if (! defined($type)) {
      return $self->log->error($self->brik_help_run('load'));
   }

   if ($type ne 'recent'
   &&  $type ne 'modified'
   &&  $type ne 'others') {
      return $self->log->error($self->brik_help_run('load'));
   }

   my $datadir = $self->global->datadir;
   my $xml_method = "xml_$type";
   my $xml_files = $self->$xml_method;
   my $count = scalar @$xml_files;

   my $old_xml = $self->xml;
   for my $c (0..$count-1) {
      my $file = $xml_files->[$c];

      # If file does not match user pattern, we don't load it
      if (defined($pattern) && $file !~ /$pattern/) {
         next;
      }

      $context->set('file::xml', 'input', $file);

      $self->log->debug("load: reading file: ".$xml_files->[$c]);

      my $xml = $context->run('file::xml', 'read')
         or return $self->log->error("load: file::xml: read");

      # Merge XML data
      if (defined($old_xml)) {
         print "DEBUG Merging\n";
         for my $k (keys %{$xml->{entry}}) {
            # Check if it already exists
            if (exists $old_xml->{entry}->{$k}) {
               # It exists. Do we load recent or modified data?
               # If so, it takes precedence, and we overwrite it.
               if ($type eq 'recent' || $type eq 'modified') {
                  $old_xml->{entry}->{$k} = $xml->{entry}->{$k};
               }
            }
            # We add it directly if it does not exist yet.
            else {
               $old_xml->{entry}->{$k} = $xml->{entry}->{$k};
            }
         }
      }
      # There was nothing previously, we write everything.
      else {
         $old_xml = $xml;
      }
   }

   return $self->xml($old_xml);
}

sub show {
   my $self = shift;
   my ($h) = @_;

   my $buf = "CVE: ".$h->{cve_id}."\n";
   $buf .= "CWE: ".$h->{cwe_id}."\n";
   $buf .= "Published datetime: ".$h->{published_datetime}."\n";
   $buf .= "Last modified datetime: ".$h->{last_modified_datetime}."\n";
   $buf .= "URL: ".$h->{url}."\n";
   $buf .= "Summary: ".($h->{summary} || '(undef)')."\n";
   $buf .= "Vuln product:\n";
   for my $vuln_product (@{$h->{vuln_product}}) {
      $buf .= "   $vuln_product\n";
   }

   return $buf;
}

sub _to_hash {
   my $self = shift;
   my ($h, $cve) = @_;

   my $published_datetime = $h->{'vuln:published-datetime'};
   my $last_modified_datetime = $h->{'vuln:last-modified-datetime'};
   my $summary = $h->{'vuln:summary'};
   my $cwe_id = $h->{'vuln:cwe'}->{id} || '(undef)';
   $cwe_id =~ s/^CWE-//;

   my $vuln_product = [];
   if (defined($h->{'vuln:vulnerable-software-list'})
   &&  defined($h->{'vuln:vulnerable-software-list'}->{'vuln:product'})) {
      my $e = $h->{'vuln:vulnerable-software-list'}->{'vuln:product'};
      if (ref($e) eq 'ARRAY') {
         $vuln_product = $e;
      }
      else {
         $vuln_product = [ $e ];
      }
   }

   return {
      cve_id => $cve,
      url => 'http://web.nvd.nist.gov/view/vuln/detail?vulnId='.$cve,
      published_datetime => $published_datetime,
      last_modified_datetime => $last_modified_datetime,
      summary => $summary,
      cwe_id => $cwe_id,
      vuln_product => $vuln_product,
   };
}

sub search {
   my $self = shift;
   my ($pattern) = @_;

   my $xml = $self->xml;
   if (! defined($xml)) {
      return $self->log->error($self->brik_help_run('load'));
   }

   if (! defined($pattern)) {
      return $self->log->error($self->brik_help_run('search'));
   }

   my $entries = $xml->{entry};
   if (! defined($entries)) {
      return $self->log->error("nothing in this xml file");
   }

   my @entries = ();
   for my $cve (keys %$entries) {
      my $this = $self->_to_hash($entries->{$cve}, $cve);

      if ($this->{cve_id} =~ /$pattern/ || $this->{summary} =~ /$pattern/i) {
         push @entries, $this;
         print $self->show($this)."\n";
      }
   }

   return \@entries;
}

sub search_by_cpe {
   my $self = shift;
   my ($cpe) = @_;

   my $xml = $self->xml;
   if (! defined($xml)) {
      return $self->log->error($self->brik_help_run('load'));
   }

   if (! defined($cpe)) {
      return $self->log->error($self->brik_help_run('search_by_cpe'));
   }

   my $entries = $xml->{entry};
   if (! defined($entries)) {
      return $self->log->error("nothing in this xml file");
   }

   my @entries = ();
   for my $cve (keys %$entries) {
      my $this = $self->_to_hash($entries->{$cve}, $cve);

      for my $vuln_product (@{$this->{vuln_product}}) {
         if ($vuln_product =~ /$cpe/i) {
            push @entries, $this;
            print $self->show($this)."\n";
            last;
         }
      }
   }

   return \@entries;
}

sub getxml {
   my $self = shift;
   my ($cve_id) = @_;

   my $xml = $self->xml;
   if (! defined($xml)) {
      return $self->log->error($self->brik_help_run('load'));
   }

   if (defined($xml->{entry})) {
      return $xml->{entry}->{$cve_id};
   }

   return;
}

1;

__END__