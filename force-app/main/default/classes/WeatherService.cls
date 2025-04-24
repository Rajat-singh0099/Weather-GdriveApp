public with sharing class WeatherService {
    @AuraEnabled(cacheable=false)
    public static String getWeatherData(String city, Double lat, Double lon, String units) {
        WeatherAPIConfig__mdt apiConfig = getApiConfig('WeatherAPI');
        String apiKey = apiConfig.API_Key__c;
    
        Http http = new Http();
        if (!String.isEmpty(city)) {
            String geocodeEndpoint = 'callout:OpenWeatherAPI/geo/1.0/direct?q=' + EncodingUtil.urlEncode(city, 'UTF-8') + '&limit=1&appid=' + apiKey;
            HttpResponse response = sendRequest(http, geocodeEndpoint);
            List<Object> geocodeData = (List<Object>) JSON.deserializeUntyped(response.getBody());
            if (!geocodeData.isEmpty()) {
                Map<String, Object> location = (Map<String, Object>) geocodeData[0];
                lat = (Double) location.get('lat');
                lon = (Double) location.get('lon');
            } else {
                throw new CalloutException('City not found');
            }
        } else if (lat != null && lon != null) {
            // Reverse geocode to get the city name
            String reverseGeocodeEndpoint = 'callout:OpenWeatherAPI/geo/1.0/reverse?lat=' + lat + '&lon=' + lon + '&limit=1&appid=' + apiKey;
            HttpResponse response = sendRequest(http, reverseGeocodeEndpoint);
            List<Object> reverseGeocodeData = (List<Object>) JSON.deserializeUntyped(response.getBody());
            if (!reverseGeocodeData.isEmpty()) {
                Map<String, Object> location = (Map<String, Object>) reverseGeocodeData[0];
                city = (String) location.get('name');
            } else {
                city = 'Unknown';
            }
        }
    
        if (lat == null || lon == null) {
            throw new CalloutException('Latitude and longitude are required.');
        }
    
        Map<String, Object> result = new Map<String, Object>();
        // Fetch current weather from Open-Meteo
        String openMeteoUnits = (units == 'imperial') ? 'temperature_unit=fahrenheit&wind_speed_unit=mph' : 'temperature_unit=celsius&wind_speed_unit=ms';
        String weatherEndpoint = 'https://api.open-meteo.com/v1/forecast?latitude=' + lat + '&longitude=' + lon + '&current=temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code&daily=temperature_2m_max,temperature_2m_min,weather_code&' + openMeteoUnits + '&timezone=auto';
        HttpResponse response = sendRequest(http, weatherEndpoint);
        Map<String, Object> weatherData = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
    
        // Structure current weather
        Map<String, Object> current = new Map<String, Object>();
        Map<String, Object> main = new Map<String, Object>();
        Map<String, Object> wind = new Map<String, Object>();
        List<Object> weatherList = new List<Object>();
    
        Map<String, Object> currentWeather = (Map<String, Object>) weatherData.get('current');
        main.put('temp', currentWeather.get('temperature_2m'));
        main.put('humidity', currentWeather.get('relative_humidity_2m'));
        wind.put('speed', currentWeather.get('wind_speed_10m'));
    
        Map<String, Object> weather = new Map<String, Object>();
        Integer code = (Integer) currentWeather.get('weather_code');
        weather.put('description', getWeatherDescription(code));
        weather.put('icon', getWeatherIcon(code));
        weatherList.add(weather);
    
        current.put('name', city != null ? city : 'Unknown');
        current.put('main', main);
        current.put('wind', wind);
        current.put('weather', weatherList);
    
        // Process daily forecast
        Map<String, Object> dailyData = (Map<String, Object>) weatherData.get('daily');
        List<Object> dailyForecast = new List<Object>();
        List<Object> dates = (List<Object>) dailyData.get('time');
        List<Object> tempMax = (List<Object>) dailyData.get('temperature_2m_max');
        List<Object> tempMin = (List<Object>) dailyData.get('temperature_2m_min');
        List<Object> weatherCodes = (List<Object>) dailyData.get('weather_code');
    
        for (Integer i = 0; i < dates.size() && i < 5; i++) {
            Map<String, Object> day = new Map<String, Object>();
            Map<String, Object> temp = new Map<String, Object>();
            temp.put('min', tempMin[i]);
            temp.put('max', tempMax[i]);
            day.put('dt', Date.valueOf((String) dates[i]).daysBetween(Date.newInstance(1970, 1, 1)) * 86400);
            day.put('temp', temp);
            Map<String, Object> dayWeather = new Map<String, Object>();
            Integer dayCode = (Integer) weatherCodes[i];
            dayWeather.put('description', getWeatherDescription(dayCode));
            dayWeather.put('icon', getWeatherIcon(dayCode));
            day.put('weather', new List<Object>{ dayWeather });
            dailyForecast.add(day);
        }
    
        result.put('current', current);
        result.put('daily', dailyForecast);
        return JSON.serialize(result);
    }

    private static WeatherAPIConfig__mdt getApiConfig(String developerName) {
        WeatherAPIConfig__mdt config = [SELECT API_Key__c FROM WeatherAPIConfig__mdt WHERE DeveloperName = :developerName LIMIT 1];
        if (config == null || String.isEmpty(config.API_Key__c)) {
            throw new CalloutException('API Key missing for ' + developerName);
        }
        return config;
    }

    private static HttpResponse sendRequest(Http http, String endpoint) {
        HttpRequest request = new HttpRequest();
        request.setEndpoint(endpoint);
        request.setMethod('GET');
        try {
            HttpResponse response = http.send(request);
            if (response.getStatusCode() != 200) {
                throw new CalloutException('Error fetching data: ' + response.getStatus() + ' - ' + response.getBody());
            }
            return response;
        } catch (Exception e) {
            throw new CalloutException('HTTP callout failed: ' + e.getMessage());
        }
    }

    private static String getWeatherDescription(Integer code) {
        Map<Integer, String> weatherCodes = new Map<Integer, String>{
            0 => 'Clear sky',
            1 => 'Mainly clear',
            2 => 'Partly cloudy',
            3 => 'Overcast',
            45 => 'Fog',
            48 => 'Depositing rime fog',
            51 => 'Drizzle: Light',
            53 => 'Drizzle: Moderate',
            55 => 'Drizzle: Dense',
            61 => 'Rain: Slight',
            63 => 'Rain: Moderate',
            65 => 'Rain: Heavy',
            66 => 'Freezing Rain: Light',
            67 => 'Freezing Rain: Heavy',
            71 => 'Snowfall: Slight',
            73 => 'Snowfall: Moderate',
            75 => 'Snowfall: Heavy',
            77 => 'Snow grains',
            80 => 'Rain showers: Slight',
            81 => 'Rain showers: Moderate',
            82 => 'Rain showers: Violent',
            85 => 'Snow showers: Slight',
            86 => 'Snow showers: Heavy',
            95 => 'Thunderstorm: Slight or Moderate',
            96 => 'Thunderstorm with slight hail',
            99 => 'Thunderstorm with heavy hail'
        };
        return weatherCodes.get(code) != null ? weatherCodes.get(code) : 'Unknown';
    }

    private static String getWeatherIcon(Integer code) {
        Map<Integer, String> iconMap = new Map<Integer, String>{
            0 => '01d', // Clear sky
            1 => '02d', // Mainly clear
            2 => '03d', // Partly cloudy
            3 => '04d', // Overcast
            45 => '50d', // Fog
            48 => '50d', // Depositing rime fog
            51 => '09d', // Drizzle: Light
            53 => '09d', // Drizzle: Moderate
            55 => '09d', // Drizzle: Dense
            61 => '10d', // Rain: Slight
            63 => '10d', // Rain: Moderate
            65 => '10d', // Rain: Heavy
            66 => '13d', // Freezing Rain: Light
            67 => '13d', // Freezing Rain: Heavy
            71 => '13d', // Snowfall: Slight
            73 => '13d', // Snowfall: Moderate
            75 => '13d', // Snowfall: Heavy
            77 => '13d', // Snow grains
            80 => '09d', // Rain showers: Slight
            81 => '09d', // Rain showers: Moderate
            82 => '09d', // Rain showers: Violent
            85 => '13d', // Snow showers: Slight
            86 => '13d', // Snow showers: Heavy
            95 => '11d', // Thunderstorm: Slight or Moderate
            96 => '11d', // Thunderstorm with slight hail
            99 => '11d'  // Thunderstorm with heavy hail
        };
        return iconMap.get(code) != null ? iconMap.get(code) : '01d';
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getCitySuggestions(String query) {
        if (String.isEmpty(query)) {
            return new List<String>();
        }

        WeatherAPIConfig__mdt config = getApiConfig('RapidApi');
        String apiKey = config.API_Key__c;

        Http http = new Http();
        String endpoint = 'https://wft-geo-db.p.rapidapi.com/v1/geo/cities?namePrefix=' + EncodingUtil.urlEncode(query, 'UTF-8') + '&limit=5';
        HttpRequest request = new HttpRequest();
        request.setEndpoint(endpoint);
        request.setMethod('GET');
        request.setHeader('X-RapidAPI-Key', apiKey);
        request.setHeader('X-RapidAPI-Host', 'wft-geo-db.p.rapidapi.com');

        HttpResponse response = http.send(request);
        if (response.getStatusCode() != 200) {
            throw new CalloutException('Error fetching suggestions');
        }

        List<String> cityNames = new List<String>();
        Map<String, Object> results = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
        for (Object city : (List<Object>) results.get('data')) {
            Map<String, Object> cityData = (Map<String, Object>) city;
            cityNames.add((String) cityData.get('name'));
        }
        return cityNames;
    }
}