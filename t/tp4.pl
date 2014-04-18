use strict; use Data::Dumper;

    use Qstruct;

    Qstruct::load_schema(q{
      qstruct MyPkg::User {
        id @0 uint64;
        accounts @1 blob[];
      }
    });

    my $user_builder = MyPkg::User->build;
    $user_builder->set_id(100);
    $user_builder->set_accounts(["asdf","abcdefghijklmnopqrstuvwxyz"]);
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
