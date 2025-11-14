// library config;

class Config {
// Change to your backend URL or make it environment-driven later
static const String baseUrl = 'http://10.0.2.2:8000'; // Android emulator -> host machine
static const Duration httpTimeout = Duration(seconds: 20);
}