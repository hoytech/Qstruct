use strict; use Data::Dumper;

    use Qstruct;

    Qstruct::load_schema(q{
      qstruct MyPkg::User {
        id @0 uint64;
        accounts @1 string[];
        tp @2 uint8[];
      }
    });

    my $user_builder = MyPkg::User->build;
    $user_builder->set_id(100);
    $user_builder->set_tp([1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17]);
    my $encoded_data = $user_builder->finish;

    print $encoded_data;

my $user = MyPkg::User->load($encoded_data);
for my $s (@{ $user->get_accounts }) { print STDERR "[$s]\n" }
__END__

    my $user = MyPkg::User->load($encoded_data);
my $accts = $user->get_accounts;
#push @$accts, "LOL";
    foreach my $z (@$accts) {
      print "$z\n";
    }

__END__
    print "User id: " . $user->get_id . "\n";
    print "User name: " . $user->get_name . "\n";
    print "*** ADMIN ***\n" if $user->get_is_admin;

    $user->get_name(my $zero_copy_name);
    print "User name: $zero_copy_name\n";
