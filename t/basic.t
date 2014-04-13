use strict;

use Test::More tests => 1;

use Qstruct;

my $def = Qstruct::parse(q{
    # asdfas
  qstruct Blah {
    # asdfas
    id @0 uint16;
    # asdfas
    email @1 string
    # asdfas
;

    a1 @2 bool;
    a2 @3 bool;
    a3 @4 bool;
    a4 @5 bool;
    a5 @6 bool;
    a6 @7 bool;
    a7 @8 bool;
/*
 *   a8 @9 bool;
 * a9 @10 bool;
*/
  }
});

is(ref $def, 'Qstruct::Definitions');
