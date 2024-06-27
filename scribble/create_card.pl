#! /usr/bin/perl

use feature ":5.11";
use strict;
use Data::GUID;
use JSON;
use Data::Dumper;

my $guid = Data::GUID->new;

my $card = {
    body => {
        contentType => 'html',
        content => "<attachement id='$guid'></attachment>",
    },
    attachement => {
        id =>   "'$guid'",
        content_type => "application/vnd.microsoft.card.adaptive",
        content => {
            type => "AdaptiveCard",
            version => "1.0",
            body =>[
                {
                    type => "TextBlock",
                    text => "text 1"
                },
                {
                    type => "TextBlock",
                    text => "text 2"
                },
            ],
        },
    },
};



say "Dit is het";
print Dumper $card;
say encode_json $card;
