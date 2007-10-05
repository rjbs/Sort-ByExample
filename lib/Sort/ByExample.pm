use strict;
use warnings;

package Sort::ByExample;

=head1 NAME

Sort::ByExample - sort lists to look like the example you provide

=head1 VERSION

version 0.001

=cut

our $VERSION = '0.001';

=head1 SYNOPSIS

  use Sort::ByExample 'sbe';

  my @example = qw(first second third fourth);
  my $sorter = sbe(\@example);

  my @output = $sorter->(qw(second third unknown fourth first));

  # output is: first second third fourth unknown

=head1 DESCRIPTION

Sometimes, you need to sort things in a pretty arbitrary order.  You know that
you might encounter any of a list of values, and you have an idea what order
those values go in.  That order is arbitrary, as far as actual automatic
comparison goes, but that's the order you want.

Sort::ByExample makes this easy:  you give it a list of example input it should
expect, pre-sorted, and it will sort things that way.  If you want, you can
provide a fallback sub for sorting unknown or equally-positioned data.

=cut

use Params::Util qw(_HASHLIKE _ARRAYLIKE);
use Sub::Exporter -setup => {
  exports => [ qw(sbe) ],
};

=head1 FUNCTIONS

=head2 sbe

  my $sorter = sbe($example, $fallback);

This function returns a subroutine that will sort lists to look more like the
example list.

The example may be a reference to an array, in which case input will be sorted
into the same order as the data in the array reference.  Input not found in the
example will be found at the end of the output, sorted by the fallback sub if
given (see below).

Alternately, the example may be a reference to a hash.  Values are used to
provide sort orders for input values.  Input values with the same sort value
are sorted by the fallback sub, if given.

The fallback sub should accept two inputs and return either 1, 0, or -1, like a
normal sorting routine.  The data to be sorted are passed as parameters.  For
uninteresting reasons, C<$a> and C<$b> can't be used.

C<sbe> is only exported by request.

=cut

sub sbe {
  my ($example, $fallback) = @_;

  my $score = 0;
  my %score = _HASHLIKE($example)  ? %$example
            : _ARRAYLIKE($example) ? (map { $_ => $score++ } @$example)
            : Carp::confess "invalid data passed to sbe";

  sub {
    sort {
      (exists $score{$a} && exists $score{$b}) ? ($score{$a} <=> $score{$b})
                                              || ($fallback ? $fallback->($a, $b) : 0)
    : exists $score{$a}                        ? -1
    : exists $score{$b}                        ? 1
    : ($fallback ? $fallback->($a, $b) : 0)
    } @_;
  }
}

=head1 TODO

=over

=item * let sbe act as a generator for installing sorting subs

=item * provide a way to say "these things occur after any unknowns"

=back

=head1 AUTHOR

Ricardo SIGNES, E<lt>rjbs@cpan.orgE<gt>

=head1 COPYRIGHT

(C) 2007, Ricardo SIGNES.  This is free software, available under the same
terms as Perl itself. 

=cut

1;
