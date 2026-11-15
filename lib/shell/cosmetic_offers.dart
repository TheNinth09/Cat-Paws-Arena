class CosmeticOffer {
  const CosmeticOffer({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.art,
    required this.leiPrice,
    required this.items,
    this.extraArt,
  });

  final String id, title, subtitle, art, leiPrice;
  final String? extraArt;
  final List<String> items;
}

const cosmeticOffers = [
  CosmeticOffer(
    id: 'bundle_pirate',
    title: 'PACHET PIRAT',
    subtitle: 'Bandană + bentiță',
    art: 'acc_pirate_bandana',
    extraArt: 'acc_ninja_headband',
    leiPrice: '14.99 LEI',
    items: ['acc_pirate_bandana', 'acc_ninja_headband'],
  ),
  CosmeticOffer(
    id: 'bundle_witch',
    title: 'PACHET VRĂJITOARE',
    subtitle: 'Pălărie + fundiță',
    art: 'acc_witch_hat',
    extraArt: 'acc_pink_bow',
    leiPrice: '17.99 LEI',
    items: ['acc_witch_hat', 'acc_pink_bow'],
  ),
];
