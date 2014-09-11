package Games::Word::TextTwist;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;
use experimental 'smartmatch';

use Module::List qw(list_modules);
use Module::Load;

# TMP
sub __solve {
    # find a 6-letter word in the wordlist, then find all words that can be
    # formed from those 6 letters.
    require Games::Word::Wordlist::Enable;
    my $wl = Games::Word::Wordlist::Enable->new;

    my $word = $wl->random_word(6)
        or die "Can't get a 6-letter word from wordlist\n";
    my @letters = split '', $word;
    my @words;
  WORD:
    for my $w0 ($wl->words_like(qr/^.{2,6}$/)) {
        my $w = $w0;
        for my $l (@letters) {
            next WORD unless $w =~ s/$l//;
        }
        push @words, $w0;
    }
}

sub new {
    my $class = shift;
    my %attrs = @_;

    # select and load default wordlist
    my $mods = list_modules("Games::Word::Wordlist::", {list_modules=>1});
    my @wls = map {s/.+:://; $_} keys %$mods;
    print "Available wordlists: ", join(", ", @wls), "\n";
    my $wl = $attrs{word_list};
    if (!$wl) {
        if (($ENV{LANG} // "") =~ /^id/ && "KBBI" ~~ @wls) {
            $wl = "KBBI";
        } else {
            if (@wls > 1) {
                @wls = grep {$_ ne 'KBBI'} @wls;
            }
            $wl = $wls[rand @wls];
        }
    }
    die "Can't find module for wordlist '$wl'" unless $wl ~~ @wls;
    my $mod = "Games::Word::Wordlist::$wl";
    load $mod;
    print "Loaded wordlist from $mod\n";

    # select eligible words from the wordlist
    my @words;
    {
        my $wlobj = $mod->new;
        my $l1 = int($attrs{min_len} // 5);
        my $l2 = int($attrs{max_len} // $l1 // 5);
        @words = $wlobj->words_like(qr/\A[a-z]{$l1,$l2}\z/);
        die "Can't find any eligible words in wordlist '$wl'"
            unless @words;
        $attrs{_wlobj} = $wlobj;
        $attrs{words} = \@words;
    }

    $attrs{num_words} //= 10;

    bless \%attrs, $class;
}

sub run {
    my $self = shift;

    $self->{num_correct} = 0;
    $self->{score} = 0;

    for my $i (1..$self->{num_words}) {
        print "\nWord $i/$self->{num_words}:\n";
        my ($is_correct, $score) = $self->ask_word;
        $self->{num_correct}++ if $is_correct;
        $self->{score} += $score;
    }
    $self->show_final_score;
}

sub ask_word {
    my $self = shift;

    my $words = $self->{words};
    my $word  = $words->[rand @$words];
    #say "D:word=$word";
    my $wlen  = length($word);

    my $max_guesses = $self->{max_guesses} // $wlen;

    my $i = 0;
    my $gletters = substr($word, 0, 1) . ("*" x ($wlen-1));
    $self->show_diff($word, $gletters);
    while ($i < $max_guesses) {
        $i++;
        print $i < $max_guesses ? "Your guess ($i/$max_guesses)? " :
            "Your last guess? ";
        chomp(my $guess = <STDIN>);
        unless ($self->{_wlobj}->is_word($guess)) {
            $self->show_diff($word, $gletters);
            print "Sorry, not a word! ";
            $i--;
            next;
        }
        unless (length($guess) eq $wlen) {
            $self->show_diff($word, $gletters);
            print "Sorry, not a $wlen-letter word! ";
            $i--;
            next;
        }
        if (lc($guess) eq $word) {
            my $score = ($wlen*(1-($i-1)/$max_guesses))*20;
            print "Correct ($score points)!\n";
            return (1, $score);
        }
        my $gletters_new = $self->show_diff($word, $guess);
        $gletters = $gletters_new
            if $self->get_num_chars($gletters, '*') >
                $self->get_num_chars($gletters_new, '*');
    }
    print "Chances used up. The correct word is: $word\n";
    return (0, 0);
}

sub get_num_chars {
    my ($self, $s, $char) = @_;
    my $orig = $s;
    $s =~ s/\Q$char//ig;
    length($orig) - length($s);
}

sub show_diff {
    my ($self, $word, $guess) = @_;
    my $gletters = "";
    #print "D:show_diff: $word vs $guess\n";
    $guess = lc($guess);
    my $word2 = $word;

    # what letters are in the incorrect position
    for my $i (0..(length($word)-1)) {
        my $l = substr($word, $i, 1);
        $word2 =~ s/\Q$l// if length($guess)>$i && substr($guess, $i, 1) eq $l;
     }

    for my $i (0..(length($word)-1)) {
        my $l  = substr($word, $i, 1);
        my $gl = length($guess) > $i ? substr($guess, $i, 1) : "";
        if ($l eq $gl) {
            print "$l ";
            $gletters .= $l;
        } elsif (length($gl) && $word2 =~ s/\Q$gl//) {
            print "$gl*";
            $gletters .= "*";
        } else {
            print "_ ";
            $gletters .= "*";
        }
        print " ";
    }
    #print "\n";
    $gletters;
}

sub show_final_score {
    my $self = shift;

    print "\n";
    printf "Number of words guessed correctly: %d/%d\n",
        $self->{num_correct}, $self->{num_words};
    printf "Final score: %.0f\n", $self->{score};
}

1;
# ABSTRACT: Word guess game

=for Pod::Coverage ^(.+)$

=head1 SYNOPSIS

 % wordguess


=head1 SEE ALSO

L<wordguess>

L<Games::GuessWord> which is more akin to Hangman but, at the time of this
writing, does not come with a readily-playable game.
