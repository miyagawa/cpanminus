package HTTP::Lite;

use 5.005;
use strict;
use Socket 1.3;
use Fcntl;
use Errno qw(EAGAIN);

use vars qw($VERSION);
BEGIN {
	$VERSION = "2.3";
}

my $BLOCKSIZE = 65536;
my $CRLF = "\r\n";
my $URLENCODE_VALID = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-.";

# Forward declarations
sub prepare_post;
sub http_write;
sub http_readline;
sub http_read;
sub http_readbytes;

# Prepare the urlencode validchars lookup hash
my @urlencode_valid;
foreach my $char (split('', $URLENCODE_VALID)) {
  $urlencode_valid[ord $char]=$char;
}
for (my $n=0;$n<255;$n++) {
  if (!defined($urlencode_valid[$n])) {
    $urlencode_valid[$n]=sprintf("%%%02X", $n);
  }
}

sub new 
{
  my $self = {};
  bless $self;
  $self->initialize();
  return $self;
}

sub initialize
{
  my $self = shift;
  $self->reset;
  $self->{timeout} = 120;
  $self->{HTTP11} = 0;
  $self->{DEBUG} = 0;
  $self->{header_at_once} = 0; 
  $self->{holdback} = 0;       # needed for http_write 
}

sub header_at_once
{
  my $self=shift;
  $self->{header_at_once} = 1;
}

sub local_addr
{
  my $self = shift;
  my $val = shift;
  my $oldval = $self->{'local_addr'};
  if (defined($val)) {
    $self->{'local_addr'} = $val;
  }
  return $oldval;
}

sub local_port
{
  my $self = shift;
  my $val = shift;
  my $oldval = $self->{'local_port'};
  if (defined($val)) {
    $self->{'local_port'} = $val;
   }
  return $oldval;
}

sub method
{
  my $self = shift;
  my $method = shift;
  $method = uc($method);
  $self->{method} = $method;
}

sub DEBUG
{
  my $self = shift;
  if ($self->{DEBUG}) {
    print STDERR join(" ", @_),"\n";
  }
}

sub reset
{
  my $self = shift;
  foreach my $var ("body", "request", "content", "status", "proxy",
    "proxyport", "resp-protocol", "error-message",  
    "resp-headers", "CBARGS", "callback_function", "callback_params")
  {
    $self->{$var} = undef;
  }
  $self->{HTTPReadBuffer} = "";
  $self->{method} = "GET";
  $self->{headers} = { 'user-agent' => "HTTP::Lite/$VERSION" };
  $self->{headermap} = { 'user-agent'  => 'User-Agent' };
}


# URL-encode data
sub escape {
  my $toencode = shift;
  return join('', 
    map { $urlencode_valid[ord $_] } split('', $toencode));
}

sub set_callback {
  my ($self, $callback, @callbackparams) = @_;
  $self->{'callback_function'} = $callback;
  $self->{'callback_params'} = [ @callbackparams ];
}

sub request
{
  my ($self, $url, $data_callback, $cbargs) = @_;
  
  my $method = $self->{method};
  if (defined($cbargs)) {
    $self->{CBARGS} = $cbargs;
  }

  my $callback_func = $self->{'callback_function'};
  my $callback_params = $self->{'callback_params'};

  # Parse URL 
  my ($protocol,$host,$junk,$port,$object) = 
    $url =~ m{^([^:/]+)://([^/:]*)(:(\d+))?(/.*)$};

  # Only HTTP is supported here
  if ($protocol ne "http")
  {
    warn "Only http is supported by HTTP::Lite";
    return undef;
  }
  
  # Setup the connection
  my $proto = getprotobyname('tcp');
  local *FH;
  socket(FH, PF_INET, SOCK_STREAM, $proto);
  $port = 80 if !$port;

  my $connecthost = $self->{'proxy'} || $host;
  $connecthost = $connecthost ? $connecthost : $host;
  my $connectport = $self->{'proxyport'} || $port;
  $connectport = $connectport ? $connectport : $port;
  my $addr = inet_aton($connecthost);
  if (!$addr) {
    close(FH);
    return undef;
  }
  if ($connecthost ne $host)
  {
    # if proxy active, use full URL as object to request
    $object = "$url";
  }

  # choose local port and address
  my $local_addr = INADDR_ANY; 
  my $local_port = "0";
  if (defined($self->{'local_addr'})) {
    $local_addr = $self->{'local_addr'};
    if ($local_addr eq "0.0.0.0" || $local_addr eq "0") {
      $local_addr = INADDR_ANY;
    } else {
      $local_addr = inet_aton($local_addr);
    }
  }
  if (defined($self->{'local_port'})) {
    $local_port = $self->{'local_port'};
  }
  my $paddr = pack_sockaddr_in($local_port, $local_addr); 
  bind(FH, $paddr) || return undef;  # Failing to bind is fatal.

  my $sin = sockaddr_in($connectport,$addr);
  connect(FH, $sin) || return undef;
  # Set nonblocking IO on the handle to allow timeouts
  if ( $^O ne "MSWin32" ) {
    fcntl(FH, F_SETFL, O_NONBLOCK);
  }

  if (defined($callback_func)) {
    &$callback_func($self, "connect", undef, @$callback_params);
  }  

  if ($self->{header_at_once}) {
    $self->{holdback} = 1;    # http_write should buffer only, no sending yet
  }

  # Start the request (HTTP/1.1 mode)
  if ($self->{HTTP11}) {
    $self->http_write(*FH, "$method $object HTTP/1.1$CRLF");
  } else {
    $self->http_write(*FH, "$method $object HTTP/1.0$CRLF");
  }

  # Add some required headers
  # we only support a single transaction per request in this version.
  $self->add_req_header("Connection", "close");    
  if ($port != 80) {
    $self->add_req_header("Host", "$host:$port");
  } else {
    $self->add_req_header("Host", $host);
  }
  if (!defined($self->get_req_header("Accept"))) {
    $self->add_req_header("Accept", "*/*");
  }

  if ($method eq 'POST') {
    $self->http_write(*FH, "Content-Type: application/x-www-form-urlencoded$CRLF");
  }
  
  # Purge a couple others
  $self->delete_req_header("Content-Type");
  $self->delete_req_header("Content-Length");
  
  # Output headers
  foreach my $header ($self->enum_req_headers())
  {
    my $value = $self->get_req_header($header);
    $self->http_write(*FH, $self->{headermap}{$header}.": ".$value."$CRLF");
  }
  
  my $content_length;
  if (defined($self->{content}))
  {
    $content_length = length($self->{content});
  }
  if (defined($callback_func)) {
    my $ncontent_length = &$callback_func($self, "content-length", undef, @$callback_params);
    if (defined($ncontent_length)) {
      $content_length = $ncontent_length;
    }
  }  

  if ($content_length) {
    $self->http_write(*FH, "Content-Length: $content_length$CRLF");
  }
  
  if (defined($callback_func)) {
    &$callback_func($self, "done-headers", undef, @$callback_params);
  }  
  # End of headers
  $self->http_write(*FH, "$CRLF");
  
  if ($self->{header_at_once}) {
    $self->{holdback} = 0; 
    $self->http_write(*FH, ""); # pseudocall to get http_write going
  }  
  
  my $content_out = 0;
  if (defined($callback_func)) {
    while (my $content = &$callback_func($self, "content", undef, @$callback_params)) {
      $self->http_write(*FH, $content);
      $content_out++;
    }
  } 
  
  # Output content, if any
  if (!$content_out && defined($self->{content}))
  {
    $self->http_write(*FH, $self->{content});
  }
  
  if (defined($callback_func)) {
    &$callback_func($self, "content-done", undef, @$callback_params);
  }  


  # Read response from server
  my $headmode=1;
  my $chunkmode=0;
  my $chunksize=0;
  my $chunklength=0;
  my $chunk;
  my $line = 0;
  my $data;
  while ($data = $self->http_read(*FH,$headmode,$chunkmode,$chunksize))
  {
    $self->{DEBUG} && $self->DEBUG("reading: $chunkmode, $chunksize, $chunklength, $headmode, ".
        length($self->{'body'}));
    if ($self->{DEBUG}) {
      foreach my $var ("body", "request", "content", "status", "proxy",
        "proxyport", "resp-protocol", "error-message", 
        "resp-headers", "CBARGS", "HTTPReadBuffer") 
      {
        $self->DEBUG("state $var ".length($self->{$var}));
      }
    }
    $line++;
    if ($line == 1)
    {
      my ($proto,$status,$message) = split(' ', $$data, 3);
      $self->{DEBUG} && $self->DEBUG("header $$data");
      $self->{status}=$status;
      $self->{'resp-protocol'}=$proto;
      $self->{'error-message'}=$message;
      next;
    } 
    if (($headmode || $chunkmode eq "entity-header") && $$data =~ /^[\r\n]*$/)
    {
      if ($chunkmode)
      {
        $chunkmode = 0;
      }
      $headmode = 0;
      
      # Check for Transfer-Encoding
      my $te = $self->get_header("Transfer-Encoding");
      if (defined($te)) {
        my $header = join(' ',@{$te});
        if ($header =~ /chunked/i)
        {
          $chunkmode = "chunksize";
        }
      }
      next;
    }
    if ($headmode || $chunkmode eq "entity-header")
    {
      my ($var,$datastr) = $$data =~ /^([^:]*):\s*(.*)$/;
      if (defined($var))
      {
        $datastr =~s/[\r\n]$//g;
        $var = lc($var);
        $var =~ s/^(.)/&upper($1)/ge;
        $var =~ s/(-.)/&upper($1)/ge;
        my $hr = ${$self->{'resp-headers'}}{$var};
        if (!ref($hr))
        {
          $hr = [ $datastr ];
        }
        else 
        {
          push @{ $hr }, $datastr;
        }
        ${$self->{'resp-headers'}}{$var} = $hr;
      }
    } elsif ($chunkmode)
    {
      if ($chunkmode eq "chunksize")
      {
        $chunksize = $$data;
        $chunksize =~ s/^\s*|;.*$//g;
        $chunksize =~ s/\s*$//g;
        my $cshx = $chunksize;
        if (length($chunksize) > 0) {
          # read another line
          if ($chunksize !~ /^[a-f0-9]+$/i) {
            $self->{DEBUG} && $self->DEBUG("chunksize not a hex string");
          }
          $chunksize = hex($chunksize);
          $self->{DEBUG} && $self->DEBUG("chunksize was $chunksize (HEX was $cshx)");
          if ($chunksize == 0)
          {
            $chunkmode = "entity-header";
          } else {
            $chunkmode = "chunk";
            $chunklength = 0;
          }
        } else {
          $self->{DEBUG} && $self->DEBUG("chunksize empty string, checking next line!");
        }
      } elsif ($chunkmode eq "chunk")
      {
        $chunk .= $$data;
        $chunklength += length($$data);
        if ($chunklength >= $chunksize)
        {
          $chunkmode = "chunksize";
          if ($chunklength > $chunksize)
          {
            $chunk = substr($chunk,0,$chunksize);
          } 
          elsif ($chunklength == $chunksize && $chunk !~ /$CRLF$/) 
          {
            # chunk data is exactly chunksize -- need CRLF still
            $chunkmode = "ignorecrlf";
          }
          $self->add_to_body(\$chunk, $data_callback);
          $chunk="";
          $chunklength = 0;
          $chunksize = "";
        } 
      } elsif ($chunkmode eq "ignorecrlf")
      {
        $chunkmode = "chunksize";
      }
    } else {
      $self->add_to_body($data, $data_callback);
    }
  }
  if (defined($callback_func)) {
    &$callback_func($self, "done", undef, @$callback_params);
  }
  close(FH);
  return $self->{status};
}

sub add_to_body
{
  my $self = shift;
  my ($dataref, $data_callback) = @_;
  
  my $callback_func = $self->{'callback_function'};
  my $callback_params = $self->{'callback_params'};

  if (!defined($data_callback) && !defined($callback_func)) {
    $self->{DEBUG} && $self->DEBUG("no callback");
    $self->{'body'}.=$$dataref;
  } else {
    my $newdata;
    if (defined($callback_func)) {
      $newdata = &$callback_func($self, "data", $dataref, @$callback_params);
    } else {
      $newdata = &$data_callback($self, $dataref, $self->{CBARGS});
    }
    if ($self->{DEBUG}) {
      $self->DEBUG("callback got back a ".ref($newdata));
      if (ref($newdata) eq "SCALAR") {
        $self->DEBUG("callback got back ".length($$newdata)." bytes");
      }
    }
    if (defined($newdata) && ref($newdata) eq "SCALAR") {
      $self->{'body'} .= $$newdata;
    }
  }
}

sub add_req_header
{
  my $self = shift;
  my ($header, $value) = @_;
  
  my $lcheader = lc($header);
  $self->{DEBUG} && $self->DEBUG("add_req_header $header $value");
  ${$self->{headers}}{$lcheader} = $value;
  ${$self->{headermap}}{$lcheader} = $header;
}

sub get_req_header
{
  my $self = shift;
  my ($header) = @_;
  
  return $self->{headers}{lc($header)};
}

sub delete_req_header
{
  my $self = shift;
  my ($header) = @_;
  
  my $exists;
  if ($exists=defined(${$self->{headers}}{lc($header)}))
  {
    delete ${$self->{headers}}{lc($header)};
    delete ${$self->{headermap}}{lc($header)};
  }
  return $exists;
}

sub enum_req_headers
{
  my $self = shift;
  my ($header) = @_;
  
  my $exists;
  return keys %{$self->{headermap}};
}

sub body
{
  my $self = shift;
  return $self->{'body'};
}

sub status
{
  my $self = shift;
  return $self->{status};
}

sub protocol
{
  my $self = shift;
  return $self->{'resp-protocol'};
}

sub status_message
{
  my $self = shift;
  return $self->{'error-message'};
}

sub proxy
{
  my $self = shift;
  my ($value) = @_;
  
  # Parse URL 
  my ($protocol,$host,$junk,$port,$object) = 
    $value =~ m{^(\S+)://([^/:]*)(:(\d+))?(/.*)$};
  if (!$host)
  {
    ($host,$port) = $value =~ /^([^:]+):(.*)$/;
  }

  $self->{'proxy'} = $host || $value;
  $self->{'proxyport'} = $port || 80;
}

sub headers_array
{
  my $self = shift;
  
  my @array = ();
  
  foreach my $header (keys %{$self->{'resp-headers'}})
  {
    my $aref = ${$self->{'resp-headers'}}{$header};
    foreach my $value (@$aref)
    {
      push @array, "$header: $value";
    }
  }
  return @array;
}

sub headers_string
{
  my $self = shift;
  
  my $string = "";
  
  foreach my $header (keys %{$self->{'resp-headers'}})
  {
    my $aref = ${$self->{'resp-headers'}}{$header};
    foreach my $value (@$aref)
    {
      $string .= "$header: $value\n";
    }
  }
  return $string;
}

sub get_header
{
  my $self = shift;
  my $header = shift;

  return $self->{'resp-headers'}{$header};
}

sub http11_mode
{
  my $self = shift;
  my $mode = shift;

  $self->{HTTP11} = $mode;
}

sub prepare_post
{
  my $self = shift;
  my $varref = shift;
  
  my $body = "";
  while (my ($var,$value) = map { escape($_) } each %$varref)
  {
    if ($body)
    {
      $body .= "&$var=$value";
    } else {
      $body = "$var=$value";
    }
  }
  $self->{content} = $body;
  $self->{headers}{'Content-Type'} = "application/x-www-form-urlencoded"
    unless defined ($self->{headers}{'Content-Type'}) and 
    $self->{headers}{'Content-Type'};
  $self->{method} = "POST";
}

sub http_write
{
  my $self = shift;
  my ($fh,$line) = @_;

  if ($self->{holdback}) {
     $self->{HTTPWriteBuffer} .= $line;
     return;
  } else {
     if (defined $self->{HTTPWriteBuffer}) {   # copy previously buffered, if any
         $line = $self->{HTTPWriteBuffer} . $line;
     }
  }

  my $size = length($line);
  my $bytes = syswrite($fh, $line, length($line) , 0 );  # please double check new length limit
                                                         # is this ok?
  while ( ($size - $bytes) > 0) {
    $bytes += syswrite($fh, $line, length($line)-$bytes, $bytes );  # also here
  }
}
 
sub http_read
{
  my $self = shift;
  my ($fh,$headmode,$chunkmode,$chunksize) = @_;

  $self->{DEBUG} && $self->DEBUG("read handle=$fh, headm=$headmode, chunkm=$chunkmode, chunksize=$chunksize");

  my $res;
  if (($headmode == 0 && $chunkmode eq "0") || ($chunkmode eq "chunk")) {
    my $bytes_to_read = $chunkmode eq "chunk" ?
        ($chunksize < $BLOCKSIZE ? $chunksize : $BLOCKSIZE) :
        $BLOCKSIZE;
    $res = $self->http_readbytes($fh,$self->{timeout},$bytes_to_read);
  } else { 
    $res = $self->http_readline($fh,$self->{timeout});  
  }
  if ($res) {
    if ($self->{DEBUG}) {
      $self->DEBUG("read got ".length($$res)." bytes");
      my $str = $$res;
      $str =~ s{([\x00-\x1F\x7F-\xFF])}{.}g;
      $self->DEBUG("read: ".$str);
    }
  }
  return $res;
}

sub http_readline
{
  my $self = shift;
  my ($fh, $timeout) = @_;
  my $EOL = "\n";

  $self->{DEBUG} && $self->DEBUG("readline handle=$fh, timeout=$timeout");
  
  # is there a line in the buffer yet?
  while ($self->{HTTPReadBuffer} !~ /$EOL/)
  {
    # nope -- wait for incoming data
    my ($inbuf,$bits,$chars) = ("","",0);
    vec($bits,fileno($fh),1)=1;
    my $nfound = select($bits, undef, $bits, $timeout);
    if ($nfound == 0)
    {
      # Timed out
      return undef;
    } else {
      # Get the data
      $chars = sysread($fh, $inbuf, $BLOCKSIZE);
      $self->{DEBUG} && $self->DEBUG("sysread $chars bytes");
    }
    # End of stream?
    if ($chars <= 0 && !$!{EAGAIN})
    {
      last;
    }
    # tag data onto end of buffer
    $self->{HTTPReadBuffer}.=$inbuf;
  }
  # get a single line from the buffer
  my $nlat = index($self->{HTTPReadBuffer}, $EOL);
  my $newline;
  my $oldline;
  if ($nlat > -1)
  {
    $newline = substr($self->{HTTPReadBuffer},0,$nlat+1);
    $oldline = substr($self->{HTTPReadBuffer},$nlat+1);
  } else {
    $newline = substr($self->{HTTPReadBuffer},0);
    $oldline = "";
  }
  # and update the buffer
  $self->{HTTPReadBuffer}=$oldline;
  return length($newline) ? \$newline : 0;
}

sub http_readbytes
{
  my $self = shift;
  my ($fh, $timeout, $bytes) = @_;
  my $EOL = "\n";

  $self->{DEBUG} && $self->DEBUG("readbytes handle=$fh, timeout=$timeout, bytes=$bytes");
  
  # is there enough data in the buffer yet?
  while (length($self->{HTTPReadBuffer}) < $bytes)
  {
    # nope -- wait for incoming data
    my ($inbuf,$bits,$chars) = ("","",0);
    vec($bits,fileno($fh),1)=1;
    my $nfound = select($bits, undef, $bits, $timeout);
    if ($nfound == 0)
    {
      # Timed out
      return undef;
    } else {
      # Get the data
      $chars = sysread($fh, $inbuf, $BLOCKSIZE);
      $self->{DEBUG} && $self->DEBUG("sysread $chars bytes");
    }
    # End of stream?
    if ($chars <= 0 && !$!{EAGAIN})
    {
      last;
    }
    # tag data onto end of buffer
    $self->{HTTPReadBuffer}.=$inbuf;
  }
  my $newline;
  my $buflen;
  if (($buflen=length($self->{HTTPReadBuffer})) >= $bytes)
  {
    $newline = substr($self->{HTTPReadBuffer},0,$bytes+1);
    if ($bytes+1 < $buflen) {
      $self->{HTTPReadBuffer} = substr($self->{HTTPReadBuffer},$bytes+1);
    } else {
      $self->{HTTPReadBuffer} = "";
    }
  } else {
    $newline = substr($self->{HTTPReadBuffer},0);
    $self->{HTTPReadBuffer} = "";
  }
  return length($newline) ? \$newline : 0;
}

sub upper
{
  my ($str) = @_;
  if (defined($str)) {
    return uc($str);
  } else {
    return undef;
  }
}

1;

__END__

=pod

=head1 NAME

HTTP::Lite - Lightweight HTTP implementation

=head1 SYNOPSIS

    use HTTP::Lite;
    $http = HTTP::Lite->new;
    $req = $http->request("http://www.cpan.org/") 
        or die "Unable to get document: $!";
    print $http->body();

=head1 DESCRIPTION

    HTTP::Lite is a stand-alone lightweight HTTP/1.1 implementation
    for perl.  It is not intended as a replacement for the
    fully-features LWP module.  Instead, it is intended for use in
    situations where it is desirable to install the minimal number of
    modules to achieve HTTP support, or where LWP is not a good
    candidate due to CPU overhead, such as slower processors.
    HTTP::Lite is also significantly faster than LWP.

    HTTP::Lite is ideal for CGI (or mod_perl) programs or for bundling
    for redistribution with larger packages where only HTTP GET and
    POST functionality are necessary.

    HTTP::Lite supports basic POST and GET operations only.  As of
    0.2.1, HTTP::Lite supports HTTP/1.1 and is compliant with the Host
    header, necessary for name based virtual hosting.  Additionally,
    HTTP::Lite now supports Proxies.

    As of 2.0.0 HTTP::Lite now supports a callback to allow processing
    of request data as it arrives.  This is useful for handling very
    large files without consuming memory.

    If you require more functionality, such as FTP or HTTPS, please
    see libwwwperl (LWP).  LWP is a significantly better and more
    comprehensive package than HTTP::Lite, and should be used instead
    of HTTP::Lite whenever possible.

=head1 CONSTRUCTOR

=over 4

=item new

This is the constructor for HTTP::Lite.  It presently takes no
arguments.  A future version of HTTP::Lite might accept parameters.

=back

=head1 METHODS

=over 4


=item request ( $url, $data_callback, $cbargs )

Initiates a request to the specified URL.

Returns undef if an I/O error is encountered, otherwise the HTTP
status code will be returned.  200 series status codes represent
success, 300 represent temporary errors, 400 represent permanent
errors, and 500 represent server errors.

See F<http://www.w3.org/Protocols/HTTP/HTRESP.html> for detailled
information about HTTP status codes.

The $data_callback parameter, if used, is a way to filter the data as it is
received or to handle large transfers.  It must be a function reference, and
will be passed: a reference to the instance of the http request making the
callback, a reference to the current block of data about to be added to the
body, and the $cbargs parameter (which may be anything).  It must return
either a reference to the data to add to the body of the document, or undef.

If set_callback is used, $data_callback and $cbargs are not used.  $cbargs
may be either a scalar or a reference.

The data_callback is called as: 
  &$data_callback( $self, $dataref, $cbargs )

An example use to save a document to file is:

  # Write the data to the filehandle $cbargs
  sub savetofile {
    my ($self,$phase,$dataref,$cbargs) = @_;
    print $cbargs $$dataref;
    return undef;
  }

  $url = "$testpath/bigbinary.dat";
  open OUT, '>','bigbinary.dat';
  $res = $http->request($url, \&savetofile, OUT);
  close OUT;

=item set_callback ( $functionref, $dataref )

At various stages of the request, callbacks may be used to modify the
behaviour or to monitor the status of the request.  These work like the
$data_callback parameter to request(), but are more verstaile.  Using
set_callback disables $data_callback in request()

The callbacks are called as: 
  callback ( $self, $phase, $dataref, $cbargs )

The current phases are:

  connect - connection has been established and headers are being
            transmitted.

  content-length - return value is used as the content-length.  If undef,
            and prepare_post() was used, the content length is
            calculated.

  done-headers - all headers have been sent

  content - return value is used as content and is sent to client.  Return
            undef to use the internal content defined by prepare_post().

  content-done - content has been successfuly transmitted.

  data - A block of data has been received.  The data is referenced by
            $dataref.  The return value is dereferenced and replaces the
            content passed in.  Return undef to avoid using memory for large
            documents.

  done - Request is done.



=item prepare_post ( $hashref )

Takes a reference to a hashed array of post form variables to upload. 
Create the HTTP body and sets the method to POST.

=item http11_mode ( 0 | 1 )

Turns on or off HTTP/1.1 support.  This is off by default due to
broken HTTP/1.1 servers.  Use 1 to enable HTTP/1.1 support.

=item add_req_header ( $header, $value )

=item get_req_header ( $header )

=item delete_req_header ( $header )

Add, Delete, or a HTTP header(s) for the request.  These functions
allow you to override any header.  Presently, Host, User-Agent,
Content-Type, Accept, and Connection are pre-defined by the HTTP::Lite
module.  You may not override Host, Connection, or Accept.

To provide (proxy) authentication or authorization, you would use:

    use HTTP::Lite;
    use MIME::Base64;
    $http = HTTP::Lite->new;
    $encoded = encode_base64('username:password');
    $http->add_req_header("Authorization", $encoded);

B<NOTE>: The present implementation limits you to one instance
of each header.

=item body

Returns the body of the document retured by the remote server.

=item headers_array

Returns an array of the HTTP headers returned by the remote
server.

=item headers_string

Returns a string representation of the HTTP headers returned by
the remote server.

=item get_header ( $header )

Returns an array of values for the requested header.  

B<NOTE>: HTTP requests are not limited to a single instance of
each header.  As a result, there may be more than one entry for
every header.

=item protocol

Returns the HTTP protocol identifier, as reported by the remote
server.  This will generally be either HTTP/1.0 or HTTP/1.1.

=item proxy ( $proxy_server )

The URL or hostname of the proxy to use for the next request.

=item status

Returns the HTTP status code returned by the server.  This is
also reported as the return value of I<request()>.

=item status_message

Returns the textual description of the status code as returned
by the server.  The status string is not required to adhere to
any particular format, although most HTTP servers use a standard
set of descriptions.

=item reset

You must call this prior to re-using an HTTP::Lite handle,
otherwise the results are undefined.

=item local_addr ( $ip )

Explicity select the local IP address.  0.0.0.0 (default) lets the system
choose.

=item local_port ( $port )

Explicity select the local port.  0 (default and recommended) lets the
system choose.

=item method ( $method )

Explicity set the method.  Using prepare_post or reset overrides this
setting.  Usual choices are GET, POST, PUT, HEAD

=back

=head1 EXAMPLES

    # Get and print out the headers and body of the CPAN homepage
    use HTTP::Lite;
    $http = HTTP::Lite->new;
    $req = $http->request("http://www.cpan.org/")
        or die "Unable to get document: $!";
    die "Request failed ($req): ".$http->status_message()
      if $req ne "200";
    @headers = $http->headers_array();
    $body = $http->body();
    foreach $header (@headers)
    {
      print "$header$CRLF";
    }
    print "$CRLF";
    print "$body$CRLF";

    # POST a query to the dejanews USENET search engine
    use HTTP::Lite;
    $http = HTTP::Lite->new;
    %vars = (
             "QRY" => "perl",
             "ST" => "MS",
             "svcclass" => "dncurrent",
             "DBS" => "2"
            );
    $http->prepare_post(\%vars);
    $req = $http->request("http://www.deja.com/dnquery.xp")
      or die "Unable to get document: $!";
    print "req: $req\n";
    print $http->body();

=head1 UNIMPLEMENTED

    - FTP 
    - HTTPS (SSL)
    - Authenitcation/Authorizaton/Proxy-Authorization
      are not directly supported, and require MIME::Base64.
    - Redirects (Location) are not automatically followed
    - multipart/form-data POSTs are not directly supported (necessary
      for File uploads).

=head1 BUGS

    Some broken HTTP/1.1 servers send incorrect chunk sizes
    when transferring files.  HTTP/1.1 mode is now disabled by
    default.

=head1 AUTHOR

Roy Hooper <rhooper@thetoybox.org>

=head1 SEE ALSO

L<LWP>
RFC 2068 - HTTP/1.1 -http://www.w3.org/

=head1 COPYRIGHT

Copyright (c) 2000-2002 Roy Hooper.  All rights reserved.

Some parts copyright 2009 - 2010 Adam Kennedy.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
