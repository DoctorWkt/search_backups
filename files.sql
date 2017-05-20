-- A filename is simply that: a file or directory's name.
--
CREATE TABLE filename (
	id integer primary key,
	name text unique not null
);

-- Build an index so we can search names faster
CREATE UNIQUE INDEX idx_filename_name on filename (name);

-- We record details about a volume which is the top of a filesystem tree.
-- We have a name for it, a description and a location.
CREATE TABLE volume (
	id integer primary key,
	name text unique not null,
	description text,
	location text
);

-- A file can be either a directory or a file. We point to the filename
-- stored elsewhere. We have the file's size and Unix last modification
-- timestamp. If the parent is not zero, this points to the parent directory.
-- If the parent is zero, then this is the root of the volume, and the
-- filename value points to a volume id
CREATE TABLE file (
	id integer primary key,
	parent integer not null,
	filename integer not null,
	size integer not null,
	timestamp integer not null
);
