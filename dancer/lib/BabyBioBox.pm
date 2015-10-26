package BabyBioBox;
use Dancer2;
use DBI qw(:sql_types);
use Template;
use Data::Entropy::Algorithms qw(rand_bits);
use MIME::Base64;
use Digest;

our $VERSION = '0.1';

set 'session'=>'Simple';
set 'database'=>'/tmp/test.db'; #change this for production
set 'template'=>'template_toolkit';

use constant BCRYPT_COST => 10; #selected for performance on the hosting box.

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
		my $query='select salt, pw_hash,blessed from users where user_email=?';
		my $sth=$dbh->prepare($query);
		$sth->bind_param(1,params->{email},SQL_VARCHAR);
		$sth->execute();
		my $results=$sth->fetch();
		$sth->finish();
		$dbh->disconnect();
		#do login things
		unless($$results[0] && $$results[2] ne 'false')
		{
			set_message('Unable to log in with this user name and password combination.<br/>'.
				'Please contact your admin for assitance');
			return redirect '/login';
		}
		my $bcrypt=Digest->new('Bcrypt');
		$bcrypt->cost(BCRYPT_COST);
		$bcrypt->salt(decode_base64($$results[0]));
		$bcrypt->add(params->{password});
		if($bcrypt->b64digest ne $$results[1])
		{
			set_message('Unable to log in with this user name and password combination.<br/>'.
				'Please contact your admin for assitance');
			return redirect '/login';
		}
		session 'logged_in'=>1; 
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
		unless(params->{'email'} && params->{'password'} && params->{'confirm_pass'})
		{
			set_message('All fields are required.  Please fill in all fields and try again');
			return redirect '/create_account';
		}
		unless(params->{'password'} eq params->{'confirm_pass'})
		{
			set_message('Password and password confirmation must match.  Please try again.');
			return redirect '/create_account';
		}
		my $dbh=db_open();
		#check for existance of account.
		my $query='select count(*) from users where user_email=?';
		my $sth=$dbh->prepare($query);
		$sth->bind_param(1,params->{email},SQL_VARCHAR);
		$sth->execute();
		my $count=$sth->fetch();
		$sth->finish();
		if($$count[0])
		{
			set_message('Account exists.  Please contact your admin if you need your password reset');
			$dbh->disconnect();
			return redirect '/create_account';
		}
		#at this point it's probably reasonably safe to actually attempt the account creation.
		#IMPORTANT: this uses the default entropy source.  Good enough for a small project but
		#	not so much so for a larger one.
		my $salt=rand_bits(8*16);
		my $bcrypt=Digest->new('Bcrypt');
		#scrubbing of inputs should really be done prior to this.
		$bcrypt->cost(BCRYPT_COST);
		$bcrypt->salt($salt);
		$bcrypt->add(params->{password});
		#now, get the base64 versions that will go into the db.
		$salt=encode_base64($salt);
		my $b64_pass=$bcrypt->b64digest;
		$query='insert into users (user_email,salt,pw_hash) values (?,?,?)';
		$sth=$dbh->prepare($query);
		$sth->bind_param(1,params->{email},SQL_VARCHAR);
		$sth->bind_param(2,$salt,SQL_CHAR);
		$sth->bind_param(3,$b64_pass,SQL_CHAR);
		$sth->execute();#should check to make sure this succeedes.
		$sth->finish();
		$dbh->disconnect();
		set_message('Account created.  Your admin will have to authorize this account before you can log in');
		return redirect '/';
	}
	template 'create',{
		'message'=>get_message()
	};
};

true;
