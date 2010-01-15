use strict;
use warnings;

package Sort::ByExample;

=head1 NAME

Sort::ByExample - sort lists to look like the example you provide

=head1 VERSION

version 0.005

=cut

our $VERSION = '0.005';

=head1 SYNOPSIS

  use Sort::ByExample
   cmp    => { -as => 'by_eng',   example => [qw(first second third fourth)] },
   sorter => { -as => 'eng_sort', example => [qw(first second third fourth)] };

  my @output = eng_sort(qw(second third unknown fourth first));
  # --> first second third fourth unknown

  # ...or...

  my @output = sort by_eng qw(second third unknown fourth first);
  # --> first second third fourth unknown

  # ...or...

  my $sorter = Sort::ByExample::sbe(\@example);
  my @output = $sorter->( qw(second third unknown fourth first) );
  # --> first second third fourth unknown

=head1 DESCRIPTION

Sometimes, you need to sort things in a pretty arbitrary order.  You know that
you might encounter any of a list of values, and you have an idea what order
those values go in.  That order is arbitrary, as far as actual automatic
comparison goes, but that's the order you want.

Sort::ByExample makes this easy:  you give it a list of example input it should
expect, pre-sorted, and it will sort things that way.  If you want, you can
provide a fallback sub for sorting unknown or equally-positioned data.

=cut

use Params::Util qw(_HASHLIKE _ARRAYLIKE _CODELIKE);
use Sub::Exporter -setup => {
  exports => { 
    sbe    => undef,
    cmp    => \'_build_cmp',
    sorter => \'_build_sorter',
  },
};

=head1 METHODS

=head2 sorter

  my $sorter = Sort::ByExample->sorter($example, $fallback);
  my $sorter = Sort::ByExample->sorter($example, \%arg);

The sorter method returns a subroutine that will sort lists to look more like
the example list.

C<$example> may be a reference to an array, in which case input will be sorted
into the same order as the data in the array reference.  Input not found in the
example will be found at the end of the output, sorted by the fallback sub if
given (see below).

Alternately, the example may be a reference to a hash.  Values are used to
provide sort orders for input values.  Input values with the same sort value
are sorted by the fallback sub, if given.

If given named arguments as C<%arg>, valid arguments are:

  fallback - a sub to sort data 
  xform    - a sub to transform each item into the key to sort

If no other named arguments are needed, the fallback sub may be given in place
of the arg hashref.

The fallback sub should accept two inputs and return either 1, 0, or -1, like a
normal sorting routine.  The data to be sorted are passed as parameters.  For
uninteresting reasons, C<$a> and C<$b> can't be used.

The xform sub should accept one argument and return the data by which to sort
that argument.  In other words, to sort a group of athletes by their medals:

  my $sorter = sbe(
    [ qw(Gold Silver Bronze) ],
    {
      xform => sub { $_[0]->medal_metal },
    },
  );

If both xform and fallback are given, then four arguments are passed to
fallback:

  a_xform, b_xform, a_original, b_original

=head2 cmp

  my $comparitor = Sort::ByExample->cmp($example, \%arg);

This routine expects the same sort of arguments as C<L</sorter>>, but returns a
subroutine that behaves like a C<L<sort|perlfunc/sort>> comparitor.  It will
take two arguments and return 1, 0, or -1.

C<cmp> I<must not> be given an C<xform> argument or an exception will be
raised.  This behavior may change in the future, but because a
single-comparison comparitor cannot efficiently perform a L<Schwartzian
transform|http://en.wikipedia.org/wiki/Schwartzian_transform>, using a
purpose-build C<L</sorter>> is a better idea.

=head1 EXPORTS

=head2 sbe

C<sbe> behaves just like C<L</sorter>>, but is a function rather than a method.
It may be imported by request.

=head2 sorter

The C<sorter> export builds a function that behaves like the C<sorter> method.

=head2 cmp

The C<cmp> export builds a function that behaves like the C<cmp> method.
Because C<sort> requires a named sub, importing C<cmp> can be very useful:

  use Sort::ByExample
   cmp    => { -as => 'by_eng',   example => [qw(first second third fourth)] },

  my @output = sort by_eng qw(second third unknown fourth first);
  # --> first second third fourth unknown

=cut

sub sbe { __PACKAGE__->sorter(@_) }

sub __normalize_args {
  my ($self, $example, $arg) = @_;

  my $score = 0;
  my %score = _HASHLIKE($example)  ? %$example
            : _ARRAYLIKE($example) ? (map { $_ => $score++ } @$example)
            : Carp::confess "invalid example data given to Sort::ByExample";

  my $fallback;
  if (_HASHLIKE($arg)) {
    $fallback = $arg->{fallback};
  } else {
    $fallback = $arg;
    $arg = {};
  }

  Carp::croak "invalid fallback routine"
    if $fallback and not _CODELIKE($fallback);

  return (\%score, $fallback, $arg);
}

sub __cmp {
  my ($self, $score, $fallback, $arg) = @_;

  return sub ($$) {
    my ($a, $b) = @_;
      (exists $score->{$a} && exists $score->{$b})
        ? ($score->{$a} <=> $score->{$b}) || ($fallback ? $fallback->($a, $b) : 0)
    : exists $score->{$a}                        ? -1
    : exists $score->{$b}                        ? 1
    : ($fallback ? $fallback->($a, $b) : 0)
  };
}

sub cmp {
  my ($self, $example, $rest) = @_;

  my ($score, $fallback, $arg) = $self->__normalize_args($example, $rest);

  Carp::confess "you may not build a transformation into a comparitor"
    if $arg->{xform};

  $self->__cmp($score, $fallback, $arg);
}

sub sorter {
  my ($self, $example, $rest) = @_;

  my ($score, $fallback, $arg) = $self->__normalize_args($example, $rest);

  if (my $xf = $arg->{xform}) {
    return sub {
      map  { $_->[1] }
      sort {
        (exists $score->{$a->[0]} && exists $score->{$b->[0]})
          ? ($score->{$a->[0]} <=> $score->{$b->[0]})
            || ($fallback ? $fallback->($a->[0], $b->[0], $a->[1], $b->[1]) : 0)
      : exists $score->{$a->[0]}                        ? -1
      : exists $score->{$b->[0]}                        ? 1
      : ($fallback ? $fallback->($a->[0], $b->[0], $a->[1], $b->[1]) : 0)
      } map { [ $xf->($_), $_ ] } @_;
    }
  }

  my $cmp = $self->__cmp($score, $fallback, $arg);

  sub { sort { $cmp->($a, $b) } @_ }
}

sub _build_sorter {
  my ($self, $name, $arg) = @_;
  my ($example) = $arg->{example};
  local $arg->{example};

  $self->sorter($example, $arg);
}

sub _build_cmp {
  my ($self, $name, $arg) = @_;
  my ($example) = $arg->{example};
  local $arg->{example};

  $self->cmp($example, $arg);
}

=head1 TODO

=over

=item * provide a way to say "these things occur after any unknowns"

=back

=head1 AUTHOR

Ricardo Signes, E<lt>rjbs@cpan.orgE<gt>

=head1 COPYRIGHT

(C) 2007 - 2010, Ricardo Signes.  This is free software, available under the
same terms as Perl itself.

=cut

1;
