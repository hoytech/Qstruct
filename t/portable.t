use strict;

use Test::More qw/no_plan/;
use Math::Int64 qw/int64 uint64/;

use Qstruct;

run(
  file => "basic-ints",

  schema => q{
    i8 @0 int8;
    i16 @1 int16;
    i32 @2 int32;
    i64 @3 int64;

    i8 @4 uint8;
    i16 @5 uint16;
    i32 @6 uint32;
    i64 @7 uint64;

    f @8 float;
    d @9 double;
  },

  vals => {
    i8 => -120,
    i16 => 1,
    i32 => -2,
    i64 => Math::Int64::int64('-258426325028528675187087700672'),
  },
);



sub run {
  my (%args) = @_;

  Qstruct::load_schema("qstruct TestSchema { $args{schema} }");

  my $filename = "t/portable-msgs/$args{file}.msg";

  if ($ENV{QSTRUCT_TEST_PORTABLE_CREATE_MESSAGES}) {
    die "must be run from root dir of dist" if !-d 't/portable-msgs/';
    print "Encoding to $filename\n";
    open(my $fh, '>:raw', $filename) || die "couldn't write to $filename: $!";
    print $fh TestSchema->encode($args{vals});
    return;
  }

  my $msg = do {
    local $/;
    open(my $fh, '<:raw', $filename) || die "couldn't open $filename: $!";
    <$fh>
  };

  my $obj = TestSchema->decode($msg);

  foreach my $key (sort keys %{ $args{vals} }) {
    is_deeply($args{vals}->{$key}, $obj->$key, "$args{file}: $key");
  }
}
