# Stats Hero Protocol #

Specification of the protocol used by this client.

## HISTORY ##
This protocol is based on the protocol used by Etsy's statsd, but
includes incompatible extensions to that protocol:

The primitive metric types have been changed to more closely resemble
those supported by the "metrics" family of libraries originally
implemented by Coda Hale.

The protocol has been extended to support batching of metrics so that
multiple measurements may be reported in a single packet.

The protocol now includes a version number and content length header so
that it can be implemented over TCP or UDP.

# PRIMITIVES #

## METER ##
An increment-only counter. An example use of a meter is counting
requests to a web service.

## METER READER ##
An increment-only counter for which you are periodically reporting a
value maintained by some external process. For example, CPU usage is
reported by Linux as a counter of "jiffies" since system boot.

## GAUGE ##
An instantaneous reading of a global value for which aggregate
statistics are not desired or useful. No aggregation or summarization is
done on these values, and the last write "wins." For example, the depth
of a global work queue could be represented as a gauge. The depth of a
per-host queue could only be represented as a gauge when each gauge
metric is recorded with a unique key.

## HISTOGRAM ##
A single measurement of a value for which aggregate statistics are
desired. Server tracks the distribution of measurements... multiple
valid values, interested in them as a collection...

Examples: Number of milliseconds elapsed during the processing of a
webservice request.

# Wire Format #

## ABNF DEFINITION ##

           metrics = header LF 1*(metric LF) ;
            header = version "|" content-length ;
           version = "1" ;
    content-length = 1*DIGIT ;
            metric = key ":" value "|" type [sample-rate] ;
       sample-rate = "|@" "0." 1*DIGIT ;
               key = key-component {"." <key-component>} ;
     key-component = 1*(ALPHA | DIGIT) ;
             value = 1*DIGIT ;
              type = "m" / "mr" / "g" / "h" ;

## DISCUSSION ##
TODO: yap about the protocol.

### EXAMPLES ##
Newlines in these examples represent an ASCII LF character. Indentation
is for presentation only.

#### Incrementing a Meter ####
The following message increments a meter with the key
"myWebservice.requests" by 1:

    1|26
    myWebservice.requests:1|m

#### Reading a Meter ####
This message reports that the current value of "someHost.cpuJiffies" is
12345:

    1|29
    someHost.cpuJiffies:12345|mr

#### Timer Values ####
Timer values should be reported as the histogram type. The statistics
server will collect the aggregate number of measurements as well as
mean, percentiles, etc. Time values should be reported in milliseconds
for sanity's sake.

In this message, a value of 85ms is reported for
"myWebservice.requestTime"

    1|30
    myWebservice.requestTime:85|h

#### Multiple Metrics in One Message ####
In this example, measurements of a meter representing requests and a
histogram representing request time are reported in one message:

    1|56
    myWebservice.requests:1|m
    myWebservice.requestTime:90|h



# References #
* ABNF: RFC 5234, <http://tools.ietf.org/html/rfc5234>
* Coda Hale's Metrics: <https://github.com/codahale/metrics>
* Etsy's statsd: <https://github.com/etsy/statsd>


