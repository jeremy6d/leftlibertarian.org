require 'lldotorg'

use Rack::ShowExceptions
use Rack::Reloader

run LLDotOrg.new