/*File to set up data store for project
 *Christopher Betancourt
 *christopher.betancourt@gmail.com
 *September 6, 2015
 *
 *Copyright (c) 2015, Christopher Betancourt
*/

/*going to make use of the fact that sqlite will alias the id columns to rowid*/
create table event_types(
	id		integer	not null,
	name	varchar(256) not null,
	primary key(id)
);

create table event_log(
	id		integer not null,
	event_type integer not null,
	event_time datetime not null,
	event_source varchar(256),
	primary key(id)
);

create table users(
	user_email	varchar(256) not null,
	salt		char(25) not null,
	pw_hash		char(31) not null,
	blessed		boolean not null default false,
	admin		boolean not null default false,
	primary key(user_email)
);

insert into event_types (name) values ("Wet Diaper"),("Dirty Diaper"),("Sleep"),("Wake"),("Bottle Feeding");
