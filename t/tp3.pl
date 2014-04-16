use strict; use Data::Dumper;

    use Qstruct;

    Qstruct::load_schema(q{
      qstruct MyPkg::User {
        id @0 uint64;
        is_admin @2 bool;
        name @1 string;
        email @3 string;
        salary @4 double;
        temperatures @5 double[];
        lols @6 uint64[4];
      }
    });

    my $user_builder = MyPkg::User->build;
    $user_builder->set_id(100);
    $user_builder->set_name("jimmy"x4);
    $user_builder->set_email('jim@lol.com');
    $user_builder->set_is_admin(1);
    $user_builder->set_salary(128332.29);
    $user_builder->set_temperatures([1.55, 934.334, 123456.9876, 7777777, -923343]);
    $user_builder->set_lols([1,2,3,45]);
    my $encoded_data = $user_builder->finish;

    my $user = MyPkg::User->load($encoded_data);
    print "User id: " . $user->get_id . "\n";
    print "User name: " . $user->get_name . "\n";
    print "Email: " . $user->get_email . "\n";
    print "Salary: " . $user->get_salary . "\n";
    print "*** ADMIN ***\n" if $user->get_is_admin;

    $user->get_name(my $zero_copy_name);
    print "User name: $zero_copy_name\n";
    $user->get_email(my $zero_copy_email);
    print "Email: $zero_copy_email\n";

    for my $temp (@{ $user->get_temperatures }) {
      print "  TMP: $temp\n";
    }

    for my $lol (@{ $user->get_lols }) {
      print "  LOL: $lol\n";
    }
