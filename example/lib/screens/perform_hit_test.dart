import 'package:arcore_flutter_plugin/arcore_flutter_plugin.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:vector_math/vector_math_64.dart';

class PerformHitTestScreen extends StatefulWidget {
  @override
  _PerformHitTestScreenState createState() => _PerformHitTestScreenState();
}

class _PerformHitTestScreenState extends State<PerformHitTestScreen> {
  final double scale = 0.005;
  Vector3 scaleVector;
  ArCoreController arCoreController;
//  ArCorePlane plane;

  @override
  void initState() {
    scaleVector = Vector3(scale, scale, scale);
    super.initState();
  }

  @override
  void dispose() {
    arCoreController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perform Hit Test'),
      ),
      body: ArCoreView(
        onArCoreViewCreated: _onArCoreViewCreated,
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () {
          print("pressed");
          arCoreController.performHitTestOnPlane().then((results) {
            print("results: $results");
            _addNode(results);
          });
        },
      ),
    );
  }

  void _onArCoreViewCreated(ArCoreController controller) {
    arCoreController = controller;
    arCoreController.onPlaneDetected = (plane) {};
  }

  void _addNode(List<ArCoreHitTestResult> results) {
    final ArCoreHitTestResult hit = results.first;

    final material = ArCoreMaterial(
      color: Color.fromRGBO(255, 255, 255, 1),
      roughness: 1.0,
      reflectance: 0.0,
    );

    final shape = ArCoreSphere(
      materials: [material],
      radius: 1,
    );

    final node = ArCoreNode(
        scale: scaleVector,
        shape: shape,
        position: hit.pose.translation,
        rotation: hit.pose.rotation);

    arCoreController.addArCoreNode(node);
  }
}
