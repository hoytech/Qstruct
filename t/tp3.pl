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
        i32 @7 int32[];
        u16 @8 uint16[3];
        s8 @9 int8[];
        omg @10 float[6];
        np @11 string[];
      }
    });

    my $user_builder = MyPkg::User->build;
    $user_builder->set_id(100);
    $user_builder->set_name("jimmy"x4);
    $user_builder->set_email('jim@lol.com')
                 ->set_is_admin(1)
                 ->set_salary(128332.29)
                 ->set_temperatures([1.55, 934.334, 123456.9876, 7777777, -923343])
                 ->set_lols([1,2,3,45]);
    $user_builder->set_i32([-1,1,9123]);
    $user_builder->set_u16([0,1,-1]);
    $user_builder->set_s8([0,1,-1,255,128,127]);
    $user_builder->set_omg([3.1415, 945654, 4954.34, 123456.78, 234, 0.000023]);
    $user_builder->set_np(["asdf", "roflcopter", "abcdefghijklmnopqrstuvwxyz"]);
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

    for my $lol (@{ $user->get_i32 }) {
      print "  I32: $lol\n";
    }

    for my $lol (@{ $user->get_u16 }) {
      print "  U16: $lol\n";
    }

    for my $lol (@{ $user->get_s8 }) {
      print "  S8: $lol\n";
    }

    for my $lol (@{ $user->get_omg }) {
      print "  OMG: $lol\n";
    }

    for my $lol (@{ $user->get_np }) {
      print "  NP: $lol\n";
    }
