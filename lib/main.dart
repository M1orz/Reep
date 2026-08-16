import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/run_record.dart';
import 'pages/home_page.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.bg,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const ReepApp());
}

class ReepApp extends StatelessWidget {
  const ReepApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reep',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: HomePage(repository: RunRepository()),
    );
  }
}
