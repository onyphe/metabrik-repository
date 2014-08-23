#
# $Id$
#
# Keystore brick
#
package Plashy::Brick::Keystore;
use strict;
use warnings;

use base qw(Plashy::Brick);

our @AS = qw(
   file
);
__PACKAGE__->cgBuildIndices;
__PACKAGE__->cgBuildAccessorsScalar(\@AS);

use Plashy::Brick::Aes;
use Plashy::Brick::Slurp;

sub help {
   print "set keystore file <file>\n";
   print "\n";
   print "run keystore search <pattern>\n";
   #print "run keystore add <data>\n";
   #print "run keystore remove <data>\n";
}

sub search {
   my $self = shift;
   my ($pattern) = @_;

   if (! defined($self->file)) {
      die("set keystore file <file>\n");
   }

   if (! defined($pattern)) {
      die("run keystore search <pattern>\n");
   }

   my $slurp = Plashy::Brick::Slurp->new(
      global => $self->global,
      file => $self->file,
   );

   my $data = $slurp->text or die("can't slurp");

   my $aes = Plashy::Brick::Aes->new(
      global => $self->global,
   );

   my $decrypted = $aes->decrypt($data) or die("can't decrypt");

   my @lines = split(/\n/, $decrypted);
   for (@lines) {
      print "$_\n" if /$pattern/i;
   }

   return 1;
}

1;

__END__
