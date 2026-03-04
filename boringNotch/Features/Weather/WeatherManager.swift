//
//  WeatherManager.swift
//  boringNotch
//
//  Created by DynaNotch on 2026-03-04.
//  GPL v3 License
//

import Combine
import CoreLocation
import Defaults
import Foundation
import os

/// Centralized weather data manager using Open Meteo API and CoreLocation.
class WeatherManager: NSObject, ObservableObject, CLLocationManagerDelegate {

    static let shared = WeatherManager()

    private let logger = Logger(subsystem: "com.dynanotch", category: "Weather")

    // MARK: - Published State

    @Published var temperature: Double?
    @Published var humidity: Int?
    @Published var weatherEmoji: String = ""
    @Published var weatherDescription: String = ""
    @Published var cityName: String = ""
    @Published var isLoading: Bool = false

    // MARK: - Computed

    var isActive: Bool { Defaults[.enableWeather] }

    var temperatureDisplay: String {
        guard let temp = temperature else { return "--" }
        let unit = Defaults[.temperatureUnit]
        if unit == "fahrenheit" {
            let f = temp * 9.0 / 5.0 + 32.0
            return String(format: "%.0f°F", f)
        }
        return String(format: "%.0f°C", temp)
    }

    var humidityDisplay: String {
        guard let h = humidity else { return "--%"}
        return "\(h)%"
    }

    // MARK: - Private

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var fetchTimer: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    private var lastLocation: CLLocation?

    // MARK: - Init

    private override init() {
        super.init()

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer

        // React to enable/disable changes
        Defaults.publisher(.enableWeather)
            .sink { [weak self] change in
                if change.newValue {
                    self?.startMonitoring()
                } else {
                    self?.stopMonitoring()
                }
            }
            .store(in: &cancellables)

        // React to manual city changes
        Defaults.publisher(.weatherManualCity)
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] change in
                guard Defaults[.enableWeather] else { return }
                let city = change.newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if city.isEmpty {
                    self?.locationManager.startUpdatingLocation()
                } else {
                    self?.geocodeCity(city)
                }
            }
            .store(in: &cancellables)

        // React to temperature unit changes
        Defaults.publisher(.temperatureUnit)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        if Defaults[.enableWeather] {
            startMonitoring()
        }
    }

    // MARK: - Monitoring

    private func startMonitoring() {
        logger.info("[WEATHER] startMonitoring")

        let manualCity = Defaults[.weatherManualCity].trimmingCharacters(in: .whitespacesAndNewlines)
        if manualCity.isEmpty {
            locationManager.startUpdatingLocation()
        } else {
            geocodeCity(manualCity)
        }

        // Fetch every 10 minutes
        fetchTimer?.cancel()
        fetchTimer = Timer.publish(every: 600, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshWeather()
            }
    }

    private func stopMonitoring() {
        logger.info("[WEATHER] stopMonitoring")
        fetchTimer?.cancel()
        fetchTimer = nil
        locationManager.stopUpdatingLocation()
    }

    private func refreshWeather() {
        let manualCity = Defaults[.weatherManualCity].trimmingCharacters(in: .whitespacesAndNewlines)
        if manualCity.isEmpty {
            if let loc = lastLocation {
                fetchWeather(latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude)
            } else {
                locationManager.startUpdatingLocation()
            }
        } else {
            geocodeCity(manualCity)
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        lastLocation = location
        locationManager.stopUpdatingLocation()
        fetchWeather(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)

        // Reverse geocode for city name
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            if let city = placemarks?.first?.locality {
                DispatchQueue.main.async {
                    self?.cityName = city
                }
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        logger.error("[WEATHER] location error: \(error.localizedDescription)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways:
            if Defaults[.enableWeather] && Defaults[.weatherManualCity].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                manager.startUpdatingLocation()
            }
        default:
            break
        }
    }

    // MARK: - Geocoding

    private func geocodeCity(_ city: String) {
        geocoder.geocodeAddressString(city) { [weak self] placemarks, error in
            guard let self = self else { return }
            if let error = error {
                self.logger.error("[WEATHER] geocode error: \(error.localizedDescription)")
                return
            }
            guard let location = placemarks?.first?.location else { return }
            DispatchQueue.main.async {
                self.cityName = city
                self.lastLocation = location
            }
            self.fetchWeather(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        }
    }

    // MARK: - API

    private func fetchWeather(latitude: Double, longitude: Double) {
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&current=temperature_2m,relative_humidity_2m,weather_code"
        guard let url = URL(string: urlString) else { return }

        isLoading = true
        logger.info("[WEATHER] fetching lat=\(latitude) lon=\(longitude)")

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.isLoading = false
            }

            if let error = error {
                self.logger.error("[WEATHER] fetch error: \(error.localizedDescription)")
                return
            }

            guard let data = data else { return }

            do {
                let response = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
                DispatchQueue.main.async {
                    self.temperature = response.current.temperature_2m
                    self.humidity = Int(response.current.relative_humidity_2m)
                    let code = Int(response.current.weather_code)
                    self.weatherEmoji = Self.wmoEmoji(code)
                    self.weatherDescription = Self.wmoDescription(code)
                    self.logger.info("[WEATHER] updated temp=\(response.current.temperature_2m) humidity=\(response.current.relative_humidity_2m) code=\(code)")
                }
            } catch {
                self.logger.error("[WEATHER] decode error: \(error.localizedDescription)")
            }
        }.resume()
    }

    // MARK: - WMO Weather Codes

    static func wmoEmoji(_ code: Int) -> String {
        switch code {
        case 0: return "☀️"
        case 1: return "🌤️"
        case 2: return "⛅"
        case 3: return "☁️"
        case 45, 48: return "🌫️"
        case 51, 53, 55: return "🌦️"
        case 56, 57: return "🌧️"
        case 61, 63, 65: return "🌧️"
        case 66, 67: return "🌨️"
        case 71, 73, 75: return "❄️"
        case 77: return "🌨️"
        case 80, 81, 82: return "🌧️"
        case 85, 86: return "❄️"
        case 95: return "⛈️"
        case 96, 99: return "⛈️"
        default: return "🌡️"
        }
    }

    static func wmoDescription(_ code: Int) -> String {
        switch code {
        case 0: return "Clear"
        case 1: return "Mostly Clear"
        case 2: return "Partly Cloudy"
        case 3: return "Overcast"
        case 45, 48: return "Fog"
        case 51, 53, 55: return "Drizzle"
        case 56, 57: return "Freezing Drizzle"
        case 61, 63, 65: return "Rain"
        case 66, 67: return "Freezing Rain"
        case 71, 73, 75: return "Snow"
        case 77: return "Snow Grains"
        case 80, 81, 82: return "Showers"
        case 85, 86: return "Snow Showers"
        case 95: return "Thunderstorm"
        case 96, 99: return "Hail Storm"
        default: return "Unknown"
        }
    }
}

// MARK: - API Response Model

private struct OpenMeteoResponse: Decodable {
    let current: CurrentWeather

    struct CurrentWeather: Decodable {
        let temperature_2m: Double
        let relative_humidity_2m: Double
        let weather_code: Double
    }
}
