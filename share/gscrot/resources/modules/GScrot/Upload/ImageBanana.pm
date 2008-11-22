###################################################
#
#  Copyright (C) Mario Kemper 2008 <mario.kemper@googlemail.com>
#
#  This file is part of GScrot.
#
#  GScrot is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 3 of the License, or
#  (at your option) any later version.
#
#  GScrot is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with GScrot; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
###################################################

package GScrot::Upload::ImageBanana;

use utf8;
use strict;
use WWW::Mechanize;
use HTTP::Status;

#define constants
#--------------------------------------
use constant TRUE  => 1;
use constant FALSE => 0;

#--------------------------------------

sub new {
	my $class = shift;

	my $self = {
		_host            => shift,
		_debug_cparam    => shift,
		_gscrot_root     => shift,
		_gettext_object  => shift,
		_main_gtk_window => shift,
		_ua              => shift
	};

	$self->{_mech} = WWW::Mechanize->new( agent => "$self->{_ua}", timeout => 20);
	$self->{_http_status} = undef;

	#received links are stored here
	$self->{_links} = undef;

	#credentials and filename
	$self->{_filename} = undef;
	$self->{_username} = undef;
	$self->{_password} = undef;
	$self->{_logged_in} = FALSE;	

	$self->{_notebook} = Gtk2::Notebook->new;
	$self->{_notebook}->set( homogeneous => 1 );
	$self->{_notebook}->set_scrollable(TRUE);

	bless $self, $class;
	return $self;
}

sub upload {
	my ( $self, $upload_filename, $username, $password ) = @_;

	#store as object vars
	$self->{_filename} = $upload_filename;
	$self->{_username} = $username;
	$self->{_password} = $password;

	my $filesize     = -s $upload_filename;
	my $max_filesize = 2048000;
	if ( $filesize > $max_filesize ) {
		$self->{_links}{'status'} = 998;
		$self->{_links}{'max_filesize'} = sprintf( "%.2f", $max_filesize / 1024 ) . " KB";
		return %{ $self->{_links} };
	}

	utf8::encode $upload_filename;
	utf8::encode $password;
	utf8::encode $username;
	if ( $username ne "" && $password ne "" && !$self->{_logged_in}) {

		$self->{_mech}->get("http://www.imagebanana.com/myib/login/");
		$self->{_http_status} = $self->{_mech}->status();
		unless ( is_success( $self->{_http_status} ) ) {
			$self->{_links}{'status'} = $self->{_http_status};
			return %{ $self->{_links} };
		}
		$self->{_mech}->form_number(1);
		$self->{_mech}->field( nick     => $username );
		$self->{_mech}->field( password => $password );
		$self->{_mech}->click("login");

		$self->{_http_status} = $self->{_mech}->status();
		unless ( is_success( $self->{_http_status} ) ) {
			$self->{_links}{'status'} = $self->{_http_status};
			return %{ $self->{_links} };
		}
		if ( $self->{_mech}->content =~ /Login nicht erfolgreich/ ) {
			$self->{_links}{'status'} = 999;
			return %{ $self->{_links} };
		}
		$self->{_links}{status} = 'OK Login';
		$self->{_logged_in} = TRUE;

	}

	$self->{_mech}->get("http://www.imagebanana.com/");
	$self->{_http_status} = $self->{_mech}->status();
	unless ( is_success( $self->{_http_status} ) ) {
		$self->{_links}{'status'} = $self->{_http_status};
		return %{ $self->{_links} };
	}
	$self->{_mech}->form_number(1);
	$self->{_mech}->field( img => $upload_filename );
	$self->{_mech}->click("send");

	$self->{_http_status} = $self->{_mech}->status();
	if ( is_success( $self->{_http_status} ) ) {
		my $html_file = $self->{_mech}->content;
		$html_file = $self->switch_html_entities($html_file);

		my @link_array;
		while ( $html_file =~ /value="(.*)" class/g ) {
			push( @link_array, $1 );
		}

		$self->{_links}{'thumb1'}    = $link_array[0];
		$self->{_links}{'thumb2'}    = $link_array[1];
		$self->{_links}{'thumb3'}    = $link_array[2];
		$self->{_links}{'friends'}   = $link_array[3];
		$self->{_links}{'popup'}     = $link_array[4];
		$self->{_links}{'direct'}    = $link_array[5];
		$self->{_links}{'hotweb'}    = $link_array[6];
		$self->{_links}{'hotboard1'} = $link_array[7];
		$self->{_links}{'hotboard2'} = $link_array[8];

		if ( $self->{_debug_cparam} ) {
			print "The following links were returned by http://www.imagebanana.com:\n";
			print $self->{_links}{'thumb1'} . "\n";
			print $self->{_links}{'thumb2'} . "\n";
			print $self->{_links}{'thumb3'} . "\n";
			print $self->{_links}{'friends'} . "\n";
			print $self->{_links}{'popup'} . "\n";
			print $self->{_links}{'direct'} . "\n";
			print $self->{_links}{'hotweb'} . "\n";
			print $self->{_links}{'hotboard1'} . "\n";
			print $self->{_links}{'hotboard2'} . "\n";
		}

		$self->{_links}{'status'} = $self->{_http_status};
		return %{ $self->{_links} };

	} else {
		$self->{_links}{'status'} = $self->{_http_status};
		return %{ $self->{_links} };
	}
}

sub create_tab {
	my $self = shift;

	#Clipboard
	my $clipboard = Gtk2::Clipboard->get( Gtk2::Gdk->SELECTION_CLIPBOARD );

	#Tooltips
	my $tooltips = Gtk2::Tooltips->new;

	my $upload_hbox   = Gtk2::HBox->new( FALSE, 0 );
	my $upload_hbox1  = Gtk2::HBox->new( TRUE,  10 );
	my $upload_hbox2  = Gtk2::HBox->new( FALSE, 10 );
	my $upload_hbox3  = Gtk2::HBox->new( TRUE,  10 );
	my $upload_hbox4  = Gtk2::HBox->new( FALSE, 10 );
	my $upload_hbox5  = Gtk2::HBox->new( TRUE,  10 );
	my $upload_hbox6  = Gtk2::HBox->new( FALSE, 10 );
	my $upload_hbox7  = Gtk2::HBox->new( TRUE,  10 );
	my $upload_hbox8  = Gtk2::HBox->new( FALSE, 10 );
	my $upload_hbox9  = Gtk2::HBox->new( TRUE,  10 );
	my $upload_hbox10 = Gtk2::HBox->new( FALSE, 10 );
	my $upload_hbox11 = Gtk2::HBox->new( TRUE,  10 );
	my $upload_hbox12 = Gtk2::HBox->new( FALSE, 10 );
	my $upload_hbox13 = Gtk2::HBox->new( TRUE,  10 );
	my $upload_hbox14 = Gtk2::HBox->new( FALSE, 10 );
	my $upload_hbox15 = Gtk2::HBox->new( TRUE,  10 );
	my $upload_hbox16 = Gtk2::HBox->new( FALSE, 10 );
	my $upload_hbox17 = Gtk2::HBox->new( TRUE,  10 );
	my $upload_hbox18 = Gtk2::HBox->new( FALSE, 10 );

	my $upload_vbox = Gtk2::VBox->new( FALSE, 0 );

	my $label_status = Gtk2::Label->new( $self->{_gettext_object}->get("Upload status:") . " "
			. status_message( $self->{_http_status} ) );

	$upload_hbox->pack_start(
		Gtk2::Image->new_from_pixbuf(
			Gtk2::Gdk::Pixbuf->new_from_file_at_scale(
				"$self->{_gscrot_root}/share/gscrot/resources/icons/logo-imagebanana.png",
				100, 100, TRUE
			)
		),
		TRUE, TRUE, 0
	);
	$upload_hbox->pack_start( $label_status, TRUE, TRUE, 0 );

	my $entry_thumb1    = Gtk2::Entry->new;
	my $entry_thumb2    = Gtk2::Entry->new;
	my $entry_thumb3    = Gtk2::Entry->new;
	my $entry_friends   = Gtk2::Entry->new;
	my $entry_popup     = Gtk2::Entry->new;
	my $entry_direct    = Gtk2::Entry->new;
	my $entry_hotweb    = Gtk2::Entry->new;
	my $entry_hotboard1 = Gtk2::Entry->new;
	my $entry_hotboard2 = Gtk2::Entry->new;
	$entry_thumb1->set_text( $self->{_links}{'thumb1'} );
	$entry_thumb2->set_text( $self->{_links}{'thumb2'} );
	$entry_thumb3->set_text( $self->{_links}{'thumb3'} );
	$entry_friends->set_text( $self->{_links}{'friends'} );
	$entry_popup->set_text( $self->{_links}{'popup'} );
	$entry_direct->set_text( $self->{_links}{'direct'} );
	$entry_hotweb->set_text( $self->{_links}{'hotweb'} );
	$entry_hotboard1->set_text( $self->{_links}{'hotboard1'} );
	$entry_hotboard2->set_text( $self->{_links}{'hotboard2'} );

	my $upload_copy1 = Gtk2::Button->new;
	$tooltips->set_tip( $upload_copy1,
		$self->{_gettext_object}->get("Copy this code to clipboard") );
	$upload_copy1->set_image( Gtk2::Image->new_from_stock( 'gtk-copy', 'menu' ) );
	$upload_copy1->signal_connect(
		'clicked' => sub {
			my ( $widget, $entry ) = @_;
			$clipboard->set_text( $entry->get_text );
		},
		$entry_thumb1
	);

	my $upload_copy2 = Gtk2::Button->new;
	$tooltips->set_tip( $upload_copy2,
		$self->{_gettext_object}->get("Copy this code to clipboard") );
	$upload_copy2->set_image( Gtk2::Image->new_from_stock( 'gtk-copy', 'menu' ) );
	$upload_copy2->signal_connect(
		'clicked' => sub {
			my ( $widget, $entry ) = @_;
			$clipboard->set_text( $entry->get_text );
		},
		$entry_thumb2
	);

	my $upload_copy3 = Gtk2::Button->new;
	$tooltips->set_tip( $upload_copy3,
		$self->{_gettext_object}->get("Copy this code to clipboard") );
	$upload_copy3->set_image( Gtk2::Image->new_from_stock( 'gtk-copy', 'menu' ) );
	$upload_copy3->signal_connect(
		'clicked' => sub {
			my ( $widget, $entry ) = @_;
			$clipboard->set_text( $entry->get_text );
		},
		$entry_thumb3
	);
	my $upload_copy4 = Gtk2::Button->new;
	$tooltips->set_tip( $upload_copy4,
		$self->{_gettext_object}->get("Copy this code to clipboard") );
	$upload_copy4->set_image( Gtk2::Image->new_from_stock( 'gtk-copy', 'menu' ) );
	$upload_copy4->signal_connect(
		'clicked' => sub {
			my ( $widget, $entry ) = @_;
			$clipboard->set_text( $entry->get_text );
		},
		$entry_friends
	);
	my $upload_copy5 = Gtk2::Button->new;
	$tooltips->set_tip( $upload_copy5,
		$self->{_gettext_object}->get("Copy this code to clipboard") );
	$upload_copy5->set_image( Gtk2::Image->new_from_stock( 'gtk-copy', 'menu' ) );
	$upload_copy5->signal_connect(
		'clicked' => sub {
			my ( $widget, $entry ) = @_;
			$clipboard->set_text( $entry->get_text );
		},
		$entry_popup
	);

	my $upload_copy6 = Gtk2::Button->new;
	$tooltips->set_tip( $upload_copy6,
		$self->{_gettext_object}->get("Copy this code to clipboard") );
	$upload_copy6->set_image( Gtk2::Image->new_from_stock( 'gtk-copy', 'menu' ) );
	$upload_copy6->signal_connect(
		'clicked' => sub {
			my ( $widget, $entry ) = @_;
			$clipboard->set_text( $entry->get_text );
		},
		$entry_direct
	);

	my $upload_copy7 = Gtk2::Button->new;
	$tooltips->set_tip( $upload_copy7,
		$self->{_gettext_object}->get("Copy this code to clipboard") );
	$upload_copy7->set_image( Gtk2::Image->new_from_stock( 'gtk-copy', 'menu' ) );
	$upload_copy7->signal_connect(
		'clicked' => sub {
			my ( $widget, $entry ) = @_;
			$clipboard->set_text( $entry->get_text );
		},
		$entry_hotweb
	);

	my $upload_copy8 = Gtk2::Button->new;
	$tooltips->set_tip( $upload_copy8,
		$self->{_gettext_object}->get("Copy this code to clipboard") );
	$upload_copy8->set_image( Gtk2::Image->new_from_stock( 'gtk-copy', 'menu' ) );
	$upload_copy8->signal_connect(
		'clicked' => sub {
			my ( $widget, $entry ) = @_;
			$clipboard->set_text( $entry->get_text );
		},
		$entry_hotboard1
	);

	my $upload_copy9 = Gtk2::Button->new;
	$tooltips->set_tip( $upload_copy9,
		$self->{_gettext_object}->get("Copy this code to clipboard") );
	$upload_copy9->set_image( Gtk2::Image->new_from_stock( 'gtk-copy', 'menu' ) );
	$upload_copy9->signal_connect(
		'clicked' => sub {
			my ( $widget, $entry ) = @_;
			$clipboard->set_text( $entry->get_text );
		},
		$entry_hotboard2
	);

	$upload_vbox->pack_start( $upload_hbox, TRUE, TRUE, 10 );

	$upload_hbox1->pack_start_defaults(
		Gtk2::Label->new( $self->{_gettext_object}->get("Thumbnail for websites") ) );
	$upload_hbox1->pack_start_defaults($entry_thumb1);
	$upload_hbox2->pack_start_defaults($upload_hbox1);
	$upload_hbox2->pack_start( $upload_copy1, FALSE, TRUE, 10 );

	$upload_hbox3->pack_start_defaults(
		Gtk2::Label->new( $self->{_gettext_object}->get("Thumbnail for boards (1)") ) );
	$upload_hbox3->pack_start_defaults($entry_thumb2);
	$upload_hbox4->pack_start_defaults($upload_hbox3);
	$upload_hbox4->pack_start( $upload_copy2, FALSE, TRUE, 10 );

	$upload_hbox5->pack_start_defaults(
		Gtk2::Label->new( $self->{_gettext_object}->get("Thumbnail for boards (2)") ) );
	$upload_hbox5->pack_start_defaults($entry_thumb3);
	$upload_hbox6->pack_start_defaults($upload_hbox5);
	$upload_hbox6->pack_start( $upload_copy3, FALSE, TRUE, 10 );

	$upload_hbox7->pack_start_defaults(
		Gtk2::Label->new( $self->{_gettext_object}->get("Show your friends") ) );
	$upload_hbox7->pack_start_defaults($entry_friends);
	$upload_hbox8->pack_start_defaults($upload_hbox7);
	$upload_hbox8->pack_start( $upload_copy4, FALSE, TRUE, 10 );

	$upload_hbox9->pack_start_defaults(
		Gtk2::Label->new( $self->{_gettext_object}->get("Popup for websites") ) );
	$upload_hbox9->pack_start_defaults($entry_popup);
	$upload_hbox10->pack_start_defaults($upload_hbox9);
	$upload_hbox10->pack_start( $upload_copy5, FALSE, TRUE, 10 );

	$upload_hbox11->pack_start_defaults(
		Gtk2::Label->new( $self->{_gettext_object}->get("Direct link") ) );
	$upload_hbox11->pack_start_defaults($entry_direct);
	$upload_hbox12->pack_start_defaults($upload_hbox11);
	$upload_hbox12->pack_start( $upload_copy6, FALSE, TRUE, 10 );

	$upload_hbox13->pack_start_defaults(
		Gtk2::Label->new( $self->{_gettext_object}->get("Hotlink for websites") ) );
	$upload_hbox13->pack_start_defaults($entry_hotweb);
	$upload_hbox14->pack_start_defaults($upload_hbox13);
	$upload_hbox14->pack_start( $upload_copy7, FALSE, TRUE, 10 );

	$upload_hbox15->pack_start_defaults(
		Gtk2::Label->new( $self->{_gettext_object}->get("Hotlink for boards (1)") ) );
	$upload_hbox15->pack_start_defaults($entry_hotboard1);
	$upload_hbox16->pack_start_defaults($upload_hbox15);
	$upload_hbox16->pack_start( $upload_copy8, FALSE, TRUE, 10 );

	$upload_hbox17->pack_start_defaults(
		Gtk2::Label->new( $self->{_gettext_object}->get("Hotlink for boards (2)") ) );
	$upload_hbox17->pack_start_defaults($entry_hotboard2);
	$upload_hbox18->pack_start_defaults($upload_hbox17);
	$upload_hbox18->pack_start( $upload_copy9, FALSE, TRUE, 10 );

	$upload_vbox->pack_start_defaults($upload_hbox2);
	$upload_vbox->pack_start_defaults($upload_hbox4);
	$upload_vbox->pack_start_defaults($upload_hbox6);
	$upload_vbox->pack_start_defaults($upload_hbox8);
	$upload_vbox->pack_start_defaults($upload_hbox10);
	$upload_vbox->pack_start_defaults($upload_hbox12);
	$upload_vbox->pack_start_defaults($upload_hbox14);
	$upload_vbox->pack_start_defaults($upload_hbox16);
	$upload_vbox->pack_start_defaults($upload_hbox18);

	return $upload_vbox;
}

sub show_all {
	my $self = shift;

	$self->{_logged_in} = FALSE;
	
	#are there any uploaded files?
	return FALSE if $self->{_notebook}->get_n_pages < 1;

	my $dlg_header
		= $self->{_gettext_object}->get("Upload") . " - "
		. $self->{_host} . " - "
		. $self->{_username};
	my $upload_dialog = Gtk2::Dialog->new(
		$dlg_header,
		$self->{_main_gtk_window},
		[qw/modal destroy-with-parent/],
		'gtk-ok' => 'accept'
	);
	$upload_dialog->set_default_response('accept');

	$upload_dialog->vbox->add( $self->{_notebook} );
	$upload_dialog->show_all;
	my $upload_response = $upload_dialog->run;

	if ( $upload_response eq "accept" ) {
		$upload_dialog->destroy();
		return TRUE;
	} else {
		$upload_dialog->destroy();
		return FALSE;
	}
}

sub show {
	my $self = shift;

	$self->{_notebook}->append_page( $self->create_tab(), $self->{_filename} );

	return TRUE;

}

sub switch_html_entities {
	my $self = shift;
	my ($code) = @_;
	$code =~ s/&amp;/\&/g;
	$code =~ s/&lt;/</g;
	$code =~ s/&gt;/>/g;
	$code =~ s/&quot;/\"/g;
	return $code;
}

1;