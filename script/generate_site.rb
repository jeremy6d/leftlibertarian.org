require 'rubygems'
require 'lldotorg'
require 'net/smtp'

def handle_exception(e)
  from = "LeftLibertarian.org generate script <leftlibertarian.org@potentiator>"
  to = "jeremy6d@gmail.com"
  msg = <<-END_OF_MESSAGE
  From: #{from}
  To: #{to}
  Subject: SCRIPT FAILED

  #{e.inspect}
  END_OF_MESSAGE

	Net::SMTP.start('localhost') do |smtp|
		smtp.send_message msg, from, to
	end
end

begin
  LLDotOrg.new('production').generate_site!
rescue Exception => e
  handle_exception(e)
rescue Timeout::Error => e
  handle_exception(e)
end

