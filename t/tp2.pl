use strict;

use Qstruct;
use Data::Dumper;

my $b = Qstruct::Builder->new();
$b->set_uint64(32, 0x123456789abcdef0);
$b->set_bool(16, 4, 1);
$b->set_string(64, "hello!");
my $l = $b->render;

printf("%x\n", Qstruct::Runtime::get_uint64($l, 32));
print "OMG: " . Qstruct::Runtime::get_bool($l, 16, 4) . "\n";
Qstruct::Runtime::get_string($l, 64, my $str);
print "LOL: [$str]\n";
