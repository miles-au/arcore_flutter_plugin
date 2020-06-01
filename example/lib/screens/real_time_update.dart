import 'package:arcore_flutter_plugin/arcore_flutter_plugin.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart';

class PerformHitTestScreen extends StatefulWidget {
  @override
  _PerformHitTestScreenState createState() => _PerformHitTestScreenState();
}

class _PerformHitTestScreenState extends State<PerformHitTestScreen> {
  final double scale = 0.01;
  Vector3 scaleVector;
  ArCoreController arCoreController;
  ArCoreNode node;

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
        title: const Text('Real Time Update'),
      ),
      body: ArCoreView(
        onArCoreViewCreated: _onArCoreViewCreated,
        enableUpdateListener: true,
      ),
    );
  }

  void _onArCoreViewCreated(ArCoreController controller) {
    arCoreController = controller;
    arCoreController.onFrameUpdate = (time) {
      arCoreController.performHitTestOnPlane().then((results) {
        if (results.isNotEmpty) {
          if (node == null) {
            _addNode(results);
          } else {
            _moveNode(results);
          }
        }
      });
    };
  }

  void _addNode(List<ArCoreHitTestResult> results) {
    final ArCoreHitTestResult hit = results.first;
    if (hit == null) return;

    final material = ArCoreMaterial(
      color: Color.fromRGBO(255, 255, 255, 1),
      roughness: 1.0,
      reflectance: 0.0,
    );

    final shape = ArCoreSphere(
      materials: [material],
      radius: 1,
    );

    node = ArCoreNode(
        scale: scaleVector,
        shape: shape,
        position: hit.pose.translation,
        rotation: hit.pose.rotation);

    arCoreController.addArCoreNode(node);
  }

  void _moveNode(List<ArCoreHitTestResult> results) {
    final ArCoreHitTestResult hit = results.first;
    if (hit == null) return;
    node.position.value = hit.pose.translation;
  }
}
