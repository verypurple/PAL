package PAL::Parser;

use warnings;
use strict;

use Exporter qw(import);
our @EXPORT = qw(parse build_ast);

sub addtochart
{
	no warnings 'experimental::smartmatch';

	my ($chart, $index, $state) = @_;

	for my $el (@{$chart->[$index]}) {
		if ($el ~~ $state) {
			return 0;
		}
	}

	push(@{$chart->[$index]}, $state);

	return 1;
}

sub p_closure
{
	my ($grammar, $i, $x, $ab, $cd) = @_;

	if (@$cd) {
		return [map { [$cd->[0], [], $_, $i] } @{$grammar->{$cd->[0]}}];
	}
	else {
		return [];
	}
}

sub p_shift
{
	my ($tokens, $i, $x, $ab, $cd, $j) = @_;

	if (@$cd and $tokens->[$i]->[0] eq $cd->[0]) {
		return [$x, [@$ab, $cd->[0]], [@$cd[1..$#$cd]], $j];
	}
	else {
		return 0;
	}
}

sub p_reduce
{
	my ($chart, $i, $x, $ab, $cd, $j) = @_;

	if (!@$cd) {
		my $prev = [grep { @{$_->[2]} and $_->[2][0] eq $x } @{$chart->[$j]}];
		my $next = [map { [$_->[0], [@{$_->[1]}, $x], [@{$_->[2]}[1..$#{$_->[2]}]], $_->[3]] } @$prev];

		return $next;
	}
	else {
		return [];
	}
}

sub parse
{
	no warnings 'experimental::smartmatch';

	my ($grammar, $accepting_rule, $tokens, $p_funcs) = @_;

	push(@$tokens, ['EOT', \0]);

	my $chart = [map { [] } (0..$#$tokens)];
	$chart->[0] = [map { [$accepting_rule, [], $_, 0] } @{$grammar->{$accepting_rule}}];

	my $tree = [];
	my $q = 0;

	for my $i (0..$#$tokens) {
		while (1) {
			my $all_changes = 0;

			for my $state (@{$chart->[$i]}) {
				$q++;
				my ($x, $ab, $cd, $j) = @$state;

				my $next_states = p_closure($grammar, $i, $x, $ab, $cd, $j);
				for my $next_state (@$next_states) {
					$all_changes |= addtochart($chart, $i, $next_state);
				}

				my $next_state = p_shift($tokens, $i, $x, $ab, $cd, $j);
				if ($next_state != 0) {
					$all_changes |= addtochart($chart, $i + 1, $next_state);
				}

				$next_states = p_reduce($chart, $i, $x, $ab, $cd, $j);
				for $next_state (@$next_states) {
					$all_changes |= addtochart($chart, $i, $next_state);
				}
			}

			if (!$all_changes) {
				last;
			}
		}
	}	
	
	for my $rule (@{$grammar->{$accepting_rule}}) {
		my $accepting_state = [$accepting_rule, $rule, [], 0];

		for my $el (@{$chart->[$#$tokens]}) {
			if ($el ~~ $accepting_state) {
				my $stack = [map { [@{$_}[0,1,3]] } grep { !@{$_->[2]} } map { @$_ } @$chart];

				return $stack;
			}
		}
	}

	return 0;
}

sub build_ast
{
	my ($stack, $tokens, $p_funcs) = @_;

	my ($left, $right, $j) = @{pop(@$stack)};
	my $rule = "$left : @$right";

	for my $i (reverse (0..$#$right)) {
		if (@$stack and $stack->[-1]->[0] eq $right->[$i]) {
			$right->[$i] = build_ast($stack, $tokens, $p_funcs);
		}
		else {
			$right->[$i] = $tokens->[$j + $i]->[1];
		}
	}

	if (exists($p_funcs->{$rule})) {
		return $p_funcs->{$rule}(@$right);
	}
	else {
		return $right;
	}
}

1;
