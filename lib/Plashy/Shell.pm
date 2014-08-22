#
# $Id$
#
package Plashy::Shell;
use strict;
use warnings;

use base qw(Term::Shell Class::Gomor::Hash);

our @AS = qw(
   path_home
   path_cwd
   prompt
   plashyrc
   plashy_history
   ps1
   title
   context
);
__PACKAGE__->cgBuildAccessorsScalar(\@AS);

use Cwd;
use File::HomeDir qw(home);
use IO::All;
use Module::Reload;
use IPC::Run;

use Plashy::Context;
use Plashy::Ext::Utils qw(peu_convert_path);

# Exists because we cannot give an argument to Term::Shell::new()
# Or I didn't found how to do it.
our $Logger;

# Exists to avoid compile-time errors.
# It is only used by Plashy::Context.
my $global;

use vars qw{$AUTOLOAD};

sub AUTOLOAD {
   my $self = shift;
   print "DEBUG autoload[$AUTOLOAD]\n";
   print "DEBUG self[$self]\n";
   $self->ps_update_prompt('xxx $AUTOLOAD ');
   #$self->ps1('$AUTOLOAD ');
   $self->ps_update_prompt;
   return 1;
}

#
# Term::Shell::main stuff
#
sub init {
   my $self = shift;

   $|++;

   if (! defined($Logger)) {
      die("[-] FATAL: Plashy::Shell::init: you must give `Logger' variable\n");
   }

   my $context = Plashy::Context->new(
      logger => $Logger,
      shell => $self,
   );
   $self->context($context);

   my $log = $context->log;

   $self->ps_set_path_home;
   $self->ps_set_signals;
   $self->ps_update_path_cwd;
   $self->ps_update_prompt;

   my $rc = $self->plashyrc($self->path_home."/.plashyrc");
   my $history = $self->plashy_history($self->path_home."/.plashy_history");

   if (-f $rc) {
      open(my $in, '<', $rc) or $log->fatal("can't open rc file [$rc]: $!");
      while (defined(my $line = <$in>)) {
         next if ($line =~ /^\s*#/);  # Skip comments
         chomp($line);
         $self->cmd($self->ps_lookup_vars_in_line($line));
      }
      close($in);
   }

   if ($self->term->can('ReadHistory')) {
      if (-f $history) {
         $self->term->ReadHistory($history)
            or $log->fatal("can't read history file [$history]: $!");
      }
   }

   $context->global_update_available_plugins
      or $log->fatal("init: global_update_available_plugins");

   my $available = $context->global_get('available');
   for my $a (keys %$available) {
      $self->add_handlers("run_$a");
   }

   #{
      #no strict 'refs';
      #use Data::Dumper;
      #print Dumper(\%{"Plashy::Shell::"})."\n";
      #my $commands = $self->ps_get_commands;
      #for my $command (@$commands) {
         #print "** adding command [$command]\n";
         #${"Plashy::Shell::"}{"run_$command"} = 1;
      #}
      #print Dumper(\%{"Plashy::Shell::"})."\n";
   #};

   return $self;
}

sub prompt_str {
   my $self = shift;

   return $self->ps1;
}

sub cmdloop {
   my $self = shift;

   $self->{stop} = 0;
   $self->preloop;

   my $buf = '';
   while (defined(my $line = $self->readline($self->prompt_str))) {
      $buf .= $self->ps_lookup_vars_in_line($line);

      if ($line =~ /[;{]\s*$/) {
         $self->ps_update_prompt('.. ');
         next;
      }

      $self->cmd($buf);
      $buf = '';
      $self->ps_update_prompt;

      last if $self->{stop};
   }

   return $self->postloop;
}

#
# Plashy::Shell stuff
#
sub ps_set_title {
   my $self = shift;
   my ($title) = @_;

   print "\c[];$title\a";

   return $self->title($title);
}

sub ps_lookup_var {
   my $self = shift;
   my ($var) = @_;

   my $context = $self->context;
   my $log = $context->log;

   if ($var =~ /^\$(\S+)/) {
      if (my $res = $context->do($var)) {
         $var =~ s/\$${1}/$res/;
      }
      else {
         $log->warning("ps_lookup_var: unable to lookup variable [$var]");
         last;
      }
   }

   return $var;
}

sub ps_lookup_vars_in_line {
   my $self = shift;
   my ($line) = @_;

   my $context = $self->context;
   my $log = $context->log;

   if ($line =~ /^\s*(?:run|set)\s+/) {
      my @t = split(/\s+/, $line);
      for my $a (@t) {
         if ($a =~ /^\$(\S+)/) {
            if (my $res = $context->do($a)) {
               $line =~ s/\$${1}/$res/;
            }
            else {
               $log->warning("ps_lookup_vars_in_line: unable to lookup variable [$a]");
               last;
            }
         }
      }
   }

   return $line;
}

sub ps_update_path_cwd {
   my $self = shift;

   my $cwd = peu_convert_path(getcwd());
   $self->path_cwd($cwd);

   return 1;
}

sub ps_set_path_home {
   my $self = shift;

   my $home = peu_convert_path(home());
   $self->path_home($home);

   return 1;
}

sub ps_update_prompt {
   my $self = shift;
   my ($str) = @_;

   if (! defined($str)) {
      my $cwd = $self->path_cwd;
      my $home = $self->path_home;
      $cwd =~ s/$home/~/;

      my $ps1 = "plashy $cwd> ";
      if ($^O =~ /win32/i) {
         $ps1 =~ s/> /\$ /;
      }
      elsif ($< == 0) {
         $ps1 =~ s/> /# /;
      }

      $self->ps1($ps1);
   }
   else {
      $self->ps1($str);
   }

   return 1;
}

sub ps_get_commands {
   my $self = shift;

   my $context = $self->context;
   my $log = $context->log;

   my $commands = $context->global_get('commands');
   if (! defined($commands)) {
      return [];
   }

   return [ split(',', $commands) ];
}

my $jobs = {};

sub ps_set_signals {
   my $self = shift;

   my @signals = grep { substr($_, 0, 1) ne '_' } keys %SIG;

   $SIG{TSTP} = sub {
      if (defined($jobs->{current})) {
         print "DEBUG SIGTSTP: ".$jobs->{current}->pid."\n";
         $jobs->{current}->kill("SIGTSTP");
         $jobs->{current}->kill("SIGINT");
         return 1;
      }
   };

   $SIG{CONT} = sub {
      if (defined($jobs->{current})) {
         print "DEBUG SIGCONT: ".$jobs->{current}->pid."\n";
         $jobs->{current}->kill("SIGCONT");
         return 1;
      }
   };

   $SIG{INT} = sub {
      if (defined($jobs->{current})) {
         print "DEBUG SIGINT: ".$jobs->{current}->pid."\n";
         $jobs->{current}->kill("SIGINT");
         undef $jobs->{current};
         return 1;
      }
   };

   return 1;
}

#
# Term::Shell::run stuff
#
sub run_say {
   my $self = shift;

   my $line = $self->line;
   $line =~ s/^say/print/;
   $line =~ s/$/."\n"/;

   return $self->cmd($line);
}

# For commands that do not need a terminal
sub run_command {
   my $self = shift;
   my (@args) = @_;

   my $context = $self->context;
   my $log = $context->log;

   my $out = '';
   IPC::Run::run(\@args, \undef, \$out);

   $context->call(sub {
      my %h = @_;

      return $_ = $h{out};
   }, out => $out) or return;

   print $out;

   return 1;
}

# For commands that need a terminal
sub run_system {
   my $self = shift;
   my (@args) = @_;

   my $context = $self->context;
   my $log = $context->log;

   if ($^O =~ /win32/i) {
      return system(@args);
   }
   else {
      eval("use Proc::Simple");
      if ($@) {
         chomp($@);
         $log->fatal("can't load Proc::Simple module: $@");
         return;
      }

      my $bg = (defined($args[-1]) && $args[-1] eq '&') || 0;
      if ($bg) {
         pop @args;
      }

      my $proc = Proc::Simple->new;
      $proc->start(@args);
      $jobs->{current} = $proc;
      if (! $bg) {
         my $status = $proc->wait; # Blocking until process exists
         return $status;
      }

      return $proc;
   }

   return;
}

sub run_ls {
   my $self = shift;

   if ($^O =~ /win32/i) {
      return $self->run_command('dir', @_);
   }
   else {
      return $self->run_command('ls', '-lF', @_);
   }
}

# XXX: off for now, need to work on it
sub _run_li {
   my $self = shift;
   my (@args) = @_;

   my $cwd = $self->path_cwd;

   my @files = io($cwd)->all;
   for my $this (@files) {
      my $file = io($this);
      my $name = $file->relative;
      next if $name =~ /^\./;

      my $size = $file->size;
      my $mtime = $file->mtime;
      my $uid = $file->uid;
      my $gid = $file->gid;
      #my $modes = $file->modes;

      print "$size $mtime $uid:$gid $file\n";
   }

   return 1;
}

sub run_history {
   my $self = shift;
   my ($c) = @_;

   my @history = $self->term->GetHistory;
   if (defined($c)) {
      return $self->cmd($self->ps_lookup_vars_in_line($history[$c]));
   }
   else {
      my $c = 0;
      for (@history) {
         print "[$c] $_\n";
         $c++;
      }
   }

   return 1;
}

# XXX: should be a brick, and run_save an alias.
sub run_save {
   my $self = shift;
   my ($data, $file) = @_;

   my $context = $self->context;
   my $log = $context->log;

   if (! defined($file)) {
      $log->error("save: pass \$data and \$file parameters");
      return;
   }

   $data = $self->ps_lookup_var($data);

   my $r = open(my $out, '>', $file);
   if (!defined($r)) {
      $log->error("save: unable to open file [$file] for writing: $!");
      return;
   }
   print $out $data;
   close($out);

   return 1;
}

sub run_cd {
   my $self = shift;
   my ($dir, @args) = @_;

   my $context = $self->context;
   my $log = $context->log;

   if (defined($dir)) {
      if (! -d $dir) {
         $log->error("cd: $dir: can't cd to this");
         return;
      }
      chdir($dir);
      $self->ps_update_path_cwd;
   }
   else {
      chdir($self->path_home);
      $self->ps_update_path_cwd;
      #$self->path_cwd($self->path_home);
   }

   $self->ps_update_prompt;

   return 1;
}

sub run_pwd {
   my $self = shift;

   print $self->path_cwd."\n";

   return 1;
}

sub run_doc {
   my $self = shift;
   my (@args) = @_;

   my $context = $self->context;
   my $log = $context->log;

   if (! defined($args[0])) {
      $log->error("you have to provide a module as an argument");
      return;
   }

   system('perldoc', @args);

   return 1;
}

sub run_sub {
   my $self = shift;
   my (@args) = @_;

   my $context = $self->context;
   my $log = $context->log;

   if (! defined($args[0])) {
      $log->error("you have to provide a function as an argument");
      return;
   }

   system('perldoc', '-f', @args);

   return 1;
}

sub run_src {
   my $self = shift;
   my (@args) = @_;

   my $context = $self->context;
   my $log = $context->log;

   if (! defined($args[0])) {
      $log->error("you have to provide a module as an argument");
      return;
   }

   system('perldoc', '-m', @args);

   return 1;
}

sub run_faq {
   my $self = shift;
   my (@args) = @_;

   my $context = $self->context;
   my $log = $context->log;

   if (! defined($args[0])) {
      $log->error("you have to provide a question as an argument");
      return;
   }

   system('perldoc', '-q', @args);

   return 1;
}

sub run_pl {
   my $self = shift;
   my (@args) = @_;

   my $context = $self->context;
   my $log = $context->log;

   my $line = $self->line;
   #print "[DEBUG] [$line]\n";
   $line =~ s/^pl\s+//;

   return $context->do($line);
}

sub run_su {
   my $self = shift;
   my ($cmd, @args) = @_;

   #print "[DEBUG] cmd[$cmd] args[@args]\n";
   if (defined($cmd)) {
      system('sudo', $cmd, @args);
   }
   else {
      system('sudo', $0);
   }

   return 1;
}

sub run_reload {
   my $self = shift;

   my $context = $self->context;
   my $log = $context->log;

   my $reloaded = Module::Reload->check;
   if ($reloaded) {
      $log->info("some modules were reloaded");
   }

   return 1;
}

# Just an alias
sub run_load {
   my $self = shift;
   my ($plugin) = @_;

   return $self->cmd("run global load $plugin");
}

sub run_show {
   my $self = shift;

   my $context = $self->context;
   my $log = $context->log;

   $context->call(sub {
      my $__lp_available = $global->available;
      my $__lp_loaded = $global->loaded;

      print "Plugin(s):\n";

      my @__lp_loaded = ();
      my @__lp_notloaded = ();

      my $__lp_total = 0;
      for my $k (sort { $a cmp $b } keys %$__lp_available) {
         #print "   $k";
         #print (exists $__lp_loaded->{$k} ? " [LOADED]\n" : "\n");
         exists($__lp_loaded->{$k}) ? push @__lp_loaded, $k : push @__lp_notloaded, $k;
         $__lp_total++;
      }

      my $__lp_count = 0;
      print "   Loaded:\n";
      for my $loaded (@__lp_loaded) {
         print "      $loaded\n";
         $__lp_count++;
      }
      print "   Count: $__lp_count\n";

      $__lp_count = 0;
      print "   Not loaded:\n";
      for my $notloaded (@__lp_notloaded) {
         print "      $notloaded\n";
         $__lp_count++;
      }
      print "   Count: $__lp_count\n";

      print "Total: $__lp_total\n";

      return 1;
   }) or return;

   return 1;
}

sub run_set {
   my $self = shift;
   my ($plugin, $k, $v) = @_;

   my $context = $self->context;
   my $log = $context->log;

   if (! defined($plugin)) {
      my $r = $context->call(sub {
         my $__lp_set = $global->set;
         my $__lp_count = 0;

         print "Set variable(s):\n";

         for my $plugin (sort { $a cmp $b } keys %$__lp_set) {
            for my $k (sort { $a cmp $b } keys %{$__lp_set->{$plugin}}) {
               print "   $plugin $k ".$__lp_set->{$plugin}->{$k}."\n";
               $__lp_count++;
            }
         }

         print "Total: $__lp_count\n";
      });
      if (! defined($r)) {
         $log->error("run_set1");
         return;
      }

      return 1;
   }

   my $r = $context->call(sub {
      my %args = @_;

      my $__lp_plugin = $args{plugin};

      if (! exists($global->loaded->{$__lp_plugin})) {
         die("plugin [$__lp_plugin] not loaded or does not exist\n");
      }
   }, plugin => $plugin);
   if (! defined($r)) {
      $log->error("run_set2");
      return;
   }

   $r = $context->call(sub {
      my %args = @_;

      my $__lp_plugin = $args{plugin};
      my $__lp_key = $args{key};
      my $__lp_val = $args{val};

      #$global->loaded->{$__lp_plugin}->init; # No init when just setting an attribute
      $global->loaded->{$__lp_plugin}->$__lp_key($__lp_val);
      $global->set->{$__lp_plugin}->{$__lp_key} = $__lp_val;
   }, plugin => $plugin, key => $k, val => $v);
   if (! defined($r)) {
      $log->error("run_set3");
      return;
   }

   return 1;
}

sub run_run {
   my $self = shift;
   my ($plugin, $method, @args) = @_;

   my $context = $self->context;
   my $log = $context->log;

   $context->call(sub {
      my %args = @_;

      my $__lp_method = $args{method};
      my $__lp_plugin = $args{plugin};
      my @__lp_args = @{$args{args}};

      my $__lp_run = $global->loaded->{$__lp_plugin};
      if (! defined($__lp_run)) {
         die("plugin [$__lp_plugin] not loaded\n");
      }

      $__lp_run->init; # Will init() only if not already done

      if (! $__lp_run->can("$__lp_method")) {
         die("no method [$__lp_method] defined for plugin [$__lp_plugin]\n");
      }

      $_ = $__lp_run->$__lp_method(@__lp_args);

      $global->shell->run_title("$_");

      return $_;
   }, plugin => $plugin, method => $method, args => \@args)
      or return;

   return 1;
}

sub run_title {
   my $self = shift;
   my ($title) = @_;

   $self->ps_set_title($title);

   return 1;
}

sub run_script {
   my $self = shift;
   my ($script) = @_;

   my $context = $self->context;
   my $log = $context->log;

   if (! defined($script)) {
      $log->error("run: you must provide a script to run");
      return;
   }

   if (! -f $script) {
      $log->error("run: script [$script] is not a file");
      return;
   }

   open(my $in, '<', $script)
      or die("[-] FATAL: Plashy::Shell::run_script: can't open file [$script]: $!\n");
   while (defined(my $line = <$in>)) {
      next if ($line =~ /^\s*#/);  # Skip comments
      chomp($line);
      $self->cmd($self->ps_lookup_vars_in_line($line));
   }
   close($in);

   return 1;
}

#
# Term::Shell::catch stuff
#
sub catch_run {
   my $self = shift;
   my (@args) = @_;

   my $context = $self->context;

   my $commands = $self->ps_get_commands;
   for my $command (@$commands) {
      if ($args[0] eq $command) {
         return $self->run_command(@args);
      }
   }

   my $available = $context->global_get('available') or return;
   if (defined($available)) {
      for my $brick (keys %$available) {
         if ($args[0] eq $brick) {
            print "DEBUG match[$brick]\n";
            #$self->ps_update_prompt("[$brick]> ");
            #$self->ps_update_prompt;
            #return $self->run_command(@args);
         }
      }
   }

   # Default to execute Perl commands
   return $self->run_pl(@args);
}

# XXX: move in Plashy::Ext
sub _ioa_dirsfiles {
   my $self = shift;
   my ($dir, $grep) = @_;

   #print "\nDIR[$dir]\n";

   my $context = $self->context;
   my $log = $context->log;

   my @dirs = ();
   eval {
      @dirs = io($dir)->all_dirs;
   };
   if ($@) {
      chomp($@);
      $log->error("$dir: dirs: $@");
      return [], [];
   }

   my @files = ();
   eval {
      @files = io($dir)->all_files;
   };
   if ($@) {
      chomp($@);
      $log->error("$dir: files: $@");
      return [], [];
   }

   #@dirs = map { $_ =~ s/^\///; $_ } @dirs;  # Remove leading slash
   #@files = map { $_ =~ s/^\///; $_ } @files;  # Remove leading slash
   @dirs = map { s/^\.\///; s/$/\//; $_ } @dirs;  # Remove leading slash, add a trailing /
   @files = map { s/^\.\///; $_ } @files;  # Remove leading slash

   #print "before[@dirs|@files]\n";

   if (defined($grep)) {
      @dirs = grep(/^$grep/, @dirs);
      @files = grep(/^$grep/, @files);
   }

   #print "after[@dirs|@files]\n";

   return \@dirs, \@files;
}

#
# Term::Shell::comp stuff
#
sub comp_run {
   my $self = shift;
   my ($word, $line, $start) = @_;

   #print "[DEBUG] word[$word] line[$line] start[$start]\n";

   my $context = $self->context;
   my $log = $context->log;

   my $available = $context->global_get('available');
   if (! defined($available)) {
      $log->warning("can't fetch available plugins");
      return ();
   }

   my @comp = ();
   for my $a (keys %$available) {
      #print "[$a] [$word]\n";
      push @comp, $a if $a =~ /^$word/;
   }

   return @comp;
}

sub comp_set {
   return shift->comp_run(@_);
}

sub comp_load {
   return shift->comp_run(@_);
}

sub comp_doc {
   my $self = shift;
   my ($word, $line, $start) = @_;

   my $context = $self->context;
   my $log = $context->log;

   #print "[DEBUG] word[$word] line[$line] start[$start]\n";

   my %comp = ();
   for my $inc (@INC) {
      if (! -d $inc) {
         next;
      }
      #print "[DEBUG] inc[$inc]\n";
      my $r = opendir(my $dir, $inc);
      if (! defined($r)) {
         $log->error("comp_doc: opendir: $dir: $!");
         next;
      }

      my @dirs = readdir($dir);
      my @comp = grep(/^$word/, @dirs);
      #print "@comp\n";
      for my $c (@comp) {
         $comp{$c}++;
      }
   }

   return keys %comp;
}

# Default to check for global completion value
sub catch_comp {
   my $self = shift;
   my ($word, $line, $start) = @_;

   #print "[DEBUG] word[$word] line[$line] start[$start]\n";

   my $dir = '.';
   if (defined($line)) {
      my $home = $self->path_home;
      $line =~ s/^~/$home/;
      if ($line =~ /^(.*)\/.*$/) {
         $dir = $1 || '/';
      }
   }

   #print "\nDIR[$dir]\n";

   my ($dirs, $files) = $self->_ioa_dirsfiles($dir, $line);

   return @$dirs, @$files;
}

#
# DESTROY
#
sub DESTROY {
   my $self = shift;

   if (defined($self->term) && $self->term->can('WriteHistory')) {
      if (defined(my $history = $self->plashy_history)) {
         $self->term->WriteHistory($history)
            or die("[-] FATAL: Plashy::Shell::DESTROY: ".
                   "can't write history file [$history]: $!\n");
      }
   }

   return 1;
}

1;

__END__

=head1 NAME

Plashy::Shell - The Plashy Shell

=head1 SYNOPSIS

   use Plashy::Shell;

   $Plashy::Shell::Logger = 'Plashy::Log::Console';
   my $shell = Plashy::Shell->new;

   $shell->cmdloop;

=head1 DESCRIPTION

Interactive use of the Plashy Shell.

=head2 GLOBAL VARIABLES

=head3 B<$Plashy::Shell::Logger>

Specify a logger class. Must be a class inherited from L<Plashy::Log>.

=head2 METHODS

=head3 B<new>

=head1 SEE ALSO

L<Plashy::Log>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2014, Patrice E<lt>GomoRE<gt> Auffret

You may distribute this module under the terms of the Artistic license.
See LICENSE.Artistic file in the source distribution archive.

=head1 AUTHOR

Patrice E<lt>GomoRE<gt> Auffret

=cut
