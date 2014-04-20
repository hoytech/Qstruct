use strict;

use Test::More;
use Qstruct;

eval {
  require Test::ZeroCopy;
};

if ($@) {
  plan skip_all => "Test::ZeroCopy not installed";
} else {
  plan tests => 3;
}


Qstruct::load_schema(q{
  qstruct MyObj {
    str @0 string;
    str2 @1 string;
    strs @2 string[];
    blob @3 blob;
    blobs @4 blob[];
  }
});

my $enc = MyObj->build
            ->str("hello world")
            ->str2("hello world"x100)
            ->strs(["HELLLLLLLLLLLLLLLLLLLLLLLLLLO!", "roflcopter"])
            ->blob("Q"x4096)
            ->blobs(["\x00", "Z"x100000])
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
