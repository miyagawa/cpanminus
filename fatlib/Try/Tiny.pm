package Try::Tiny;

use strict;
#use warnings;

use vars qw(@EXPORT @EXPORT_OK $VERSION @ISA);

BEGIN {
	require Exporter;
	@ISA = qw(Exporter);
}

$VERSION = "0.09";

$VERSION = eval $VERSION;

@EXPORT = @EXPORT_OK = qw(try catch finally);

$Carp::Internal{+__PACKAGE__}++;

# Need to prototype as @ not $$ because of the way Perl evaluates the prototype.
# Keeping it at $$ means you only ever get 1 sub because we need to eval in a list
# context & not a scalar one

sub try (&;@) {
	my ( $try, @code_refs ) = @_;

	# we need to save this here, the eval block will be in scalar context due
	# to $failed
	my $wantarray = wantarray;

	my ( $catch, @finally );

	# find labeled blocks in the argument list.
	# catch and finally tag the blocks by blessing a scalar reference to them.
	foreach my $code_ref (@code_refs) {
		next unless $code_ref;

		my $ref = ref($code_ref);

		if ( $ref eq 'Try::Tiny::Catch' ) {
			$catch = ${$code_ref};
		} elsif ( $ref eq 'Try::Tiny::Finally' ) {
			push @finally, ${$code_ref};
		} else {
			use Carp;
			confess("Unknown code ref type given '${ref}'. Check your usage & try again");
		}
	}

	# save the value of $@ so we can set $@ back to it in the beginning of the eval
	my $prev_error = $@;

	my ( @ret, $error, $failed );

	# FIXME consider using local $SIG{__DIE__} to accumulate all errors. It's
	# not perfect, but we could provide a list of additional errors for
	# $catch->();

	{
		# localize $@ to prevent clobbering of previous value by a successful
		# eval.
		local $@;

		# failed will be true if the eval dies, because 1 will not be returned
		# from the eval body
		$failed = not eval {
			$@ = $prev_error;

			# evaluate the try block in the correct context
			if ( $wantarray ) {
				@ret = $try->();
			} elsif ( defined $wantarray ) {
				$ret[0] = $try->();
			} else {
				$try->();
			};

			return 1; # properly set $fail to false
		};

		# copy $@ to $error; when we leave this scope, local $@ will revert $@
		# back to its previous value
		$error = $@;
	}

	# set up a scope guard to invoke the finally block at the end
	my @guards =
    map { Try::Tiny::ScopeGuard->_new($_, $failed ? $error : ()) }
    @finally;

	# at this point $failed contains a true value if the eval died, even if some
	# destructor overwrote $@ as the eval was unwinding.
	if ( $failed ) {
		# if we got an error, invoke the catch block.
		if ( $catch ) {
			# This works like given($error), but is backwards compatible and
			# sets $_ in the dynamic scope for the body of C<$catch>
			for ($error) {
				return $catch->($error);
			}

			# in case when() was used without an explicit return, the C<for>
			# loop will be aborted and there's no useful return value
		}

		return;
	} else {
		# no failure, $@ is back to what it was, everything is fine
		return $wantarray ? @ret : $ret[0];
	}
}

sub catch (&;@) {
	my ( $block, @rest ) = @_;

	return (
		bless(\$block, 'Try::Tiny::Catch'),
		@rest,
	);
}

sub finally (&;@) {
	my ( $block, @rest ) = @_;

	return (
		bless(\$block, 'Try::Tiny::Finally'),
		@rest,
	);
}

{
  package # hide from PAUSE
    Try::Tiny::ScopeGuard;

  sub _new {
    shift;
    bless [ @_ ];
  }

  sub DESTROY {
    my @guts = @{ shift() };
    my $code = shift @guts;
    $code->(@guts);
  }
}

__PACKAGE__

__END__

