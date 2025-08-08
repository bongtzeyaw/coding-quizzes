require 'net/http'
require 'json'

class WeatherAPI
  def get_weather(city)
    return nil if [nil, ''].include?(city)

    uri = URI("https://api.weather.example.com/v1/current?city=#{city}")
    response = Net::HTTP.get_response(uri)

    if response.code == '200'
      data = JSON.parse(response.body)
      temp = data['temperature']
      desc = data['description']
      hum = data['humidity']
      wind = data['wind_speed']

      result = "Weather in #{city}: "
      result += "Temperature: #{temp}\u00b0C, "
      result += "Description: #{desc}, "
      result += "Humidity: #{hum}%, "
      result + "Wind: #{wind}km/h"

    elsif response.code == '404'
      'City not found'
    elsif response.code == '500'
      'Server error'
    else
      'Unknown error'
    end
  rescue StandardError => e
    "Error: #{e.message}"
  end

  def get_forecast(city, days)
    return nil if city.nil? || city == '' || days.nil? || days < 1 || days > 7

    uri = URI("https://api.weather.example.com/v1/forecast?city=#{city}&days=#{days}")
    response = Net::HTTP.get_response(uri)

    if response.code == '200'
      data = JSON.parse(response.body)
      forecasts = data['forecasts']

      result = "#{days}-day forecast for #{city}:\n"
      for i in 0..forecasts.length - 1
        date = forecasts[i]['date']
        temp = forecasts[i]['temperature']
        desc = forecasts[i]['description']

        result += "#{date}: #{temp}\u00b0C, #{desc}\n"
      end

      result
    elsif response.code == '404'
      'City not found'
    elsif response.code == '500'
      'Server error'
    else
      'Unknown error'
    end
  rescue StandardError => e
    "Error: #{e.message}"
  end
end
