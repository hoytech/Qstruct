use strict; use Data::Dumper;

    use Qstruct;

    Qstruct::load_schema(q{
      qstruct MyPkg::User {
        id @0 uint64;
        is_admin @2 bool;
        name @1 string;
      }
    });

    my $user_builder = MyPkg::User->build;
    $user_builder->set_id(100);
    $user_builder->set_name("jimmy");
    $user_builder->set_is_admin(1);
    my $encoded_data = $user_builder->finish;

    my $user = MyPkg::User->load($encoded_data);
    print "User id: " . $user->get_id . "\n";
    print "User name: " . $user->get_name . "\n";
    print "*** ADMIN ***\n" if $user->get_is_admin;

    $user->get_name(my $zero_copy_name);
    print "User name: $zero_copy_name\n";
