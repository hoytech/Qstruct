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
            ->set_str("hello world")
            ->set_str2("hello world"x100)
            ->set_strs(["HELLLLLLLLLLLLLLLLLLLLLLLLLLO!", "roflcopter"])
            ->set_blob("Q"x4096)
            ->set_blobs(["\x00", "Z"x100000])
            ->finish;

my $obj = MyObj->load($enc);

{
  $obj->get_str(my $val);
  Test::ZeroCopy::is_zerocopy($val, $enc);
}

{
  $obj->get_str2(my $val);
  Test::ZeroCopy::is_zerocopy($val, $enc);
}

{
  $obj->get_blob(my $val);
  Test::ZeroCopy::is_zerocopy($val, $enc);
}
