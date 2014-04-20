use strict;

use Test::More;
use Qstruct;

eval {
  require Test::ZeroCopy;
};

if ($@) {
  plan skip_all => "Test::ZeroCopy not installed";
} else {
  plan tests => 9;
}


Qstruct::load_schema(q{
  qstruct MyObj {
    str @0 string;
    str2 @1 string;
    strs @2 string[];
    blob @3 blob;
    blobs @4 blob[];
    hash @5 uint8[32];
    ints @6 uint8[];
  }
});

my $enc = MyObj->build
            ->str("hello world")
            ->str2("hello world"x100)
            ->strs(["HELLLLLLLLLLLLLLLLLLLLLLLLLLO!", "roflcopter"])
            ->blob("Q"x4096)
            ->blobs(["\x00", "Z"x100000])
            ->hash("Q"x32)
            ->ints([48, 49, 50, 51, 52])
            ->encode;

my $obj = MyObj->decode($enc);

{
  $obj->str(my $val);
  Test::ZeroCopy::is_zerocopy($val, $enc);
}

{
  $obj->str2(my $val);
  Test::ZeroCopy::is_zerocopy($val, $enc);
}

{
  $obj->blob(my $val);
  Test::ZeroCopy::is_zerocopy($val, $enc);
}

{
  $obj->hash->raw(my $val);
  Test::ZeroCopy::is_zerocopy($val, $enc);
  my $val2 = $obj->hash->raw;
  Test::ZeroCopy::isnt_zerocopy($val2, $enc);
}

{
  $obj->ints->raw(my $val);
  Test::ZeroCopy::is_zerocopy($val, $enc);
  my $val2 = $obj->ints->raw;
  Test::ZeroCopy::isnt_zerocopy($val2, $enc);
}

{
  $obj->strs->foreach(sub {
    Test::ZeroCopy::is_zerocopy($_[0], $enc);
  });
}
