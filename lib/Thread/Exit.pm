package Thread::Exit;

# Make sure we have version info for this module
# Make sure we do everything by the book from now on

our $VERSION = '0.01';
use strict;

# Make sure we only load stuff when we actually need it

use AutoLoader 'AUTOLOAD';

# Make sure we can do threads
# Make sure we can serialize

use threads ();
use Thread::Serialize ();

# Clone detection logic
# Thread local reference to original threads::new (set in BEGIN)
# Thread local flag to indicate we're exiting
# Thread local flag for automatic inheritance
# Thread local reference to END routine that executes after thread has ended

my $CLONE = 0;
my $new;
my $exiting = 0;
our $automatic = 0;
our $end;

# Make sure we do this before anything else
#  Allow for dirty tricks
#  Hijack the thread creation routine with a sub that
#   Saves the class
#   Save the context

BEGIN {
    no strict 'refs';
    $new = \&threads::new;
    *threads::new = sub {
        my $class = shift;
        my $sub = shift;
        my $wantarray = wantarray;

#   Save the original reference of sub to execute
#   Creates a new thread with a sub
#    Execute the original sub within an eval {} context and save returnn values
#    Save the result of the eval
#    Execute the end routine (if there is one)

        $new->( $class,sub {
            my @return = eval { $sub->( @_ ) };
            my $data = $@;
            &$end if $end;

#    If we're exiting
#     Make sure we remove what was there to preserve the data
#     Thaw the data to be returned
#    Elsif we died in another way inside the thread
#     Show the error
#    Return whatever we need to return

            if ($exiting) {
                chomp( $data );
                @return = Thread::Serialize::thaw( $data );
            } elsif ($data) {
                warn $data;
            }
            return $wantarray ? @return : $return[0];
        },@_ );
    };

#  Steal the system exit with a sub
#   If we're in a thread started after this was loaded
#    Set the exiting flag
#    Freeze parameters and use that to die with (winds up in $@ later)
#   Elsif we're in mod_perl (and in originating thread)
#    Call the mod_perl exit routine
#   Perform the standard exit

    *CORE::GLOBAL::exit = sub {
        if ($CLONE) {
            $exiting = 1;
            die Thread::Serialize::freeze( @_ ).$/;
        } elsif (exists( &Apache::exit )) {
            goto &Apache::exit;
        }
        goto &CORE::exit;
    };
} #BEGIN

# Satisfy -require-

1;

#---------------------------------------------------------------------------

# standard Perl features

#---------------------------------------------------------------------------

sub CLONE {

# Mark this thread as a child
# Disable end sub if not automatically inheriting

    $CLONE++;
    $end = undef unless $automatic;
} #CLONE

#---------------------------------------------------------------------------

# AutoLoader takes over from here

__END__

#---------------------------------------------------------------------------

# class methods

#---------------------------------------------------------------------------
#  IN: 1 class (ignored)
#      2 new subroutine specification (undef to disable)
#      3 flag: chain before (-1), after (1) or replace (0 = default)
# OUT: 1 current code reference

sub end {

# If we have a new subroutine specification
#  Get new setting
#  If it is not empty and not a code reference yet
#   Make the subref absolute if it isn't yet
#   Convert to a code ref

    if (@_ > 1) {
        my $new = $_[1];
        if ($new and !ref($new)) {
            $new = caller().'::'.$new unless $new =~ m#::#;
            $new = \&$new;
        }

#  If we have an old and a new subroutine and we're not replacing
#   Obtain copy of current code ref
#   If chaining this before current
#    Create closure anonymous sub with new one first
#   Else (chaining after current)
#    Create closure anonymous sub with old one first

        if ($end and $new and $_[2]) {
            my $old = $end;
            if ($_[2] < 0) {
	        $end = sub { &$new; &$old };
            } else {
	        $end = sub { &$old; &$new };
            }

#  Else (resetting or replacing or no old)
#   Just set the new value
# Return the current code reference

        } else {
            $end = $new;
        }
    }
    $end;
} #end

#---------------------------------------------------------------------------
#  IN: 1 class (ignored)
#      2 new setting of automatic flag
# OUT: 1 current setting of automatic flag

sub automatic {

# Set new automatic flag if one specified
# Return current setting

    $automatic = $_[1] if @_ > 1;
    $automatic;
} #automatic
#  IN: 1 class (ignored)
#      2..N method/value hash

#---------------------------------------------------------------------------
#  IN: 1 class
#      2..N method/value hash

sub import {

# Get the parameter hash
# For all of the methods and values
#  Die now if invalid method
#  Call the method with the value

    my ($class,%param) = @_;
    while (my ($method,$value) = each %param) {
        die "Cannot call method $method during initialization\n"
         unless $method =~ m#^(?:automatic|end)$#;
        $class->$method( $value );
    }
} #import

#---------------------------------------------------------------------------

=head1 NAME

Thread::Exit - provide thread-local exit() and END {}

=head1 SYNOPSIS

    use Thread::Exit (); # just make exit() thread local
    use Thread::Exit
     end => 'end_sub',   # set sub to exec at end of thread (default: none)
     automatic => 1,     # make all new threads end the same (default: 0)
    ;

    Thread::Exit->end( \$end_sub ); # set/adapt END sub later
    Thread::Exit->end( undef );     # disable END sub
    $end = Thread::Exit->end;

    Thread::Exit->automatic( 1 );   # make all new threads use this end sub
    Thread::Exit->automatic( 0 );   # new threads won't use this end sub
    $automatic = Thread::Exit->automatic;

    $thread = threads->new( sub { exit( "We've exited" ) } );
    print $thread->join;            # prints "We've exited"

=head1 DESCRIPTION

                  *** A note of CAUTION ***

 This module only functions on Perl versions 5.8.0 and later.
 And then only when threads are enabled with -Dusethreads.  It
 is of no use with any version of Perl before 5.8.0 or without
 threads enabled.

                  *************************

This module add two features to threads that are sorely missed by some.

The first feature is that you can use exit() within a thread to return() from
that thread only.  Without this module, exit() stops B<all> threads and exits
to the calling process (which usually is the operating system).  With this
module, exit() functions just as return() (including passing back values to
the parent thread).

The second feature is that you can specify a subroutine that will be executed
B<after> the thread is done, but B<before> the thread returns to the parent
thread.  Multiple "end" subroutines can be chained together if necessary.

=head1 MOD_PERL

To allow this module to function under Apache with mod_perl, a special check
is included for the existence of the Apache::exit() subroutine.  If that exists,
that exit routine will be preferred above the CORE::exit() routine when exiting
from the thread in which the first C<use Thread::Exit> occurred.

This may need further fine-tuning when I've actually tried this with Apache
myself.

=head1 CAVEATS

Because transport of data structures between threads is severely limited in
the current threads implementation (perl 5.8.0), data structures need to be
serialized.  This is achieved by using the L<Thread::Serialize> library.
Please check that module for information about the limitations (of any) of
data structure transport between threads.

=head1 TODO

Examples should be added.

=head1 AUTHOR

Elizabeth Mattijsen, <liz@dijkmat.nl>.

Please report bugs to <perlbugs@dijkmat.nl>.

=head1 COPYRIGHT

Copyright (c) 2002 Elizabeth Mattijsen <liz@dijkmat.nl>. All rights
reserved.  This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<threads>, L<Thread::Serialize>.

=cut
