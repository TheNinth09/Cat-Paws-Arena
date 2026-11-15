import '../catalog.dart';

// Proposed launch economy. `pawsBalance` is the contract's earned-paws field;
// it is not the legacy `coins` balance.
const int dailyMatchCount = 5;
const double dailyWinRate = 0.5;
const int earnedPawsPerWin = 100;
const int launchCosmeticPawsPrice = 2500;

final launchCosmetics = [
  for (var i = 0; i < accessories.length; i++)
    (
      id: accessories[i],
      name: accessoryNames[i],
      pawsPrice: launchCosmeticPawsPrice,
    ),
];

int get expectedEarnedPawsPerDay =>
    (dailyMatchCount * dailyWinRate * earnedPawsPerWin).round();

int get launchCosmeticsTotalPawsPrice =>
    launchCosmetics.fold<int>(0, (sum, item) => sum + item.pawsPrice);

double get daysToEarnEveryLaunchCosmetic =>
    launchCosmeticsTotalPawsPrice / expectedEarnedPawsPerDay;
