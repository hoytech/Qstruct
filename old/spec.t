use strict;

use Qstruct;

Qstruct::load_schema(q{
  qstruct User {
    name @0 string;
    emails @1 string[];
    hash @2 int64[];
  }
});

my $bytes = User->encode({ name => 'jimmy',
                           emails => ['a@b.com', 'c@d.com'],
                           hash => "Q"x16,
                         });

my $user = User->decode($bytes);

my $emails = $user->emails;
for(my $i=0; $i < $emails->len; $i++) {
  $emails->get($i, my $email);
  print "email: $email\n";
}


__END__

#foreach my $c (@{ $user->hash }) {
#  print "$c\n";
#}
$user->hash->raw(my $hash);
print "[[$hash]]\n";

__END__

$user->emails->foreach(sub {
  print "email: $_\n";
});


my $hash = $user->raw;

print "[$hash]\n";


#my $bytes = User->build->name("jimmy")
#                       ->emails(["a@b.com", "c@d.com"])
#                       ->hash("\x00"x32)
#                       ->encode;

foreach my $email (@{ $user->emails }) {
  print "$email\n";
}

__END__

$user->name(my $name);
print "name is $name\n";

foreach my $c (@{ $user->hash }) {
  print "$c";
}
print "\n";

__END__

my $emails = $user->emails;
for(my $i=0; $i < $emails->num; $i++) {
  $emails->get($i, my $email);
  print "email: $email\n";
}

$user->emails->foreach(sub {
  print "email: $_[0]\n";
});

$user->hash->raw(my $hash);
print "HASH: $hash\n";
