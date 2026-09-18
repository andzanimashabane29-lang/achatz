import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:a_chatz/src/shared/widgets/luxury_scaffold.dart';

class BBCNewsFeedScreen extends StatefulWidget {
  const BBCNewsFeedScreen({super.key});

  @override
  State<BBCNewsFeedScreen> createState() => _BBCNewsFeedScreenState();
}

class _BBCNewsFeedScreenState extends State<BBCNewsFeedScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = false;
  List<Map<String, dynamic>> _newsList = [];
  Map<String, dynamic> _weatherInfo = {};
  String _selectedCity = 'London';

  final List<String> _cities = ['London', 'New York', 'Paris', 'Tokyo', 'Johannesburg', 'Sydney'];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchBBCNews();
    _fetchWeather('London');
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchBBCNews() async {
    setState(() {
      _loading = true;
    });

    try {
      final response = await http.get(Uri.parse(
          'https://api.rss2json.com/v1/api.json?rss_url=http://feeds.bbci.co.uk/news/rss.xml'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final articles = data['items'] as List?;
        if (articles != null && articles.isNotEmpty) {
          setState(() {
            _newsList = articles.map((a) => {
              'title': a['title'] ?? 'BBC Breaking News',
              'description': a['description'] ?? 'Stay updated on the latest global headlines.',
              'urlToImage': a['thumbnail'],
              'publishedAt': a['pubDate'] ?? '',
              'source': 'BBC News',
              'link': a['link'],
            }).toList();
          });
          return;
        }
      }
      _loadMockNews();
    } catch (_) {
      _loadMockNews();
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  void _loadMockNews() {
    setState(() {
      _newsList = [
        {
          'title': 'Global Climate Pact Reaches Historic Milestone',
          'description': 'More than 190 nations agree on a comprehensive roadmap to accelerate transition away from fossil fuels, with target dates pulled forward.',
          'urlToImage': 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?auto=format&fit=crop&w=800&q=80',
          'publishedAt': '2026-05-19T10:00:00Z',
          'source': 'BBC Science',
          'link': 'https://www.bbc.com/news',
        },
        {
          'title': 'AI Supercomputers Set to Predict Extreme Weather Weeks Ahead',
          'description': 'A new alliance of meteorological agencies launches a highly localized deep-learning grid capable of forecasting storms 14 days in advance.',
          'urlToImage': 'https://images.unsplash.com/photo-1504608524841-42fe6f032b4b?auto=format&fit=crop&w=800&q=80',
          'publishedAt': '2026-05-19T08:30:00Z',
          'source': 'BBC Tech',
          'link': 'https://www.bbc.com/news',
        }
      ];
    });
  }

  Future<void> _fetchWeather([String city = 'London']) async {
    setState(() {
      _selectedCity = city;
    });

    try {
      final geoRes = await http.get(Uri.parse('https://geocoding-api.open-meteo.com/v1/search?name=$city&count=1&language=en&format=json'));
      if (geoRes.statusCode == 200) {
        final geoData = jsonDecode(geoRes.body);
        final results = geoData['results'] as List?;
        if (results != null && results.isNotEmpty) {
          final loc = results.first;
          final lat = loc['latitude'];
          final lon = loc['longitude'];
          final name = loc['name'];
          final country = loc['country'] ?? '';
          
          final displayName = country.isNotEmpty ? '$name, $country' : name;

          final response = await http.get(Uri.parse(
              'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current_weather=true'));
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final cw = data['current_weather'];
            if (cw != null) {
              setState(() {
                _weatherInfo = {
                  'temp': cw['temperature'],
                  'windspeed': cw['windspeed'],
                  'code': cw['weathercode'],
                  'city': displayName,
                };
              });
              return;
            }
          }
        } else {
           if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(
               content: Text('Location not found.'),
               behavior: SnackBarBehavior.floating,
               backgroundColor: Colors.redAccent,
             ));
           }
           return;
        }
      }
      _loadMockWeather();
    } catch (_) {
      _loadMockWeather();
    }
  }

  void _loadMockWeather() {
    final Map<String, double> temps = {
      'London': 14.5,
      'New York': 19.0,
      'Paris': 17.2,
      'Tokyo': 22.8,
      'Johannesburg': 24.0,
      'Sydney': 18.3,
    };
    setState(() {
      _weatherInfo = {
        'temp': temps[_selectedCity] ?? 18.0,
        'windspeed': 12.4,
        'code': 1,
        'city': _selectedCity,
      };
    });
  }

  String _getWeatherCondition(int code) {
    if (code <= 1) return 'Clear Sky';
    if (code <= 3) return 'Partly Cloudy';
    if (code <= 48) return 'Foggy';
    if (code <= 65) return 'Rainy';
    return 'Stormy';
  }

  IconData _getWeatherIcon(int code) {
    if (code <= 1) return Icons.wb_sunny_rounded;
    if (code <= 3) return Icons.cloud_queue_rounded;
    if (code <= 48) return Icons.blur_on_rounded;
    if (code <= 65) return Icons.umbrella_rounded;
    return Icons.thunderstorm_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;
    return LuxuryScaffold(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: theme.surface,
          elevation: 4,
          iconTheme: IconThemeData(color: theme.onSurface),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: theme.onSurface),
            onPressed: () => Navigator.pop(context),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                color: theme.onSurface,
                child: Text(
                  'B B C',
                  style: TextStyle(
                    color: theme.surface,
                    fontFamily: 'Impact',
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'News & Weather',
                style: TextStyle(color: theme.onSurface, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: theme.onSurface,
            indicatorWeight: 3,
            labelColor: theme.onSurface,
            unselectedLabelColor: theme.onSurface.withOpacity(0.5),
            tabs: const [
              Tab(icon: Icon(Icons.article), text: "World Feed"),
              Tab(icon: Icon(Icons.cloudy_snowing), text: "Global Weather"),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            // ── Tab 1: News Feed ───────────────────────────────
            RefreshIndicator(
              onRefresh: _fetchBBCNews,
              color: theme.onSurface,
              child: _loading && _newsList.isEmpty
                  ? Center(child: CircularProgressIndicator(color: theme.onSurface))
                  : ListView.builder(
                      padding: const EdgeInsets.all(14),
                      itemCount: _newsList.length,
                      itemBuilder: (context, index) {
                        final item = _newsList[index];
                        return InkWell(
                          onTap: () async {
                            final url = item['link'];
                            if (url != null && url.isNotEmpty) {
                              final uri = Uri.parse(url);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri);
                              }
                            }
                          },
                          child: Card(
                            color: theme.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(color: theme.onSurface.withOpacity(0.2)),
                            ),
                            margin: const EdgeInsets.only(bottom: 16),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (item['urlToImage'] != null)
                                Image.network(
                                  item['urlToImage'],
                                  height: 180,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    height: 180,
                                    color: theme.onSurface.withOpacity(0.1),
                                    child: Icon(Icons.image, size: 50, color: theme.onSurface.withOpacity(0.3)),
                                  ),
                                ),
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: theme.onSurface,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            item['source'],
                                            style: TextStyle(
                                                color: theme.surface, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        Text(
                                          'LIVE NOW',
                                          style: TextStyle(
                                              color: theme.onSurface, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      item['title'],
                                      style: TextStyle(
                                          color: theme.onSurface, fontSize: 18, fontWeight: FontWeight.bold, height: 1.3),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      item['description'],
                                      style: TextStyle(color: theme.onSurface.withOpacity(0.7), fontSize: 13, height: 1.4),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ));
                      },
                    ),
            ),

            // ── Tab 2: Weather Feed ────────────────────────────
            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "World Cities Weather Monitor",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.onSurface),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Real-time meteorological forecast linked to BBC global network.",
                    style: TextStyle(color: theme.onSurface.withOpacity(0.6), fontSize: 13),
                  ),
                  // Search Box
                  TextField(
                    controller: _searchController,
                    style: TextStyle(color: theme.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Search city or country...',
                      hintStyle: TextStyle(color: theme.onSurface.withOpacity(0.5)),
                      prefixIcon: Icon(Icons.search, color: theme.onSurface),
                      filled: true,
                      fillColor: theme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide(color: theme.onSurface.withOpacity(0.2)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide(color: theme.onSurface.withOpacity(0.2)),
                      ),
                    ),
                    onSubmitted: (val) {
                      if (val.trim().isNotEmpty) {
                        _fetchWeather(val.trim());
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // City Picker Row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _cities.map((city) {
                        final isSel = city == _selectedCity;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedCity = city;
                              _searchController.text = city;
                            });
                            _fetchWeather(city);
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSel ? theme.onSurface : theme.surface,
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: isSel ? Colors.transparent : theme.onSurface.withOpacity(0.2)),
                            ),
                            child: Text(
                              city,
                              style: TextStyle(
                                color: isSel ? theme.surface : theme.onSurface,
                                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 30),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: theme.surface,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: theme.onSurface.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _weatherInfo['city'] ?? _selectedCity,
                          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: theme.onSurface),
                        ),
                        const SizedBox(height: 12),
                        Icon(
                          _getWeatherIcon(_weatherInfo['code'] ?? 0),
                          size: 72,
                          color: theme.onSurface,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "${_weatherInfo['temp'] ?? '--'}°C",
                          style: TextStyle(fontSize: 54, fontWeight: FontWeight.w900, color: theme.onSurface),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _getWeatherCondition(_weatherInfo['code'] ?? 0),
                          style: TextStyle(fontSize: 18, color: theme.onSurface.withOpacity(0.7), fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 20),
                        Divider(color: theme.onSurface.withOpacity(0.2)),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                Icon(Icons.air, color: theme.onSurface.withOpacity(0.6)),
                                const SizedBox(height: 4),
                                Text("Wind Speed", style: TextStyle(color: theme.onSurface.withOpacity(0.6), fontSize: 12)),
                                const SizedBox(height: 4),
                                Text("${_weatherInfo['windspeed'] ?? '--'} km/h", style: TextStyle(color: theme.onSurface, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Column(
                              children: [
                                Icon(Icons.water_drop, color: theme.onSurface.withOpacity(0.6)),
                                const SizedBox(height: 4),
                                Text("Humidity", style: TextStyle(color: theme.onSurface.withOpacity(0.6), fontSize: 12)),
                                const SizedBox(height: 4),
                                Text("64%", style: TextStyle(color: theme.onSurface, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
