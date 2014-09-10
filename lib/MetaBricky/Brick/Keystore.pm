#
# $Id$
#
# Keystore brick
#
package Metabricky::Brick::Keystore;
use strict;
use warnings;

use base qw(Metabricky::Brick);

our @AS = qw(
   file
);
__PACKAGE__->cgBuildIndices;
__PACKAGE__->cgBuildAccessorsScalar(\@AS);

use Metabricky::Brick::Aes;
use Metabricky::Brick::Slurp;

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

   my $slurp = Metabricky::Brick::Slurp->new(
      global => $self->global,
      file => $self->file,
   );

   my $data = $slurp->text or die("can't slurp");

   my $aes = Metabricky::Brick::Aes->new(
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
