#!/usr/bin/env perl

use 5.010.001;
use Function::Parameters;
use Types::Standard qw(Str Int ArrayRef RegexpRef);
use JSON -convert_blessed_universally;
use Image::ExifTool qw(:Public);
use File::Basename;
use File::Spec;
use File::Path qw(make_path remove_tree);
use Carp qw(croak carp);

# set backup directory
my $backupdir = "backup";

fun main ()
{
    mkdir $backupdir unless -d $backupdir;

    my @files = &getVideoFiles();

    for $file (@files) {
        my $backup = &backupAndReturnBackFileName($file);
        &cutVideoEnd($backup, $file);
    }
}

fun getVideoFiles ()
{
    my @videos;
    my @suffix = qw(*.mp4 *.mov);
    for my $suffix (@suffix) {
        my @files = `find * -type f -iname "$suffix"`;
        chomp(@files);

        # exclude files already in backup directory
        my @files = grep !/^$backupdir\//, @files;
        push @videos, @files;
    }
    return @videos;
}

# move $file to $backupdir and keep the directory structure
# return the full path of the backup
fun backupAndReturnBackFileName ($file)
{
    # get the file name and path
    my ( $dir, $filename, $fullname ) = &getDirnameFilename($file);

    # create backupdir/path if doesn't exist
    my $backuppath = File::Spec->catdir($backupdir, $dir);
    system("mkdir $backuppath") unless -e $backuppath;

    # move file to backupdir/path
    system("mv -n $fullname $backuppath");

    # return backupdir/path/filename
    return File::Spec->catfile( $backuppath, $filename);
}

fun cutVideoEnd ($input, $output)
{
    return if -e $output;

    say "$input         => $output";
    my $cut_duration = 3;
    my $input_duration = `ffprobe -v error -select_streams v:0 -show_entries stream=duration -of default=noprint_wrappers=1:nokey=1 '$input'`;
    my $output_duration = $input_duration - $cut_duration;
    system("ffmpeg -i '$input' -map 0 -c copy -t $output_duration '$output'");
}

# copy file to target directory $dst.
# if $dst/$file exists and differ from $file, do nothing.
fun copyToFolder ( $file, $dst )
{
    system("mkdir -p $dst") unless -e $dst;

    my $fn = basename $file;
    if ( -e "$dst/$fn" and "$dst/$fn" eq $file ) {
        say "'$dst/$fn' and '$file' are the same file";
        return;
    }
    if ( -e "$dst/$fn" and isDiff( $file, "$dst/$fn" ) ) {
        say "'$dst/$fn' exists and differ from '$file'";
        return;
    }
    my $cmd = $config->{'command'};
    system("$cmd $file $dst");
}

fun getDirnameFilename (Str $file, Str $path=".")
{
    my $dir      = dirname $file;
    my $filename = basename $file;
    $dir = File::Spec->catdir( $path, $dir ) if ($path);
    my $fullname = File::Spec->catfile( $dir, $filename );
    return ( $dir, $filename, $fullname );
}

fun openFile (Str $file, Str :$path=".", Str :$mode = '<')
{
    my ( $dir, $filename, $fullname ) = getDirnameFilename( $file, $path );

    make_path( $dir, { mode => 0777 } ) if $dir;
    open my $fh, $mode, $fullname or croak "cannot access $fullname\n";
    return $fh;
}

fun getFileContent (Str $file, Str :$path=".")
{
    my $fh  = openFile( $file, path => $path ) or croak "$file $!";
    my @tmp = <$fh>;
    close($fh);
    return @tmp;
}

fun readConfigFile ( $filename )
{
    my @data        = &getFileContent($filename);
    my $onelinedata = join "\n", @data;
    return from_json($onelinedata);
}

&main();
