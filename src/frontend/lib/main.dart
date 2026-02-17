import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LibreBeats',
      theme: ThemeData(
        colorScheme: ColorScheme.dark(),
        
      ),
      home: const MyHomePage(title: 'LibreBeats'),
    );
  }
}

class MyHomePage extends StatefulWidget {

  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(17, 0, 0, 0),
        title: Center(child: Text(widget.title)),
      ),
      body: Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black,
          child: Center(child: Text('Hello LibreBeats!', style: TextStyle(color: Colors.white, fontSize: 24))),
        ),
      bottomNavigationBar: BottomAppBar(
        // elevation
        elevation: 0,
        // transparent
        color: const Color.fromARGB(17, 0, 0, 0),
        child: SizedBox(
          height: 50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(onPressed: () => {}, icon: Icon(Icons.search)),
              IconButton(onPressed: () => {}, icon: Icon(Icons.home)),
              IconButton(onPressed: () => {}, icon: Icon(Icons.settings)),
            ],
          ),
        ),
      )
    );
  }
}
