#!/usr/bin/perl
package FileModel;
use strict;
use warnings;
use DBI;
use Data::Dumper;

use Exporter;
use vars qw(@ISA @EXPORT @EXPORT_OK);
@ISA    = qw(Exporter);
@EXPORT = qw(dbOpenDatabase dbCloseDatabase dbAddFilename dbAddVolume dbAddFile
  dbGetFilename dbGetFilenameId dbGetVolume dbGetVolumeId dbGetFile
  dbExistsFile dbSearchFile
);

@EXPORT_OK = qw();

# Database handle used by all functions
my $dbfile = "files.db";
my $dbh;

# Synchronise the database
sub dbSynchronise {
    $dbh->commit;
    print("*");
    alarm(30);
}

# Close the database
sub dbCloseDatabase {
    $dbh->commit;
    $dbh->disconnect;
    exit(0);
}

# Open the database. Make it non-synchronous and with no auto commits
# to speed up the inserts. Catch a bunch of signals to ensure that
# we flush the journal at the end. Also flush the journal with a commit
# every 30 seconds.
sub dbOpenDatabase {
    my ($dfile)= @_;
    $dbfile= $dfile if ($dfile);

    if ( !defined($dbh) ) {
        $dbh = DBI->connect( "dbi:SQLite:dbname=$dbfile", "", "" );
        $dbh->do('PRAGMA synchronous=OFF');
        $dbh->{AutoCommit} = 0;
        $dbh->do('PRAGMA journal_mode=MEMORY');
        $dbh->do("PRAGMA cache_size = 80000");
        $SIG{INT}  = \&dbCloseDatabase;
        $SIG{TERM} = \&dbCloseDatabase;
        $SIG{QUIT} = \&dbCloseDatabase;
        $SIG{ALRM} = \&dbSynchronise;
        alarm(30);
    }
}

# Add a filename: name
sub dbAddFilename {
    my $name = shift;
    my $sth =
      $dbh->prepare_cached("INSERT OR IGNORE INTO filename(name) VALUES (?)");
    $sth->execute($name);
    my @row = $dbh->selectrow_array( "SELECT id FROM filename WHERE name = ?",
        undef, $name );
    return ( $row[0] );
}

# Add a volume: name, description, location
sub dbAddVolume {
    my $sth =
      $dbh->prepare_cached(
            "INSERT OR IGNORE INTO volume(name, description, location) "
          . "VALUES (?,?,?)" );
    $sth->execute(@_);
    my @row = $dbh->selectrow_array( "SELECT id FROM volume WHERE name = ?",
        undef, $_[0] );
    return ( $row[0] );
}

# Add a file: filename, parent-id, size, last modification time
# Returns the file-id and a true value if it was already in the db
sub dbAddFile {
    my ( $fileshort, $parentid, $size, $mtime, $dupcheck ) = @_;

    # Get the filename-id of the file's name
    my $nameid = dbAddFilename($fileshort);

    # If this filename-id and parent-id pair already exist,
    # return the file-id as we have already processed this before
    if ($dupcheck) {
        my @row = $dbh->selectrow_array(
            "SELECT id FROM file WHERE filename = ? AND parent = ?",
            undef, $nameid, $parentid );
        return ( $row[0], 1 ) if ( $row[0] );
    }

    my $sth =
      $dbh->prepare_cached(
            "INSERT INTO file(parent, filename, size, timestamp) "
          . "VALUES (?,?,?,?)" );
    $sth->execute( $parentid, $nameid, $size, $mtime );
    my $rv = $dbh->last_insert_id( undef, undef, undef, undef );
    return ( $rv, 0 );
}

# Get the filename given an id, or return undef
sub dbGetFilename {
    my $id  = shift;
    my @row = $dbh->selectrow_array( "SELECT name FROM filename WHERE id = ?",
        undef, $id );
    return ( $row[0] );
}

# Get the details of a volume given an id, return an array
sub dbGetVolume {
    my $id  = shift;
    my @row = $dbh->selectrow_array( "SELECT name FROM volume WHERE id = ?",
        undef, $id );
    return (@row);
}

# Get the volume id given a name, return a value or undef
sub dbGetVolumeId {
    my $name = shift;
    my @row  = $dbh->selectrow_array( "SELECT id FROM volume WHERE name = ?",
        undef, $name );
    return ( $row[0] );
}

# Get the filename id given a name, return a value or undef
sub dbGetFilenameId {
    my $name = shift;
    my @row  = $dbh->selectrow_array( "SELECT id FROM filename WHERE name = ?",
        undef, $name );
    return ( $row[0] );
}

# Get the details of a file given an id, return an array
sub dbGetFile {
    my $id  = shift;
    my @row = $dbh->selectrow_array(
        "SELECT id,parent,filename,size,timestamp FROM file WHERE id = ?",
        undef, $id );
    return (@row);
}

# Return true if there already exists a file with the given filename and
# parent-id, else return false
sub dbExistsFile {
    my ( $name, $parentid ) = @_;

    # Give up if the filename doesn't exist
    my $nameid = dbGetFilenameId($name);
    return (0) if ( !defined($nameid) );

    # Get the row-id of a file with this filename and parent-id
    my @row = $dbh->selectrow_array(
        "SELECT id FROM file WHERE filename = ? AND parent = ?",
        undef, $nameid, $parentid );
    return ( $row[0] ? $row[0] : 0 );
}

# Return a list of file ids whose filenames match the given pattern
# $how==0 means exact match, $how==1 means like match, $how==2 means regexp
sub dbSearchFile {
    my ($pattern, $how) = @_;
    $how=1 if (!defined($how));

my @searchstyle= ( "file.filename=filename.id where filename.name = ?",
	"file.filename=filename.id where filename.name like ?",
	"file.filename=filename.id where filename.name regexp ?" );

    my $rowref     = $dbh->selectall_arrayref(
        "select file.id from file inner join filename on " .
	$searchstyle[$how], undef, $pattern
    );
    return ($rowref);
}

1;
