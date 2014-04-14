package Qstruct;

use strict;
use Carp;

use Qstruct::Array;

our $VERSION = '0.100';

require XSLoader;
XSLoader::load('Qstruct', $VERSION);



sub _install_closure {
  no strict 'refs';
  *{$_[0]} = $_[1];
}


sub load_schema {
  my $spec = shift;

  Qstruct::parse_schema($spec)->iterate(sub {
    my $def = shift;

    my $body_size = $def->{body_size};

    _install_closure("$def->{name}::build", sub {
      return bless { b => Qstruct::Builder->new($body_size), }, "$_[0]::Builder";
    });

    _install_closure("$def->{name}::load", sub {
      Qstruct::Runtime::sanity_check($_[1]) || croak "malformed qstruct (too short)";
      return bless { e => $_[1], }, "$_[0]::Loader";
    });

    _install_closure("$def->{name}::Builder::finish", sub {
      return $_[0]->{b}->render;
    });

    for(my $i=0; $i < $def->{num_items}; $i++) {
      my $item = Qstruct::Definitions::get_item($def->{def_addr}, $i);

      my $setter_name = "$def->{name}::Builder::set_$item->{name}";
      my $getter_name = "$def->{name}::Loader::get_$item->{name}";

      my $type = $item->{type};
      my $base_type = $type & 0xFFFF;
      my $fixed_array_size = $item->{fixed_array_size};
      my $is_unsigned = $type & (1<<16);
      my $is_array_fix = $type & (1<<17);
      my $is_array_dyn = $type & (1<<18);

      my $byte_offset = $item->{byte_offset};
      my $bit_offset = $item->{bit_offset};

      if ($base_type == 1) { # string
        _install_closure($setter_name, sub {
          $_[0]->{b}->set_string($byte_offset, $_[1]);
        });

        _install_closure($getter_name, sub {
          Qstruct::Runtime::get_string($_[0]->{e}, $byte_offset, exists $_[1] ? $_[1] : my $o);
          return $o if !exists $_[1];
        });
      } elsif ($base_type == 3) { # bool
        _install_closure($setter_name, sub {
          $_[0]->{b}->set_bool($byte_offset, $bit_offset, $_[1] ? 1 : 0);
        });

        _install_closure($getter_name, sub {
          Qstruct::Runtime::get_bool($_[0]->{e}, $byte_offset, $bit_offset);
        });
      } elsif ($base_type == 9) { # int64
        if ($is_array_dyn) {
          _install_closure($setter_name, sub {
            my $elems = scalar @{$_[1]};
            my $array_offset = $_[0]->{b}->set_array($byte_offset, $elems * 8, 8);
            for (my $i=0; $i<$elems; $i++) {
              $_[0]->{b}->set_uint64($array_offset + ($i * 8), $_[1]->[$i]);
            }
          });

          _install_closure($getter_name, sub {
            my $buf = $_[0]->{e};
            my ($array_base, $elems) = @{ Qstruct::Runtime::get_dyn_array($_[0]->{e}, $byte_offset, 8) };
            my @arr;
            tie @arr, 'Qstruct::Array',
                      {
                        n => $elems,
                        a => sub {
                               return undef if $_[0] >= $elems;
                               return Qstruct::Runtime::get_uint64($buf, $array_base + ($_[0] * 8), 1);
                             },
                      };
            return \@arr;
          });
        } else {
          _install_closure($setter_name, sub {
            $_[0]->{b}->set_uint64($byte_offset, $_[1]);
          });

          _install_closure($getter_name, sub {
            Qstruct::Runtime::get_uint64($_[0]->{e}, $byte_offset);
          });
        }
      } else {
        croak "unknown type: $base_type/$type";
      }
    }
  });
}




1;


__END__

=encoding utf-8

=head1 NAME

Qstruct - Quick structure serialisation

=head1 SYNOPSIS

    use Qstruct;

    ## Parse and load schema
    Qstruct::load_schema(q{
      ## This is my schema

      qstruct MyPkg::User {
        id @0 uint64;
        is_admin @2 bool;
        name @1 string;
        account_ids @3 uint64[];
      }
    });

    ## Build a new user message
    my $user_builder = MyPkg::User->build;
    $user_builder->set_id(100);
    $user_builder->set_name("jimmy");
    $user_builder->set_is_admin(1);
    $user_builder->set_account_ids([1234,5678]);
    my $message = $user_builder->finish;

    ## Load a user message and access some fields
    my $user = MyPkg::User->load($message);
    print "User id: " . $user->get_id . "\n";
    print "User name: " . $user->get_name . "\n";
    print "*** ADMIN ***\n" if $user->get_is_admin;

    ## Zero-copy access of strings/blobs
    $user->get_name(my $name);

    ## Arrays
    foreach my $id (@{ $user->get_account_ids }) {
      print "$id\n";
    }


=head1 DESCRIPTION

B<Qstruct> is a binary data serialisation format. Unlike L<Storable>, L<Data::MessagePack>, L<Sereal>, L<CBOR::XS> etc, Qstruct requires a schema. This makes it more like L<ASN.1|http://www.itu.int/en/ITU-T/asn1/Pages/introduction.aspx>, L<Thrift::XS>, or L<Google::ProtocolBuffers>.

In addition to the above, Qstruct is heavily inspired by L<Cap'n Proto|http://kentonv.github.io/capnproto/>. I am indebted to Kenton Varda for thinking through and publishing many of the details of how this type of serialisation should work. Qstructs originally came about as an attempt to implement Cap'n Proto in perl.


=head1 GOALS

The goal of Qstruct is to provide as close as possible performance to C C<struct>s -- even ones containing pointers -- while also being portable, extensible, and safe. The way it does this is by making the "in-memory" representation the same as the "wire" representation. Because it's redundant to distinguish between these representations, this documentation will only refer to I<the> B<Qstruct format>.

C<Portable>: All integers and floating point numbers are stored in little-endian byte order and can start at unaligned offsets (if you load messages from unaligned offsets). Despite these restrictions, Qstructs can be used on any CPU, even ones that are big-endian or have strict alignment requirements.

C<Extensible>: New fields can be added to the structure as needed without invalidating already created messages. The fields can be renamed or moved within the qstruct schema as long as you don't change the types or C<@> ids of existing fields.

C<Safe>: Accessing data from untrusted sources should never cause the program to read or write out of bounds causing a segfault or worse. The Qstruct format is designed to be quite simple in order to help with verifying and testing this. Although not implemented yet, there is a canonicalisation specification in development so Qstructs will be cache-friendly and suitable for digitally signing.

C<Efficient>: Because there is no difference between "in-memory" versus "wire" formats, there is no encoding/decoding needed. Even for extremely large messages, loading is instantaneous (it just does some basic sanity checking of the message size and header information). If you only access a few fields of a message you don't pay any deserialisation costs for the fields you didn't access: You only pay for what you use. Furthermore, all operations are inherently zero-copy. In other words, the values you extract will always be pointers into the message data. The only copying that occurs is what you copy manually (see below).

=head1 SCHEMA LANGUAGE

The schema language is modeled very closely after the Cap'n Proto schema language.

A schema is a series of qstructs. Each qstruct contains 0 or more fields. Each field is 3 items: The name, the C<@> id, and the type specifier.

Whitespace is insignificant. C and perl-style comments are supported.

Here is an example schema:

      qstruct User {
        id @0 uint64;
        active @4 bool;
        name @2 string;
        email_addrs @3 string[]; # dynamic array (pointer-based)
        sha256_checksum @1 uint8[32]; # fixed array (inlined in body)
      }

      qstruct Some::Package::Junk {
        /* There can be multiple qstructs in a schema.
         * And this one is... empty!
         */
      }


=head1 TYPES

=over 4

=item  int

A family of types that differ in signedness, size, and alignment: C<int8>, C<int16>, C<int32>, C<int64>, C<uint8>, C<uint16>, C<uint32>, C<uint64>.

Always stored in little-endian byte order (even when in memory on big-endian machines).

Default: 0

=item  float/double

IEEE-754 floating point numbers in little-endian byte order. C<float> and <double> both consume and are aligned at 4 and 8 bytes respectively.

Default: 0.0

=item  boolean

A single-bit "flag". This is the only type where multiple values can be packed together inside a single-byte.

Default: 0 (false)


=item  string/blob

A pointer and size possibly referring to a subsequent part of the message. These fields consume at least 16 bytes each. The only difference between B<string>s and B<blob>s is that blobs are aligned at 16 bytes and are therefore suitable for maintaining alignment of nested qstructs.

Strings and blobs are both considered arbitrary sequences of bytes and neither type enforces any character encoding. I don't believe it is necessary for (or even the place of) a serialisation format to dictate encoding policy. Of course you are free to enforce/assume a common encoding for all of I<your> messages.

Neither strings nor blobs are NUL-byte terminated. Failure to adhere to the associated sizes of strings or blobs is a serious bug in your code. This is only an issue when using the L<libqstruct|https://github.com/hoytech/libqstruct> C API. In perl this is never a problem.

Qstruct strings employ a space optimisation called B<tagged-sizes>. This is the only "clever" packing trick in the Qstruct format. Because the alignment of strings doesn't matter and because 64 bit sizes have heaps of room to work with, string sizes are encoded specially. If the lower nibble of the first byte is zero then the whole 64-bit size is bit-shifted down 8 bits giving the size of the entity the pointer is pointing to. If the lower nibble of the first byte was instead non-zero, this nibble is taken to be an inline length and the pointer is ignored: Instead the string is located at the following byte and is free to use the remaining 7 bytes of the size and the 8 bytes of the following pointer. So, only strings of 15 (0xF) or fewer bytes can be size-tagged. Blobs never use tagged-sizes because of their alignment requirements.

Default: "" (empty string)


=back





=head1 FORMAT

=head2 MESSAGE

A message is a block of data representing a Qstruct. It is either in the process of being built or is read-only and suitable for accessing.

The message data should be considered a binary blob. It may contain NUL bytes so its length must be stored separately (ie, you can't count on a terminating NUL).

Messages can in theory be any size representable by an unsigned 64 bit number. However, on 32-bit machines some messages are too large to access and attempting to build or load/access these messages will throw exceptions.

Messages are not self-delimiting so when transmitting or storing they need to be framed in some fashion. For example, when sending across a socket you might choose to send an 8-byte little-endian integer before the message data to indicate the size of the message that follows. When you apply framing be aware that depending on how the receiver/loader implements framing it may impact data alignment.


=head2 HEADER

All Qstructs start with a 16 byte C<header>. The first 8 bytes are reserved and should always be 0s. The next 8 bytes are a little-endian unsigned 64-bit integer that indicate how large the following C<body> is (the body is always shorter than the total message size because it doesn't include the header or the heap).

    00000000  00 00 00 00 00 00 00 00  15 2f 00 00 00 00 00 00
              |--reserved (all 0s)--|  |body size (LE uint64)|

The reserved bytes are for future extensions such as schema versioning.



=head2 BODY

The body immediately follows the header. Its exact format depends on the schema. For example, consider the following schema:

    qstruct User {
      id @0 uint64;
      is_admin @1 bool;
      name @2 string;
      is_locked @3 bool;
    }

Suppose we create a message with the following data:

    my $user = User->build;
    $user->set_name("hello world!");
    $user->set_id(100);
    $user->set_is_admin(1);
    $user->set_is_locked(1);
    my $message = $user->finish;

Here is the hexdump of the resulting message:

    00000000  00 00 00 00 00 00 00 00  20 00 00 00 00 00 00 00  |................|
              |---------------------header-------------------|

    00000010  64 00 00 00 00 00 00 00  03 00 00 00 00 00 00 00  |d...............|
              |--------id (@0)------|  || |----free space----|
                                       ||
                                       |->is_admin|is_locked (@1|@3)

    00000020  0c 68 65 6c 6c 6f 20 77  6f 72 6c 64 21 00 00 00  |.hello world!...|
              || |--------inline string data--------| |--pad-|
              ||
              |-> name (@2) tag byte indicating length of inline string


When computing the body offsets, the Qstruct compiler will always try to find the first location in the message that a data type will fit into while still respecting the alignment preference of the data type. Essentially it works like a B<first-fit> memory allocator.

The body size needs to be stored in the header because the size of the body will change depending on the version of the schema. If a field that has an end offset beyond the message body is accessed, a default value is returned (see the types section).


=head2 HEAP

When a tagged size can't be used, either because it is a string exceeding 15 bytes in length or because the type prohibits it (ie it's a blob or an array), the value will be appended onto the B<heap>.

Heap locations are referenced by "pointers" which are actually offsets from the beginning of the header in bytes. For example, given the schema from the previous section, if the name is instead C<too long for tagged size> then it must be stored in the heap: 

    HDR:  00000000  00 00 00 00 00 00 00 00  20 00 00 00 00 00 00 00  |........ .......|
    BODY: 00000010  64 00 00 00 00 00 00 00  03 00 00 00 00 00 00 00  |d...............|
    BODY: 00000020  00 18 00 00 00 00 00 00  30 00 00 00 00 00 00 00  |........0.......|
                    |-------size << 8-----|  |----start offset-----|
    HEAP: 00000030  74 6f 6f 20 6c 6f 6e 67  20 66 6f 72 20 74 61 67  |too long for tag|
    HEAP: 00000040  67 65 64 20 73 69 7a 65                           |ged size|

The heap is also used for dynamic arrays. In contrast to fixed-size inline arrays which are allocated in the body, dynamic arrays point to a variable number of sequential elements in the heap.

In the case of dynamic arrays of strings or blobs in the array's heap location there may be additional pointers which refer to the array's elements.

Pointers must always point forwards (ie be larger than the offset of the pointer itself).

Because there is no first-class support for nested or linked data-types, the maximum pointer traversal depth is 2.



=head1 ARRAYS



=head1 ZERO-COPY



=head1 PORTABLE

This module uses the "slow" but portable accessors described in L<libqstruct|https://github.com/hoytech/libqstruct>'s docs so it should work on any machine regardless of endianess or alignment requirements. These accessors are not actually slow relative to the overhead of making a perl function or method call.

Because the perl module uses the slow and portable accessors, no matter what CPU you use you do not need to ensure that you load messages from aligned offsets. When using the C API, if you choose to compile with the non-portable accessors you should be aware that depending on your CPU you may have reliabilty or performance issues if you load messages from non-aligned offsets. However, on modern intel x86-64 CPUs you can use the "fast" interface and not sacrifice reliability or performance even when accessing non-aligned messages.


=head1 EXTENSIBLE

As long as you don't change existing fields' types or C<@> ids, you can always add new fields to a qstruct. Any messages that were created with the old schema will still be loadable. Accessing new fields in old messages will return the default values of their respective types.

You can change the name of any field as long as you don't change the C<@> id.

The order of the fields in a struct are irrelevant -- only the types and C<@> ids influence the packing order. Similarly, comments can be added/removed anywhere.

You can change the signedness of integer types as long as you are OK with effectively re-casting the data (ie negative ints become large positive ints or large positive ints become negative ints).

You can change a blob to a string (though this impacts canonicalisation) but you can't change a string to a blob (due to alignment).


=head1 SAFETY

=head2 SAFETY OF SCHEMA PARSING

Do not process schemas from potentially malicious sources. There are trivial memory consumption attacks possible. That said, the ragel finite state machine parser is very precise so there should be no code-execution attacks possible.

=head2 SAFETY OF LOADING/ACCESSING

If you use the wrong schema or the message has been corrupted by a malicious attacker then there should be no possibility of a segfault or reading/writing out of bounds. However, the message data will be garbage (but of course malicious messages can encode garbage data anyway).

When loading or accessing a message there should be no way to make this module consume any more memory than you explicitly copy out of it (see the zero copy section). In any one operation this will be at most the size of the message. With zero-copy accessors none of the message data is copied at all.

Unlike Cap'n Proto, the simplistic nature of the Qstruct format does not provide list-like/tree-like/nested data-structures so there is nothing to configure in the Qstruct implementation to prevent stack overflows, cycles, or recursion.

Note that you can treat blobs as nested Qstructs and manually traverse them (or arrays of them). If you do that in some data-directed (as opposed to code-directed) fashion you may have similar issues. I suggest using purely code-directed traversals if possible.


=head1 CANONICALISATION

This is not implemented yet but, subject to some constraints I will document here, messages can be efficiently converted into canonical forms. The C<copy> method will return a canonicalised version of a message. The biggest complication is canonicalisation across schema changes.

There is a lot to think about for this -- don't rely on this feature for security until at least all the following points are fleshed out: All pointers must point forward and be strictly increasing when traversed in a designated order. Null out all free and unallocated space. Make sure tagged-size optimisation is always applied when possible. Null out high bytes and high nibble in tagged-sizes. Ensure body is the right size for the current schema version. Ensure no extra padding on end of message. Null out reserved area. Normalise NaN representations (qNaN/sNan). Make sure 0-length strings/blobs/arrays always point to NULL.



=head1 SEE ALSO

L<Qstruct github repo|https://github.com/hoytech/Qstruct>

L<libqstruct github repo|https://github.com/hoytech/libqstruct>

=head1 AUTHOR

Doug Hoyte, C<< <doug@hcsw.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2014 Doug Hoyte.

This module is licensed under the same terms as perl itself.

The bundled C<libqstruct> is (C) Doug Hoyte and licensed under the 2-clause BSD license.
