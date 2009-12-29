# leftlibertarian.org Site Generator #

This code runs the [http://leftlibertarian.org] site, which aggregates posts from various left libertarian blogs. Instead of manually parsing the feeds, it uses the Google Reader API via John Nunemaker's googlereader gem to do the trick, with a few hacks to support API updates since the gem's last tweaking. I also employ Nokogiri to do parse the HTML in the feed title and body, which solves two problems: unicode support and truncation of long posts. Finally, I throw HAML and SASS in the mix because I heart them.

Hopefully I'll factor out the stuff that's in the greadie.rb file, which is my "google reader" library.