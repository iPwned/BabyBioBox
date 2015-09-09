/*File to set up data store for project
 *Christopher Betancourt
 *christopher.betancourt@gmail.com
 *September 6, 2015
 *
 *Copyright (c) 2015, Christopher Betancourt
*/
create table event_types(
	id		integer	not null,
	name	varchar(256) not null,
	primary key(id)
);

create table event_log(
	id		integer not null,
	event_type integer not null,
	event_time datetime not null,
	primary key(id)
);
