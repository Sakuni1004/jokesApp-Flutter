import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:internet_connection_checker/internet_connection_checker.dart'; // Import the package

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Joke Caching App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.system,
      home: const MyHomePage(title: 'Jokes App'),
    );
  }
}

class Joke {
  final String setup;
  final String punchline;

  Joke({required this.setup, required this.punchline});

  // Deserialize JSON to Joke object
  factory Joke.fromJson(Map<String, dynamic> json) {
    return Joke(
      setup: json['setup'],
      punchline: json['punchline'],
    );
  }

  // Serialize Joke object to JSON
  Map<String, dynamic> toJson() {
    return {
      'setup': setup,
      'punchline': punchline,
    };
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<Joke> _jokes = [];
  bool _isLoading = false;
  bool _useMonospaceFont = false;
  bool _isOnline = false; 

  @override
  void initState() {
    super.initState();
    _loadCachedJokes(); 
    _checkConnection(); 
  }

  /// Checks the internet connection status
  Future<void> _checkConnection() async {
    bool isConnected = await InternetConnectionChecker().hasConnection;
    setState(() {
      _isOnline = isConnected;
    });

    
    if (!_isOnline) {
      _loadCachedJokes();
    }
  }

  /// Loads cached jokes from shared_preferences
  Future<void> _loadCachedJokes() async {
    final prefs = await SharedPreferences.getInstance();
    final jokesJson = prefs.getStringList('cached_jokes') ?? [];
    setState(() {
      // Deserialize jokes from JSON
      _jokes = jokesJson
          .map((jokeJson) => Joke.fromJson(jsonDecode(jokeJson)))
          .toList();
    });
  }

  /// Fetches a new joke from the API
  Future<void> _fetchJoke() async {
    setState(() {
      _isLoading = true;
    });

    try {
      
      if (_isOnline) {
        final response = await http.get(
          Uri.parse('https://official-joke-api.appspot.com/random_joke'),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          Joke joke = Joke.fromJson(data); 

          // Update jokes list and cache
          setState(() {
            _jokes.insert(0, joke);
            if (_jokes.length > 5) {
              _jokes = _jokes.sublist(0, 8); 
            }

            // Toggle font dynamically
            _useMonospaceFont = !_useMonospaceFont;
          });
          await _cacheJokes();
        } else {
          _showError("Failed to fetch a joke. Please try again!");
        }
      } else {
        // If offline, show cached jokes
        _showError("No internet connection. Using cached jokes.");
      }
    } catch (e) {
      // Handle offline or API failure
      _showError("Unable to fetch jokes. Displaying cached jokes.");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Caches jokes to shared_preferences
  Future<void> _cacheJokes() async {
    final prefs = await SharedPreferences.getInstance();
  
    List<String> jokesJson =
        _jokes.map((joke) => jsonEncode(joke.toJson())).toList();
    await prefs.setStringList('cached_jokes', jokesJson);
  }

  /// Deletes a joke from the list
  Future<void> _deleteJoke(int index) async {
    setState(() {
      _jokes.removeAt(index);
    });
    await _cacheJokes(); 
  }

  /// Shows error messages in a snackbar
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isLoading)
                
                Image.asset('assets/loading.gif', width: 100, height: 100)
              else if (_jokes.isEmpty)
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    
                    Image.asset('assets/joker.gif', width: 200, height: 200),
                    const SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 103, 58, 183)
                            .withOpacity(0.4), 
                        borderRadius: BorderRadius.circular(12), 
                      ),
                      padding: const EdgeInsets.all(16.0),
                      child: const Text(
                        'No jokes available. Please fetch some jokes!',
                        style: TextStyle(fontSize: 20, fontFamily: 'poppins'),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                )
              else
                Expanded(
                  child: Scrollbar(
                    thumbVisibility: true, 
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          ListView.builder(
                            shrinkWrap: true,
                            itemCount: _jokes.length,
                            itemBuilder: (context, index) {
                              return Container(
                                decoration: BoxDecoration(
                                  color: const Color.fromARGB(255, 103, 58, 183)
                                      .withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                child: ListTile(
                                  title: Text(
                                    '${_jokes[index].setup} - ${_jokes[index].punchline}',
                                    style: _useMonospaceFont
                                        ? GoogleFonts.poppins(fontSize: 13)
                                        : GoogleFonts.poppins(fontSize: 13),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete,
                                        color:
                                            Color.fromARGB(255, 237, 119, 108)),
                                    onPressed: () => _deleteJoke(index),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _fetchJoke,
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  side: const BorderSide(
                      color: Color.fromARGB(255, 103, 58, 183),
                      width: 1), 
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('Fetch Joke'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
