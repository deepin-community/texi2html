#! /usr/bin/perl -w
#+##############################################################################
#
# manage_i18n.pl: manage translation files
#
#    Copyright (C) 2003-2005  Patrice Dumas <dumas@centre-cired.fr>,
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
#    02110-1301  USA
#
#-##############################################################################

# This requires perl version 5 or higher
require 5.0;

use strict;

use File::Copy;
#use Data::Dumper;
use Data::Dumper;
use Getopt::Long qw(GetOptions);

my $USE_DATA_DUMPER = '1';
select(STDERR);
$| = 1;
select(STDOUT);
$| = 1;

my $help = 0;
my $language;
my $dir = 'i18n'; # name of the directory containing the per language files
my $output; # file containing all the translations or output directory
# = 'translations.pl'; # file containing all the translations
my @known_languages = ('en', 'de', 'nl', 'es', 'no', 'pt', 'pt_BR', 'ja',
  'fr'); # The supported languages
my @searched_dirs = (); # dir searched for sources and language files

#my $template = 'template';
my $template_lang = 'en';
my @sources = ('texi2html.pl', 'texi2html.init', 'T2h_i18n.pm', 
 'examples/roff.init', 'examples/noheaders.init');

GetOptions('Include=s' => \@searched_dirs, 'output=s' => \$output, 
  'directory=s' => \$dir, 'help+' => \$help);


if ($help)
{
    my $command_basename = $0;
    $command_basename =~ s%.*/%%;
    my $usage_text = <<EOT;
Usage: 
  $command_basename -h
  $command_basename [-I <dir>][-d <i18n_dir>][-o <out_dir>] template source_files...
  $command_basename [-I <dir>][-d <i18n_dir>][-o <out_dir>] update [ language... ]
  $command_basename [-I <dir>][-d <i18n_dir>][-o <result_file>] merge

Default languages are files in the i18n_dir without the following extensions:
.bak,.orig,.old,.dpkg-old,.rpmnew,.rpmsave
EOT
    print $usage_text;
    exit 0;
}

if (!@searched_dirs)
{
    @searched_dirs = ('.');
}

if (@ARGV < 1)
{
    die "Need a command\n";
}

my $command = shift @ARGV;

my $output_dir = $dir;
$output_dir = $output if (defined($output));

my $translations_file = 'translations.pl';
$translations_file = $output if (defined($output));

sub locate_file($$)
{
    my $file = shift;
    my $directories = shift;

    $directories = \@searched_dirs if !defined($directories);

    if ($file =~ /^\//)
    {
         return $file if (-e $file and -r $file);
    }
    else
    {
         foreach my $dir (@$directories)
         {
              next unless (-d "$dir");
              return "$dir/$file" if (-e "$dir/$file" and -r "$dir/$file");
         }
    }
    return undef;
}

my $defaults_file = "$dir/$template_lang";

use vars qw(
$LANGUAGES 
$T2H_OBSOLETE_STRINGS
);

# Strings not in code
my $template_strings =
{
 'January' => '', 
 'February' => '',
 'March' => '', 
 'April' => '',
 'May' => '',
 'June' => '',
 'July' => '',
 'August' => '',
 'September' => '',
 'October' => '',
 'November' => '',
 'December' => '', 
 'T2H_today' => '%s, %d %d',
};

# Handle per language files
if ($USE_DATA_DUMPER)
{
   $Data::Dumper::Sortkeys = 1;
}

sub update_language_file($$$$$);

#die "No suitable $dir directory\n" unless (-d $dir and -r $dir);

sub get_languages($$)
{
    my $directories = shift;
    my $i18n_dir = shift;
    my @languages = ();
    foreach my $searched_dir (@$directories)
    {
         my $dir = "$searched_dir/$i18n_dir";
         if (opendir DIR, $dir)
         {
             my @new_languages = grep {
                 ! /^\./ &&
                 ! /\.(bak|orig|old|dpkg-old|rpmnew|rpmsave)$/ &&
                 ! /~$/ &&
                 ! /^#.*#$/ &&
                -f $dir . '/' . $_
             } readdir DIR;
             closedir DIR;
             foreach my $language (@new_languages)
             {
                 push @languages, $language unless grep {$_ eq $language}
                       @languages;
             }
         }
    }
    my @known = @known_languages;
    foreach my $lang (@languages)
    {
         if (grep {$_ eq $lang} @known)
         {
              @known = grep {$_ ne $lang} @known;
         }
         else
         {
             warn "Remark: you could update the known languages array for `$lang'\n";
         }
    }
    warn "Remark: the following known languages have no corresponding file: @known\n" if (@known);
    return @languages;
}

sub merge_i18n_files($$$)
{
    my $directories = shift;
    my $i18n_dir = shift;
    my $translation_file = shift;
    my @languages = get_languages($directories, $i18n_dir);
    die "No languages found\n" unless (@languages);
    if (-f $translation_file)
    {
        unless (File::Copy::copy ($translation_file, "$translation_file.old"))
        {
            die "Error copying $translation_file to $translation_file.old\n";
        }
    }
    #foreach my $lang ($template, @known_languages)
    die "open $translation_file failed" unless (open (TRANSLATIONS, ">$translation_file"));
    foreach my $lang (@languages)
    {
         my $file = locate_file("$i18n_dir/$lang", $directories);
         next unless defined($file);
         unless (open (FILE, $file))
         {
              warn "open $file failed: $!\n";
              return;
         }
         while (<FILE>)
         {
              print TRANSLATIONS;
         }
         close FILE;
    }
}
        
sub update_language_hash($$$)
{
    my $from_file = shift;
	my $lang = shift;
	my $reference = shift;

    if (defined($from_file) and -f $from_file)
    {
        eval { require($from_file) ;};
        if ($@)
        {
            warn "require $from_file failed: $@\n";
            return;
        }
        if (!defined($LANGUAGES->{$lang}))
        {
            warn "LANGUAGES->{$lang} not defined in $from_file\n";
            return;
        }
    }
    if (!defined($T2H_OBSOLETE_STRINGS->{$lang}))
    {
        $T2H_OBSOLETE_STRINGS->{$lang} = {};
    }
    if (!defined($LANGUAGES->{$lang}))
    {
        $LANGUAGES->{$lang} = {};
    }
	
	foreach my $string (keys %{$LANGUAGES->{$lang}})
	{
        $T2H_OBSOLETE_STRINGS->{$lang}->{$string} = $LANGUAGES->{$lang}->{$string}
            if (defined($LANGUAGES->{$lang}->{$string}) and ($LANGUAGES->{$lang}->{$string} ne ''));
    }
	
    $LANGUAGES->{$lang} = {};
    
    foreach my $string (keys (%{$reference}))
    {
        if (exists($T2H_OBSOLETE_STRINGS->{$lang}->{$string}) and
            defined($T2H_OBSOLETE_STRINGS->{$lang}->{$string}) and
            ($T2H_OBSOLETE_STRINGS->{$lang}->{$string} ne ''))
        {
             $LANGUAGES->{$lang}->{$string} = $T2H_OBSOLETE_STRINGS->{$lang}->{$string};
             delete $T2H_OBSOLETE_STRINGS->{$lang}->{$string};
        }
        else
        {
             $LANGUAGES->{$lang}->{$string} = '';
        }
    }
	return 1;
}

# Based on the template file, update the different language files
sub update_i18n_files($$$$@)
{
    my $directories = shift;
    my $i18n_dir = shift;
    my $out_i18n_dir = shift;
    my $template_language = shift;

    my @languages = grep {$template_language ne $_} 
         get_languages($directories, $i18n_dir);
    if (@_)
    {
        @languages = ();
        foreach my $lang (@_)
        {
            unless (grep {$lang eq $_} @known_languages)
            {
                warn "Remark: you could update the known languages array for `$lang'\n";
            }
            push (@languages, $lang) unless (grep {$lang eq $_} @languages);
        }
    }
    unless (@languages)
    {
        warn "No languages to update\n" ;
        return;
    }
    
    my $template_file = locate_file("$i18n_dir/$template_language", 
         $directories);
    die "No $i18n_dir/$template_language found\n" unless 
         (defined($template_file));
    eval { require($template_file) ;};
    if ($@)
    {
        die "require $template_file failed: $@\n";
    }
    die "LANGUAGE->{'$template_language'} undef after require $template_file\n" unless
         (defined($LANGUAGES) and defined($LANGUAGES->{$template_language}));
    foreach my $string (keys(%$template_strings))
    {
        die "template string $string undef" 
           unless (defined($LANGUAGES->{$template_language}->{$string}));
    }
    unless (-d $out_i18n_dir)
    {
        if (!mkdir($out_i18n_dir, oct(755)))
        {
            die "cannot mkdir $out_i18n_dir: $!\n";
        }
    }
    foreach my $lang (@languages)
    {
        update_language_file($directories, $i18n_dir, $out_i18n_dir, 
            $template_language, $lang);
    }
    return 1;
}

sub copy_or_touch($$)
{
    my $from_file = shift;
    my $to_file = shift;
    my $atime = time;
    my $mtime = $atime;
    if ($to_file eq $from_file)
    {
        utime $atime, $mtime, $from_file;
        return;
    }
    elsif (-f $to_file)
    {
        my $identical_files = 1;
        if (open(FROMFILE, $from_file))
        {
             if (open(TOFILE, $to_file))
             {
                  my $to_file_lines = '';
                  my $from_file_lines = '';
                  while (<FROMFILE>)
                  {
                       $from_file_lines .= $_;
                  }
                  while (<TOFILE>)
                  {
                       $to_file_lines .= $_;
                  }
                  if ($from_file_lines eq $to_file_lines) 
                  {
                       utime $atime, $mtime, $from_file;
                       return;
                  }
             }
        }
        else
        {
             warn "Error opening $from_file\n";
             utime $atime, $mtime, $to_file;
        }            
    }
    unless (File::Copy::copy($from_file, $to_file))
    {
        warn "Error copying $from_file to $to_file\n";
    }
}

sub update_language_file($$$$$)
{
    my $directories = shift;
    my $i18n_dir = shift;
    my $out_i18n_dir = shift;
    my $template_language = shift;
    my $lang = shift;
    my $from_file = locate_file("$i18n_dir/$lang", $directories);
    my $to_file = "$out_i18n_dir/$lang";

    return unless (defined($from_file));

    return unless (update_language_hash($from_file, $lang,
        $LANGUAGES->{$template_language}));

    if (-f $to_file)
    {
        unless (File::Copy::copy($to_file, "$to_file.old"))
        {
            warn "Error copying $to_file to $to_file.old\n";
            return;
        }
    }
    if (!$USE_DATA_DUMPER)
    {
        copy_or_touch($from_file, $to_file);
        return;
    }
    unless (open(FILE, ">$to_file"))
    {
         warn "open $to_file failed: $!\n";
         return;
    }
	
    print FILE "" . Data::Dumper->Dump([$LANGUAGES->{$lang}], [ "LANGUAGES->{'$lang'}" ]);
    print FILE "\n";
    print FILE Data::Dumper->Dump([$T2H_OBSOLETE_STRINGS->{$lang}], [ "T2H_OBSOLETE_STRINGS->{'$lang'}"]);
    print FILE "\n";
    print FILE "\n";
    close FILE;
}

sub update_template($$$$@)
{
    my $directories = shift;
    my $i18n_dir = shift;
    my $template_language = shift;
    my $out_dir = shift;
    my $source_strings = {};
    unless (@_)
    {
        die "No source files\n";
    }
    foreach my $source (@_)
    {
        my $source_file = locate_file($source, $directories);
        unless (defined($source_file))
        {
            warn "$source_file not found\n";
            next;
        }
        unless (open (FILE, "$source_file"))
        {
            warn "open $source_file failed: $!\n";
            next;
        }
        my $line_nr = 0;
        while (<FILE>)
        {
             $line_nr++;
             my $string;
             next if /^\s*#/;
             while ($_)
             {
                  if (defined($string))
                  {
                       if (s/^([^\\']*)(\\|')//)
                       {
                            $string .= $1 if (defined($1));
                            if ($2 eq "'")
                            {
                                 $source_strings->{$string} = '' ;
                                 $string = undef;
                            }
                            else
                            {
                                 if (s/^(.)//)
                                 {
                                      #$string .= '\\' . $1;
                                      $string .= $1;
                                 }
                                 else
                                 {
                                      warn "\\ at end of line, file $source_file, line nr $line_nr\n";
                                      $source_strings->{$string} = '' ;
                                      $string = undef;
                                 }
                            }
                       }
                       else
                       {     
                            warn "string not closed file $source_file, line nr $line_nr\n";
                            $source_strings->{$string} = '' ;
                            $string = undef;
                       }
                  }
                  elsif (s/^.*?&\$I\s*\('//)
                  {
                       $string = '';
                  }
                  else
                  {
                       last;
                  }
             }
        }
        close FILE;
    }
    foreach my $string (keys(%$template_strings))
    {
        $source_strings->{$string} = $template_strings->{$string};
    }
    my $template_file = 
        locate_file("$i18n_dir/$template_language",$directories);
    die unless (update_language_hash($template_file, 
            $template_language, $source_strings));
	foreach my $string (keys(%$template_strings))
	{ # use values in template_srings if it exists
        my $existing_string = $LANGUAGES->{$template_language}->{$string};
        $LANGUAGES->{$template_language}->{$string} = $template_strings->{$string} 
          if ((!defined($existing_string)) or ($existing_string eq ''));
    }
    unless (-d $out_dir)
    {
        if (!mkdir($out_dir, oct(755)))
        {
            die "cannot mkdir $out_dir: $!\n";
        }
    }
    my $out_template_file = "$out_dir/$template_language";
    
    if (!$USE_DATA_DUMPER)
    {
        return if (!defined($template_file));
        copy_or_touch($template_file, $out_template_file);
        return;
    }
    unless (open(TEMPLATE, ">$out_template_file"))
    {
        die "open $out_template_file failed: $!\n";
    }
    print TEMPLATE "" . Data::Dumper->Dump([$LANGUAGES->{$template_language}], [ "LANGUAGES->{'$template_language'}" ]);
    print TEMPLATE "\n";
    print TEMPLATE Data::Dumper->Dump([$T2H_OBSOLETE_STRINGS->{$template_language}], [ "T2H_OBSOLETE_STRINGS->{'$template_language'}"]);
    print TEMPLATE "\n";
    print TEMPLATE "\n";
    close TEMPLATE;
}

if ($command eq 'update')
{
    update_i18n_files(\@searched_dirs, $dir, $output_dir, 
         $template_lang, @ARGV);
}
elsif ($command eq 'merge')
{
    merge_i18n_files(\@searched_dirs, $dir, $translations_file);
}
elsif ($command eq 'template')
{
    my @source_files = @ARGV;
    unless (@source_files)
    {
         @source_files = @sources;
    }
    update_template(\@searched_dirs, $dir, $template_lang, $output_dir,
          @source_files);
}

#elsif ($command eq 'all')
#{
#    my @source_files = @ARGV;
#    unless (@source_files)
#    {
#         @source_files = @sources;
#    }
#    update_template(\@searched_dirs, $dir, $output_dir, $template_lang, 
#         @source_files);
#    update_i18n_files(\@searched_dirs, $dir, $dir,
#          $template_lang, "$output_dir/$template_lang");
#    merge_i18n_files(\@searched_dirs, $dir, $translations_file);
#}
else
{
    warn "Unknown i18n command: $command\n";
}
exit 0;

1;
