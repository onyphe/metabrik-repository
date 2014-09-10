#
# $Id$
#
package MetaBricky::Brick;
use strict;
use warnings;

use base qw(Class::Gomor::Array);

our @AS = qw(
   global
   debug
   inited
);

__PACKAGE__->cgBuildIndices;
__PACKAGE__->cgBuildAccessorsScalar(\@AS);

sub new {
   my $self = shift->SUPER::new(
      debug => 0,
      inited => 0,
      @_,
   );

   my $href = $self->default_values;
   for my $k (keys %$href) {
      $self->$k($href->{$k});
   }

   return $self;
}

sub default_values {
   return {};
}

sub init {
   my $self = shift;

   if ($self->inited) {
      return;
   }

   $self->inited(1);

   return $self;
}

sub require_variables {
   my $self = shift;
   my (@vars) = @_;

   die("you must set variable(s): ".join(', ', @vars)."\n");
}

sub self {
   my $self = shift;

   return $self;
}

sub DESTROY {
   my $self = shift;

   return $self;
}

1;

__END__