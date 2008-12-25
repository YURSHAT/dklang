#!/usr/bin/perl
#****************************************************************
#  $Id$
#****************************************************************
# Requires the following environment variables to be set:
#   CHM_API_FILE_PREFIX
#   HELP_COMPILER
#

use strict;
use locale;

 # Declare constants
my $usr_short_name        = 'DKLang API';

my $src_path              = 'C:/Dev/DKLang';
my $out_path              = 'C:/Dev/DKLang/Help';
my $file_prefix           = $ENV{'CHM_API_FILE_PREFIX'};
my $css_file              = 'main.css';
my $toc_file              = $file_prefix.'index.html';
my $typeidx_file          = $file_prefix.'types.html';
my $source_hhp_file       = 'dklang.hhp';
my $hhp_file              = $file_prefix.'project.hhp';
my $source_hhc_file       = 'dklang.hhc';
my $hhc_file              = $file_prefix.'contents.hhc';
my $hhk_file              = $file_prefix.'keywords.hhk';
my $hh_compiler           = $ENV{'HELP_COMPILER'};
my $insert_contents_after = 'DKLang API Reference'; # ������, ����� �������� ��������� ������ � ���� ����������
 # Validate external variables
die("ERROR: CHM_API_FILE_PREFIX environment variable should be set.\n") unless ($file_prefix);
die("ERROR: HELP_COMPILER environment variable should be set.\n") unless ($hh_compiler);

my %units;     # ������ -> ������� -> �������� ��������
my %allobjs;   # ������ ������ �� ��� �������
my @htmlfiles; # ������ ������ HTML-������
 # ����
my @types = (
    { CHAR    => 'I',
      NAME    => 'Interfaces',
      TITLE   => 'interface',
      PRINTER => sub { qq|$_[0]->{NAME} = interface(<span class=declaration>$_[0]->{DECL}</span>)|; }
    },
    { CHAR    => 'C',
      NAME    => 'Classes',
      TITLE   => 'class',
      PRINTER => sub { qq|$_[0]->{NAME} = class(<span class=declaration>$_[0]->{DECL}</span>)|; }
    },
    { CHAR    => 'R',
      NAME    => 'Records',
      TITLE   => 'record',
      PRINTER => sub { qq|$_[0]->{NAME} = $_[0]->{DECL}|; }
    },
    { CHAR    => 'P',
      NAME    => 'Pointers',
      TITLE   => 'pointer',
      PRINTER => sub { qq|$_[0]->{NAME} = ^<span class=declaration>$_[0]->{DECL}</span>|; }
    },
    { CHAR    => 'E',
      NAME    => 'Enumerations',
      TITLE   => 'enumeration',
      PRINTER => sub { qq|$_[0]->{NAME} = <span class=declaration>$_[0]->{DECL}</span>|; }
    }
  );
 # ���������� ��� ������ �� ���� �� typechar
my %typebychar;
foreach(@types) { $typebychar{$_->{CHAR}} = $_; }

 # ���������� ������ �������� ���� Delphi
my %keywords;
foreach(
  split ' ',
    'and array as asm at automated begin case class const constructor destructor dispinterface div '.
    'do downto else end except exports file finalization finally for function goto if implementation '.
    'in inherited initialization inline interface is label library mod nil not object of on or out '.
    'packed private procedure program property protected public published raise read record repeat '.
    'resourcestring set shl shr string then threadvar to try type unit until uses var while with write xor'
  ) { $keywords{$_} = 1; }

 # ������������ �����
foreach(glob "$src_path/*.pas") { processFileCallback($_); }
if (%units){
   # ������ �������� �������
  mkdir $out_path, 0777;
   # ���������� �����
  print "Writing HTML files...\n";
  writeHTML();
   # ������� ������ �����
  print "Writing type index...\n";
  writeTypeIndex();
   # ������ ������ HTML Help
  print "Writing HTML Help Project...\n";
  writeHHP();
  print "Writing HTML Help Project Contents...\n";
  writeHHC();
  print "Writing HTML Help Project Keywords...\n";
  writeHHK();
  print "Generating HTML Help...\n";
  my $dos_hhp = "$out_path/$hhp_file";
  $dos_hhp =~ s|/|\\|g;
  print `"$hh_compiler" $dos_hhp`;
   # ������� ��������������� �����
  print "Removing generated files...\n";
  my $dos_remove_pattern = "$out_path/$file_prefix*.*";
  $dos_remove_pattern =~ s|/|\\|g;
  `del $dos_remove_pattern`;
  print "Done\n";
  exit 0;
} else {
  print "No files found\n";
  exit 1;
}

######################################################################################################################

sub hiliteKeyword {
  my ($word, $pre) = @_;
  if ($pre !~ /.*<[^>]*$/) {
    if ($keywords{lc($word)}) {
      $word = "<span class=keywd>$word</span>";
    } elsif (my $refobj = $allobjs{$word}) {
      $word = qq|<a href="$refobj->{HTMLFILE}" title="$typebychar{$refobj->{TYPE}}->{TITLE} $refobj->{REFUNIT}->{NAME}.$word">$word</a>|;
    }
  }
  return $word;
}
sub hiliteSymbol {
  my ($sym, $pre) = @_;
  return ($pre !~ /.*<[^>]*$/)?"<span class=symbol>$sym</span>":$sym;
}

 # ������������ ���������: (String): String
sub highlight($) {
  my $str = shift;
  $str =~ s|(\w+)|hiliteKeyword($1, $`)|ge;      # �������� �����
  $str =~ s|([^\w<> ]+)|hiliteSymbol($1, $`)|ge; # �������
  return $str;
}

 # ������������ ������: (RefUnit, ObjName, ObjTypeChar, ObjDecl, ObjComment)
sub regObj {
  my $refobj = {
    REFUNIT  => $_[0],
    NAME     => $_[1],
    HTMLFILE => "$file_prefix$_[0]->{NAME}-$_[1].html",
    TYPE     => $_[2],
    DECL     => $_[3],
    COMMENT  => $_[4],
    ATTRS    => {}
  };
  $_[0]->{OBJECTS}->{$_[1]} = $refobj;
  $allobjs{$_[1]} = $refobj;
  return $refobj;
}

 # Callback-���������, ���������� ��� �����. ������������ �������� ����, �������� ���. ������ ������� � %units
sub processFileCallback {
  if (-s && /\.pas$/i) {
    my $file = shift; #$File::Find::name;
     # Parse the input file
    open(FI, $file) or die "Cannot open $file for reading: $!";
    my $intf_clause = 0;
    my $type_clause = 0;
    my $header_processed = 0;
    my $comment = '';
    my $refunit;
    my $refobject;
    while(<FI>){
      chomp;
       # ���� ������ �������� ������ �����������, ���������� ���
      if (m|^\s*//\s*(?:--)?\s*(.*[A-Za-z�-�].*)| && !m(\$Id:|///|Props|Prop handlers|Prop storage|Message handlers|Events)i) {
        $comment .= ($comment?' ':'').$1;
       # ��������� ������: unit XXXXX;
      } elsif (/^\s*unit\s+(\w+)\;/i) {
        $refunit = {
          NAME     => $1,
          HTMLFILE => $file_prefix."unit-$1.html",
          SIZE     => -s $file,
          COMMENT  => $comment,
          OBJECTS  => {}
        };
        $units{$1} = $refunit;
       # 'interface' section
      } elsif ($refunit && /^\s*interface\s*$/i) {
        $intf_clause = 1;
       # 'type' section
      } elsif ($intf_clause && /^\s*type\s*$/i) {
        $type_clause = 1;
       # end of 'type' section
      } elsif ($type_clause && /^\s*(?:const|var|resourcestring|threadvar)\s*$/i) {
        $type_clause = 0;
       # 'implementation' section
      } elsif (/^\s*implementation\s*$/i) {
        last;
       # ���������� �������
      } elsif ($type_clause && /\b(\w+)\s*=\s*(class|interface)\(\s*([\w, ]+)\s*\)/i) {
        $refobject = regObj($refunit, $1, uc(substr($2, 0, 1)), $3, $comment);
        $comment = '';
       # ���������� ������
      } elsif ($type_clause && /\b(\w+)\s*=\s*((?:packed\s*)?record)/i) {
        $refobject = regObj($refunit, $1, 'R', $2, $comment);
        $comment = '';
       # ���������� ���������
      } elsif ($type_clause && /\b(\w+)\s*=\s*\^\s*(\w+)/) {
        $refobject = regObj($refunit, $1, 'P', $2, $comment);
        $comment = '';
       # ���������� ������������
      } elsif ($type_clause && /\b(\w+)\s*=\s*(\([\s\w.,]+\))/) {
        $refobject = regObj($refunit, $1, 'E', $2, $comment);
        $comment = '';
       # ������� �������
      } elsif ($refobject && /^\s*(property|function|procedure)\s*(\w+)\s*(.*;)/i) {
        $refobject->{ATTRS}->{$2} = {
          NAME    => $2,
          KIND    => $1,
          DECL    => $3,
          COMMENT => $comment
        };
        $comment = '';
       # ���� ������
      } elsif ($refobject && $refobject->{TYPE} eq 'R' && /^\s*(\w+)\s*:\s*(\w+)\s*;\s*(?:\/\/\s*)?(.*)/) {
        $refobject->{ATTRS}->{$1} = {
          NAME    => $1,
          KIND    => '',
          DECL    => ': '.$2,
          COMMENT => $3
        };
        $comment = '';
       # ����� �������� �������
      } elsif ($refobject && /\bend\s*;/) {
        undef $refobject;
        $comment = '';
      } elsif (/\w+/ && !/^\s*type\s*$/i) {
        $comment = '';
      }
    }
    close(FI);
  }
}

 # ����� ���������� HTML-����� (FileHandle)
sub writeFileFooter($) {
  my $fh = shift;
  print $fh <<END;
  </div>
</body>
</html>
END
}

 # ����� ��������� HTML-����� (FileHandle, Title, Header, Comment)
sub writeFileHeader {
  my ($fh, $title, $header, $comment) = @_;
  print $fh <<END;
<html>
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=windows-1251">
  <title>$title</title>
  <link rel="stylesheet" type="text/css" href="$css_file">
</head>
<body>
  <h1>$header</h1>
  <p align=center>$comment
  <div class=pagebody>
END
}

 # ������� HTML Help Project Contents
sub writeHHC {
   # ���������� ���������� API reference
  my $new_contents =
    qq|<ul>\n|.
    qq|  <li><object type="text/sitemap"><param name="Name" value="Units"><param name="Local" value="$toc_file"></object>\n|.
    qq|  <ul>\n|;
   # -- ���� �� �������
  foreach my $unitname(sort keys %units) {
    my $refunit = $units{$unitname};
    $new_contents .=
      qq|  <li><object type="text/sitemap"><param name="Name" value="$unitname"><param name="Local" value="$refunit->{HTMLFILE}"></object>\n|.
      qq|  <ul>\n|;
     # ���� �� ��������
  my %objects = %{$refunit->{OBJECTS}};
    foreach my $objname(sort keys %objects) {
    my $refobj = $objects{$objname};
      $new_contents .= qq|  <li><object type="text/sitemap"><param name="Name" value="$objname"><param name="Local" value="$refobj->{HTMLFILE}"></object>\n|;
    }
    $new_contents .= qq|  </ul>\n|;
  };
   # -- ����������
  $new_contents .=
    qq|  </ul>\n|.
    qq|  <li><object type="text/sitemap"><param name="Name" value="Type Index"><param name="Local" value="$typeidx_file"></object>\n|.
    qq|</ul>\n|;
   # ���������� ����� ����������
   # -- ��������� �������� ���� ����������
  open(FH_In, "$out_path/$source_hhc_file") or die "Cannot open $out_path/$source_hhc_file for reading: $!\n";
   # -- ��������� ���� ������ ���������� �� ������
  open(FH_Out, ">$out_path/$hhc_file") or die "Cannot open $out_path/$hhc_file for writing: $!\n";
  my $insertion_point_found = 0;
  while(<FH_In>) {
     # ������� ������ ������������� ����� ����������
    print FH_Out $_;
     # ���� ��� ������ ������, ����� �������� ����� �������� ����� ���������� - ������� ����
    $insertion_point_found = 1 if(/<param name="Name" value="$insert_contents_after">/i);
     # ��������� ����� ���������� ����� �������� �������
    if($insertion_point_found && /<\/object>/i) {
      $insertion_point_found = 0;
      print FH_Out $new_contents;
    }
  }
  close(FH_Out);
  close(FH_In);
}

 # ������� HTML Help Project Keywords
sub writeHHK {
  open(FHK, ">$out_path/$hhk_file") or die "Cannot open $out_path/$hhk_file for writing: $!\n";
   # ���������
  print FHK <<END;
<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML//EN">
<html>
<head></head>
<body>
<ul>
END
   # ���� �� �������� � �������
  foreach my $kw(sort (keys %units, keys %allobjs)) {
    my $refobj = $allobjs{$kw};
    my $file = $refobj ? $refobj->{HTMLFILE} : $units{$kw}->{HTMLFILE};
    print FHK qq|  <li><object type="text/sitemap"><param name="Name" value="$kw"><param name="Local" value="$file"></object>\n|;
  };
   # ����������
  print FHK
    qq|</ul>\n|.
    qq|</body></html>\n|;
  close(FHK);
}

 # ������� HTML Help Project
sub writeHHP {
   # ���������� ����� ���� �������
   # -- ��������� �������� ���� �������
  open(FH_In, "$out_path/$source_hhp_file") or die "Cannot open $out_path/$source_hhp_file for reading: $!\n";
   # -- ��������� ���� ������ ������� �� ������
  open(FH_Out, ">$out_path/$hhp_file") or die "Cannot open $out_path/$hhp_file for writing: $!\n";
  while(<FH_In>) {
     # ��������� �������� ����������
    s/^(Contents file=).*/$1$hhc_file\n/;
     # ������� ������ ������������� ����� ����������
    print FH_Out $_;
     # ��������� ���� �������� ���� � ������ [OPTIONS]
    print FH_Out "Index file=$hhk_file\n" if(/\[OPTIONS\]/i);
     # ��������� ������ ������ � ������ [FILES]
    print FH_Out join("\n", @htmlfiles), "\n" if(/\[FILES\]/i);
  }
  close(FH_Out);
  close(FH_In);
}

 # ������� ��������� ������ � ���� HTML-������
sub writeHTML{
   # ��������� ���� TOC
  push @htmlfiles, $toc_file;
  open(FHTOC, ">$out_path/$toc_file") or die "Cannot open $out_path/$toc_file for writing: $!\n";
  writeFileHeader(
    \*FHTOC,
    'Unit Reference',
    'Unit Reference',
    qq|List of <b>$usr_short_name</b> units in alphabetical order - <a href="$typeidx_file">Type Index</a>|);
   # ������� ��������� ������� �������
  print FHTOC
    "<table class=framed align=center>\n".
    "<tr><th>Unit</th><th>Size</th><th>Description</th></tr>\n";
  my $idx_unit = 0;
  foreach my $unitname(sort keys %units) {
    my $refunit = $units{$unitname};
     # ������� ���������� ����� �������� / ��������� ������ ��������� �����
    my $type_nav_html = '';
    foreach my $reftype(@types) {
      my $typechar = $reftype->{CHAR};
       # ���� �� �������� ������
      my $objcount = 0;
      foreach my $objname(keys %{$refunit->{OBJECTS}}) { $objcount++ if $refunit->{OBJECTS}->{$objname}->{TYPE} eq $typechar; }
       # ���� ���� ������� �������� ���� - ��������� � ������ ���������
      $type_nav_html .=
        qq| <a href="$refunit->{HTMLFILE}#$typechar" title="$reftype->{NAME}: $objcount"><span class=framed>$typechar<span class=sub>$objcount</span></span></a>|
        if $objcount;
    }
     # ��������� ������ � TOC
    my $unit_color = $idx_unit%2?' bgcolor=#f0f0f0':'';
    print FHTOC
      qq|<tr$unit_color>\n|.
      qq|  <td><a href="$refunit->{HTMLFILE}">$unitname</a><br>$type_nav_html</td>\n|.
      qq|  <td class=comment align=right>$refunit->{SIZE}</td>\n|.
      qq|  <td class=comment>$refunit->{COMMENT}</td>\n|.
      qq|</tr>\n|;
     # ������ HTML-���� ������
    writeUnit($refunit);
     # ����������� ������ ������
    $idx_unit++;
  };
   # ������� ���������� ������� �������
  print FHTOC "</table>\n";
   # ��������� ���� TOC
  writeFileFooter(\*FHTOC);
  close(FHTOC);
}

 # ������ HTML-���� �������: (RefUnit, RefObj)
sub writeObj {
  my ($refunit, $refobj) = @_;
   # ������ HTML-���� �������
  push @htmlfiles, $refobj->{HTMLFILE};
  open(FHO, ">$out_path/$refobj->{HTMLFILE}") or die "Cannot open $out_path/$refobj->{HTMLFILE} for writing: $!\n";
  writeFileHeader(
    \*FHO,
    "$refunit->{NAME} / $refobj->{NAME}",
    qq|<a href="$toc_file">$usr_short_name</a> / <a href="$refunit->{HTMLFILE}">$refunit->{NAME}</a> / $refobj->{NAME} $typebychar{$refobj->{TYPE}}->{TITLE}|,
    $refobj->{COMMENT});
     # ���� �� ��������� �������
    my $idx_attr = 0;
    print FHO "<table class=framed align=center>\n";
    foreach my $attrname(sort keys %{$refobj->{ATTRS}}) {
      my $refattr = $refobj->{ATTRS}->{$attrname};
      my $attr_color = $idx_attr%2?' bgcolor=#f0f0f0':'';
      my $attr_html = highlight("$refattr->{KIND} $attrname<span class=declaration>$refattr->{DECL}</span>");
      print FHO
        qq|<tr$attr_color>\n|.
        qq|  <td class=declmain>\n|.
        qq|    $attr_html\n|.
        qq|  </td>\n|.
        qq|  <td class=comment>$refattr->{COMMENT}</td>\n|.
        qq|</tr>\n|;
      $idx_attr++;
    }
  print FHO "</table>\n";
  print FHO qq|<p align=center><a href="$refunit->{HTMLFILE}">$refunit->{NAME} unit</a> - <a href="$toc_file">contents</a> - <a href="$typeidx_file">type index</a>|;
   # ��������� HTML-���� �������
  writeFileFooter(\*FHO);
  close(FHO);
}

 # ������� ������ �����
sub writeTypeIndex {
  push @htmlfiles, $typeidx_file;
  open(FHTI, ">$out_path/$typeidx_file") or die "Cannot open $out_path/$typeidx_file for writing: $!\n";
  writeFileHeader(\*FHTI, 'Type Index', qq|<a href="$toc_file">$usr_short_name</a> / Type Index|, "List of all $usr_short_name types in alphabetical order");
   # ������� ��������� ������� �����
  print FHTI
    "<table class=framed align=center>\n".
    "<tr><th>Type</th><th>Object</th><th>Unit</th><th>Comments</th></tr>\n";
  my $idx_type = 0;
  foreach my $typename(sort keys %allobjs) {
    my $type_color = $idx_type%2?' bgcolor=#f0f0f0':'';
    my $refobj = $allobjs{$typename};
    print FHTI
      qq|<tr$type_color>\n|.
      qq|  <td>$typebychar{$refobj->{TYPE}}->{TITLE}</td>\n|.
      qq|  <td><a href="$refobj->{HTMLFILE}">$refobj->{NAME}</a></td>\n|.
      qq|  <td><a href="$refobj->{REFUNIT}->{HTMLFILE}">$refobj->{REFUNIT}->{NAME}</a></td>\n|.
      qq|  <td class=comment>$refobj->{COMMENT}</td>\n|.
      qq|</tr>\n|;
    $idx_type++;
  };
   # ������� ���������� ������� �����
  print FHTI "</table>\n";
   # ��������� ����
  writeFileFooter(\*FHTI);
  close(FHTI);
}

 # ������ HTML-���� ������: (RefUnit)
sub writeUnit {
  my ($refunit) = @_;
   # ������ HTML-���� ������
  push @htmlfiles, $refunit->{HTMLFILE};
  open(FHU, ">$out_path/$refunit->{HTMLFILE}") or die "Cannot open $out_path/$refunit->{HTMLFILE} for writing: $!\n";
  writeFileHeader(
    \*FHU,
    "$refunit->{NAME}",
    qq|<a href="$toc_file">$usr_short_name</a> / $refunit->{NAME} unit|,
    "$refunit->{COMMENT}<br>Size: <b>$refunit->{SIZE}</b>");
   # ���� �� ����� ��������
  foreach my $reftype(@types) {
    my $typechar = $reftype->{CHAR};
     # ���� �� �������� ������
    my $idx_obj = 0;
    my $obj_html = '';
    foreach my $objname(sort keys %{$refunit->{OBJECTS}}) {
      my $refobj = $refunit->{OBJECTS}->{$objname};
       # ���� ������ ����������� ����
      if ($refobj->{TYPE} eq $typechar) {
        my $obj_color = $idx_obj%2?' bgcolor=#f0f0f0':'';
        my $obj_printed = highlight(&{sub{$typebychar{$refobj->{TYPE}}->{PRINTER}}}->($refobj));
        $obj_html .=
          qq|<tr$obj_color>\n|.
          qq|  <td class=declmain>\n|.
          qq|    $obj_printed\n|.
          qq|  </td>\n|.
          qq|  <td class=comment>$refobj->{COMMENT}</td>\n|.
          qq|</tr>\n|;
         # ������ HTML-���� �������
        writeObj($refunit, $refobj);
        $idx_obj++;
      }
    }
     # ���� ���� ������� �������� ���� - �������
    if ($obj_html) {
      print FHU
        qq|<table class=framed align=center>\n|.
        qq|<tr><th colspan=2><a name=$typechar></a>$reftype->{NAME}</th></tr>\n|.
        qq|$obj_html|.
        qq|</table>\n|;
    }
  }
  print FHU qq|<p align=center><a href="$toc_file">contents</a> - <a href="$typeidx_file">type index</a>|;
   # ��������� HTML-���� ������
  writeFileFooter(\*FHU);
  close(FHU);
}
