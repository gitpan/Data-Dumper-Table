package Data::Dumper::Table;

use 5.018;
use utf8;
no diagnostics;

use Scalar::Util qw( reftype refaddr blessed );
use Text::Table;

use Exporter qw( import );
our @EXPORT = qw( Tabulate );

our $VERSION = 0.001;

our %seen;

sub Tabulate ($) {
    my ($thing) = @_;
    my $run = \do { my $o };
    $run = refaddr($run);
    $seen{ $run } = { };
    my $rv = _tblize($thing, $run);
    delete $seen{ $run };
    return $rv;
}

sub _tblize {
    my ($thing, $run) = @_;
    return '(* undef *)' unless defined $thing;
    my $r = reftype($thing);
    my $addr = uc sprintf('%x', refaddr($thing));
    my $alias
        = defined $thing
            ? ($r ? ($r . '(0x' . $addr . ')') : '( scalar )')
            : '(* undef *)'
            ;
    if (my $b = blessed($thing)) {
        $alias = $b . '=' . $alias;
    }
    if ($seen{ $run }->{ $alias }++) {
        return 'CIRCULAR->' . $alias;
    }
    my $container = Text::Table->new($alias);
    my $inner = $thing;
    if ($r eq 'ARRAY') {
        my %header;
        my @v = grep {
            ref($_) eq 'HASH' ?
            do {
                for my $k (keys %$_) {
                    undef $header{ $k };
                }
                1;
            } : undef
        } @$thing;
        if (@v == @$thing) {
            my @head = sort keys %header;
            $inner = Text::Table->new(@head);
            for my $row (@$thing) {
                my @body;
                for my $k (@head) {
                    push @body, (exists($row->{ $k }) ? _tblize($row->{ $k }, $run) : '(* no data *)');
                }
                $inner->add(@body);
            }
        }
        else {
            for my $row (@$thing) {
                $inner->add(_tblize($row, $run));
            }
        }
    }
    elsif ($r eq 'HASH') {
        my @keys = sort keys %$thing;
        $inner = Text::Table->new(qw( key value ));
        for my $k (@keys) {
            $inner->add($k, _tblize($thing->{ $k }, $run));
        }
    }
    elsif ($r eq 'CODE') {
        $inner = 'sub DUMMY { }'; # TODO for now
    }
    elsif (uc $r eq 'REGEXP') {
        $inner = "$thing";
    }
    elsif ($r) {
        $inner = 'REF->' . _tblize($$thing, $run); # TODO for now
    }
    else {
        $inner = "$thing";
    }
    $container->add("$inner");
    return "$container";
}

1;

__END__

=head1 NAME

Data::Dumper::Table - A more tabular way to Dumper your Data

=head1 VERSION

Version 0.001

=head1 SYNOPSIS

    use Data::Dumper::Table;

    say Tabulate $some_crazy_data_structure;

=head1 DESCRIPTION

The goal of Data::Dumper::Table is to provide a more-tabular alternative to Data::Dumper.

=head1 EXPORTED FUNCTIONS

=head2 Tabulate DATA

Turn the provided DATA into a (hopefully) nicely-formatted table. More verbose and space-hungry than Data::Dumer, but possibly easier to envision.

=head1 CAVEATS

=head2 This is Alpha software

This module is explicitly alpha-quality software. If you successfully use it in production, you're a braver being than I am.

=head1 TODO

=head2 Sortkeys

Replicate $Data::Dumper::Sortkeys

=head2 Deparse

Replicate $Data::Dumper::Deparse

=cut

