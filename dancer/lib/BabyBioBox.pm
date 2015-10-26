package BabyBioBox;
use Dancer2;
use DBI;
use Template;

our $VERSION = '0.1';

set 'session'=>'Simple';
set 'database'=>'/tmp/test.db'; #change this for production
set 'template'=>'template_toolkit';


my $glbl_message='';

sub db_open
{
	my $dbh=DBI->connect('dbi:SQLite:dbname='.setting('database')) or die $DBI::errstr;
	return $dbh;
}

sub set_message
{
	my $message=shift;
	$glbl_message=$message;
}

sub get_message
{
	my $message=$glbl_message;
	$glbl_message='';
	return $message;
}

hook before_template => sub{
	my $tokens=shift;

	$tokens->{'login_url'}=uri_for('/login');
	$tokens->{'creation_url'}=uri_for('/create_account');
};

get '/' => sub {
	if(! session('logged_in'))
	{
		return redirect '/login';
	}
	#else show data logging and display options.
	
    template 'index';
};

any ['get','post']=> '/login' => sub {
	if(request->method() eq 'POST')
	{
		my $dbh=db_open();
		#do login things
		$dbh->disconnect();
		session 'logged_in'=>1; #replace with real login logic
		return redirect '/';
	}
	
	template 'login',{
		'message'=>get_message()	
	};
};

any ['get','post']=>'/logout'=> sub{
	app->destroy_session();
	set_message('Successfully logged out.');
	return redirect '/';
};

any ['get','post']=>'/create_account'=>sub{
	if(request->method() eq 'POST')
	{
		my $dbh=db_open();
		#do account creation things
		$dbh->disconnect();
		session 'logged_in'=>1;#replace with real creation verification logic
		return redirect '/';
	}
	template 'create';
};

true;
