class DiseaseAdvisory {
  const DiseaseAdvisory({
    required this.summary,
    required this.actions,
    required this.sourceTitle,
    required this.sourceUrl,
    this.urgent = false,
  });

  final String summary;
  final List<String> actions;
  final String sourceTitle;
  final String sourceUrl;
  final bool urgent;
}

const Map<String, DiseaseAdvisory> diseaseAdvisories = {
  'Apple___Apple_scab': DiseaseAdvisory(
    summary:
        'Apple scab is favored by wet foliage and can cause leaf loss and poor-quality fruit.',
    actions: [
      'Rake, remove, or finely mulch fallen leaves to reduce the fungus overwintering nearby.',
      'Prune to open the canopy so leaves dry faster; consider scab-resistant varieties for future planting.',
      'Ask a local fruit-tree adviser about any fungicide schedule; preventive treatments do not cure existing lesions.',
    ],
    sourceTitle: 'University of Minnesota Extension: Apple scab',
    sourceUrl:
        'https://extension.umn.edu/garden-and-home/yard-and-garden/gardening-in-minnesota/yard-and-garden-problems/apple-scab',
  ),
  'Apple___Black_rot': DiseaseAdvisory(
    summary:
        'Black rot can affect apple leaves, fruit, and woody branches; a photo alone cannot confirm it.',
    actions: [
      'Remove mummified fruit and dead or diseased wood where practical, and dispose of infected debris.',
      'Keep the tree vigorous and inspect branches for sunken or cracked cankers.',
      'Have extensive branch or trunk cankers checked by a local fruit-tree specialist.',
    ],
    sourceTitle: 'Penn State Extension: Apple black rot and frogeye leaf spot',
    sourceUrl:
        'https://extension.psu.edu/pome-fruit-disease-black-rot-and-frogeye-leaf-spot',
  ),
  'Apple___Cedar_apple_rust': DiseaseAdvisory(
    summary:
        'Cedar-apple rust needs both an apple-family host and a juniper or cedar host; it is often a minor problem.',
    actions: [
      'Use resistant apple varieties where suitable and keep the canopy open for airflow.',
      'Avoid planting junipers or eastern red cedar close to apple trees when planning a new landscape.',
      'Removing distant junipers is usually not a reliable fix because spores can travel long distances.',
    ],
    sourceTitle: 'University of Minnesota Extension: Cedar-apple rust',
    sourceUrl:
        'https://extension.umn.edu/garden-and-home/yard-and-garden/gardening-in-minnesota/yard-and-garden-problems/cedar-apple-rust',
  ),
  'Apple___healthy': DiseaseAdvisory(
    summary:
        'The model did not recognize a disease in this image. That does not rule out early or hidden symptoms.',
    actions: [
      'Keep scouting new leaves and fruit, especially after prolonged wet weather.',
      'Remove fallen leaves in autumn and maintain an open canopy.',
      'If symptoms continue, photograph several leaves and ask a local Extension or horticulture adviser.',
    ],
    sourceTitle: 'University of Minnesota Extension: Preventing plant diseases',
    sourceUrl:
        'https://extension.umn.edu/garden-and-home/yard-and-garden/gardening-in-minnesota/yard-and-garden-problems/preventing-plant-diseases-in-the-garden',
  ),
  'Corn_(maize)___Common_rust_': DiseaseAdvisory(
    summary:
        'Common rust often causes limited loss in commercial hybrids, though cool, wet weather can increase it.',
    actions: [
      'Scout the field and note how much of the canopy is affected and the crop growth stage.',
      'Choose resistant hybrids when planning future plantings.',
      'Ask a local crop adviser before using a fungicide; timing and expected yield response depend on the field.',
    ],
    sourceTitle: 'University of Minnesota Extension: Common rust on corn',
    sourceUrl:
        'https://extension.umn.edu/agriculture/crop-production/corn/common-rust-on-corn',
  ),
  'Corn_(maize)___healthy': DiseaseAdvisory(
    summary:
        'The model did not recognize a disease in this image. Continue scouting the crop through the season.',
    actions: [
      'Inspect multiple plants across the field, including leaves around and above the ear.',
      'Use hybrids suited to local conditions and follow regional crop-management guidance.',
      'Recheck if rust-colored pustules or long gray-brown lesions appear.',
    ],
    sourceTitle: 'University of Minnesota Extension: Corn disease resources',
    sourceUrl: 'https://extension.umn.edu/corn/corn-pest-management',
  ),
  'Corn_(maize)___Northern_Leaf_Blight': DiseaseAdvisory(
    summary:
        'Northern corn leaf blight is a fungal leaf disease that can persist in infected corn residue.',
    actions: [
      'Prefer resistant or tolerant hybrids for future planting.',
      'Where practical, rotate out of corn and manage infected residue according to local tillage and soil-conservation advice.',
      'Scout upper leaves near tasseling and ask a local crop adviser whether additional action is justified.',
    ],
    sourceTitle: 'University of Minnesota Extension: Northern corn leaf blight',
    sourceUrl:
        'https://extension.umn.edu/agriculture/crop-production/corn/northern-corn-leaf-blight',
  ),
  'Potato___Early_blight': DiseaseAdvisory(
    summary:
        'Early blight can survive in crop debris and often begins on older leaves.',
    actions: [
      'Use healthy seed potatoes and rotate potatoes and related crops away from the same area for at least two years.',
      'Water at soil level, mulch to limit soil splash, and keep foliage dry when possible.',
      'Remove spotted leaves carefully and clean tools after working on affected plants.',
    ],
    sourceTitle:
        'University of Minnesota Extension: Early blight in tomato and potato',
    sourceUrl:
        'https://extension.umn.edu/agriculture/specialty-crops/vegetable-farming/disease-management/early-blight-in-tomato-and-potato',
  ),
  'Potato___healthy': DiseaseAdvisory(
    summary:
        'The model did not recognize a disease in this image. Continue checking both leaves and tubers.',
    actions: [
      'Start with certified, healthy seed potatoes and remove volunteer potato plants.',
      'Rotate crops and avoid leaving diseased plant material in the garden or field.',
      'Seek a local diagnosis if spots, rapid wilting, or tuber discoloration develops.',
    ],
    sourceTitle: 'University of Minnesota Extension: Growing potatoes',
    sourceUrl:
        'https://extension.umn.edu/garden-and-home/yard-and-garden/gardening-in-minnesota/growing-potatoes',
  ),
  'Potato___Late_blight': DiseaseAdvisory(
    summary:
        'Possible late blight needs prompt confirmation because it can spread quickly and affect potato tubers.',
    actions: [
      'Contact a local Extension plant clinic or agriculture adviser promptly and share clear photos of several plants.',
      'Avoid moving wet foliage or plant debris through the crop while arranging a diagnosis.',
      'Check nearby potato and tomato plants; follow local guidance for handling suspected plants and cull piles.',
    ],
    sourceTitle:
        'University of Minnesota Extension: Late blight of tomato and potato',
    sourceUrl:
        'https://extension.umn.edu/agriculture/specialty-crops/vegetable-farming/disease-management/late-blight',
    urgent: true,
  ),
  'Tomato___Bacterial_spot': DiseaseAdvisory(
    summary:
        'Bacterial spot can spread in splashing water and on hands or tools when foliage is wet.',
    actions: [
      'Remove affected leaves when plants are dry, and clean tools before working on healthy plants.',
      'Water at the base, improve spacing and airflow, and avoid handling plants while wet.',
      'Rotate tomatoes and related crops; choose disease-free seed and transplants.',
    ],
    sourceTitle:
        'University of Minnesota Extension: Bacterial spot of tomato and pepper',
    sourceUrl:
        'https://extension.umn.edu/agriculture/specialty-crops/vegetable-farming/disease-management/bacterial-spot-of-tomato-and-pepper',
  ),
  'Tomato___Early_blight': DiseaseAdvisory(
    summary:
        'Early blight commonly starts on older, lower leaves and can spread from soil splash and plant debris.',
    actions: [
      'Remove spotted leaves early; avoid removing more than one-third of the plant foliage at once.',
      'Use mulch, stake plants for airflow, and water at the base rather than over the leaves.',
      'Rotate tomatoes and related crops for two years and clean tools after pruning.',
    ],
    sourceTitle:
        'University of Minnesota Extension: Early blight in tomato and potato',
    sourceUrl:
        'https://extension.umn.edu/agriculture/specialty-crops/vegetable-farming/disease-management/early-blight-in-tomato-and-potato',
  ),
  'Tomato___healthy': DiseaseAdvisory(
    summary:
        'The model did not recognize a disease in this image. Continue to monitor new growth and fruit.',
    actions: [
      'Water near the soil and allow good airflow around plants.',
      'Remove fallen or infected plant debris and rotate tomato-family crops.',
      'If symptoms appear, photograph several leaves and consult a local plant-health adviser.',
    ],
    sourceTitle: 'University of Minnesota Extension: Preventing plant diseases',
    sourceUrl:
        'https://extension.umn.edu/garden-and-home/yard-and-garden/gardening-in-minnesota/yard-and-garden-problems/preventing-plant-diseases-in-the-garden',
  ),
  'Tomato___Late_blight': DiseaseAdvisory(
    summary:
        'Possible late blight needs prompt confirmation because it can spread quickly in cool, wet conditions.',
    actions: [
      'Contact a local Extension plant clinic or agriculture adviser promptly and share photos of multiple leaves and stems.',
      'Avoid moving wet leaves or plant debris between plants while arranging confirmation.',
      'Keep foliage as dry as possible and follow local guidance for suspect plants and crop debris.',
    ],
    sourceTitle:
        'University of Minnesota Extension: Late blight of tomato and potato',
    sourceUrl:
        'https://extension.umn.edu/agriculture/specialty-crops/vegetable-farming/disease-management/late-blight',
    urgent: true,
  ),
  'Tomato___Leaf_Mold': DiseaseAdvisory(
    summary:
        'Tomato leaf mold is favored by high humidity and prolonged moisture on foliage.',
    actions: [
      'Increase spacing and airflow; stake, string, or prune carefully to reduce a dense, humid canopy.',
      'Use drip irrigation or water at the base and avoid wetting leaves.',
      'Remove crop residue at season end and start with clean seed or transplants.',
    ],
    sourceTitle: 'University of Minnesota Extension: Tomato leaf mold',
    sourceUrl:
        'https://extension.umn.edu/agriculture/specialty-crops/vegetable-farming/disease-management/tomato-leaf-mold',
  ),
  'Tomato___Target_Spot': DiseaseAdvisory(
    summary:
        'Target spot can begin inside a dense tomato canopy; other leaf diseases can look similar in a photo.',
    actions: [
      'Improve spacing and airflow, and avoid prolonged leaf wetness from overhead irrigation.',
      'Remove infected debris and inspect inner-canopy leaves as well as outer leaves.',
      'Get a local diagnosis before considering disease-specific treatments.',
    ],
    sourceTitle: 'University of Florida IFAS Extension: Target spot of tomato',
    sourceUrl: 'https://edis.ifas.ufl.edu/publication/PP351',
  ),
};

class DiseaseSections {
  const DiseaseSections({
    required this.cause,
    required this.symptoms,
    required this.prevention,
    required this.treatment,
    this.favorableConditions = const [],
  });

  final String cause;
  final List<String> symptoms;
  final List<String> favorableConditions;
  final List<String> prevention;
  final List<String> treatment;
}

const DiseaseSections _healthySections = DiseaseSections(
  cause: 'No disease class was identified as the top model result.',
  symptoms: [
    'The model did not find a trained disease pattern that scored highest.',
    'This image result cannot rule out early, hidden, or different crop problems.',
  ],
  favorableConditions: [],
  prevention: [
    'Continue scouting new growth and check more than one plant.',
    'Use healthy planting material, good airflow, and watering practices suited to the crop.',
    'Remove crop debris when recommended for that disease and region.',
  ],
  treatment: [
    'No treatment is recommended based only on this image.',
    'If symptoms continue or spread, ask a local plant-health adviser to confirm the cause.',
  ],
);

const Map<String, DiseaseSections> diseaseSections = {
  'Apple___Apple_scab': DiseaseSections(
    cause:
        'Venturia inaequalis, a fungus that infects apple and crabapple leaves and fruit.',
    symptoms: [
      'Olive-green to dark scabby spots on leaves.',
      'Dark, rough lesions may also appear on fruit.',
      'Severe leaf infection can lead to early leaf drop.',
    ],
    favorableConditions: [
      'Repeated rain or irrigation that keeps leaves wet.',
      'A dense canopy that dries slowly.',
    ],
    prevention: [
      'Remove or finely mulch fallen leaves to reduce overwintering fungus.',
      'Prune to open the canopy so foliage dries faster.',
      'Consider scab-resistant varieties for future planting.',
    ],
    treatment: [
      'Sanitation helps reduce new infections but does not cure existing lesions.',
      'Ask a local fruit-tree adviser about preventive treatments appropriate to the region and crop.',
    ],
  ),
  'Apple___Black_rot': DiseaseSections(
    cause:
        'Diplodia seriata, also known by the older name Botryosphaeria obtusa.',
    symptoms: [
      'Round leaf spots with purple borders and tan centers.',
      'Firm fruit rot that can dry into mummified fruit.',
      'Sunken, rough, or cracked cankers on branches.',
    ],
    favorableConditions: [
      'Warm, wet weather and wounds or dead wood on stressed trees.',
    ],
    prevention: [
      'Remove mummified fruit and dead wood that can hold the fungus.',
      'Maintain tree vigor and avoid unnecessary wounds.',
      'Dispose of infected wood according to local guidance.',
    ],
    treatment: [
      'Prune dead or cankered branches where safe and practical, then remove the debris.',
      'Have large branch or trunk cankers assessed by a fruit-tree specialist.',
    ],
  ),
  'Apple___Cedar_apple_rust': DiseaseSections(
    cause:
        'Gymnosporangium rust fungi that use both an apple-family host and a juniper or cedar host.',
    symptoms: [
      'Bright yellow to orange spots on apple leaves.',
      'Spore-producing projections may develop on the underside of leaf spots later in the season.',
    ],
    favorableConditions: [
      'Wet spring weather and susceptible apple and juniper/cedar hosts in the area.',
    ],
    prevention: [
      'Choose resistant apple varieties where suitable.',
      'Keep the apple canopy open for airflow.',
      'Avoid planting new junipers or eastern red cedar close to apple trees.',
    ],
    treatment: [
      'This disease is often minor and may need no treatment.',
      'Ask a local tree-health adviser if infection is extensive or fruit is affected.',
    ],
  ),
  'Apple___healthy': _healthySections,
  'Corn_(maize)___Common_rust_': DiseaseSections(
    cause:
        'Puccinia sorghi, a rust fungus that produces spores in leaf pustules.',
    symptoms: [
      'Rust-colored to dark-brown raised pustules on both leaf surfaces.',
      'Pustules may darken as they age; severe infection can cause leaf yellowing.',
    ],
    favorableConditions: [
      'Cool, wet weather, heavy dew, and prolonged leaf wetness.',
    ],
    prevention: [
      'Choose resistant corn hybrids suited to local conditions.',
      'Scout the field regularly, especially during cool, wet weather.',
    ],
    treatment: [
      'Assess disease level, crop stage, and expected yield before deciding on action.',
      'Ask a local crop adviser whether a fungicide is justified; follow local guidance and product labels.',
    ],
  ),
  'Corn_(maize)___healthy': _healthySections,
  'Corn_(maize)___Northern_Leaf_Blight': DiseaseSections(
    cause:
        'Exserohilum turcicum, a fungus that can survive in infected corn residue.',
    symptoms: [
      'Long, cigar-shaped gray-green to tan lesions on leaves.',
      'Lesions may enlarge and merge during prolonged leaf wetness.',
    ],
    favorableConditions: [
      'Moderate temperatures with long periods of leaf wetness or dew.',
    ],
    prevention: [
      'Plant resistant or tolerant hybrids when available.',
      'Rotate crops and manage infected residue where practical and consistent with soil-conservation needs.',
      'Scout upper leaves during the growing season.',
    ],
    treatment: [
      'Check disease severity and crop stage with a local crop adviser.',
      'Use any crop-protection product only when locally recommended and according to its label.',
    ],
  ),
  'Potato___Early_blight': DiseaseSections(
    cause:
        'Alternaria solani, a fungus that can persist in infected crop debris.',
    symptoms: [
      'Dark leaf spots, often with concentric rings.',
      'Symptoms commonly begin on older, lower leaves.',
      'Infection can cause yellowing and leaf loss.',
    ],
    favorableConditions: [
      'Warm, humid conditions, older foliage, and infected crop debris.',
    ],
    prevention: [
      'Use healthy seed potatoes and rotate away from potato-family crops.',
      'Mulch to limit soil splash and water near the soil rather than over leaves.',
      'Keep plants spaced for airflow and remove volunteer potato plants.',
    ],
    treatment: [
      'Remove spotted leaves carefully and clean tools after use.',
      'Ask a local potato adviser about field-specific management if the disease is spreading.',
    ],
  ),
  'Potato___healthy': _healthySections,
  'Potato___Late_blight': DiseaseSections(
    cause:
        'Phytophthora infestans, a rapidly spreading water mold that affects potato and tomato.',
    symptoms: [
      'Large dark or water-soaked leaf blotches, sometimes with pale green edges.',
      'White growth may appear on infected tissue in humid conditions.',
      'Potato tubers may become discolored or rot.',
    ],
    favorableConditions: [
      'Cool, wet, humid weather that allows rapid spread.',
    ],
    prevention: [
      'Use certified seed potatoes and manage volunteer potatoes and cull piles.',
      'Avoid prolonged leaf wetness and check nearby potato and tomato plants.',
      'Follow regional late-blight alerts and crop guidance.',
    ],
    treatment: [
      'Promptly contact a local Extension plant clinic or agriculture adviser to confirm the result.',
      'Avoid carrying wet foliage or plant debris through the crop while arranging diagnosis.',
      'Follow local instructions for suspected plants and crop debris.',
    ],
  ),
  'Tomato___Bacterial_spot': DiseaseSections(
    cause:
        'Xanthomonas bacteria; several related species can cause bacterial spot on tomato.',
    symptoms: [
      'Small dark or brown leaf spots, sometimes with yellow halos.',
      'Spots may also appear on stems or fruit.',
      'Splashing water, wet foliage, hands, and tools can spread bacteria.',
    ],
    favorableConditions: [
      'Warm, humid weather, rain splash, and overhead irrigation.',
    ],
    prevention: [
      'Start with disease-free seed and transplants.',
      'Water at the base and avoid working with wet plants.',
      'Clean tools and rotate tomato-family crops as local guidance recommends.',
    ],
    treatment: [
      'Remove affected leaves when plants are dry and sanitize tools between plants.',
      'Seek local advice if symptoms spread; plants cannot be cured by removing only a few spots.',
    ],
  ),
  'Tomato___Early_blight': DiseaseSections(
    cause: 'Alternaria species that cause early blight on tomato.',
    symptoms: [
      'Dark brown leaf spots with concentric, target-like rings.',
      'Symptoms often begin on older, lower leaves.',
      'Yellowing and leaf drop can occur around lesions.',
    ],
    favorableConditions: [
      'Warm, wet weather and splashing water from infected soil or debris.',
    ],
    prevention: [
      'Use mulch to reduce soil splash and water at the base of plants.',
      'Stake plants for airflow and rotate tomato-family crops.',
      'Remove plant debris and volunteer tomatoes where appropriate.',
    ],
    treatment: [
      'Remove spotted leaves early, taking care not to remove too much foliage at once.',
      'Clean tools after pruning and ask a local adviser if the disease is progressing.',
    ],
  ),
  'Tomato___healthy': _healthySections,
  'Tomato___Late_blight': DiseaseSections(
    cause:
        'Phytophthora infestans, a rapidly spreading water mold that affects tomato and potato.',
    symptoms: [
      'Large dark leaf blotches that may have pale green edges.',
      'Dark lesions can affect stems; white growth may appear in humid conditions.',
      'Fruit can develop firm, dark brown spots.',
    ],
    favorableConditions: [
      'Cool, wet, humid conditions with prolonged leaf wetness.',
    ],
    prevention: [
      'Keep foliage as dry as practical and provide good airflow.',
      'Inspect nearby potato and tomato plants, especially during cool, wet weather.',
      'Remove crop debris and volunteers according to local guidance.',
    ],
    treatment: [
      'Promptly contact a local Extension plant clinic or agriculture adviser to confirm the result.',
      'Avoid moving wet leaves or plant debris between plants while arranging diagnosis.',
      'Follow local instructions for suspected plants and crop debris.',
    ],
  ),
  'Tomato___Leaf_Mold': DiseaseSections(
    cause:
        'Passalora fulva, a fungus favored by humid conditions and prolonged leaf wetness.',
    symptoms: [
      'Pale yellow patches may appear on the upper leaf surface.',
      'Olive-gray mold may develop on the corresponding underside.',
      'Dense, humid canopies are at higher risk.',
    ],
    favorableConditions: [
      'High humidity, prolonged leaf wetness, and poor air circulation.',
    ],
    prevention: [
      'Increase plant spacing and airflow through the canopy.',
      'Use drip irrigation or water at the base to keep foliage dry.',
      'Remove crop residue at season end and use clean planting material.',
    ],
    treatment: [
      'Remove affected leaves when practical and improve ventilation.',
      'Ask a local tomato adviser to confirm the disease if symptoms continue.',
    ],
  ),
  'Tomato___Target_Spot': DiseaseSections(
    cause:
        'Corynespora cassiicola, a fungus that can cause leaf and fruit lesions.',
    symptoms: [
      'Brown leaf lesions may develop lighter centers and darker concentric rings.',
      'Disease can begin in the inner canopy and cause defoliation.',
      'Other tomato leaf diseases can look similar in photos.',
    ],
    favorableConditions: [
      'Warm, humid conditions, long leaf-wetness periods, and dense canopies.',
    ],
    prevention: [
      'Improve spacing and airflow and avoid prolonged leaf wetness.',
      'Remove infected crop debris and scout the inner canopy.',
    ],
    treatment: [
      'Get a local diagnosis before choosing disease-specific treatment.',
      'Ask a local Extension or crop adviser for current recommendations.',
    ],
  ),
};

String displayDiseaseName(String className) {
  return className.replaceAll('___', ' · ').replaceAll('_', ' ').trim();
}
