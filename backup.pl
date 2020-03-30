#!/usr/bin/perl -wl
use strict;     
use warnings;   
use File::Path;
use Getopt::Long;
use DBI;

sub backup;
sub getDatabases;
sub checkandcreateFolder;
sub backupDB;
sub msgFHEM;

my $VERSION				= "0.2";

# Zugangsdaten NAS

my $NAS_IP				= "192.168.0.22";
my $NAS_VOLUME			= "/volume2/FHEMBackup";
my $NAS_LOCAL_VOLUME	= "/mnt/backup/";

# Zugangsdaten Mysql

my $MYSQL_HOST			= "localhost";
my $MYSQL_USER			= "backupuser";
my $MYSQL_PASSWD		= "PcYWjbeCSTMVqZTh";

# Backup Folder
my $BACKUP_FOLDER 		= "/backup_tmp";
my $BACKUP_FILES 		= "$BACKUP_FOLDER/files/";

# Logfilename
my $LOGFILE 			= "$BACKUP_FOLDER/logs/backup.log";

my ($YEAR, $MONTH, $DAYOFMONTH, $HOUR, $MINUTE, $SECOND)
 = (localtime())[5, 4, 3, 2, 1, 0];
$YEAR += 1900;

my $TIMESTAMP 			= "$YEAR-$MONTH-$DAYOFMONTH";
my $CURRENT_BACKUP_DIR 	= "$BACKUP_FILES$TIMESTAMP";
my @DATABASES			= getDatabases;


my $log_level			= 0;
my @folders				= ("/srv/ftp","/home/administrator/testscripte");

print "TIMESTAMP=$TIMESTAMP";
print "CURRENT_BACKUP_DIR=$CURRENT_BACKUP_DIR";

#backupDB();
backup();
sub backup
{
	msgFHEM("setreading Backup info backup starting now");
	my $state = checkState();
	print "BACKUP - State:$state";
	if ($state eq "online")
	{
		my $result = qx(mount -t nfs $NAS_IP:$NAS_VOLUME $NAS_LOCAL_VOLUME 2>&1);
		my $mount = qx(mount | grep $NAS_VOLUME | awk '{print \$2}');
		chomp($mount);
		if ($mount eq "on")
		{
			print "NFS wurde gemountet";
		}
		else
		{
			print "NFS konnte nicht gemountet werden";
		}		
	}
	else
	{
		msgFHEM("set Backup error");
		msgFHEM("setreading Backup info Nas ist Offline");
	}

}
sub getDatabases 
{
	#print "GetDatabases";
	#print "Username:$MYSQL_USER";
	my $dsn = "DBI:mysql:host=$MYSQL_HOST";
	my $dbh	= DBI->connect($dsn,$MYSQL_USER,$MYSQL_PASSWD,{PrintError => 0, RaiseError => 1});
	my $query = qq^SHOW DATABASES^;
	my $sth		= $dbh->prepare($query);
	$sth->execute();
	my @tmpdb;
	while (my $db = $sth->fetchrow_array())
	{
		if ($db ne "information_schema")
		{
			push (@tmpdb,$db);
		}
		
	}
	$sth->finish;
	$dbh->disconnect;
	return @tmpdb;
}
sub backupDB
{
	checkandcreateFolder($CURRENT_BACKUP_DIR);
	foreach my $db (@DATABASES)
	{
		print "Datenbank:$db wird gesichert";
		my $cmd = "mysqldump -u$MYSQL_USER -p$MYSQL_PASSWD $db > $CURRENT_BACKUP_DIR/$TIMESTAMP-$db.sql";
		print "CMD:$cmd";
		my $result = system($cmd);
		if ($result eq "0")
		{
			print "Result=$result";
		}
		
	}	

}
sub checkandcreateFolder
{
	my $folder = shift;
	print "Verzeichnis:$folder";
	if (!-d $folder)
        {
            print "Verzeichnis $folder existiert nicht!";
            mkpath($folder, 0, 0755);
            if (-d $folder)
            {
                print "Verzeichnis $folder wurde erstellt";
            }
            else
            {
                print "Verzeichnis $folder konnte nicht erstellt werden";
                print "Programm Abbruch!";
                exit(1);
            }
        }
}

sub msgFHEM
{
	my $msg = shift;
	print "Funktion:msgFHEM";
	print "msgFHEM - msg:$msg";
	qx(perl /opt/fhem/fhem.pl 7072 \"$msg\");
}

sub checkState
{
	my $ping = "ping -c 1 -w 2 $NAS_IP"; 
	#Log3 $hash, 3, "[$name] executing: $ping";
	my $res = qx ($ping);
      $res = ""   if (!defined($res));
  
   #Log3 $hash, 3, "[$name] result executing ping: $res";

   my $return;
   if ($res =~ m/100%/)
	{
		$return = "offline";
	}
	else
	{
		$return = "online";
	}
   
   return $return;
}
