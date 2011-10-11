package App::IRC::Bot::Shoze::i18n::fr;

=head1 NAME

App::IRC::Bot::Shoze::i18n - Internationalization module

=cut

=head1 SYNOPSIS

=cut

use base qw(App::IRC::Bot::Shoze::i18n);
use warnings;
use strict;

use utf8;

use vars qw(%Lexicon);

%Lexicon = (
    'Ok you\'re in!' => 'Ok t\'es dedans',
    'Bye!' => 'Aurevoir!',
    'You are not logged' => 'Vous n\'êtes pas authentifié',
    'Already logged in' => 'Vous êtes déjà authentifié',
    'No password supplied' => 'Mot de passe non spécifié',
    'Invalid username' => 'Nom d\'utilisatateur non valide',
    'Hostmask doesn\'t match' => 'Le masque d\'hôte ne correspond pas',
    'Invalid password' => 'Mot de passe non valide',
    'Listing users' => 'Liste des utilisateurs',
    'No user in database' => 'Il n\'y à pas d\'utilisateur dans la base de donnée',
    'Invalid username \'[_1]\'' => 'Nom d\'utilisateur \'[_1]\' invalide',
    'User information' => "Information utilisateur",
    'level' => 'niveau',
    'hostmask' => 'masque d\'hôte',
    'is bot' => 'est un robot',
    'created on' => 'créé le',
    'pending' => 'en attente',
    'yes' => 'oui',
    'no' => 'non',
    'Cannot delete user \'[_1]\'' => 'Ne peut pas effacer l\'utilisateur \'[_1]\'',
    'User \'[_1]\' successfully deleted' => 'Effacement de l\'utilisateur \'[_1]\' réussi',
    'You cannot delete user with higher or same level as you' => 'Vous ne pouvez pas effacer un utilisateur ayant un level identique ou superieur au votre',
    'Cannot create user \'[_1]\'' => 'Impossible de créer l\'utilisateur [_1]',
    'User \'[_1]\' created' => 'L\'utilisateur [_1] à été créé',
    'User \'$name\' already exist' => 'L\'utilisateur [_1] existe déjà',
    'language' => 'langage',
    'output' => 'sortie',
    'Listing commands for level [_1]' => 'Liste des commandes pour le niveau [_1]',
    
);



1;