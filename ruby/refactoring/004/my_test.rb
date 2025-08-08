require 'minitest/autorun'
require 'minitest/mock'
require_relative 'my_answer'

class WeatherAPITest < Minitest::Test
  def setup
    @api = WeatherAPI.new
  end

  def test_get_weather_successful_response
    mock_response = Minitest::Mock.new
    mock_response.expect :code, '200'
    mock_response.expect :body, '{"temperature": 25, "description": "Clear skies", "humidity": 60, "wind_speed": 10}'

    Net::HTTP.stub :get_response, mock_response, URI('https://api.weather.example.com/v1/current?city=Tokyo') do
      expected_output = "Weather in Tokyo: Temperature: 25°C, Description: Clear skies, Humidity: 60%, Wind: 10km/h"
      assert_equal expected_output, @api.get_weather('Tokyo')
    end
  end

  def test_get_weather_city_not_found
    mock_response = Minitest::Mock.new
    mock_response.expect :code, '404'

    Net::HTTP.stub :get_response, mock_response, URI('https://api.weather.example.com/v1/current?city=NonExistentCity') do
      assert_equal 'City not found', @api.get_weather('NonExistentCity')
    end
  end

  def test_get_weather_server_error
    mock_response = Minitest::Mock.new
    mock_response.expect :code, '500'

    Net::HTTP.stub :get_response, mock_response, URI('https://api.weather.example.com/v1/current?city=Tokyo') do
      assert_equal 'Server error', @api.get_weather('Tokyo')
    end
  end

  def test_get_weather_unknown_error
    mock_response = Minitest::Mock.new
    mock_response.expect :code, ''

    Net::HTTP.stub :get_response, mock_response, URI('https://api.weather.example.com/v1/current?city=Tokyo') do
      assert_equal 'Unknown error', @api.get_weather('Tokyo')
    end
  end

  def test_get_weather_invalid_city_is_nil
    assert_nil @api.get_weather(nil)
  end

  def test_get_weather_invalid_city_is_empty
    assert_nil @api.get_weather('')
  end

  def test_get_forecast_successful_response
    mock_response = Minitest::Mock.new
    mock_response.expect :code, '200'
    mock_response.expect :body, '{"forecasts":[{"date": "2025-08-09", "temperature": 28, "description": "Sunny"}, {"date": "2025-08-10", "temperature": 26, "description": "Partly cloudy"}]}'

    Net::HTTP.stub :get_response, mock_response, URI('https://api.weather.example.com/v1/forecast?city=Tokyo&days=2') do
      expected_output = "2-day forecast for Tokyo:\n2025-08-09: 28°C, Sunny\n2025-08-10: 26°C, Partly cloudy\n"
      assert_equal expected_output, @api.get_forecast('Tokyo', 2)
    end
  end

  def test_get_forecast_city_not_found
    mock_response = Minitest::Mock.new
    mock_response.expect :code, '404'

    Net::HTTP.stub :get_response, mock_response, URI('https://api.weather.example.com/v1/forecast?city=NonExistentCity&days=3') do
      assert_equal 'City not found', @api.get_forecast('NonExistentCity', 3)
    end
  end

  def test_get_forecast_server_error
    mock_response = Minitest::Mock.new
    mock_response.expect :code, '500'

    Net::HTTP.stub :get_response, mock_response, URI('https://api.weather.example.com/v1/forecast?city=Tokyo&days=3') do
      assert_equal 'Server error', @api.get_forecast('Tokyo', 3)
    end
  end

  def test_get_forecast_unknown_error
    mock_response = Minitest::Mock.new
    mock_response.expect :code, ''

    Net::HTTP.stub :get_response, mock_response, URI('https://api.weather.example.com/v1/forecast?city=Tokyo&days=3') do
      assert_equal 'Unknown error', @api.get_forecast('Tokyo', 3)
    end
  end

  def test_get_forecast_invalid_city_is_nil
    assert_nil @api.get_forecast(nil, 3)
  end

  def test_get_forecast_invalid_city_is_empty
    assert_nil @api.get_forecast('', 3)
  end

  def test_get_forecast_invalid_days_is_nil
    assert_nil @api.get_forecast('Tokyo', nil)
  end

  def test_get_forecast_invalid_days_is_less_than_one
    assert_nil @api.get_forecast('Tokyo', 0)
  end

  def test_get_forecast_invalid_days_is_greater_than_seven
    assert_nil @api.get_forecast('Tokyo', 8)
  end
end
