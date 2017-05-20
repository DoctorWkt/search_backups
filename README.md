# search_backups
This a set of small Perl scripts to build a catalog on a set of mountable
backups, and to search the catalog.

I have a set of five or six USB hard disks, which I've used over the years
to backup my home and work systems. I've used various tools such as _rsync_,
_rsnapshot_ and a Btrfs tool to copy files over to the hard disks. Now I
have 100 million or so files out on several disks, and trying to find a file
is becoming hard. Hence these scripts.

# Creating the Initial Database

The backup catalog is stored in an Sqlite3 file called `files.db`. To create
an initial database file:

```
$ cat files.sql | sqlite3 files.db
```

# Adding a Volume's Details to the Database

Before you add new backup entries to the database, you first must add
details of the "volume". This helps you remember the details of each
backup device and where it is. To add the details of a volume, do:

```
$ ./add_volume [-db dbfile] volume_name description location
```

_volume_name_ should be a short word or phrase that describes the volume.
_description_ can be a sentence or two that describes the volume. I use
the text that I write on the sticky label that I put on each USB drive.
_location_ can be a sentence or two that describes where you can find the
volume.

As an example, here is one volume that I added to the database:

```
$ ./add_volume apr2014 'Warrens Back Drive Data from June 2011 to April 2014' 'Study cupboard at home'
```

The _-db_ option allows you to choose a different Sqlite3 database file
instead of the default `files.db`.

There is a short script, `list_volumes`, to list what volumes are available.
It simply sends an SQL command to the database to list the _volume_ table:

```
$ ./list_volumes
1|fred|fred|fred
2|offsite|Off-site Backup|Study cupboard at home
3|may2011|Warrens Backup Drive, Data up to May 2011|Study cupboard at home
4|iso|ISO Images past, 2012, onwards|Study cupboard at home
5|apr2014|Warrens Back Drive Data from June 2011 to April 2014|Study cupboard at home
6|bob|Backup of Backups|Study cupboard at home
```

The first entry was a test entry that I didn't use.

# Building a Database Catalog

Assume that you have a backup mount at `/mountpoint` and you have given this
the volume name _fred_. To add all the files to the catalog, you would do:

```
$ ./add_files fred /mountpoint
```

This will print out a decimal point `.` as the script enters a new directory.
The script will also print out an asterisk `*` every 30 seconds, so that you
get some other indication of progress.

The insert speed seems to be reasonably constant regardless of the size
of the database.

There are some command-line options to the script:

```
Usage: ./add_files [-v] [-s] [-db dbfile] volume_name mountpoint [startdir]
```

* _-v_ set a verbose flag, which I used when debugging
* _-s_ tells the script to look out for and skip directories already processed
* _-db_ chooses a different a different Sqlite3 database file instead of the default `files.db`

You should use the _-s_ flag when you are rescanning a backup volume for new
entries, otherwise it will add everything back into the database and you will
get duplicate entries. Note, however, that the _-s_ flag does slow things
down considerably.

If you know specifically what has been added, it's easier to use the
_startdir_ option at the end of the command-line. For example, assume
that your volume is mounted on `/mountpoint` and that latest backup was
placed at `/mountpoint/2017-April`. You would run the command:

```
$ ./add_files fred /mountpoint /mountpoint/2017-April
```

This will automatically set the _-s_ flag, and only scan from
`/mountpoint/2017-April` downwards.

You should expect a decent-sized USB drive to take several hours for the
script to build the catalog. I have a 3T USB drive which is about 60% full
and this took 5 or 6 hours to scan.

# Size and Contents of the Catalog

The catalog contains:
 * the full pathname of each file and directory
 * the size of each file and directory in bytes
 * the last modification timestamp for each file and directory

Filenames are stored only once, with a numeric id assigned to each name.
Full pathnames are stored as a set of pointers from one row in the database
to another row.

As I am storing snapshots of my systems on the same USB drive, a lot of
files and directories have the same name. My database is using just under
30 bytes per file entry in the database, on average. My current database
has 103,062,302 file entries for a size of 2,919,738,368 bytes (2.9 Gibytes).

# Searching the Database

You can search for a filename or directory in the catalog in one of three
ways:
* an exact name match using the SQL _=_ operation
* a 'like' match using the SQL _like_ operation; this is the default
* a regexp pattern using the Sqlite _regexp_ operation

The command-line usage is:

```
Usage: ./find_files [-e] [-r] [-db dbfile] pattern
```
* _-e_ turns on exact matching
* _-r_ turns on regular expression matching

If you want to use regular expressions, you may need to install a version of
Sqlite3 with a regular expression library. On Ubuntu:

```
$ sudo apt-get install sqlite3-pcre
```

and then add this line to your `$HOME/.sqliterc`:

```
.load /usr/lib/sqlite3/pcre.so
```

## Examples of Catalog Searches

Exact searches, obviously, will only match filenames exactly. Like searches
use the SQL `like` syntax, so you should use the percent sign `%` to
match on any number of any characters. A regexp search uses the
Perl-compatible regular expressions.

Here are some example searches on my 2.9 Gibyte catalog. Note that the
first part of the retrieved pathname is actually the volume name.

```
$ ./find_files -e pyr.txt
      2245  Tue Mar 21 14:37:06 1989  /offsite/Neddie/2015-10-01-10:21:23/home/wkt/Misc/pyr.txt
      2245  Tue Mar 21 14:37:06 1989  /offsite/Neddie/2016-02-05-15:58:13/home/wkt/Misc/pyr.txt
      2245  Tue Mar 21 14:37:06 1989  /offsite/Neddie/2016-02-07-12:58:42/home/wkt/Misc/pyr.txt
      2245  Tue Mar 21 14:37:06 1989  /offsite/Neddie/2016-08-09-21:09:29/home/wkt/Misc/pyr.txt
...
      2245  Sun Apr 26 09:12:55 1998  /may2011/Archives/Misc/WBAOT2_May1998/MS-DOG/30M-Disk/pyr.txt
      2245  Tue Mar 21 14:37:06 1989  /may2011/Neddie/home/wkt/Misc/pyr.txt
      2245  Tue Mar 21 14:37:06 1989  /apr2014/Neddie/2012-11-21/home/wkt/Misc/pyr.txt
...
      2245  Tue Mar 21 14:37:06 1989  /bob/2014_April/Neddie/2011-12-19/home/wkt/Misc/pyr.txt
      2245  Tue Mar 21 14:37:06 1989  /bob/2014_April/Neddie/2012-04-14/home/wkt/Misc/pyr.txt
      2245  Tue Mar 21 14:37:06 1989  /bob/2014_April/Neddie/2012-07-31/home/wkt/Misc/pyr.txt
```
The first time I did the search it took about 50 seconds. The second time
it took 8 seconds as the disk blocks were cached in memory.

```
$ ./find_files '%clex.%'
...
     10380  Sun Aug  7 14:28:30 2016  /bob/Offsite/Neddie/2017-04-09-17:36:26/usr/local/src/Github/xv6-minix2/cmd/wish/clex.c
     17461  Wed Nov  3 06:45:18 2004  /bob/Offsite/Neddie/2017-04-09-17:36:26/usr/local/unixtree/OpenBSD-4.6/gnu/usr.bin/binutils/binutils/rclex.c.gz
      3915  Wed Nov  3 06:22:04 2004  /bob/Offsite/Neddie/2017-04-09-17:36:26/usr/local/unixtree/OpenBSD-4.6/gnu/usr.bin/binutils/binutils/rclex.l.gz
       537  Tue Jan 24 10:39:13 2017  /bob/Offsite/Neddie/2017-04-09-17:36:26/usr/local/10audit/V10/usr/src/cmd/odist/pax/src/lib/libx/port/fclex.c.html
      1202  Sat Mar  6 05:14:11 2010  /bob/Offsite/Neddie/2017-04-09-17:36:26/usr/local/v10tree/OpenSolaris_b135/cmd/fm/eversholt/common/esclex.h.gz
       268  Wed Dec 13 08:03:44 1989  /bob/Offsite/Minnie/2017-05-14-11:37:45/usr/500/Backup/Minnie/daily.0/usr/local/v10tree/V10/usr/src/cmd/odist/pax/src/lib/libx/port/fclex.c.gz
...
       537  Tue Jan 24 10:39:13 2017  /bob/Offsite/Minnie/2017-05-14-11:37:45/usr/500/Backup/Minnie/daily.0/var/www/v10lobby/V10/usr/src/cmd/odist/pax/src/lib/libx/port/fclex.c.html
```

Both the first and second _like_ searches took about 45 seconds.

```
$ ./find_files -r '[Cc]lex\.[ch]'
     19897  Mon Nov 20 12:28:48 1989  /bob/2014_April/Neddie/2012-11-21/home/wkt/Old/OldCDs/WarrensBigArchiveOfThings/Archive/Source/Local/Clam/1.3c/clex.c
     21067  Tue Nov 23 10:51:11 1993  /bob/2014_April/Neddie/2012-11-21/home/wkt/Old/OldCDs/WarrensBigArchiveOfThings/Archive/Source/Local/Clam/1.4/clex.c
     67208  Wed Nov  3 06:45:18 2004  /bob/2014_April/Neddie/2012-11-21/usr/local/src/Src/OpenBSD-4.6/gnu/usr.bin/binutils/binutils/rclex.c
     21987  Sat Mar  6 05:14:11 2010  /bob/2014_April/Neddie/2012-11-21/usr/local/src/Src/OpenSolaris_b135/cmd/fm/eversholt/common/esclex.c
      2422  Sat Mar  6 05:14:11 2010  /bob/2014_April/Neddie/2012-11-21/usr/local/src/Src/OpenSolaris_b135/cmd/fm/eversholt/common/esclex.h
...
       544  Mon Jan 23 15:34:49 1989  /bob/Offsite/Neddie/cur/usr/local/Unix/UnixArchive/Applications/News/C-News/Feb_1993_Release/libcnews/fopenclex.c
     11264  Sun Aug  7 14:28:23 2016  /bob/Offsite/Neddie/cur/usr/local/src/Github/Wish/clex.c
     10380  Mon Aug 15 16:44:35 2016  /bob/Offsite/Neddie/cur/usr/local/src/Github/xv6-freebsd/cmd/wish/clex.c
...
     21987  Sat Mar  6 05:14:11 2010  /apr2014/Henry/2011-06-29/usr/local/unixtree/OpenSolaris_b135/cmd/fm/eversholt/common/esclex.c
      2422  Sat Mar  6 05:14:11 2010  /apr2014/Henry/2011-06-29/usr/local/unixtree/OpenSolaris_b135/cmd/fm/eversholt/common/esclex.h
     67208  Wed Nov  3 06:45:18 2004  /apr2014/Henry/2011-12-19/usr/local/unixtree/OpenBSD-4.6/gnu/usr.bin/binutils/binutils/rclex.c
```

Both searches took 1 minute 47 seconds.

One important thing to note about searches is that the search pattern only applies to each component of the pathname, not the full pathname. So if you searched
for 'a%b', it _won't_ find a pathname with _...a/b..._.

Similarly, a match on a directory name _won't_ list the contents below the
directory, only the directory itself. If you search for the exact pattern
_.git_, then you will get results like this:

```
$ ./find_files -e .git
       166  Mon Apr 11 21:26:57 2016  /bob/Offsite/Minnie/2017-05-14-11:37:45/usr/500/Backup/Minnie/daily.0/usr/local/src/sccpdp7/.git
       138  Sat Mar 11 10:05:13 2017  /bob/Offsite/Minnie/2017-05-14-11:37:45/usr/500/Backup/Minnie/daily.0/usr/local/src/simh/.git
       138  Wed Apr 27 09:58:40 2016  /bob/Offsite/Minnie/2017-05-14-11:37:45/usr/500/Backup/Minnie/daily.0/usr/local/src/simple-rcs2git/.git
       138  Tue Apr 12 07:37:11 2016  /bob/Offsite/Minnie/2017-05-14-11:37:45/usr/500/Backup/Minnie/daily.0/usr/local/src/swieros/.git
       138  Mon Feb 22 17:44:52 2016  /bob/Offsite/Minnie/2017-05-14-11:37:45/usr/500/Backup/Minnie/daily.0/usr/local/src/unix-jun72/.git
```

but not anything in the `.git` directories.
