import 'package:flutter/material.dart';
import 'package:gpt_box/lab/configs/enum.dart';
import 'package:gpt_box/lab/main.dart';

import 'utils/themsdata.dart';


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BuildShip UI',
      debugShowCheckedModeBanner: false,
      theme: AppThemes(context: context).themeData,
      home: const BuildShipHome(),
    );
  }
}
class BuildShipHome extends StatefulWidget {
  const BuildShipHome( {super.key});

  @override
  State<BuildShipHome> createState({currentView = CurrentView.templates }) => _BuildShipHomeState(currentView: currentView);
}

class _BuildShipHomeState extends State<BuildShipHome> {
  final CurrentView currentView;

  _BuildShipHomeState({required this.currentView});


  @override
  Widget build(BuildContext context) {
    setState = this.setState;
    return BuildShipHomeFake(setState);
  }
}