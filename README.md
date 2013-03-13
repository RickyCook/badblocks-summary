Badblocks Summary
=================

Parses a file containing a block number per line (default output of the badblocks command)
and gathers information such as contiguous sections and number of unique bad blocks.

<pre>Usage: $name filename | --test
  filename  the location of the file to parse
    --test  run unit tests</pre>

- Will output some summary information every 500000 unique blocks.
- Note that if the input file is unordered, only the unique block count can be trusted. In
this case, gap grouping information is likely incorrect.