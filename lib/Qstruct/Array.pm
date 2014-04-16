package Qstruct::Array;

use strict;
use Carp;

use Tie::Array;
our @ISA = ('Tie::Array');


sub TIEARRAY {
  my $class = shift;
  my $obj = shift;
  return bless $obj, $class;
}

sub FETCH {
  my $self = shift;
  my $index = shift;
  return $self->{a}->($index);
}

sub FETCHSIZE {
  my $self = shift;
  return $self->{n};
}

sub STORE {
  croak "unable to modify a read-only Qstruct array";
}


1;
