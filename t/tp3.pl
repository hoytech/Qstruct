use strict; use Data::Dumper;

    use Qstruct;

    Qstruct::load_schema(q{
      qstruct MyPkg::User {
        id @0 uint64;
        is_admin @2 bool;
        name @1 string;
        email @3 string;
      }
    });

    my $user_builder = MyPkg::User->build;
    $user_builder->set_id(100);
    $user_builder->set_name("jimmy"x4);
    $user_builder->set_email('jim@lol.com');
    $user_builder->set_is_admin(1);
    my $encoded_data = $user_builder->finish;

    my $user = MyPkg::User->load($encoded_data);
    print "User id: " . $user->get_id . "\n";
    print "User name: " . $user->get_name . "\n";
    print "Email: " . $user->get_email . "\n";
    print "*** ADMIN ***\n" if $user->get_is_admin;

    $user->get_name(my $zero_copy_name);
    print "User name: $zero_copy_name\n";
    $user->get_email(my $zero_copy_email);
    print "Email: $zero_copy_email\n";
