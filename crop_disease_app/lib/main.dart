import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models/disease_advisory.dart';
import 'services/crop_disease_classifier.dart';

enum CropType {
  potato('Potato', '🥔', 'Potato'),
  tomato('Tomato', '🍅', 'Tomato'),
  corn('Corn', '🌽', 'Corn_(maize)'),
  apple('Apple', '🍎', 'Apple');

  const CropType(this.title, this.emoji, this.modelPrefix);

  final String title;
  final String emoji;
  final String modelPrefix;

  bool matchesClass(String className) =>
      className.startsWith('${modelPrefix}___');
}

void main() {
  runApp(const CropDiseaseApp());
}

class CropDiseaseApp extends StatelessWidget {
  const CropDiseaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    const forest = Color(0xFF1F5D42);
    return MaterialApp(
      title: 'Crop Disease Detection',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: forest),
        scaffoldBackgroundColor: const Color(0xFFF5F7F1),
        cardTheme: const CardThemeData(color: Colors.white, elevation: 0),
      ),
      home: const CropDiseaseHome(),
    );
  }
}

class CropDiseaseHome extends StatefulWidget {
  const CropDiseaseHome({super.key});

  @override
  State<CropDiseaseHome> createState() => _CropDiseaseHomeState();
}

class _CropDiseaseHomeState extends State<CropDiseaseHome> {
  final ImagePicker _picker = ImagePicker();
  final CropDiseaseClassifier _classifier = CropDiseaseClassifier();
  File? _selectedImage;
  CropType? _selectedCrop;
  bool _working = false;
  String? _error;

  Future<void> _chooseImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 100,
        maxWidth: 3000,
        maxHeight: 3000,
      );
      if (picked == null || !mounted) return;
      final file = File(picked.path);
      final cropSelectedForThisImage = _selectedCrop;
      setState(() {
        _selectedImage = file;
        _error = null;
        _working = true;
      });

      final result = await _classifier.predict(file);
      if (!mounted) return;
      setState(() {
        _working = false;
      });
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => CropResultScreen(
            imageFile: file,
            prediction: result,
            selectedCrop: cropSelectedForThisImage,
          ),
        ),
      );
      if (!mounted) return;
      setState(() => _selectedImage = null);
    } catch (exception) {
      if (!mounted) return;
      final message = exception.toString();
      final modelMissing = message.contains('crop_disease_resnet50.tflite') ||
          message.contains('Unable to load asset');
      setState(() {
        _working = false;
        _error = modelMissing
            ? 'The trained model is missing from this app build. Rebuild the APK with the model assets included.'
            : 'Could not analyze this image. Try another clear leaf photo. Details: $message';
      });
    }
  }

  @override
  void dispose() {
    _classifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              sliver: SliverList.list(
                children: [
                  _buildHeader(theme),
                  const SizedBox(height: 22),
                  _buildCropPanel(theme),
                  const SizedBox(height: 18),
                  _buildImageActions(),
                  if (_selectedImage != null) ...[
                    const SizedBox(height: 20),
                    _buildSelectedImage(),
                  ],
                  if (_working) ...[
                    const SizedBox(height: 20),
                    const Center(child: CircularProgressIndicator()),
                    const SizedBox(height: 10),
                    const Center(child: Text('Checking the leaf…')),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 20),
                    _buildError(theme),
                  ],
                  const SizedBox(height: 24),
                  _buildNotice(theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Image.asset(
            'assets/icon/logo.jpeg',
            width: 104,
            height: 104,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              width: 104,
              height: 104,
              color: theme.colorScheme.primaryContainer,
              child: Icon(Icons.eco_rounded,
                  size: 48, color: theme.colorScheme.primary),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text('Welcome to',
            style: theme.textTheme.titleMedium
                ?.copyWith(color: const Color(0xFF527363))),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Crop',
                style: theme.textTheme.displaySmall?.copyWith(
                  color: const Color(0xFF145A3A),
                  fontWeight: FontWeight.w900,
                ),
              ),
              TextSpan(
                text: 'Care',
                style: theme.textTheme.displaySmall?.copyWith(
                  color: const Color(0xFFF28C28),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          'Crop Disease & Pest Detection\nwith Expert Advisory',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            color: const Color(0xFF355B49),
            height: 1.3,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildCropPanel(ThemeData theme) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.eco_rounded,
                    color: theme.colorScheme.primary, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Select Crop',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: const Color(0xFF145A3A),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              'Choose the crop in your photo to check the result.',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
            ),
            const SizedBox(height: 14),
            Row(
              children: CropType.values
                  .map((crop) => _buildCropChoice(theme, crop))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCropChoice(ThemeData theme, CropType crop) {
    final selected = _selectedCrop == crop;
    return Expanded(
      child: Padding(
        padding: EdgeInsets.only(right: crop == CropType.apple ? 0 : 7),
        child: Semantics(
          button: true,
          selected: selected,
          label: 'Select ${crop.title}',
          child: Material(
            color: selected ? const Color(0xFFD8EEDB) : const Color(0xFFF7F9F2),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => setState(() {
                _selectedCrop = selected ? null : crop;
              }),
              child: Container(
                height: 88,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected
                        ? theme.colorScheme.primary
                        : const Color(0xFFE4EADF),
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(crop.emoji, style: const TextStyle(fontSize: 28)),
                    const SizedBox(height: 4),
                    Text(
                      crop.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: const Color(0xFF174C37),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageActions() {
    return Row(
      children: [
        Expanded(
          child: _imageAction(
            title: 'Open Camera',
            subtitle: 'Take a plant photo',
            icon: Icons.photo_camera_rounded,
            color: const Color(0xFF168544),
            source: ImageSource.camera,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _imageAction(
            title: 'Upload Image',
            subtitle: 'Choose from gallery',
            icon: Icons.photo_library_rounded,
            color: const Color(0xFFF28C16),
            source: ImageSource.gallery,
          ),
        ),
      ],
    );
  }

  Widget _imageAction({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required ImageSource source,
  }) {
    return SizedBox(
      height: 150,
      child: FilledButton(
        onPressed: _working ? null : () => _chooseImage(source),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.all(12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: const TextStyle(fontSize: 11, height: 1.2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Image.file(
        _selectedImage!,
        height: 240,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const SizedBox(
          height: 160,
          child: Center(child: Text('Image preview is unavailable.')),
        ),
      ),
    );
  }

  Widget _buildError(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(_error!, style: const TextStyle(height: 1.4))),
          ],
        ),
      ),
    );
  }

  Widget _buildNotice(ThemeData theme) {
    return Text(
      'This student project provides an image-based suggestion, not a confirmed diagnosis. Similar leaf symptoms can have different causes. For serious or spreading damage, consult a local agriculture or plant-disease expert.',
      style: theme.textTheme.bodySmall
          ?.copyWith(color: Colors.black54, height: 1.45),
    );
  }
}

class CropResultScreen extends StatefulWidget {
  const CropResultScreen({
    required this.imageFile,
    required this.prediction,
    required this.selectedCrop,
    super.key,
  });

  final File imageFile;
  final CropPrediction prediction;
  final CropType? selectedCrop;

  @override
  State<CropResultScreen> createState() => _CropResultScreenState();
}

class _CropResultScreenState extends State<CropResultScreen> {
  int _activeTab = 0;

  DiseaseAdvisory get _advisory => widget.prediction.advisory;
  DiseaseSections get _sections =>
      diseaseSections[widget.prediction.best.label] ??
      diseaseSections['Tomato___healthy']!;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = widget.prediction.best.probability.clamp(0.0, 1.0).toDouble();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTopBar(theme),
                  const SizedBox(height: 18),
                  if (!widget.prediction.isSupportedLeaf)
                    _buildInvalidImageResult(theme)
                  else ...[
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth >= 700) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 5, child: _buildLeafPhoto()),
                              const SizedBox(width: 20),
                              Expanded(
                                  flex: 6,
                                  child: _buildResultSummary(theme, score)),
                            ],
                          );
                        }
                        return Column(
                          children: [
                            _buildLeafPhoto(),
                            const SizedBox(height: 16),
                            _buildResultSummary(theme, score),
                          ],
                        );
                      },
                    ),
                    if (widget.prediction.alternatives.length > 1) ...[
                      const SizedBox(height: 12),
                      _buildAlternativeMatches(theme),
                    ],
                    const SizedBox(height: 18),
                    _buildTabs(theme),
                    const SizedBox(height: 14),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: _buildTabContent(theme,
                          key: ValueKey<int>(_activeTab)),
                    ),
                    const SizedBox(height: 18),
                    _buildSource(),
                    if (_advisory.urgent) ...[
                      const SizedBox(height: 12),
                      _callout(
                        theme,
                        'Prompt local confirmation is recommended because this disease can spread quickly.',
                        icon: Icons.priority_high_rounded,
                      ),
                    ],
                    const SizedBox(height: 18),
                    _buildActions(theme),
                    const SizedBox(height: 16),
                    Text(
                      'This student project gives an image-based suggestion, not a confirmed diagnosis. For serious or spreading damage, ask a local agriculture or plant-health adviser.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.black54,
                        height: 1.45,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInvalidImageResult(ThemeData theme) {
    final rejectionScore =
        widget.prediction.invalidImageProbability.clamp(0.0, 1.0).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildLeafPhoto(),
        const SizedBox(height: 18),
        Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                const Icon(
                  Icons.image_not_supported_outlined,
                  size: 54,
                  color: Color(0xFFB34B32),
                ),
                const SizedBox(height: 12),
                Text(
                  'Invalid image',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: const Color(0xFF8B2E25),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This is not a supported crop leaf image. Please upload a clear photo of one apple, corn, potato, or tomato leaf.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
                ),
                const SizedBox(height: 10),
                Text(
                  'No disease result or remedy was generated. Rejection score: ${(rejectionScore * 100).toStringAsFixed(1)}%.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.black54),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Choose another image'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar(ThemeData theme) {
    return Row(
      children: [
        IconButton.filledTonal(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/icon/logo.jpeg',
                  width: 42,
                  height: 42,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.eco_rounded,
                    size: 38,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Crop',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF145A3A),
                      ),
                    ),
                    TextSpan(
                      text: 'Care',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFF28C28),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Home',
          onPressed: () =>
              Navigator.of(context).popUntil((route) => route.isFirst),
          icon: const Icon(Icons.home_rounded),
        ),
      ],
    );
  }

  Widget _buildLeafPhoto() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: AspectRatio(
        aspectRatio: 1.18,
        child: Image.file(
          widget.imageFile,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: const Color(0xFFE3EBDD),
            alignment: Alignment.center,
            child: const Text('Image preview is unavailable.'),
          ),
        ),
      ),
    );
  }

  Widget _buildResultSummary(ThemeData theme, double score) {
    final classParts = widget.prediction.best.label.split('___');
    final crop = _cropForLabel(widget.prediction.best.label);
    final rawDiseaseName = classParts.length > 1
        ? classParts.last.replaceAll('_', ' ').trim()
        : displayDiseaseName(widget.prediction.best.label);
    final diseaseName = rawDiseaseName.isEmpty
        ? rawDiseaseName
        : rawDiseaseName[0].toUpperCase() + rawDiseaseName.substring(1);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFE5F4E6),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                '${crop.emoji}  ${crop.title}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF145A3A),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              diseaseName,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: const Color(0xFF164C37),
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              diseaseName.toLowerCase() == 'healthy'
                  ? 'No disease pattern detected'
                  : 'Detected disease',
              style:
                  theme.textTheme.titleMedium?.copyWith(color: Colors.black54),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE9E4),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.center_focus_strong_rounded,
                      color: Color(0xFFB64335)),
                  const SizedBox(width: 8),
                  Text(
                    'Confidence: ${(score * 100).toStringAsFixed(1)}%',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: const Color(0xFF9B3028),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(_advisory.summary, style: const TextStyle(height: 1.5)),
            const SizedBox(height: 8),
            Text(
              'Model confidence is not diagnostic certainty.',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
            ),
            if (widget.selectedCrop != null &&
                !widget.selectedCrop!
                    .matchesClass(widget.prediction.best.label)) ...[
              const SizedBox(height: 12),
              _callout(
                theme,
                'You selected ${widget.selectedCrop!.title}, but the model result is for ${crop.title}. Check the photo and crop before following this advice.',
                icon: Icons.info_outline_rounded,
              ),
            ],
            if (score < 0.60) ...[
              const SizedBox(height: 10),
              _callout(
                theme,
                'Low confidence. Try a brighter, closer photo of one leaf and confirm with a local plant-health adviser.',
                icon: Icons.tips_and_updates_outlined,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAlternativeMatches(ThemeData theme) {
    final alternatives = widget.prediction.alternatives.skip(1).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Wrap(
          spacing: 14,
          runSpacing: 8,
          children: [
            Text('Other possible matches:', style: theme.textTheme.labelLarge),
            for (final score in alternatives)
              Text(
                '${displayDiseaseName(score.label)} · ${(score.probability * 100).toStringAsFixed(1)}%',
                style:
                    theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs(ThemeData theme) {
    const labels = ['Disease Info', 'Cause', 'Prevention', 'Treatment'];
    const icons = [
      Icons.eco_rounded,
      Icons.biotech_rounded,
      Icons.verified_user_rounded,
      Icons.medication_rounded,
    ];

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List<Widget>.generate(labels.length, (index) {
            final selected = _activeTab == index;
            return InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => setState(() => _activeTab = index),
              child: Container(
                constraints: const BoxConstraints(minWidth: 96),
                padding: const EdgeInsets.fromLTRB(14, 15, 14, 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected
                          ? theme.colorScheme.primary
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      icons[index],
                      color:
                          selected ? theme.colorScheme.primary : Colors.black54,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      labels[index],
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: selected
                            ? theme.colorScheme.primary
                            : Colors.black54,
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildTabContent(ThemeData theme, {required Key key}) {
    switch (_activeTab) {
      case 1:
        return Column(
          key: key,
          children: [
            _textSectionCard(
              theme,
              title: 'Causal organism',
              icon: Icons.biotech_rounded,
              text: _sections.cause,
              tint: const Color(0xFFFFF3E1),
            ),
          ],
        );
      case 2:
        return Column(
          key: key,
          children: [
            _listSectionCard(
              theme,
              title: 'Prevention',
              icon: Icons.verified_user_rounded,
              items: _sections.prevention,
              tint: const Color(0xFFE8F6EA),
            ),
          ],
        );
      case 3:
        return Column(
          key: key,
          children: [
            _listSectionCard(
              theme,
              title: 'Treatment and next steps',
              icon: Icons.medication_rounded,
              items: _sections.treatment,
              tint: const Color(0xFFFFF3E1),
            ),
            const SizedBox(height: 12),
            _listSectionCard(
              theme,
              title: 'Practical advice',
              icon: Icons.checklist_rounded,
              items: _advisory.actions,
              tint: const Color(0xFFE8F6EA),
            ),
          ],
        );
      default:
        return Column(
          key: key,
          children: [
            _listSectionCard(
              theme,
              title: 'Symptoms',
              icon: Icons.eco_rounded,
              items: _sections.symptoms,
              tint: const Color(0xFFE8F6EA),
            ),
            const SizedBox(height: 12),
            _textSectionCard(
              theme,
              title: 'Causal organism',
              icon: Icons.biotech_rounded,
              text: _sections.cause,
              tint: const Color(0xFFFFF3E1),
            ),
            if (_sections.favorableConditions.isNotEmpty) ...[
              const SizedBox(height: 12),
              _listSectionCard(
                theme,
                title: 'Favourable conditions',
                icon: Icons.thermostat_rounded,
                items: _sections.favorableConditions,
                tint: const Color(0xFFE8F6EA),
              ),
            ],
          ],
        );
    }
  }

  Widget _listSectionCard(
    ThemeData theme, {
    required String title,
    required IconData icon,
    required List<String> items,
    required Color tint,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: tint,
                  foregroundColor: const Color(0xFF1F704C),
                  child: Icon(icon),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: const Color(0xFF164C37),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 7),
                      child:
                          Icon(Icons.circle, size: 7, color: Color(0xFF2E8B57)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                        child:
                            Text(item, style: const TextStyle(height: 1.45))),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _textSectionCard(
    ThemeData theme, {
    required String title,
    required IconData icon,
    required String text,
    required Color tint,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: tint,
              foregroundColor: const Color(0xFF1F704C),
              child: Icon(icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: const Color(0xFF164C37),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(text, style: const TextStyle(height: 1.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSource() {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: _openSource,
        icon: const Icon(Icons.open_in_new_rounded, size: 18),
        label: Text(_advisory.sourceTitle, textAlign: TextAlign.left),
      ),
    );
  }

  Widget _buildActions(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Scan Another'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              side: BorderSide(color: theme.colorScheme.primary, width: 1.5),
              foregroundColor: theme.colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: _saveAdvisory,
            icon: const Icon(Icons.description_outlined),
            label: const Text('Save Advisory'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              backgroundColor: const Color(0xFF087A51),
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _callout(ThemeData theme, String message, {required IconData icon}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(height: 1.4))),
        ],
      ),
    );
  }

  CropType _cropForLabel(String label) {
    for (final crop in CropType.values) {
      if (crop.matchesClass(label)) return crop;
    }
    return CropType.tomato;
  }

  Future<void> _openSource() async {
    final uri = Uri.parse(_advisory.sourceUrl);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the advisory link.')),
      );
    }
  }

  Future<void> _saveAdvisory() async {
    final buffer = StringBuffer()
      ..writeln('CropCare advisory')
      ..writeln(displayDiseaseName(widget.prediction.best.label))
      ..writeln(
          'Model confidence: ${(widget.prediction.best.probability * 100).toStringAsFixed(1)}%')
      ..writeln()
      ..writeln(_advisory.summary)
      ..writeln()
      ..writeln('Treatment and next steps:');
    for (final item in _sections.treatment) {
      buffer.writeln('• $item');
    }
    for (final item in _advisory.actions) {
      buffer.writeln('• $item');
    }
    buffer
      ..writeln()
      ..writeln('Source: ${_advisory.sourceTitle}')
      ..writeln(_advisory.sourceUrl);
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Advisory copied. Paste it into a note to keep it.')),
    );
  }
}
