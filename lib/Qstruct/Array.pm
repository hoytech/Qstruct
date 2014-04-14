package Qstruct::Array;

use strict;

use Tie::Array;
our @ISA = ('Tie::Array');

use Data::Dumper;


sub TIEARRAY {
  my $class = shift;
  my $obj = shift;
  return bless $obj, $class;
}

sub FETCH {
  my $self  = shift;
  my $index = shift;
  return $self->{a}->($index);
}

sub FETCHSIZE {
  my $self = shift;
  return $self->{n};
}


1;
