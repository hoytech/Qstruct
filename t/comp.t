use strict;

use Test::More qw/no_plan/;
use Math::Int64 qw(int64 uint64);
use List::Util qw/shuffle/;

use Qstruct;

my $type_specs = {
  string => {
    vals => ["", "asdf", "QQQQQQQQQQQQQQQ", "ZZZZZZZZZZZZZZZ", "roflcopter"x1000],
    no_array_fixed => 1,
  },
  blob => {
    vals => ["", "asdf", "roflcopter"x1000],
    no_array_fixed => 0,
  },
  bool => {
    vals => [0, 1],
    no_array_dyn => 0,
    no_array_fixed => 0,
  },
  int8 => {
    vals => [0, 1, -1, 127],
  },
  uint8 => {
    vals => [0, 198, 255],
  },
  int16 => {
    vals => [0, -10, -32767],
  },
  uint16 => {
    vals => [0, 12345, 65535],
  },
  int32 => {
    vals => [0, -100, 2147483647],
  },
  uint32 => {
    vals => [0, 2713640343, 4294967296],
  },
  int64 => {
    vals => [int64('0'), int64('-1000'), int64('9223372036854775807')],
  },
  uint64 => {
    vals => [uint64('0'), uint64('9876543210'), uint64('18446744073709551616')],
  },
  float => {
    vals => [0, -1.2339999744e+10],
  },
  double => {
    vals => [0, 1.28089993101642e-31],
  },
};


sub run_test {
  my $schema = "qstruct TestSchema {\n";

  for my $i (0..$#_) {
    $schema .= "i$i \@$i $_[$i];\n";
  }

  $schema .= "}\n";

  #print STDERR "SCHEMA: $schema\n";

  Qstruct::load_schema($schema);

  my $builder = TestSchema->build;

  my @build_order = shuffle 0..$#_;
  my @test_vals;

  for my $i (@build_order) {
    my $method = "set_i$i";
    $test_vals[$i] = gen_rand_vals($_[$i]);
    #use Data::Dumper; print STDERR "$method: ".Dumper($test_vals[$i]);
    $builder->$method($test_vals[$i]);
  }

  my $encoded = $builder->finish;
  undef $builder;

  #print $encoded;

  my $obj = TestSchema->load($encoded);

  for my $i (0..$#_) {
    my $method = "get_i$i";
    my $val = $obj->$method;
    is_deeply($val, $test_vals[$i], "$_[$i]");
  }
}

sub gen_rand_vals {
  my $spec = shift;

  $spec =~ m/^(\w+)/ || die "unknown type spec [$spec]";
  my $type = $1;

  my $type_spec = $type_specs->{$type} || die;

  if ($spec =~ m/\[(\d+)\]$/) {
    my $array_size = $1;
    die "$type can't be fixed array" if $type_spec->{no_array_fixed};
    return [ map { pick_rand($type_spec->{vals}) } 1..$array_size ];
  } elsif ($spec =~ m/\[\]$/) {
    die "$type can't be dyn array" if $type_spec->{no_array_dyn};
    return [ map { pick_rand($type_spec->{vals}) } 0..rand(10) ];
  } else {
    return pick_rand($type_spec->{vals});
  }
}

sub pick_rand {
  my $arr_ref = shift;
  return $arr_ref->[rand(scalar @$arr_ref)];
}





srand(0);

run_test(qw{ int8 bool string[] bool uint64[4] float });
run_test(qw{ string[] string[] });
