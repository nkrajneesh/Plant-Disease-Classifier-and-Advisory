import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/disease_advisory.dart';
import 'leaf_preprocessor.dart';

class DiseaseScore {
  const DiseaseScore({required this.label, required this.probability});

  final String label;
  final double probability;
}

class CropPrediction {
  const CropPrediction({
    required this.best,
    required this.alternatives,
    required this.isSupportedLeaf,
    required this.invalidImageProbability,
    required this.leafClassConfidence,
  });

  final DiseaseScore best;
  final List<DiseaseScore> alternatives;
  final bool isSupportedLeaf;
  final double invalidImageProbability;
  final double leafClassConfidence;
  DiseaseAdvisory get advisory =>
      diseaseAdvisories[best.label] ?? diseaseAdvisories['Tomato___healthy']!;
}

class CropDiseaseClassifier {
  // This asset path stays stable for the existing Android packaging setup;
  // its contents are the newly retrained 17-output leaf/invalid-image model.
  static const String _modelAsset = 'assets/crop_disease_resnet50.tflite';
  static const String _labelsAsset = 'assets/class_names.json';
  static const String _metadataAsset = 'assets/model_metadata.json';
  static const String _notLeafLabel = '__not_a_supported_leaf__';
  final LeafImagePreprocessor _preprocessor = LeafImagePreprocessor();

  Interpreter? _interpreter;
  IsolateInterpreter? _backgroundInterpreter;
  List<String>? _classNames;
  int? _notLeafIndex;
  double _notLeafProbabilityThreshold = 0.5;
  double _minimumLeafConfidence = 0.0;

  Future<void> _ensureLoaded() async {
    if (_interpreter != null && _backgroundInterpreter != null) return;

    final labelsText = await rootBundle.loadString(_labelsAsset);
    final decodedLabels = jsonDecode(labelsText);
    if (decodedLabels is! List) {
      throw const FormatException('The model class-name file is invalid.');
    }
    final classNames = decodedLabels.cast<String>();
    final classNameSet = classNames.toSet();
    final diseaseLabels = classNameSet.difference({_notLeafLabel});
    if (classNameSet.length != classNames.length ||
        !_classNamesIncludeInvalidLabel(classNames) ||
        diseaseLabels.length != diseaseAdvisories.length ||
        diseaseLabels.difference(diseaseAdvisories.keys.toSet()).isNotEmpty ||
        diseaseAdvisories.keys.toSet().difference(diseaseLabels).isNotEmpty) {
      throw const FormatException(
          'The model labels do not match the app advice list.');
    }

    final metadataText = await rootBundle.loadString(_metadataAsset);
    final metadata = jsonDecode(metadataText);
    if (metadata is! Map<String, dynamic>) {
      throw const FormatException('The model metadata file is invalid.');
    }
    final gate = metadata['invalid_image_gate'];
    if (gate is! Map<String, dynamic>) {
      throw const FormatException(
          'The model is missing its invalid-image rejection settings.');
    }
    final notLeafThreshold = gate['not_leaf_probability_threshold'];
    final leafThreshold = gate['minimum_leaf_confidence'];
    if (notLeafThreshold is! num || leafThreshold is! num) {
      throw const FormatException(
          'The invalid-image rejection thresholds are invalid.');
    }
    _notLeafProbabilityThreshold = notLeafThreshold.toDouble();
    _minimumLeafConfidence = leafThreshold.toDouble();
    _notLeafIndex = classNames.indexOf(_notLeafLabel);

    final interpreter = await Interpreter.fromAsset(_modelAsset);
    interpreter.allocateTensors();
    final inputShape = interpreter.getInputTensor(0).shape;
    final outputShape = interpreter.getOutputTensor(0).shape;
    if (inputShape.length != 4 ||
        inputShape[0] != 1 ||
        inputShape[1] != LeafImagePreprocessor.size ||
        inputShape[2] != LeafImagePreprocessor.size ||
        inputShape[3] != 3 ||
        outputShape.length != 2 ||
        outputShape[0] != 1 ||
        outputShape[1] != classNames.length) {
      interpreter.close();
      throw const FormatException(
          'The model tensor shape does not match the app settings.');
    }

    _interpreter = interpreter;
    _classNames = classNames;
    _backgroundInterpreter = await IsolateInterpreter.create(
      address: interpreter.address,
      debugName: 'CropDiseaseResNet50',
    );
  }

  Future<CropPrediction> predict(File imageFile) async {
    await _ensureLoaded();
    final imageBytes = await imageFile.readAsBytes();
    final rgb = _preprocessor.preprocess(imageBytes);
    final classNames = _classNames!;
    final input = List<List<List<List<double>>>>.generate(
      1,
      (_) => List<List<List<double>>>.generate(
        LeafImagePreprocessor.size,
        (y) => List<List<double>>.generate(
          LeafImagePreprocessor.size,
          (x) {
            final pixelOffset = (y * LeafImagePreprocessor.size + x) * 3;
            final red = rgb[pixelOffset].toDouble();
            final green = rgb[pixelOffset + 1].toDouble();
            final blue = rgb[pixelOffset + 2].toDouble();
            // ResNet50 preprocessing converts RGB to BGR, then subtracts ImageNet means.
            return <double>[
              blue - 103.939,
              green - 116.779,
              red - 123.68,
            ];
          },
        ),
      ),
    );
    final output = <List<double>>[
      List<double>.filled(classNames.length, 0.0),
    ];
    await _backgroundInterpreter!.run(input, output);

    final scores = <DiseaseScore>[];
    for (var index = 0; index < classNames.length; index++) {
      final probability = output[0][index];
      if (!probability.isFinite) {
        throw const FormatException('The model returned an invalid score.');
      }
      scores.add(
          DiseaseScore(label: classNames[index], probability: probability));
    }
    scores.sort((a, b) => b.probability.compareTo(a.probability));
    final invalidProbability = output[0][_notLeafIndex!];
    final diseaseScores =
        scores.where((score) => score.label != _notLeafLabel).toList();
    final bestDisease = diseaseScores.first;
    final supportedLeaf = scores.first.label != _notLeafLabel &&
        invalidProbability < _notLeafProbabilityThreshold &&
        bestDisease.probability >= _minimumLeafConfidence;
    return CropPrediction(
      best: bestDisease,
      alternatives: supportedLeaf ? diseaseScores.take(3).toList() : const [],
      isSupportedLeaf: supportedLeaf,
      invalidImageProbability: invalidProbability,
      leafClassConfidence: bestDisease.probability,
    );
  }

  Future<void> dispose() async {
    await _backgroundInterpreter?.close();
    _interpreter?.close();
    _backgroundInterpreter = null;
    _interpreter = null;
  }

  bool _classNamesIncludeInvalidLabel(List<String> names) =>
      names.length == diseaseAdvisories.length + 1 &&
      names.contains(_notLeafLabel);
}
