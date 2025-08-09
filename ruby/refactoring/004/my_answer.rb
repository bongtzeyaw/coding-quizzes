require 'net/http'
require 'json'

class WeatherAPIError < StandardError
  private_class_method :new

  attr_reader :message, :code

  def initialize(message, code = nil)
    @message = message
    @code = code
  end

  CITY_NOT_FOUND = new('City not found', '404')
  SERVER_ERROR   = new('Server error', '500')
  UNKNOWN_ERROR  = new('Unknown error')
end

class WeatherAPI
  def get_weather(city)
    with_error_handling do
      return nil if [nil, ''].include?(city)

      uri = URI("https://api.weather.example.com/v1/current?city=#{city}")
      response = Net::HTTP.get_response(uri)

      case response.code
      when '200'
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
      when '404'
        raise WeatherAPIError::CITY_NOT_FOUND
      when '500'
        raise WeatherAPIError::SERVER_ERROR
      else
        raise WeatherAPIError::UNKNOWN_ERROR
      end
    end
  end

  def get_forecast(city, days)
    with_error_handling do
      return nil if city.nil? || city == '' || days.nil? || days < 1 || days > 7

      uri = URI("https://api.weather.example.com/v1/forecast?city=#{city}&days=#{days}")
      response = Net::HTTP.get_response(uri)

      case response.code
      when '200'
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
      when '404'
        raise WeatherAPIError::CITY_NOT_FOUND
      when '500'
        raise WeatherAPIError::SERVER_ERROR
      else
        raise WeatherAPIError::UNKNOWN_ERROR
      end
    end
  end

  private

  def with_error_handling
    yield
  rescue WeatherAPIError => e
    e.message
  rescue StandardError => e
    "Error: #{e.message}"
  end
end
