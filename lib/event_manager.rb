require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def legislators_by_zipcode(zipcode)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = File.read('secret.key').strip

  begin
    civic_info.representative_info_by_address(
      address: zipcode,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

def format_phone(phone_array)
  area_code = phone_array.slice(0, 3).join
  first_half = phone_array.slice(3, 3).join
  second_half = phone_array.slice(6, 4).join
  "(#{area_code}) #{first_half}-#{second_half}"
end

def clean_phone(phone_string)
  phone = phone_string.scan(/\d/)
  if (phone.length == 11 && phone[0] == "1") || phone.length == 10
    return format_phone(phone.last(10))
  end
  return "No valid phone number on file"
end

puts 'EventManager Initialized'

contents = CSV.open(
  'event_attendees.csv', 
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)
  phone = clean_phone(row[:homephone])

  form_letter = erb_template.result(binding)

  #save_thank_you_letter(id, form_letter)  
  
  puts "#{name}'s phone number: #{phone}"
end