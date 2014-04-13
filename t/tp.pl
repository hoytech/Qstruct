use strict;

use Qstruct;
use Data::Dumper;

my $spec = q{
  qstruct asdf {
    aasdf @0 blob[2];
  }

  qstruct roflcopter {
    a @1 uint8;
    b @0 bool;
  }
};

Qstruct::parse_schema($spec)->iterate(sub {
  my $def = shift;
  #print Dumper(\@_);
  for(my $i=0; $i < $def->{num_items}; $i++) {
    print "WERD: " . Dumper(Qstruct::Definitions::get_item($def->{def_addr},$i));
  }
});
