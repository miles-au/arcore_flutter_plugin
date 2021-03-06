import 'dart:typed_data';

import 'package:arcore_flutter_plugin/src/arcore_augmented_image.dart';
import 'package:arcore_flutter_plugin/src/arcore_rotating_node.dart';
import 'package:arcore_flutter_plugin/src/utils/vector_utils.dart';
import 'package:flutter/services.dart';
import 'package:meta/meta.dart';
import 'arcore_hit_test_result.dart';

import 'arcore_node.dart';
import 'arcore_plane.dart';

typedef StringResultHandler = void Function(String text);
typedef UnsupportedHandler = void Function(String text);
typedef FrameUpdateHandler = void Function(int time);
typedef ArCoreHitResultHandler = void Function(List<ArCoreHitTestResult> hits);
typedef ArCorePlaneHandler = void Function(ArCorePlane plane);
typedef ArCoreAugmentedImageTrackingHandler = void Function(
    ArCoreAugmentedImage);

const UTILS_CHANNEL_NAME = 'arcore_flutter_plugin/utils';

class ArCoreController {
  static checkArCoreAvailability() async {
    final bool arcoreAvailable = await MethodChannel(UTILS_CHANNEL_NAME)
        .invokeMethod('checkArCoreApkAvailability');
    return arcoreAvailable;
  }

  ArCoreController({
    int id,
    this.enableTapRecognizer,
    this.enableUpdateListener,
    this.forceTapOnScreenCenter,
  }) {
    _channel = MethodChannel('arcore_flutter_plugin_$id');
    _channel.setMethodCallHandler(_handleMethodCalls);
    init();
  }

  final bool enableUpdateListener;
  final bool enableTapRecognizer;
  final bool forceTapOnScreenCenter;
  MethodChannel _channel;
  StringResultHandler onError;
  StringResultHandler onNodeTap;

  ArCoreHitResultHandler onPlaneTap;
  ArCorePlaneHandler onPlaneDetected;
  ArCoreAugmentedImageTrackingHandler onTrackingImage;

  /// is run on every frame update at the beginning. Returns frame start time in milliseconds
  FrameUpdateHandler onFrameUpdate;

  init() async {
    try {
      await _channel.invokeMethod<void>('init', {
        'enableTapRecognizer': enableTapRecognizer,
        'enableUpdateListener': enableUpdateListener,
        'forceTapOnScreenCenter': forceTapOnScreenCenter,
      });
    } on PlatformException catch (ex) {
      print(ex.message);
    }
  }

  Future<dynamic> _handleMethodCalls(MethodCall call) async {
    switch (call.method) {
      case 'onError':
        if (onError != null) {
          onError(call.arguments);
        }
        break;
      case 'onNodeTap':
        if (onNodeTap != null) {
          onNodeTap(call.arguments);
        }
        break;
      case 'onPlaneTap':
        if (onPlaneTap != null) {
          final List<dynamic> input = call.arguments;
          final objects = input
              .cast<Map<dynamic, dynamic>>()
              .map<ArCoreHitTestResult>(
                  (Map<dynamic, dynamic> h) => ArCoreHitTestResult.fromMap(h))
              .toList();
          onPlaneTap(objects);
        }
        break;
      case 'onPlaneDetected':
        if (enableUpdateListener && onPlaneDetected != null) {
          final plane = ArCorePlane.fromMap(call.arguments);
          onPlaneDetected(plane);
        }
        break;
      case 'onTrackingImage':
        print('flutter onTrackingImage');
        final arCoreAugmentedImage =
            ArCoreAugmentedImage.fromMap(call.arguments);
        onTrackingImage(arCoreAugmentedImage);
        break;
      case 'onFrameUpdate':
        if (enableUpdateListener && onFrameUpdate != null) {
          final time = call.arguments['time'];
          onFrameUpdate(time);
        }
        break;
      default:
        print('Unknown method ${call.method} ');
    }
    return Future.value();
  }

  /// Perform Hit Test
  /// defaults to center of the screen.
  /// x and y values are between 0 and 1
  Future<List<ArCoreHitTestResult>> performHitTestOnPlane(
      {double x = 0.5, double y = 0.5}) async {
    assert(x >= 0 && y >= 0 && x <= 1 && y <= 1);
    final List<dynamic> results =
        await _channel.invokeMethod('performHitTestOnPlane', {'x': x, 'y': y});
    if (results == null) {
      return [];
    } else {
      final objects = results
          .cast<Map<dynamic, dynamic>>()
          .map<ArCoreHitTestResult>(
              (Map<dynamic, dynamic> r) => ArCoreHitTestResult.fromMap(r))
          .toList();
      return objects;
    }
  }

  Future<void> addArCoreNode(ArCoreNode node, {String parentNodeName}) {
    assert(node != null);
    final params = _addParentNodeNameToParams(node.toMap(), parentNodeName);
    print(params.toString());
    _addListeners(node);
    return _channel.invokeMethod('addArCoreNode', params);
  }

  addArCoreNodeToAugmentedImage(ArCoreNode node, int index,
      {String parentNodeName}) {
    assert(node != null);

    final params = _addParentNodeNameToParams(node.toMap(), parentNodeName);
    return _channel.invokeMethod(
        'attachObjectToAugmentedImage', {'index': index, 'node': params});
  }

  Future<void> addArCoreNodeWithAnchor(ArCoreNode node,
      {String parentNodeName}) {
    assert(node != null);
    final params = _addParentNodeNameToParams(node.toMap(), parentNodeName);
    print(params.toString());
    _addListeners(node);
    return _channel.invokeMethod('addArCoreNodeWithAnchor', params);
  }

  Future<void> removeNode({@required String nodeName}) {
    assert(nodeName != null);
    return _channel.invokeMethod('removeARCoreNode', {'nodeName': nodeName});
  }

  Map<String, dynamic> _addParentNodeNameToParams(
      Map geometryMap, String parentNodeName) {
    if (parentNodeName?.isNotEmpty ?? false)
      geometryMap['parentNodeName'] = parentNodeName;
    return geometryMap;
  }

  void _addListeners(ArCoreNode node) {
    node.position.addListener(() => _handlePositionChanged(node));
    node?.shape?.materials?.addListener(() => _updateMaterials(node));

    if (node is ArCoreRotatingNode) {
      node.degreesPerSecond.addListener(() => _handleRotationChanged(node));
    }
  }

  void _handlePositionChanged(ArCoreNode node) {
    _channel.invokeMethod<void>(
        'positionChanged',
        _getHandlerParams(node, {
          'name': node.name,
          'position': convertVector3ToMap(node.position.value)
        }));
  }

  void _handleRotationChanged(ArCoreRotatingNode node) {
    _channel.invokeMethod<void>('rotationChanged',
        {'name': node.name, 'degreesPerSecond': node.degreesPerSecond.value});
  }

  void _updateMaterials(ArCoreNode node) {
    _channel.invokeMethod<void>(
        'updateMaterials', _getHandlerParams(node, node.shape.toMap()));
  }

  Map<String, dynamic> _getHandlerParams(
      ArCoreNode node, Map<String, dynamic> params) {
    final Map<String, dynamic> values = <String, dynamic>{'name': node.name}
      ..addAll(params);
    return values;
  }

  Future<void> loadSingleAugmentedImage({@required Uint8List bytes}) {
    assert(bytes != null);
    return _channel.invokeMethod('load_single_image_on_db', {
      'bytes': bytes,
    });
  }

  Future<void> loadAugmentedImagesDatabase({@required Uint8List bytes}) {
    assert(bytes != null);
    return _channel.invokeMethod('load_augmented_images_database', {
      'bytes': bytes,
    });
  }

  void dispose() {
    _channel?.invokeMethod<void>('dispose');
  }

  Future<void> removeNodeWithIndex(int index) {
    try {
      return _channel.invokeMethod('removeARCoreNodeWithIndex', {
        'index': index,
      });
    } catch (ex) {
      print(ex);
    }
  }
}
