import { LightningElement, track } from 'lwc';
import getWeatherData from '@salesforce/apex/WeatherService.getWeatherData';
import getCitySuggestions from '@salesforce/apex/WeatherService.getCitySuggestions';

export default class WeatherApp extends LightningElement {
    @track city = '';
    @track weatherData = null;
    @track error = null;
    @track isLoading = false;
    @track citySuggestions = [];
    @track showSuggestions = false;
    @track units = 'metric';

    unitOptions = [
        { label: 'Celsius', value: 'metric' },
        { label: 'Fahrenheit', value: 'imperial' }
    ];

    debounceTimer;

    handleCityChange(event) {
        this.city = event.target.value;
        clearTimeout(this.debounceTimer);
        this.debounceTimer = setTimeout(() => {
            if (this.city.length > 2) {
                getCitySuggestions({ query: this.city })
                    .then((suggestions) => {
                        this.citySuggestions = suggestions;
                        this.showSuggestions = true;
                    })
                    .catch((error) => {
                        console.error('Error fetching suggestions:', error);
                        this.citySuggestions = [];
                        this.showSuggestions = false;
                    });
            } else {
                this.showSuggestions = false;
            }
        }, 300);
    }

    handleSuggestionClick(event) {
        this.city = event.currentTarget.dataset.city;
        this.showSuggestions = false;
        this.fetchWeather();
    }

    handleBlur() {
        this.showSuggestions = false;
    }

    handleUnitsChange(event) {
        this.units = event.detail.value;
        if (this.weatherData && this.city) {
            this.fetchWeather();
        }
    }

    fetchWeather() {
        if (!this.city) {
            this.error = 'Please enter a city name.';
            return;
        }

        this.isLoading = true;
        this.error = null;

        getWeatherData({ city: this.city, units: this.units })
            .then((response) => {
                this.weatherData = JSON.parse(response);
                setTimeout(() => this.adjustForecastStyling(), 0); // Ensure styling is applied after data update
            })
            .catch((error) => {
                this.error = error.body?.message || 'Failed to fetch weather data.';
                console.error(error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    fetchWeatherByLocation() {
        this.isLoading = true;
        this.error = null;

        if (navigator.geolocation) {
            navigator.geolocation.getCurrentPosition(
                (position) => {
                    const { latitude, longitude } = position.coords;
                    getWeatherData({ city: null, lat: latitude, lon: longitude, units: this.units })
                        .then((response) => {
                            this.weatherData = JSON.parse(response);
                            this.city = this.weatherData.current.name || 'Current Location';
                        })
                        .catch((error) => {
                            this.error = error.body?.message || 'Failed to fetch weather data.';
                            console.error(error);
                        })
                        .finally(() => {
                            this.isLoading = false;
                        });
                },
                (error) => {
                    this.error = 'Unable to get location.';
                    this.isLoading = false;
                    console.error(error);
                }
            );
        } else {
            this.error = 'Geolocation not supported.';
            this.isLoading = false;
        }
    }

    get weatherDescription() {
        return this.weatherData?.current?.weather?.[0]?.description || 'N/A';
    }

    get weatherIconUrl() {
        const icon = this.weatherData?.current?.weather?.[0]?.icon;
        return icon ? `https://openweathermap.org/img/wn/${icon}@2x.png` : '';
    }

    get unitSymbol() {
        return this.units === 'metric' ? '°C' : '°F';
    }

    get windUnit() {
        return this.units === 'metric' ? 'm/s' : 'mph';
    }

    get processedDailyWeather() {
        return (this.weatherData?.daily || []).map(day => ({
            dt: day.dt,
            formattedDate: new Date(day.dt * 1000).toLocaleDateString(),
            temp: day.temp,
            weatherDescription: day.weather[0]?.description || 'N/A',
            forecastIconUrl: day.weather[0]?.icon ? `https://openweathermap.org/img/wn/${day.weather[0].icon}@2x.png` : ''
        }));
    }
}