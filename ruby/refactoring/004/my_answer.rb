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
  BASE_PATH = "https://api.weather.example.com/v1/"

  def get_weather(city)
    with_error_handling do
      return nil unless valid_city_input?(city)

      uri = build_uri('current', { city: })
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
      return nil unless valid_city_input?(city) && valid_days_input?(days)

      uri = build_uri('forecast', { city:, days: })
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

  def valid_city_input?(city)
    return false unless city

    !city.empty?
  end

  def valid_days_input?(days)
    return false unless days

    days.is_a?(Integer) && days.between?(2, 6)
  end

  def build_uri(path, query_params = {})
    uri = URI.join(BASE_PATH, path)
    uri.query = URI.encode_www_form(query_params) unless query_params.empty?
    uri
  end

  def with_error_handling
    yield
  rescue WeatherAPIError => e
    e.message
  rescue StandardError => e
    "Error: #{e.message}"
  end
end
