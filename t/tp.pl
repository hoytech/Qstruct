use strict;

use Qstruct;
use Data::Dumper;

my $spec = q{
  qstruct asdf {
        id @0 uint64;
        is_admin @1 bool;
        name @2 string;
        is_locked @3 bool;
  }

  #qstruct roflcopter {
  #  a @1 uint8;
  #  b @0 bool;
  #}
};

Qstruct::parse_schema($spec)->iterate(sub {
  my $def = shift;
  print Dumper($def);
  for(my $i=0; $i < $def->{num_items}; $i++) {
    print "WERD: " . Dumper(Qstruct::Definitions::get_item($def->{def_addr},$i));
  }
});
