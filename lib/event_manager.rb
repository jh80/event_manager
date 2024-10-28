require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'pry-byebug'

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

def highest_freq_from_hash(frequency_hash)
  frequency_hash.reduce({max: 0, stat: []}) do |max_hash, (stat, frequency)|
    unless max_hash[:max] > frequency
      if max_hash[:max] == frequency
        max_hash[:stat] << stat
      else
        max_hash[:stat] = [stat]
      end
      max_hash[:max] = frequency
    end
    max_hash
  end
end

def frequency_hash(attendees, stat)
  attendees.each_with_object(Hash.new) do |attendee, frequency|
  attendee_stat = attendee[stat]
  frequency[attendee_stat] = frequency[attendee_stat] ? frequency[attendee_stat] + 1 : 1
  end
end

puts 'EventManager Initialized'

contents = CSV.open(
  'event_attendees.csv', 
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

attendees = contents.map do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)
  phone = clean_phone(row[:homephone])

  form_letter = erb_template.result(binding)

  reg_time = Time.strptime(row[1], '%D %R')

  reg_hour = reg_time.hour

  reg_wday = Date::DAYNAMES[Date.strptime(row[1], '%D %R').wday]

  #save_thank_you_letter(id, form_letter)  
  
  {id: id, name: name, zipcode: zipcode, legislators: legislators, phone: phone, reg_time: reg_time, reg_hour: reg_hour, reg_wday: reg_wday}
end

puts highest_freq_from_hash(frequency_hash(attendees, :reg_wday))
puts highest_freq_from_hash(frequency_hash(attendees, :reg_hour))
